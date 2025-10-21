#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024-present AmberELEC (https://github.com/AmberELEC)

hotkey_ev=/dev/input/by-path/platform-odroidgo3-joypad-event-joystick
power_ev=/dev/input/by-path/platform-ff180000.i2c-event
# hotkey=BTN_TRIGGER_HAPPY1 #0x2c0
hotkey=BTN_TRIGGER_HAPPY5 #0x2C4 function key for r36s models that support it
hotkey_code=0x2c4
powerkey=KEY_POWER

# date +%s

ARCH="$(cat /storage/.config/.OS_ARCH)"
if [ "${ARCH}" == "RG351P" ] || [ "${ARCH}" == "RG351V" ]; then
    hotkey_ev=/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick
    hotkey=BTN_TR
    hotkey_code=0x137
elif [ "${ARCH}" == "RG552" ]; then
    power_ev=/dev/input/by-path/platform-rockchip-key-event
fi

# check if we have custom variables
if test -f /storage/.config/custom.cfg; then
    source /storage/.config/custom.cfg
fi

hotkey_press="*($hotkey), value 1*"
hotkey_release="*($hotkey), value 0*"
power_key="($powerkey), value 1"
POWER_PID=0
HOTKEY_PID=0

extract_info() {
    local string="$1"
    
    # Extracting the dynamic part after --rom
    rom_part="${string#*--rom }"
    rom_part="${rom_part%% --*}"

    # Extracting the dynamic part after --platform
    platform_part="${string#*--platform }"
    platform_part="${platform_part%% --*}"

    # Extracting the ROM file name only
    full_file="${rom_part##*/}"

    # Extract ROM without extension
    only_rom="${full_file%.zip}"

    # extract last ROM saved
    save_state=$(ls -tp /storage/roms/savestates/$platform_part | grep -E "$only_rom" | head -1)

    # Extract the number using sed
    save_number=$(echo "$save_state" | sed -n 's/.*state\([0-9]\{1,\}\).*/\1/p')

    # If no number is found, set number to 0
    if [ -z "$save_number" ]; then
        save_number=0
    fi

    # Return the extracted number
    echo $save_number
}

modify_command() {
    local string="$1"

    # Extracting the dynamic part after '-state_slot '
    slot_part="${string#*-state_slot }"
    slot_part="${slot_part%% *}"

    # totally remove -state_slot from command as it's stops state.auto from loading if state number is not obtained correctly
    string="${string//-state_slot $slot_part/ }"

    echo "$string"
}

meta_upd() {
    # check for game launch time file

    if [ -f /tmp/gt_launch.inf ]; then
        # get current datetime in seconds
        cur_time="$(date +%s)"
        gl_time="$(cat /tmp/gt_launch.inf | sed -n '3p')"
        # get the difference
        actual_time="$(( ${cur_time}-${gl_time} ))"
        sed -i "3s/.*/${actual_time}/" /tmp/gt_launch.inf
        #clean up rom title for gamelist.xml passing
        rom_name="$(cat /tmp/gt_launch.inf | sed -n '2p')"
        rom_name=".\/${rom_name##*/}"
        sed -i "2s/.*/${rom_name}/" /tmp/gt_launch.inf
        #update metadata
            #check to see if gamelist.xml exists for sys and create one if needed
            # /storage/roms/$sys_name/gamelist.xml
        sys_name="$(cat /tmp/gt_launch.inf | sed -n '1p')"
        GAME_LIST="/storage/roms/${sys_name}/gamelist.xml"
        if ! [ -f "${GAME_LIST}" ]; then
cat << EOF > ${GAME_LIST}
<?xml version="1.0"?>
<gameList>
</gameList>
EOF
        fi
        # Add basic rom details to gamelist.xml if none exist so parser can be used
        if [ -f "${GAME_LIST}" ];then
            rom_mname="$(cat /tmp/gt_launch.inf | sed -n '2p')"
            rom_mtitle="${rom_mname%.*}"
            if ! grep -q "$rom_mname" "${GAME_LIST}"; then
            echo "adding game... path does not exist"
            sed -i "/<\/gameList>/i\ \t<game> \n\t\t<path>$rom_mname<\/path> \n\t\t<name>${rom_mtitle##*/}<\/name> \n\t<\/game>" "${GAME_LIST}"
            fi
        fi
        
        python3 /usr/bin/lg_meta_ud.py
    fi
}

auto_state() {
    # get rom platform and rom name
    local string="$1"

    rom_part="${string#*--rom }"
    rom_part="${rom_part%% --*}"
    rom_part="${rom_part//\\}"

    platform_part="${string#*--platform }"
    platform_part="${platform_part%% --*}"

    # may want to get savestate_directory from raappend.cfg instead... just in case of changes to pref
    # SV_STATE_DIR=$(cat /tmp/raappend.cfg | grep "savestate_directory" | cut -d'"' -f 2)

    # get the most recent save state and create state.auto (benefit is user will have a state history to fall back on)
    MST_RCNT=$(ls -tr "/storage/roms/savestates/${platform_part}/" | tail -1)
    # MST_RCNT=$(ls -tr "${SV_STATE_DIR}/" | tail -1)
    MST_RCNT=${MST_RCNT//".png"}

    cp -f "/storage/roms/savestates/${platform_part}/${MST_RCNT}" "/storage/roms/savestates/${platform_part}/${MST_RCNT%.*}.state.auto"
    # cp -f "${SV_STATE_DIR}/${MST_RCNT}" "${SV_STATE_DIR}/${MST_RCNT%.*}.state.auto"
    meta_upd
}

pp_shutdown () {
    $(/usr/bin/show_splash.sh)
    $(/usr/bin/sync)
    $(systemctl poweroff)
}

power_proc () {
    evtest --grab "$power_ev" | while read line; do
        if [[ $line == *"$power_key"* ]] || [[ $# -gt 0 ]]; then
            $(/usr/bin/adckeys.py hotkey_code release)
            PID=$(pgrep -f "sh -c -- /usr/bin/runemu.py --rom")
            if [ -n "$PID" ]; then
                if [ $(pidof mpv) ]; then
                    # quit mpv with shift+q
                    COMMAND=$(tr '\0' ' ' < "/proc/$PID/cmdline" | sed 's/sh -c -- //')
                    nost=$(modify_command "$COMMAND")
                    echo $nost > /storage/.config/lastgame
                    mpv_qr="Shift+q"
                    echo '{"command":["keypress", "'${mpv_qr}'"]}' | socat - "/tmp/mpvsocket"
                    meta_upd
                    # shutdown
                    pp_shutdown
                elif [ $(pidof retroarch) ]; then
                    #totally agnostic to either autosave set or not -- save sate
                    COMMAND=$(tr '\0' ' ' < "/proc/$PID/cmdline" | sed 's/sh -c -- //')
                    $(echo -n "SAVE_STATE" | /usr/bin/nc -u -w1 127.0.0.1 55355)
                    # modify command to remove saveslot ref.. interferes and prevents autoload if slot not correct
                    nost=$(modify_command "$COMMAND")
                    echo $nost > /storage/.config/lastgame
                    $(echo -n "PAUSE_TOGGLE" | /usr/bin/nc -u -w1 127.0.0.1 55355)
                    # create .state.auto for launch
                    $(auto_state "$COMMAND")
                    # shutdown
                    pp_shutdown
                fi
            elif ! pgrep -f "sh -c --" >/dev/null; then
                pp_shutdown
            fi    
        fi
    done
}

hotkey_proc () {
    evtest "$hotkey_ev" | while read line; do
        case $line in
            ($hotkey_press)
                pid_file="/var/run/power_proc.pid"
                if [ -f "$pid_file" ]; then
                    kill "$(cat "$pid_file")" >/dev/null 2>&1
                    rm "$pid_file"
                fi
                power_proc &
                POWER_PID=$!
                echo $POWER_PID > "$pid_file"
            ;;
            ($hotkey_release)
                # echo "this is a key release"
                kill $((POWER_PID+1))
            ;;
        esac
        if test -f /tmp/lastGame; then
            rm -rf /tmp/lastGame
            power_proc "now"
        fi
    done
}

hotkey_proc