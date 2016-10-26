#!/bin/bash

# Configs
LIBRARY_FOLDER="library"
BINARY="spotify"
TMP_FOLDER="/tmp"

debuginfo() {
    if [[ "$DEBUG" = "1" ]]; then
        echo "$1"
    fi
}

usage() {
    echo "$0 [-v] [-d <path>]" 1>&2;
    echo ""
    echo "Available options:"
    echo "-d <path> Sets the library directory"
    echo "-h        Displays this help page"
    echo "-p        Encodes mp3 files with a bitrate of 320kbps (Use this option if you have a Premium account)"
    echo "-v        Turns on the debug mode"
}

init() {
    DEBUG=0
    BITRATE=160

    while getopts ":d: :h :p :v" opt; do
        case $opt in
            d)
                LIBRARY_FOLDER="$OPTARG"
                ;;
            h)
                usage
                exit 1
                ;;
            p)
                BITRATE=320
                ;;
            v)
                DEBUG=1
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                exit 1
                ;;
        esac
    done

    # Makes the library path absolute
    if [[ ! "$LIBRARY_FOLDER" = /* ]]; then
        LIBRARY_FOLDER=`readlink -f $LIBRARY_FOLDER`
        debuginfo "Library: $LIBRARY_FOLDER"
    fi

    # Creates the library folder if it doesn't exist
    if [ ! -d "$LIBRARY_FOLDER" ]; then
        mkdir $LIBRARY_FOLDER
        cd $LIBRARY_FOLDER
    fi

    # Sets on quiet mode if it isn't on debug mode
    if [[ "$DEBUG" = "0" ]]; then
        QUIET="--quiet"
    else
        QUIET=""
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
    TRACK_NUMBER=$(echo "$DBUSOUTPUT" | grep xesam:trackNumber -A 1 | grep variant | cut -d' ' -f30- | sed 's/"$//g')
    LENGTH=$(echo "$DBUSOUTPUT" | grep mpris:length -A 1 | grep variant | cut -d' ' -f30- | sed 's/"$//g')
    debuginfo "Original LENGTH: $LENGTH"
    LENGTH_SECONDS=`expr $LENGTH / 1000000`

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
        get_track_info
        echo "PAUSED:   No"
        PAUSED=0
        CURRENT_TRACK=$TRACKDATA
    fi

    # check if track is an ad
    if [[ ! "$XPROP_TRACKDATA" == *"$TRACKDATA"* && "$PAUSED" = "0" ]]; then
        echo "AD:       Yes"
        AD=1
    elif [[ "$TRACKDATA" == " - Spotify" && "$PAUSED" = "0" ]]; then
        echo "AD:       Yes"
        AD=1
    elif [[ ! "$XPROP_TRACKDATA" == *"$TRACKDATA"* && "$PAUSED" = "1" ]]; then
        echo "AD:       Can't say"
        AD=0
    else
        echo "AD:       No"
        AD=0
    fi
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
    MP3_FILE="$LIBRARY_FOLDER/$ARTIST/$ALBUM/$TITLE.mp3"
    TMP_WAV="$TMP_FOLDER/$TITLE.wav"
    TMP_MP3="$TMP_FOLDER/$TITLE.mp3"

    # Stops all active recordings
    killall arecord $QUIET

    # Checks if the track needs to be recorded.
    if [ -f "$MP3_FILE" ]; then
        exit 1
    fi

    # Captures sound from "pulse_monitor" device to a temporary wav file
    echo "Recording $TMP_MP3"
    arecord -f cd -D pulse_monitor -r 44100 -d $LENGTH_SECONDS $QUIET "$TMP_WAV"

    # Converts the temporary wav file to mp3
    lame -b $BITRATE -B $BITRATE "$TMP_WAV" "$TMP_MP3" $QUIET

    echo "Recorded $TMP_MP3"
    while [ ! -f "$TMP_MP3" ]
    do
        sleep 2
    done

    # Adds metadata to the mp3 file
    mid3v2 -a "$ARTIST" -A "$ALBUM" -t "$TITLE" "$TMP_MP3" -T "$TRACK_NUMBER"

    # Check if the mp3 has the right length
    FILE_LENGTH=`sox "$TMP_MP3" -n stat 2>&1 | sed -n 's#^Length (seconds):[^0-9]*\([0-9.]*\)$#\1#p'`
    debuginfo "FILE_LENGTH: $FILE_LENGTH"
    FILE_LENGTH=${FILE_LENGTH%.*}

    # Removes the mp3 file if it hasn't the correct length
    debuginfo "Recorded file has $FILE_LENGTH seconds. It should have $LENGTH_SECONDS seconds."
    if [ "$FILE_LENGTH" != "$LENGTH_SECONDS" ]; then
        if [ -f "$TMP_MP3" ]; then
            rm -f "$TMP_MP3"
            echo "Removed invalid recording $TMP_MP3"
        fi
    else
        create_artist
        create_album
        mv "$TMP_MP3" "$MP3_FILE"
        echo "Successfully recorded $MP3_FILE"
    fi

    # Deletes the temporary wav file
    if [ -f "$TMP_WAV" ]; then
        rm -f "$TMP_WAV"
    fi
}

create_track() {
    if [ ! -f "$LIBRARY_FOLDER/$ARTIST/$ALBUM/$TITLE" ]; then
        record_track &
    fi
}

# MAIN
init "$@"
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
