#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024-present AmberELEC (https://github.com/AmberELEC)

# LOGO_SEQ="/usr/config/splash/usr_logo"
LOGO_SEQ="/usr/share/p4_splash"
USR_LOGO="/storage/.config/splash"
USR_SEQ="${USR_LOGO}/usr_logo"

count=0

anim_play(){
  for img in "$LOGO_SEQ"/*.{jpg,jpeg,png}; do
    [ -e "$img" ] || continue

    if (( count % 2 == 0 )); then
    magick $img bgra:/dev/fb0
    fi
  
    ((count++))
  done 
}

rnd_mp4(){
  if ls "${mp4_files}" &>/dev/null; then
    random_mp4=${mp4_files[RANDOM % ${#mp4_files[@]}]}
    if [ -e "${random_mp4}" ]; then
          echo -en '\033[1J' >/dev/console &
          dd if=/dev/zero count=1000 bs=1024 > /dev/fb0 &
          mpv --video-osd=no "${random_mp4}"
          exit 1
    else
      rnd_mp4
    fi
  fi
}

. /etc/profile

DEVICE=$(tr -d '\0' < /sys/firmware/devicetree/base/model)

if [ "$DEVICE" == "Anbernic RG351P" ]; then
  magick /usr/config/splash/splash-480.png bgra:/dev/fb0
elif [ "$DEVICE" == "Anbernic RG552" ]; then
  ply-image /usr/config/splash/splash-1920.png
else

  #check to see if USR has added their own image sequence or mp4 files.
  shopt -s nullglob  # Prevents globbing errors when no files match
  img_files=("$USR_SEQ"/*.{jpg,jpeg,png})
  shopt -s nullglob
  mp4_files=("$USR_SEQ"/*.{mp4,mkv,gif})

  # If USR folder exists, and if the array is empty, use base logo sequence
  if [ -d "${USR_SEQ}" ]; then
    # If MP4's found in .config/spalsh/usr_logo.. choose a random vid.
    rnd_mp4

    if ls "${img_files}" &>/dev/null; then
      LOGO_SEQ="${USR_SEQ}"
    else
      LOGO_SEQ="${LOGO_SEQ}"
    fi

  fi
  anim_play
fi
