#!/bin/bash
# Automatically move video file(s) to /tmp after viewing them.
# (when the process that's viewing them closes)
# I made this because I keep freshly downloaded YouTube videos in a
# Downloads folder until I watch them, and moving them myself every time
# was getting cumbersome.
# New feature: backs up a list of your downloaded videos so that getting
# them back isn't a nightmare if your hard drive dies before you back it
# up.

PLAYER=/usr/bin/smplayer

ls --group-directories-first $HOME/Downloads > $HOME/Dropbox/Settings/Scripts/Downloads

for i in "$@"; do
  if [ -d "$i" ]; then
    echo "open-in-tmp.sh: error: directories not supported"
    notify-send "open-in-tmp.sh: error: directories not supported"
    exit 1
  fi
  if ! [ -f "$i" ]; then
    echo "open-in-tmp.sh: error: file not found"
    notify-send "open-in-tmp.sh: error: file not found"
    exit 1
  fi
done

ARGS=()
for i in "$@"; do
  ARG="\"$i\""
  # skip subtitles files
  if [[ "$ARG" =~ ".srt" ]] || [[ "$ARG" =~ ".ass" ]] || [[ "$ARG" =~ ".ssa" ]] || [[ "$ARG" =~ ".sub" ]]
  then continue
  else ARGS+=( "$ARG" )
  fi
done

eval "$PLAYER" ${ARGS[@]} &
wait $!
disown

for i in "$@"; do
  mv "$i" /tmp/
done