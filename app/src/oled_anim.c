
#include <device.h>
#include <drivers/display.h>
#include <zephyr.h>
#include <logging/log.h>
#include "cat_keyboard_animation.h"

LOG_MODULE_REGISTER(oled_cat_anim, LOG_LEVEL_DBG);

#define ANIMATION_FRAMES 3
#define FRAME_DURATION_MS 200

const uint8_t *frames[] = {
    cat_frame_0,
    cat_frame_1,
    cat_frame_2
};

#define FRAME_WIDTH 128
#define FRAME_HEIGHT 64
#define FRAME_BUFFER_SIZE (FRAME_WIDTH * FRAME_HEIGHT / 8)

void main(void) {
    const struct device *display_dev;
    display_dev = DEVICE_DT_GET(DT_CHOSEN(zephyr_display));

    if (!device_is_ready(display_dev)) {
        LOG_ERR("Display device not ready");
        return;
    }

    int frame = 0;
    while (1) {
        display_write(display_dev, 0, 0, &((struct display_buffer_descriptor) {
            .buf_size = FRAME_BUFFER_SIZE,
            .width = FRAME_WIDTH,
            .height = FRAME_HEIGHT,
            .pitch = FRAME_WIDTH,
        }), frames[frame]);

        frame = (frame + 1) % ANIMATION_FRAMES;
        k_msleep(FRAME_DURATION_MS);
    }
}
