#!/bin/bash

vol=$(amixer sget 'Playback' | grep "Front Left:" | awk '{ print $4 }' | tr -d '[]')
spk_curr=$(amixer sget 'Playback Path' | grep "Item0:" | awk '{ print $2 }' | tr -d "'")

if [ "$spk_curr" == "OFF" ]; then
    amixer sset 'Playback Path' SPK_HP
    amixer sset 'Playback' ${vol}
fi

exit