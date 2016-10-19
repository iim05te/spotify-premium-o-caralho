#!/bin/bash

killall arecord --quiet
arecord -c 2 -D pulse_monitor -r 192000 -d $1 --quiet "$2".wav
# lame -V0 -h --vbr-new $2.wav $2.mp3
lame -h "$2.wav" "$2.mp3" --quiet
if [ -f "$2.wav" ]; then
    rm -f "$2.wav"
fi
