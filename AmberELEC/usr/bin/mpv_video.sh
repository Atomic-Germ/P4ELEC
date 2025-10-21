#!/bin/bash

export SDL_GAMECONTROLLERCONFIG=$(grep R36S "/storage/.config/mpv/gamecontrollerdb.txt")

/usr/bin/gptokeyb "mpv" -c "/storage/.config/mpv/mpv.gptk" -k "mpv" &

/usr/bin/mpv --input-ipc-server=/tmp/mpvsocket "${1}"

# /usr/bin/mpv --fs "${1}"

echo 0 > "/sys/class/backlight/backlight/bl_power"

kill -9 $(pgrep gptokey)

exit 0
