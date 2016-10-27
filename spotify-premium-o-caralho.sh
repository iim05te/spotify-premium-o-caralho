#!/bin/bash

# Prints the available options
usage() {
    echo "$0 [-hpv] [-d <path>]" 1>&2;
    echo ""
    echo "Available options:"
    echo "-d <path> Sets the library directory"
    echo "-h        Displays this help page"
    echo "-p        Encodes mp3 files with a bitrate of 320kbps (Use this option if you have a Premium account)"
    echo "-v        Turns on the debug mode"
}

# Prints output if debug mode is enabled
debuginfo() {
    if [[ "$DEBUG" = "1" ]]; then
        echo "$1"
    fi
}

# Initializes the script
init() {
    # Configs
    LIBRARY_FOLDER="library"
    BINARY="spotify"
    TMP_FOLDER="/tmp"
    BITRATE=160

    # States
    DEBUG=0
    IS_RECORDING=0

    # Children Pids
    RECORDING_DISPLAY_PID=""
    RECORDING_PID=""

    # Text colours
    readonly RED="\033[01;31m"
    readonly GREEN="\033[01;32m"
    readonly BLUE="\033[01;34m"
    readonly YELLOW="\033[00;33m"
    readonly BOLD="\033[01m"
    readonly END="\033[0m"

    # Gets command line arguments
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

    WINDOWID=$(xdotool search --classname "$BINARY" | tail -1)
    if [[ -z "$WINDOWID" ]]; then
      echo "Spotify not active. Exiting."
      exit 1
    fi

    SPOTIFY_VERSION=`spotify --version`
    debuginfo "$SPOTIFY_VERSION"

    xpropcommand=(xprop -spy -id "$WINDOWID" _NET_WM_NAME)
}

# Gets all info from dbus
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

# Gets the Spotify sink info from PulseAudio sound server
get_pactl_info() {
    pacmd list-sink-inputs | grep -B 25 "application.process.binary = \"$BINARY\""
}

# Updates the main states
get_state() {
    get_track_info

    # Check if the track is paused
    debuginfo "$(get_pactl_info)"
    if get_pactl_info | grep 'state: CORKED' > /dev/null 2>&1; then
        # Waits and rechecks
        sleep 0.75
        if get_pactl_info | grep 'state: CORKED' > /dev/null 2>&1; then
            debuginfo "PAUSED:   Yes"
            PAUSED=1
        fi
        get_track_info
    else
        get_track_info
        debuginfo "PAUSED:   No"
        PAUSED=0
        CURRENT_TRACK=$TRACKDATA
    fi

    # Checks if the track is an ad
    if [[ ! "$XPROP_TRACKDATA" == *"$TRACKDATA"* && "$PAUSED" = "0" ]]; then
        debuginfo "AD:       Yes"
        AD=1
    elif [[ "$TRACKDATA" == " - Spotify" && "$PAUSED" = "0" ]]; then
        debuginfo "AD:       Yes"
        AD=1
    elif [[ ! "$XPROP_TRACKDATA" == *"$TRACKDATA"* && "$PAUSED" = "1" ]]; then
        debuginfo "AD:       Can't say"
        AD=0
    else
        debuginfo "AD:       No"
        AD=0
    fi
}

# Starts recording the playing track
start_recording() {
    # Gets ready to be sacrificed by his parent
    trap "sacrifice_child" SIGTERM

    # Captures sound from "pulse_monitor" device to a temporary wav file
    arecord -f cd -D pulse_monitor -r 44100 -d $LENGTH_SECONDS $QUIET "$TMP_WAV"

    # Sets recording state to stopped
    IS_RECORDING=0

    # Converts the temporary wav file to mp3
    lame -b $BITRATE -B $BITRATE "$TMP_WAV" "$TMP_MP3" $QUIET

    # Deletes the temporary wav file
    if [ -f "$TMP_WAV" ]; then
        rm -f "$TMP_WAV"
    fi

    # Waits a while until the mp3 file is created
    while [ ! -f "$TMP_MP3" ]
    do
        sleep 2
    done

    # Adds metadata to the mp3 file
    mid3v2 -a "$ARTIST" -A "$ALBUM" -t "$TITLE" "$TMP_MP3" -T "$TRACK_NUMBER"

    # Checks if the mp3 has the correct length
    FILE_LENGTH=`sox "$TMP_MP3" -n stat 2>&1 | sed -n 's#^Length (seconds):[^0-9]*\([0-9.]*\)$#\1#p'`
    debuginfo "FILE_LENGTH: $FILE_LENGTH"
    FILE_LENGTH=${FILE_LENGTH%.*}

    # Removes the mp3 file if it hasn't the correct length
    if [ "$FILE_LENGTH" != "$LENGTH_SECONDS" ]; then
        if [ -f "$TMP_MP3" ]; then
            rm -f "$TMP_MP3"
            echo -e "\r$RED[ERROR]$END $TMP_MP3 has $FILE_LENGTH seconds instead of $LENGTH_SECONDS.";
            exit 1
        fi
    fi

    # Creates the artist's folder
    if [ ! -d "$LIBRARY_FOLDER/$ARTIST" ]; then
        mkdir "$LIBRARY_FOLDER/$ARTIST"
    fi

    # Creates the album's folder
    if [ ! -d "$LIBRARY_FOLDER/$ARTIST/$ALBUM" ]; then
        mkdir "$LIBRARY_FOLDER/$ARTIST/$ALBUM"
    fi

    # Moves the recorded file to the library
    mv "$TMP_MP3" "$MP3_FILE"
    echo -e "\r$GREEN[OK]$END $MP3_FILE";
}

# Sets recording state to started, and starts recording
start_recording_display() {
    # Gets ready to be sacrificed by his parent
    trap "sacrifice_child" SIGTERM

    MP3_FILE="$LIBRARY_FOLDER/$ARTIST/$ALBUM/$TITLE.mp3"
    TMP_MP3="$TMP_FOLDER/$TITLE.mp3"

    # Checks if the track needs to be recorded.
    if [ -f "$MP3_FILE" ]; then
        echo "Já existe $MP3_FILE"
        exit 1
    fi

    # Creates a new process to record
    start_recording &
    RECORDING_PID=$!

    # Updates the progress output every second until it reaches the end
    i=0
    while [ $i -lt $LENGTH_SECONDS ]
    do
        sleep 1
        i=$(($i + 1))
        percent=$((100*$i/$LENGTH_SECONDS))
        echo -en "\r$YELLOW[Recording $TMP_WAV]$END $percent% ($i/$LENGTH_SECONDS)";
    done
    echo -en "\033[2K"
}

# Sets recording state to paused, and stops recording
pause_recording() {
    echo -en "\033[2K"
    echo -e "\r$RED[Recording paused $TMP_WAV]$END This file will be deleted";
    kill -15 $RECORDING_DISPLAY_PID > /dev/null 2>&1
}

# Sets recording state to stopped, and stops recording
stop_recording() {
    IS_RECORDING=0
    kill -15 $RECORDING_DISPLAY_PID > /dev/null 2>&1
    echo -en "\033[2K"
}

# Kills a child process, ie, stops the recording process
sacrifice_child() {
    kill -9 $RECORDING_PID
    exit 1
}

# Stops main execution
terminate() {
    echo ""
    stop_recording
    exit 1
}

# Main execution starts here
init "$@"

trap "terminate" SIGINT

while read XPROPOUTPUT; do
    get_state
    debuginfo "$DBUSOUTPUT"
    debuginfo "Artist:   $ARTIST"
    debuginfo "Album:    $ALBUM"
    debuginfo "Song:     $TITLE"
    debuginfo "Length:   $LENGTH_SECONDS"

    TMP_WAV="$TMP_FOLDER/$TITLE.wav"

    # Is playing some track
    if [[ "$PAUSED" = "0" && "$AD" = "0" ]]; then
        if [[ $IS_RECORDING = "1" ]]; then
            stop_recording
            # echo "matou o $RECORDING_DISPLAY_PID"
        fi

        # Starts recording if it is a new track
        if [ ! -f "$LIBRARY_FOLDER/$ARTIST/$ALBUM/$TITLE" ]; then
            # Creates a new process to display the recording progress
            start_recording_display &
            IS_RECORDING=1
            RECORDING_DISPLAY_PID=$!
        fi

    # Is paused
    elif [[ "$PAUSED" = "1" && "$AD" = "0" ]]; then
        if [[ $IS_RECORDING = "1" ]]; then
            pause_recording
        else
            echo -en "\r$BLUE[Paused]$END";
        fi

    # Is playing ads
    elif [[ "$PAUSED" = "0" && "$AD" = "1" ]]; then
        echo -e "\r$BLUE[Playing Ads]$END Please wait";
        if [[ $IS_RECORDING = "1" ]]; then
            stop_recording
        fi
    fi
done < <("${xpropcommand[@]}")
