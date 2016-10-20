#!/bin/bash

# WARNING: This installation script has only been tested on Ubuntu

# DEPENDENCIES
dep=(xprop pacmd xdotool arecord lame)

# TEXT COLOURS
readonly RED="\033[01;31m"
readonly GREEN="\033[01;32m"
readonly BLUE="\033[01;34m"
readonly YELLOW="\033[00;33m"
readonly BOLD="\033[01m"
readonly END="\033[0m"

# VAR

INSTALLDIR="$HOME/bin"
APPDIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"      # try to follow XDG specs

SCRIPT="spotify-premium-o-caralho.sh"
ALSA_CONFIG=".asoundrc"

INFOMSG1="\e[1;93mWARNING: $INSTALLDIR is not part of your PATH. Your current PATH:

\e[0m$PATH

\e[1;93mIf you are on Ubuntu you might have to relog to complete the installation.
This will update your PATH and make the script available to your system.

\e[0mIf the launcher doesn't work after relogging you will have to manually add
$INSTALLDIR to your PATH variable.

Alternatively you could abort this installation and follow the instructions in the
README to manually install Spotify AdKiller.

\e[1;93mDo you want to proceed with the installation? \e[0m(y/n)"

ERRORMSG1="\e[1;31mERROR: One or more files not found. Please make sure to \
execute this script in the right working directory.\e[0m"

ERRORMSG2="ERROR: Please install these missing dependencies before running the script"

# FCT

checkdep(){
  for i in "${dep[@]}"; do
    if  ( ! type "$i" &>/dev/null ); then
      miss=("${miss[@]}" "and" "$i")
      missing="1"
    fi
  done
}


# MAIN

## check for missing dependencies
checkdep
if [[ $missing -eq 1 ]]; then
  misslist=$(echo ${miss[@]} | cut -c 4-)
  echo -e "$RED$misslist not found$END"
  echo -e "$ERRORMSG2"
  exit 1
fi

## check if INSTALLDIR is part of PATH
## prompt user for action
if [[ ! "$PATH" == ?(*:)"$INSTALLDIR"?(:*) ]]; then
  echo -e "$INFOMSG1"
  read INSTALLCHOICE
  if [[ "$INSTALLCHOICE" != "y" ]]; then
    echo "Aborting installation."
    exit 1
  else
    echo "Proceeding with installation."
  fi
fi

## check if all files present
if [[ ! -f "$SCRIPT" ]]; then
  echo -e "$ERRORMSG1"
  exit 1
fi

echo

echo "## Changing permissions ##"
chmod -v +x "$SCRIPT"

echo

echo "## Creating installation directories ##"
mkdir -vp "$INSTALLDIR"

echo

echo "## Installing files ##"
cp -v "$SCRIPT" "$INSTALLDIR/"
cp -v "$ALSA_CONFIG" ~/

echo

echo "## Done. ##"
