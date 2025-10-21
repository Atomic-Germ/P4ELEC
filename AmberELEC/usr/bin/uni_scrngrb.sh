#!/bin/bash

# Define the folder to scan (current directory by default)
# FOLDER="${1:-.}"
FOLDER="/storage/roms/screenshots/"

# hotkey_ev=/dev/input/by-path/platform-odroidgo3-joypad-event-joystick
hotkey_ev=/dev/input/event2
power_ev=/dev/input/event0

selectkey=BTN_TRIGGER_HAPPY1 #0x2c0

l3key=BTN_TRIGGER_HAPPY3
l3_press="*($l3key), value 1*"
l3_release="*($l3key), value 0*"

hotkey=BTN_TRIGGER_HAPPY5 #0x2C4 function key for r36s models that support it
hotkey_press="*($hotkey), value 1*"
hotkey_release="*($hotkey), value 0*"

pwrkey=KEY_POWER
power_press="*($pwrkey), value 1*"
power_release="*($pwrkey), value 0*"

SCRNGRB_PID=0

kill_grab() {
    PROCESS_LIST=$(pgrep "uni_scrngrb.sh")

    # Convert to an array
    IFS=$'\n' read -rd '' -a PROCESS_ARRAY <<<"$PROCESS_LIST"

    # Get the number of processes
    PROCESS_COUNT=${#PROCESS_ARRAY[@]}

    # Kill all connected process after second instance
    for ((i=2; i<PROCESS_COUNT; i++)); do
        kill "${PROCESS_ARRAY[i]}"
    done
}

pp_shutdown () {
    $(/usr/bin/show_splash.sh)
    $(/usr/bin/sync)
    $(systemctl poweroff)
}


take_the_shot() {
    if [ ! -d "$FOLDER" ]; then
        mkdir -p "$FOLDER"
    fi

    # Find all files matching the naming pattern and count them
    COUNT=$(ls "$FOLDER" | grep -Eo 'u_screenshot_[0-9]+' | sed 's/u_screenshot_//' | sort -n | tail -1)

    # If no screenshots exist, start from 001
    if [[ -z "$COUNT" ]]; then
        NEXT_NUM=1
    else
        NEXT_NUM=$((10#$COUNT + 1))
    fi

    # Format the new filename with zero padding
    NEXT_FILENAME=$(printf "u_screenshot_%03d.png" "$NEXT_NUM")

    echo "$NEXT_FILENAME"

    fbgrab -d /dev/fb0 "${FOLDER}${NEXT_FILENAME}"
}


screen_grab() {
    evtest "$hotkey_ev" | while read line; do
        case $line in
            ($l3_press)
                echo "grabbing frame buffer now"
                take_the_shot
            ;;
            ($l3_release)
                exit
            ;;
        esac
    done
}


pwr_grab() {
    evtest "$power_ev" | while read line; do
        case $line in
            ($power_press)
                pp_shutdown
            ;;
        esac
    done
}


hotkey_proc() {
    evtest "$hotkey_ev" | while read line; do
        case $line in
            ($hotkey_press)
                echo "FN Key Pressed"
                screen_grab & pwr_grab &
            ;;
            ($hotkey_release)
                echo "FN key released..."
                kill_grab
            ;;
        esac
    done
}

hotkey_proc


