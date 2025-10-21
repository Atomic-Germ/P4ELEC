#!/bin/bash

vol_r36s=$(amixer sget 'Playback' | grep "Front Left:" | awk '{ print $4 }' | tr -d '[]')
last_vol=$(head -n 1 "/storage/.config/.volume")

mkdir -p /var/lib/alsa/
amixer sset 'Playback Path' SPK_HP
alsactl store
ln -s /dev/input/event3 /dev/input/by-path/platform-rg351-keys-event
systemctl restart volume.service
if [ -f "/storage/.config/.volume" ]; then
  amixer sset 'Playback' ${last_vol}
else
  amixer sset 'Playback' 75%
fi
exit
