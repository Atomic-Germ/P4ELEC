#!/bin/bash

source /etc/profile

EE_DEVICE=$(cat /storage/.config/.OS_ARCH)
EXECLOG="/tmp/logs/exec.log"
ROM="${1##*/}"
PLATFORM="nds"
BASEFOLDER="/storage/drastic/aarch64/drastic/"
CONFFOLDER="${BASEFOLDER}config"
DRASTICFOLDER="${BASEFOLDER}drastic"
CONFFILE="${CONFFOLDER}/drastic.cfg"
SDLFLD="${BASEFOLDER}TF1"
CONF="/storage/.config/distribution/configs/distribution.conf"

## BG folder for Steward
USRCFBG="/usr/config/steward/bg/"
BGSHARE="/storage/.config/steward/bg/"
STEWARDBG="/storage/roms/nds/bg"

function get_setting() {
        #We look for the setting on the ROM first, if not found we search for platform and lastly we search globally
        PAT="s|^${PLATFORM}\[\"${ROM}\"\].*${1}=\(.*\)|\1|p"
        EES=$(sed -n "${PAT}" "${CONF}" | head -1)

        if [ -z "${EES}" ]; then
                PAT="s|^${PLATFORM}[\.-]${1}=\(.*\)|\1|p"
                EES=$(sed -n "${PAT}" "${CONF}" | head -1)
        fi

        if [ -z "${EES}" ]; then
                PAT="s|^global[\.-].*${1}=\(.*\)|\1|p"
                EES=$(sed -n "${PAT}" "${CONF}" | head -1)
        fi

        [ -z "${EES}" ] && EES="false"

}

function get_steward() {
        #We look for the setting on the ROM first, if not found we search for platform and lastly we search globally
        PAT="s|^${PLATFORM}\[\"${ROM}\"\].*${1}=\(.*\)|\1|p"
        EES=$(sed -n "${PAT}" "${CONF}" | head -1)

        if [ -z "${EES}" ]; then
                PAT="s|^${PLATFORM}[\.-]${1}=\(.*\)|\1|p"
                EES=$(sed -n "${PAT}" "${CONF}" | head -1)
        fi

        if [ -z "${EES}" ]; then
                PAT="s|^global[\.-].*${1}=\(.*\)|\1|p"
                EES=$(sed -n "${PAT}" "${CONF}" | head -1)
        fi

        [ -z "${EES}" ] && EES="false"

        echo "${EES}"

}

function set_config_value(){
        sed -i "s/^\(${1} = \).*/${1} = ${2}/" ${CONFFILE}
}

function set_es_setting(){
        ES_KEY="${1}"   # Key with the value we're getting from ES
        DEFF="${2}"     # Default value
        CFG_KEY="${3}"  # Key in the config file
        DEF552="${4}"   # Default for the 552 if applicable.

        get_setting "${ES_KEY}"
        if [ "${EES}" == "auto" ] || [ "${EES}" == "false" ]; then
                if [ "$EE_DEVICE" == "RG552" ] && [ ! -z "${DEF552}" ]; then
                        set_config_value "${CFG_KEY}" "${DEF552}"
                else
                        set_config_value "${CFG_KEY}" "${DEFF}"
                fi
        else
                set_config_value "${CFG_KEY}" "${EES}"
        fi
        

}

function clear_steward_bg(){
        if [ ! -z "$( ls -A "${STEWARDBG}/" )" ]; then
                rm -fr ${STEWARDBG}/*.png
        fi
}

function set_steward_bg(){
        DSV=$(get_steward "steward_mode")
        LAYOUT1=$(get_steward "layout_01")
        LAYOUT2=$(get_steward "layout_02")
        LAYCOL=$(get_steward "layout_color")

        #Get BG color then proceed to layout config
        if [ ! "${LAYCOL}" ] || [ "${LAYCOL}" == "auto" ] || [ "${LAYCOL}" == "false" ]; then
                LAYCOL="2"
        fi

        #BG layout 1
        if [ ! "${LAYOUT1}" ] || [ "${LAYOUT1}" == "auto" ] || [ "${LAYOUT1}" == "false" ]; then
                LAYOUT1="bg_v1"
        fi

        #BG layout 2
        if [ ! "${LAYOUT2}" ] || [ "${LAYOUT2}" == "auto" ] || [ "${LAYOUT2}" == "false" ]; then
                LAYOUT2="bg_vh_s2"
        fi

        LAYOUT1="${LAYOUT1}.png"
        LAYOUT2="${LAYOUT2}.png"

        #check to see if bg is wanted
        if [ ! ${DSV} == "3" ]; then

                #clear then copy wanted coloured layout with correct naming to drastic rom bg folder
                clear_steward_bg

                cp "${BGSHARE}${LAYCOL}/${LAYOUT1}" "${STEWARDBG}/"
                cp "${BGSHARE}${LAYCOL}/${LAYOUT2}" "${STEWARDBG}/"
        else
                #clear then copy blank layout with correct naming to drastic rom bg folder
                clear_steward_bg

                cp "${BGSHARE}blank.png" "${STEWARDBG}/${LAYOUT1}"
                cp "${BGSHARE}blank.png" "${STEWARDBG}/${LAYOUT2}"
        fi

}

# check for steward folder and create/copy if they do not exist

if [ ! -d "${BGSHARE}" ]; then
        mkdir -p "${BGSHARE}"
        cp -rf "${USRCFBG}." "${BGSHARE}"
fi

# check for BG folder in NDS rom folder

if [ ! -d "${STEWARDBG}/" ]; then
        mkdir -p "${STEWARDBG}/"
fi

# Check drastic is installed and config copied to /storage/drastic/aarch64/drastic

if [ ! -d "${CONFFOLDER}" ]
then
  mkdir -p "${CONFFOLDER}"
  cp -rf /usr/share/drastic/drastic.cfg "${CONFFOLDER}"
fi

if [ ! -f "${CONFFILE}" ]
then
  cp -rf /usr/share/drastic/config/drastic.cfg "${CONFFOLDER}"
fi

if [ ! -f "${DRASTICFOLDER}" ]
then
  mkdir -p "${BASEFOLDER}"
  cp -rf /usr/share/drastic/data/* "${BASEFOLDER}"
fi

if [ ! -d "${SDLFLD}" ]; then
  cp -rf "/usr/share/drastic/data/TF1/" "${BASEFOLDER}"
  cp -rf "/usr/share/drastic/data/TF2/" "${BASEFOLDER}"
  cp -rf "/usr/share/drastic/config/" "${BASEFOLDER}"
fi

cd "${BASEFOLDER}"

# Emulation Station Settings

set_es_setting "highres_3d" "0" "hires_3d" "1"
set_es_setting "threaded_3d" "1" "threaded_3d"
set_es_setting "frameskip_type" "2" "frameskip_type"
set_es_setting "frames_skipped" "1" "frameskip_value"
set_es_setting "show_fps" "0" "show_frame_counter"
set_es_setting "screen_mode" "1" "screen_orientation"
set_es_setting "screen_swap" "0" "screen_swap"
set_es_setting "disable_edge_marking" "0" "disable_edge_marking"
set_es_setting "bios_language" "1" "firmware.language"
set_es_setting "birthday_month" "0" "firmware.birthday_month"
set_es_setting "birthday_day" "1" "firmware.birthday_day"
set_es_setting "favorite_color" "4" "firmware.favorite_color"

# End of EmulationStation settings implementation

# Set Steward BG
set_steward_bg

# Start Drastic with Steward SDL Libary

if [ "${DSV}" == "1" ]; then
        ./drastic "${1}" >> $EXECLOG 2>&1
elif [ ! "${DSV}" == "1" ] || [ ! ${DSV} ]; then
        LD_PRELOAD=./TF1/libSDL2-2.0.so.0.3000.2 ./drastic "${1}" >> $EXECLOG 2>&1
fi
