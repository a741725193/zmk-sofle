# STORAGE MODE
`key map` 변경 후 `firmaware`를 넣기 위해선 키보드를 `Storage mode` 로 전환 시켜야 합니다.
`Storage mode`를 변경 하는 방법을 소개 합니다.

## Left keyboard

on/off switch를 off로 두고 reset 스위치를 누른 상태에서 Switch를 on 으로 변경합니다.
파란불이 깜박일 때 까지 reset 버튼을 누르고 있다가 reset 버튼에서 손을 때면 storage mode로 들어가며 LCD에 아무것도 표시되지 않습니다.

그리고 MACOS 기준으로 Finder 에 `NICENANO` 이동식 디스크가 표시 됩니다.

![image](resource/images/nicenano_storagemode.png)

## Right Keyboard

on/off switch를 off로 두고 reset 스위치를 누른 상태에서 Switch를 on 으로 변경합니다.
파란불이 깜박일 때 까지 reset 버튼을 누르고 있다가 reset 버튼에서 손을 때면 storage mode로 들어가며 LCD에 아무것도 표시되지 않습니다.

그리고 MACOS 기준으로 Finder 에 `NICENANO` 이동식 디스크가 표시 됩니다.

![image](resource/images/nicenano_storagemode.png)

# FIRMWARE 적용하기

Action Tab 에서 최근 PUSH와 함께 동작중인 action을 확인할 수 있습니다. 1개는 `firmware.zip`을 또 다른 action은 kaymap 변경에 따른 keymap 이미지를 그린다.
이 중에 `firmware.zip`를 다운 받아 압축을 해제한다. 그리고 `*.uf2` 파일 3개가 보이게 되는데, `*_right.uf2` 는 오른쪽 키보드에 넣습니다. `*_left.uf2`와 `settings_reset-nice_nano_v2-zmk.uf2` 는 왼쪽 키도드에 넣습니다.
스토리지에 파일을 넣으면 자동으로 storage mode는 종료되고 키보드가 재시작 하며 조금전 스토리지 모드에 넣었던 firmware가 적용되며 keymap이 변경되게 된다.

# Refresh fork

`fork`를 하게 된경우 `git remote --verbose` 를 해보면 아래와 같이 표현되게 됩니다.

```bash
@static-voidmain ➜ /workspaces/zmk-sofle (main) $ git remote --verbose
origin  https://github.com/static-voidmain/zmk-sofle (fetch)
origin  https://github.com/static-voidmain/zmk-sofle (push)
upstream        https://github.com/a741725193/zmk-sofle.git (fetch)
upstream        https://github.com/a741725193/zmk-sofle.git (push)
```

여기서 `origin` 은 `fork` 된 내 소스코드이고, `upstream` 은 내가 `fork` 한 소스 repostory 입니다.

```bash
@static-voidmain ➜ /workspaces/zmk-sofle (main) $ git fetch upstream
@static-voidmain ➜ /workspaces/zmk-sofle (main) $ git merge upstream/main
```

하여 Pull requeset를 만들어 소스코드에 push 하면 `a741725193/zmk-sofle` repository 최신 소스코드를 `fork`한 나의 소스코드에 적용하게 된다.