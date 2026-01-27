#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ZMK Dongle Flasher ===${NC}\n"

# Request sudo access upfront (before keyboard stops working)
echo -e "${YELLOW}Requesting sudo access (needed for mounting)...${NC}"
sudo -v || {
    echo -e "${RED}Error: sudo access required${NC}"
    exit 1
}

# Keep sudo alive in the background
(while true; do sudo -n true; sleep 50; done) 2>/dev/null &
SUDO_KEEPER_PID=$!

# Cleanup function to kill sudo keeper on exit
cleanup() {
    kill $SUDO_KEEPER_PID 2>/dev/null || true
}
trap cleanup EXIT

echo -e "${GREEN}✓ Sudo access granted${NC}\n"

# Step 1: Wait for GitHub Actions build to complete
echo -e "${YELLOW}[1/5] Checking GitHub Actions build status...${NC}"

# Get the latest workflow run from the build workflow
LATEST_RUN=$(gh run list --workflow "Build ZMK firmware" --limit 1 --json databaseId,status,conclusion --jq '.[0]')

if [ -z "$LATEST_RUN" ]; then
    echo -e "${RED}Error: No workflow runs found${NC}"
    exit 1
fi

RUN_ID=$(echo "$LATEST_RUN" | jq -r '.databaseId')
RUN_STATUS=$(echo "$LATEST_RUN" | jq -r '.status')
RUN_CONCLUSION=$(echo "$LATEST_RUN" | jq -r '.conclusion')

echo "Latest workflow run: #$RUN_ID"
echo "Status: $RUN_STATUS"

if [ "$RUN_STATUS" != "completed" ]; then
    echo -e "${YELLOW}Build is still running. Waiting for completion...${NC}"
    echo "(You can press Ctrl+C to cancel)"
    echo ""

    gh run watch "$RUN_ID" || {
        echo -e "${RED}Error: Failed to watch workflow run${NC}"
        exit 1
    }

    # Get the final conclusion
    RUN_CONCLUSION=$(gh run view "$RUN_ID" --json conclusion --jq '.conclusion')
fi

if [ "$RUN_CONCLUSION" != "success" ]; then
    echo -e "${RED}Error: Workflow run failed with conclusion: $RUN_CONCLUSION${NC}"
    echo "Please check the workflow logs on GitHub"
    exit 1
fi

echo -e "${GREEN}✓ Build completed successfully${NC}\n"

# Step 2: Download artifacts
echo -e "${YELLOW}[2/5] Downloading build artifacts...${NC}"

# Create temp directory
TEMP_DIR=$(mktemp -d)
echo "Using temp directory: $TEMP_DIR"

# Download artifacts from the latest successful run
gh run download "$RUN_ID" --dir "$TEMP_DIR" 2>/dev/null || {
    echo -e "${RED}Error: Failed to download artifacts. Make sure 'gh' CLI is installed and authenticated.${NC}"
    echo "Run: gh auth login"
    rm -rf "$TEMP_DIR"
    exit 1
}

echo -e "${GREEN}✓ Download complete${NC}\n"

# Step 3: Find and extract the dongle firmware
echo -e "${YELLOW}[3/5] Looking for dongle firmware...${NC}"

# Look for the dongle .uf2 file, excluding debug builds
DONGLE_FILE=$(find "$TEMP_DIR" -name "*dongle*.uf2" ! -name "*debug*.uf2" | head -n 1)

if [ -z "$DONGLE_FILE" ]; then
    echo -e "${RED}Error: Could not find dongle firmware file (non-debug)${NC}"
    echo "Contents of download directory:"
    ls -R "$TEMP_DIR"
    echo ""
    echo "Available .uf2 files:"
    find "$TEMP_DIR" -name "*.uf2"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Found firmware: $(basename "$DONGLE_FILE")"
echo -e "${GREEN}✓ Firmware ready${NC}\n"

# Step 4: Wait for bootloader mode
echo -e "${YELLOW}[4/5] Waiting for dongle to enter bootloader mode...${NC}"
echo "Please double-tap the reset button on your dongle now."
echo ""

# Common bootloader labels
BOOTLOADER_LABELS=("NICENANO" "NRF52BOOT" "NICE_NANO" "BOOT" "FEATHERBOOT")
BOOTLOADER_DEVICE=""
TIMEOUT=60
ELAPSED=0

# Temporarily disable exit on error for bootloader detection
set +e

while [ $ELAPSED -lt $TIMEOUT ]; do
    # Check /dev/disk/by-label/ for bootloader
    for label in "${BOOTLOADER_LABELS[@]}"; do
        if [ -L "/dev/disk/by-label/$label" ]; then
            DEVICE=$(readlink -f "/dev/disk/by-label/$label" 2>/dev/null) || continue

            # Skip if it's an nvme device or other non-removable device
            if [[ "$DEVICE" == *"nvme"* ]] || [[ "$DEVICE" == *"mmcblk"* ]]; then
                continue
            fi

            # Get the parent block device (e.g., sda from sda1)
            BLOCK_DEVICE=$(lsblk -no PKNAME "$DEVICE" 2>/dev/null) || BLOCK_DEVICE=""
            if [ -z "$BLOCK_DEVICE" ]; then
                # Fallback: strip trailing digits and partition indicator
                BLOCK_DEVICE=$(basename "$DEVICE" | sed 's/[0-9]*$//' | sed 's/p$//')
            fi

            # Skip if we couldn't determine the block device
            [ -z "$BLOCK_DEVICE" ] && continue

            # Check if it's a removable device (USB devices are removable)
            if [ -f "/sys/block/$BLOCK_DEVICE/removable" ]; then
                IS_REMOVABLE=$(cat "/sys/block/$BLOCK_DEVICE/removable" 2>/dev/null) || continue
                if [ "$IS_REMOVABLE" == "1" ]; then
                    # Check size - bootloaders are typically very small (< 100MB)
                    SIZE_BYTES=$(lsblk -bno SIZE "$DEVICE" 2>/dev/null) || SIZE_BYTES="0"
                    SIZE_MB=$((SIZE_BYTES / 1024 / 1024))

                    if [ "$SIZE_MB" -lt 100 ] && [ "$SIZE_MB" -gt 0 ]; then
                        BOOTLOADER_DEVICE="$DEVICE"
                        BOOTLOADER_LABEL="$label"
                        break 2
                    fi
                fi
            fi
        fi
    done

    # Visual progress indicator
    echo -ne "\rWaiting... ${ELAPSED}s / ${TIMEOUT}s "
    sleep 1
    ((ELAPSED++))
done

echo "" # New line after progress

# Re-enable exit on error
set -e

if [ -z "$BOOTLOADER_DEVICE" ]; then
    echo -e "${RED}Error: Bootloader device not detected after ${TIMEOUT} seconds${NC}"
    echo "Make sure your dongle is connected and in bootloader mode"
    echo "Looked for labels: ${BOOTLOADER_LABELS[*]}"
    echo ""
    echo "Available devices:"
    lsblk -o NAME,LABEL,SIZE,TYPE
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}✓ Bootloader detected: $BOOTLOADER_DEVICE (label: $BOOTLOADER_LABEL)${NC}\n"

# Step 5: Mount and flash firmware
echo -e "${YELLOW}[5/5] Mounting and flashing firmware...${NC}"

# Create temporary mount point
MOUNT_POINT=$(mktemp -d)
echo "Mounting $BOOTLOADER_DEVICE to $MOUNT_POINT"

# Mount the device
sudo mount "$BOOTLOADER_DEVICE" "$MOUNT_POINT" || {
    echo -e "${RED}Error: Failed to mount bootloader${NC}"
    rm -rf "$TEMP_DIR" "$MOUNT_POINT"
    exit 1
}

# Copy firmware (use sudo since mount point is owned by root)
sudo cp "$DONGLE_FILE" "$MOUNT_POINT/" || {
    echo -e "${RED}Error: Failed to copy firmware${NC}"
    sudo umount "$MOUNT_POINT"
    rm -rf "$TEMP_DIR" "$MOUNT_POINT"
    exit 1
}

echo "Copied $(basename "$DONGLE_FILE") to $MOUNT_POINT"

# Sync and unmount
sync
sleep 1

sudo umount "$MOUNT_POINT" || echo -e "${YELLOW}Warning: Device may have already ejected itself${NC}"
rm -rf "$MOUNT_POINT"

echo -e "${GREEN}✓ Firmware flashed successfully${NC}\n"

# Cleanup
rm -rf "$TEMP_DIR"

echo -e "${GREEN}=== Flashing Complete! ===${NC}"
echo "The dongle should reboot automatically and your new firmware is ready."
echo ""