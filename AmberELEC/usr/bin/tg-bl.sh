#!/bin/bash

#toggle backlight
BL_POWER="/sys/class/backlight/backlight/bl_power"
BL_STATE="$(cat ${BL_POWER})"

if [ ${BL_STATE} == 0 ]; then
    echo 1 > ${BL_POWER}
else
    echo 0 > ${BL_POWER}
fi

exit 0
