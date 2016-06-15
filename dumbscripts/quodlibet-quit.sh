#!/bin/bash
# monitor for quodlibet to quit and stop all the scripts in that event

notify-send "quodlibet script ready to exit"
while true; do
  if [ "$(pkill -0 -fc 'python2 /usr/bin/quodlibet')" = "0" ]; then
    killall quodlibet-monitor.sh
    pkill -f "dbus-monitor --profile interface='net.sacredchao.QuodLibet',member='SongStarted'"
    notify-send "quodlibet has exit"
    exit
  fi
  sleep 2
done
