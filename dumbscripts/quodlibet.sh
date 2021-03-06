#!/bin/bash
# A huge wrapper for quodlibet that does various things.
SETTINGS=$HOME/Dropbox/Settings/Scripts
QUEUE=$SETTINGS/quodlibet-queue
LAST_PLAYER=$SETTINGS/quodlibet-player
CURRENT=$SETTINGS/quodlibet-current
SEEK=$SETTINGS/quodlibet-seek
CURRENT_SONG=$(grep 'song = ' $HOME/.quodlibet/config | sed 's/song = //')
CURRENT_SEEK=$(grep 'song = ' $HOME/.quodlibet/config | sed 's/seek = //')

function save-queue {
  if pgrep 'quodlibet' | grep -v $$
  then cp $HOME/.quodlibet/current "$CURRENT"
  else
    CURRENT_SONG=$(grep 'song = ' $HOME/.quodlibet/config | sed 's/song = //')
    echo "~filename=$CURRENT_SONG" > "$CURRENT"
  fi
  cp $HOME/.quodlibet/queue "$QUEUE"
  echo $CURRENT_SEEK > "$SEEK"
  hostname > "$LAST_PLAYER"
  notify-send "quodlibet: queue saved"
}

killall quodlibet-wait.sh 2>/dev/null || true
rm $HOME/.dumbscripts/quodlibet-found-router 2>/dev/null || true

if [ ! $# -eq 0 ]; then
  quodlibet --run --play-file "$@" & disown
  exit
elif pgrep 'quodlibet' | grep -v $$; then
  save-queue
  notify-send "but it might be outdated since you didn't quit, until #1358 is fixed"
  exit
fi

# get newer queue from other computer
$HOME/.dumbscripts/quodlibet-wait-for-cloud.sh
if ! [ -f "$LAST_PLAYER" ]; then
  notify-send -t 10000 "quodlibet-player file missing; recreating"
  hostname > "$LAST_PLAYER"
elif [ "$(<"$LAST_PLAYER")" = "" ]; then
  notify-send -u critical -t 300000 "quodlibet-player file empty--WTF? recreating"
  hostname > "$LAST_PLAYER"
fi
if ! grep -Fxq $(hostname) "$LAST_PLAYER"; then
  notify-send "quodlibet: switching from $(<"$LAST_PLAYER")"
  hostname > "$LAST_PLAYER"
  CURRENT_SONG="$(grep '~filename=' "$CURRENT" | sed 's/~filename=//')"
  CURRENT_SEEK=$(<"$SEEK")
  sed -i "s|song = .*|song = $(echo $CURRENT_SONG | sed 's/|/\\\|/')|" $HOME/.quodlibet/config
  sed -i "s/seek = .*/seek = $CURRENT_SEEK/" $HOME/.quodlibet/config
  cp "$CURRENT" $HOME/.quodlibet/current
  cp "$QUEUE" $HOME/.quodlibet/queue
fi

# check for an outdated queue
if grep -Fxq "$CURRENT_SONG" $HOME/.quodlibet/queue
then notify-send -u critical -t 300000 "quodlibet: queue may be outdated"
fi

/usr/bin/quodlibet --run --hide-window &
QUODLIBET=$!
wait $QUODLIBET
disown $QUODLIBET
sleep 1 # make sure there's time to save all the files
save-queue

exit
# I gave up on the stuff below this when upgrading to quodlibet 4
# somehow caused scripts to not run, disown to behave differently, and
# `quodlibet --stop` to only work if I manually run it in a terminal
# rather than this script. I've dealt with enough bizarre and impossible
# bugs caused by running quodlibet in a script for more than one
# lifetime, so I'm done.
# At this point, quodlibet has gotten so robust at keeping track of its
# currently playing song that I don't need all this redundant overhead
# anymore anyway.
# - 1/27/2018

# This nexus of quodlibet scripts makes its queue actually robust and
# sync to DropBox. Without this script, quodlibet's default queue
# behavior is atrocious. It will forget files, not always remember what
# it was playing on shutdown, and ALWAYS add the now-playing song to the
# end of the queue on shutdown for some reason. It was impossible to use
# the queue without constant babysitting.

# Running in the background, these scripts turn quodlibet into a daemon,
# and automatically save the queue to DropBox every time a new song
# starts playing, and also if you launch the script again while it's
# already running.

# Another feature it has that probably only I will care about is: it
# makes sure only one of your multiple networked computers (in these
# scripts, it's named ROUTER, and is stored by hostname in the file
# $HOME/Dropbox/Settings/Scripts/ROUTER) runs quodlibet. That way, you
# can have quodlibet automatically run at boot on your desktop, and
# then have it run at boot on your laptop if you're away from home with
# just your laptop, all automatically. To use that feature, run the
# quodlibet-wait.sh script to run quodlibet INSTEAD of this main one.

# You may be wondering why I end quodlibet commands with & and wait $!
# It's because of a bug where if I just ran the command without a &, the
# script would get stuck. Forever. Even though the command exits fine
# and pretty quickly. No idea. Something wrong with quodlibet in scripts

source $HOME/.dumbscripts/quodlibet-functions.sh
killall quodlibet-wait.sh 2>/dev/null || true
rm $HOME/.dumbscripts/quodlibet-found-router 2>/dev/null || true

if [ ! $# -eq 0 ]; then
  quodlibet --run --play-file "$@" &
  exit
elif pgrep 'quodlibet' | grep -v $$; then
  killall quodlibet-monitor.sh &
  pkill -f "dbus-monitor --profile interface='net.sacredchao.QuodLibet',member='SongStarted'"
  check-queue
  $HOME/.dumbscripts/quodlibet-monitor.sh &
  exit
fi

touch $HOME/.dumbscripts/quodlibet-starting
/usr/bin/quodlibet --run --hide-window &
while ! ([[ "$(quodlibet --status)" =~ "paused" ]] \
      || [[ "$(quodlibet --status)" =~ "playing" ]])
do sleep 1; done
sleep 20 # needs extra time to actually load AFTER IT SAYS IT'S LOADED
load-queue ; quodlibet --stop &
$HOME/.dumbscripts/quodlibet-quit.sh &
$HOME/.dumbscripts/quodlibet-monitor.sh &

disown -r && exit
