#!/bin/bash
# Move video file(s) to /tmp, then open them.
# I made this because I keep freshly downloaded YouTube videos in a
# videos folder until I watch them, and moving them myself every time
# was getting cumbersome.
# New feature: backs up a list of your downloaded videos so that getting
# them back isn't a nightmare if your hard drive dies before you back it
# up.

PLAYER=smplayer
FOLDER=/tmp/vids

$HOME/.dumbscripts/update-downloads.sh

if ! [ -d "$FOLDER" ]
then mkdir -p "$FOLDER"
fi

for i in "$@"; do
  if [ -d "$i" ]; then
    echo "$(basename $0): error: directories not supported"
    notify-send "$(basename $0): error: directories not supported"
    exit 1
  fi
  if ! [ -f "$i" ]; then
    echo "$(basename $0): error: file not found"
    notify-send "$(basename $0): error: file not found"
    exit 1
  fi
  mv "$i" "$FOLDER/"
done

ARGS=()
for i in "$@"; do
  # skip subtitles files
  if [[ "$ARG" =~ ".srt" ]] || [[ "$ARG" =~ ".ass" ]] || [[ "$ARG" =~ ".ssa" ]] || [[ "$ARG" =~ ".sub" ]] || [[ "$ARG" =~ ".idx" ]] || [[ "$ARG" =~ ".vtt" ]]
  then continue
  fi
  ARG="$FOLDER/$(basename "$i")" # get post-mv path
  ARGS+=( "$ARG " )
done

sleep 0.2
$PLAYER "${ARGS[@]}" & disown
