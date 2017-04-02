#!/bin/bash
# Wrapper for youtube-dl to make video downloading easier for me, and
# eliminate the need of a browser to get to the video wherever possible.

# About half of the credit for this file goes to my brother, John Bove

# You have to run it with the --terminal option to make it not open up
# in a new terminal window. Why? Because I like to use YT2Player on
# Firefox to click on a Youtube video and immediately get a terminal
# window of youtube-dl downloading it.
# I suggest making a script called /usr/local/bin/video-dl that runs
# this script with the --terminal option.

# The other options are, you guessed it, the URL of the video, any extra
# folder inside of the destination you want it stored in (good for
# using the playlist feature to download a whole season), and any extra
# options to send straight to youtube-dl. Other options include a
# compatibility check and telling the script to ask you how you want to
# handle the link. The proper order of the options goes:

# USAGE: download-vid.sh [--terminal|(--compatible)] (--compatible) URL
# [[destination subfolder]] [--ask] [extra options for youtube-dl]
# My own made-up usage notation:
# (parentheses) mean the argument is optional AND renders all of the
# optional arguments that come after it moot and useless.
# [[double brackets]] mean the argument is optional UNLESS you want to
# include the arguments that come after it. So, for the subfolder
# option, if you want to include extra options for youtube-dl, but don't
# want to specify a subfolder, you'll have to put a "./" in as its
# argument.

# Another feature is youtube annotations: it uses youtube-ass
# (https://github.com/nirbheek/youtube-ass) to get a .ass subtitle of
# the annotations and, if there are any annotations, saves the file
# with the same name as the video (otherwise deletes the file).

# Bonus feature: type "dailyshow" as the URL argument to automatically
# get the newest episode of the Daily Show with Trevor Noah. I wish I
# could do that with other shows as easily.
# That hasn't been working lately, because Comedy Central changed their
# site and doesn't update that redirect-to-newest-episode URL until at
# least 24 hours after the episode is available to stream.

# Now has integration with browser.sh to automatically open video links
# that are compatible with this script according to YOUR choice at the
# time! Download, browser, or video player.

# Now also integrates with a new script, queue-dl, that queues up video
# downloads instead of downloading them all at once. For me,
# /usr/local/bin/queue-dl is a symlink to
# $HOME/.dumbscripts/download-vid-queue.sh, which is now a file in this
# git repo.

# Another new feature: if you feed it a text file with URLs separated by
# whitespace instead of a single URL, it will download each of those
# URLs in order, using queue-dl to (annoyingly) pop up a download window
# for each one. Currently not working.

# If you, like my brother, have a crippling monthly bandwidth limit, you
# can put the MAC address of your router in $LOWBAND to automatically
# download videos in 360p when you're home, and go for HD otherwise.
# That feature requires my mac-address.sh script and arping (from the
# package iputils) to be automatic. Otherwise, you can modify the script
# to just always download in 360p.
# Supported sites for automatic 360p are in that if-statement.
# Also can do automatic 720p with MEDBAND.

ROUTER="$(ip neigh show $(ip route show match 0/0 | awk '{print $3}') | awk '{ print $5 }')"
LOWBAND=( "00:0d:93:21:9d:f4" "14:dd:a9:d7:67:14" )
MEDBAND=( "08:86:3b:b4:eb:d4" )
DOWNLOADER=queue-dl
TERMINAL=/usr/bin/mate-terminal
BROWSER=$(grep BROWSER= $HOME/.dumbscripts/browser.sh | sed 's/BROWSER=//')
PLAYER=/usr/bin/smplayer
if [ "$1" = "--terminal" ] || [ "$1" = "--compatible" ]; then
  if [ "$2" = "--compatible" ]; then
    URL="$3"
    FOLDER="$4"
    EXOPT="${@:5}"
  else
    URL="$2"
    FOLDER="$3"
    EXOPT="${@:4}"
  fi
else
  URL="$1"
  FOLDER="$2"
  if [ "$3" = "--ask" ]
  then EXOPT="${@:4}"
  else EXOPT="${@:3}"
  fi
fi
DEST="$HOME/Downloads/$FOLDER"
# text file queue mode--not working because of weird quote issues
#if [ -f "$URL" ]; then
#  FILE="$URL"
#  readarray URLS <"$FILE"
#  for URL in "${URLS[@]}"; do
#  URL="$(echo -n "$URL")" # readarray leaves the newline in there
#  nohup $HOME/.dumbscripts/download-vid.sh "$URL" "$FOLDER" "$EXOPT" >/dev/null & sleep 0.5
#  done
#  exit 0
#fi

function compatibility_check {
  echo -n "Checking for compatibility... "
  if [[ "$URL" =~ "youtube.com" ]] || [[ "$URL" =~ "youtu.be" ]] \
  || [[ "$URL" =~ "cinemassacre.com" ]] || [[ "$URL" =~ "channelawesome.com" ]] \
  || [[ "$URL" =~ "teamfourstar.com" ]] \
  || [[ "$URL" =~ "vessel.com" ]] \
  || [[ "$URL" =~ "dailymotion.com" ]] \
  || [[ "$URL" =~ "crunchyroll.com" ]] \
  || [[ "$URL" =~ "vimeo.com" ]] \
  || [[ "$URL" =~ "cc.com" ]] \
  || [[ "$URL" =~ "ted.com" ]] \
  || [[ "$URL" =~ "cwseed.com" ]]
  then
    echo "Website is compatible"
    exit 0
  else
    echo "Unknown website"
    exit 1
  fi
}

# Plagiaraized from http://stackoverflow.com/questions/3685970/check-if-an-array-contains-a-value
function contains() {
  local n=$#
  local value=${!n}
  for ((i=1;i < $#;i++)) {
    if [ "${!i}" == "${value}" ]; then
      echo "y"
      return 0
    fi
  }
  echo "n"
  return 1
}

if [[ "$URL" =~ "youtube.com" ]]; then
  ID="$(echo $URL | cut -f 2 -d "=")"
  $HOME/.local/share/git/youtube-ass/youtube-ass.py "$ID"
  # check for empty annotations file
  # It's referred to with that wildcard in the beginning because once,
  # I somehow ended up with a file that had a hyphen in front of it (so
  # it was named "-$ID.ass" instead of just "$ID.ass", and so it didn't
  # get moved or deleted. I don't know why youtube-ass did that.
  # The double-hyphen makes it treat the file as a filename no matter
  # what. I had to do that because I've had to deal with files named
  # "--$ID.ass", which were interpreted as arguments. Why not just put
  # it in quotes? Because that made the wildcard stop being a wildcard.
  if [ "$(grep -A2 '\[Events\]' -- *$ID.ass | sed -n 3p)" = "" ]; then rm -- *$ID.ass
  else mv -- *$ID.ass "$DEST$ID.ass"
  fi
  if [ "$(grep -A2 '\[Events\]' -- *$ID.ssa | sed -n 3p)" = "" ]; then rm -- *$ID.ssa
  else mv -- *$ID.ssa "$DEST$ID.ssa"
  fi
elif [[ "$URL" =~ "crunchyroll.com" ]]; then
  OPT="--write-sub --sub-lang enUS --recode-video mkv --embed-subs"
  URL="$(curl -LIs -o /dev/null -w '%{url_effective}' "$URL")"
elif [ "$URL" = "dailyshow" ]; then
  URL="$(curl -LIs -o /dev/null -w '%{url_effective}' "http://www.cc.com/shows/the-daily-show-with-trevor-noah/full-episodes")"
fi

if [ "$2" = "--compatible" ]
then compatibility_check # will result in an exit after execution
fi

if [ $(contains "${LOWBAND[@]}" "$ROUTER") = "y" ]; then
  echo "Trying to download low quality..."
  if [[ "$URL" =~ "youtube.com" ]] || [[ "$URL" =~ "youtu.be" ]] \
  || [[ "$URL" =~ "cinemassacre.com" ]] \
  || [[ "$URL" =~ "channelawesome.com" ]]; then
    OPT="-f \"18/best[height<=360]\""
  elif [[ "$URL" =~ "teamfourstar.com" ]]; then
    OPT="-f \"510/5/best[height<=360]\""
  elif [[ "$URL" =~ "vessel.com" ]]; then
    OPT="-f \"mp4-360-500K/best[height<=360]\""
  elif [[ "$URL" =~ "dailymotion.com" ]]; then
    OPT="-f \"http-380/best[height<=380]\""
  elif [[ "$URL" =~ "crunchyroll.com" ]]; then
    OPT="$OPT -f \"hls-meta-0/360p/best[height<=360]\""
  elif [[ "$URL" =~ "vimeo.com" ]]; then
    OPT="-f \"http-360p/best[height<=360]\""
  elif [[ "$URL" =~ "cc.com" ]]; then
    OPT="-f \"http-1028/1028/best[height<=360]\""
  elif [[ "$URL" =~ "ted.com" ]]; then
    OPT="-f \"http-1253/hls-1253/rtmp-600k/best[height<=360]\""
  elif [[ "$URL" =~ "cwseed.com" ]]; then
    OPT="-f \"hls-640/640/best[height<=360]\""
  else
    echo "WARNING: Unknown website. May not get desired quality."
    OPT="-f \"best[height<=360]\""
    # commented out because I was sick of not being able to leave a
    # batch downloading unattended
    #read -p "Download anyway? [Y/N] " ANS
    # case $ANS in
    #   [nN]* ) exit;;
    # esac
  fi
elif [ $(contains "${MEDBAND[@]}" "$ROUTER") = "y" ]; then
  echo "Trying to download medium quality..."
  if [[ "$URL" =~ "youtube.com" ]] || [[ "$URL" =~ "youtu.be" ]] \
  || [[ "$URL" =~ "cinemassacre.com" ]] \
  || [[ "$URL" =~ "channelawesome.com" ]]; then
    OPT="-f \"22/best[height<=720]/18/best[height<=360]\""
  elif [[ "$URL" =~ "teamfourstar.com" ]]; then
    OPT="-f \"1120/6/best[height<=720]/510/5/best[height<=360]\""
  elif [[ "$URL" =~ "vessel.com" ]]; then
    OPT="-f \"mp4-720-2400K/best[height<=720]/mp4-360-500K/best[height<=360]\""
  elif [[ "$URL" =~ "dailymotion.com" ]]; then
    OPT="-f \"http-780/best[height<=780]/http-380/best[height<=380]\""
  elif [[ "$URL" =~ "crunchyroll.com" ]]; then
    OPT="$OPT -f \"hls-meta-2/720p/best[height<=720]/hls-meta-1/480p/hls-meta-0/360p/best[height<=360]\""
  elif [[ "$URL" =~ "vimeo.com" ]]; then
    OPT="-f \"http-720p/best[height<=720]/http-360p/best[height<=360]\""
  elif [[ "$URL" =~ "cc.com" ]]; then
    OPT="-f \"http-3128/3128/best[height<=720]/http-1028/1028/best[height<=360]\""
  elif [[ "$URL" =~ "ted.com" ]]; then
    OPT="-f \"http-3976/hls-3976/rtmp-1500k/best[height<=720]/http-1253/hls-1253/rtmp-600k/best[height<=360]\""
  elif [[ "$URL" =~ "cwseed.com" ]]; then
    OPT="-f \"hls-2100/2100/best[height<=720]/hls-640/640/best[height<=360]\""
  else
    echo "WARNING: Unknown website. May not get desired quality."
    OPT="-f \"best[height<=720]\""
    # commented out because I was sick of not being able to leave a
    # batch downloading unattended
    #read -p "Download anyway? [Y/N] " ANS
    # case $ANS in
    #   [nN]* ) exit;;
    # esac
  fi
else echo "Trying to download high quality..."
fi

# the LC_ALL thing is to fix a bug where it needs LC_ALL to encode the
# filename properly
CMD="env LC_ALL=$LANG $DOWNLOADER $OPT ${EXOPT[@]} -o"

if [[ "$URL" =~ "cc.com" ]]; then
  CMD="$CMD \"$DEST%(title)s $ID.%(ext)s\" \"$URL\""
elif [[ "$URL" =~ "vessel.com" ]] || [[ "$URL" =~ "ted.com" ]] \
  || [[ "$URL" =~ "cwseed.com" ]]; then
  CMD="$CMD \"$DEST%(extractor)s - %(title)s $ID.%(ext)s\" \"$URL\""
else
  CMD="$CMD \"$DEST%(uploader)s - %(title)s $ID.%(ext)s\" \"$URL\""
fi

if [ "$1" != "--terminal" ]; then
  if [ "$1" = "--compatible" ]
  then CMD="$HOME/.dumbscripts/download-vid.sh --terminal --compatible \"$URL\"; cat"
  elif [ "$3" = "--ask" ]; then
    echo "#!/bin/bash" >/tmp/download-vid-ask.sh
    chmod +x /tmp/download-vid-ask.sh
    echo 'while true; do' | tee -a /tmp/download-vid-ask.sh
    echo '  read -n 1 -p "Download, browser, player, copy link, or quit? [D/B/P/C/Q] " ANS' | tee -a /tmp/download-vid-ask.sh
    echo '  case $ANS in' | tee -a /tmp/download-vid-ask.sh
    echo '    [dD] )' "echo; $CMD; break;;" | tee -a /tmp/download-vid-ask.sh
    echo '    [bB] )' "nohup $BROWSER \"$URL\" >/dev/null & sleep 0.5; break;;" | tee -a /tmp/download-vid-ask.sh
    echo '    [pP] )' "nohup $PLAYER \"$URL\" >/dev/null & sleep 0.5; break;;" | tee -a /tmp/download-vid-ask.sh
    echo '    [cC] )' "echo -n \"$URL\" | xclip -selection c; sleep 0.5; break;;" | tee -a /tmp/download-vid-ask.sh
    echo '    [qQ] ) break;;' | tee -a /tmp/download-vid-ask.sh
    echo '       * ) echo "invalid option"' | tee -a /tmp/download-vid-ask.sh
    echo '  esac' | tee -a /tmp/download-vid-ask.sh
    echo 'done' | tee -a /tmp/download-vid-ask.sh
    echo 'rm /tmp/download-vid-ask.sh' | tee -a /tmp/download-vid-ask.sh
    CMD="/tmp/download-vid-ask.sh"
  fi
  CMD="$TERMINAL --geometry=80x10 --title=youtube-dl -e \"bash -c '$(echo $CMD)'\""
fi

eval "$CMD"
ERROR=$?

if [ "$ERROR" != 0 ] && [ "$ERROR" != 255 ]; then
  echo "Something went wrong"
  if [ "$1" != "--terminal" ]
  then read -n1 -r -p "Press any key to exit..."
  fi
  exit $ERROR
fi

if [[ "$URL" =~ "youtube.com" ]] && [ -f "$DEST$ID.ass" ]
then mv "$DEST$ID.ass" "$(find $DEST -name "*$ID.mp4" | sed -n 1p | sed 's/\.mp4/\.ass/')"
fi
