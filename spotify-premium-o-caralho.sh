#!/bin/bash

# Configs
LIBRARY_FOLDER="library"
BINARY="spotify"
DEBUG=0

debuginfo() {
    if [[ "$DEBUG" = "1" ]]
    then
        echo "$1"
    fi
}

init() {
    if [[ ! "$LIBRARY_FOLDER" = /* ]]; then
        CWD=`pwd`
        LIBRARY_FOLDER="$CWD/$LIBRARY_FOLDER"
        debuginfo "Library: $LIBRARY_FOLDER"
    fi
    if [ ! -d "$LIBRARY_FOLDER" ]; then
        mkdir $LIBRARY_FOLDER
        cd $LIBRARY_FOLDER
    fi

    SPOTIFY_VERSION=`spotify --version`
    debuginfo "$SPOTIFY_VERSION"

    WINDOWID=$(xdotool search --classname "$BINARY" | tail -1)
    if [[ -z "$WINDOWID" ]]; then
      echo "Spotify not active. Exiting."
      exit 1
    fi

    xpropcommand=(xprop -spy -id "$WINDOWID" _NET_WM_NAME)
}

get_track_info() {
  XPROPOUTPUT=$(xprop -id "$WINDOWID" _NET_WM_NAME)
  DBUSOUTPUT=$(dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 \
   org.freedesktop.DBus.Properties.Get  string:'org.mpris.MediaPlayer2.Player' string:'Metadata')
  ARTIST=$(echo "$DBUSOUTPUT"| grep xesam:artist -A 2 | grep string | cut -d\" -f 2- | sed 's/"$//g' | sed -n '2p')
  ALBUM=$(echo "$DBUSOUTPUT"| grep xesam:album -A 2 | grep string | cut -d\" -f 2- | sed 's/"$//g' | sed -n '2p')
  XPROP_TRACKDATA="$(echo "$XPROPOUTPUT" | cut -d\" -f 2- | sed 's/"$//g')"
  LENGTH=$(echo "$DBUSOUTPUT" | grep mpris:length -A 1 | grep variant | cut -d' ' -f30- | sed 's/"$//g')
  LENGTH_SECONDS=`expr $LENGTH / 1000000`
  # LENGTH_MINUTES=$(($LENGTH_SECONDS / 60))

  TITLE=$(echo "$DBUSOUTPUT" | grep xesam:title -A 1 | grep variant | cut -d\" -f 2- | sed 's/"$//g')
  TRACKDATA="$ARTIST - $TITLE"
}

get_pactl_info() {
  pacmd list-sink-inputs | grep -B 25 "application.process.binary = \"$BINARY\""
}

get_state() {
  get_track_info

  # check if track paused
  debuginfo "$(get_pactl_info)"
  if get_pactl_info | grep 'state: CORKED' > /dev/null 2>&1; then
    # wait and recheck
    sleep 0.75
    if get_pactl_info | grep 'state: CORKED' > /dev/null 2>&1; then
      echo "PAUSED:   Yes"
      PAUSED=1
    fi
    get_track_info
  else
    echo "PAUSED:   No"
    PAUSED=0
    CURRENT_TRACK=$TRACKDATA
  fi

  # check if track is an ad
  if [[ ! "$XPROP_TRACKDATA" == *"$TRACKDATA"* && "$PAUSED" = "0" ]]
    then
        echo "AD:       Yes"
        AD=1
  elif [[ "$TRACKDATA" == " - Spotify" && "$PAUSED" = "0" ]]
    then
        echo "AD:       Yes"
        AD=1
  elif [[ ! "$XPROP_TRACKDATA" == *"$TRACKDATA"* && "$PAUSED" = "1" ]]
    then
        echo "AD:       Can't say"
        AD=0
    else
        echo "AD:       No"
        AD=0
  fi

  # debuginfo "admute: $ADMUTE; pausesignal: $PAUSESIGNAL; adfinished: $ADFINISHED"
}

print_horiz_line(){
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

create_artist() {
    if [ ! -d "$LIBRARY_FOLDER/$ARTIST" ]; then
        mkdir "$LIBRARY_FOLDER/$ARTIST"
    fi
}

create_album() {
    if [ ! -d "$LIBRARY_FOLDER/$ARTIST/$ALBUM" ]; then
        mkdir "$LIBRARY_FOLDER/$ARTIST/$ALBUM"
    fi
}

record_track() {
    FILE="$LIBRARY_FOLDER/$ARTIST/$ALBUM/$TITLE"
    echo "Recording $FILE".mp3
    $CWD/recorder.sh "$LENGTH_SECONDS" "$FILE" &
}

create_track() {
    create_artist
    create_album
    if [ ! -f "$LIBRARY_FOLDER/$ARTIST/$ALBUM/$TITLE" ]; then
        record_track
    fi
}

# MAIN
init
while read XPROPOUTPUT; do
    get_state
    debuginfo "$DBUSOUTPUT"
    debuginfo "Artist:   $ARTIST"
    debuginfo "Album:    $ALBUM"
    debuginfo "Song:     $TITLE"
    debuginfo "Length:   $LENGTH_SECONDS"

    if [[ "$PAUSED" = "0" && "$AD" = 0 ]]; then
        create_track
    fi
    print_horiz_line
done < <("${xpropcommand[@]}")
