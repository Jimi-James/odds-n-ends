#!/bin/bash

# My default browser script. This script does a number of things:
# 1. Parse links to get rid of URL redirects, automatically convert
# HTML character codes (like http%2A%3F%3F turns into http://), and open
# known files in your program of choice using a Bash 4 hash
# 2. Automatically open all links on ONE computer in the network, the
# designated "ROUTER". So, if you click a link from your laptop and your
# default browser is set to this script, it'll open that link in your
# "ROUTER", or in my case, my desktop, according to what you've set in
# the files it draws all that info from. As a bonus, it's smart enough
# to open the link in that laptop if the "ROUTER" is not accessible, or
# if it doesn't have a Logitech mouse plugged in. That's great for if
# you have a KVM switch and don't want to open links in a desktop whose
# mouse & keyboard are currently plugged into another computer.
# 3. Double-click proof. If the same link is opened multiple times at
# once, it'll notice that and only open it once. I added that because of
# a bug where Rambox (the chat program) opens links 4-6 times at once.
# It's not perfect, because there's no way to ensure that this script
# DEFINITELY won't have 2 or more instances running at the same time.
# Currently, I've reduced what was always 4-6 simultaneous link openings
# to USUALLY 1, ocassionally 2.
# "At once" in this script means within $LOCKTIME seconds.
# WARNING: Feature #3 means there is usually a text file containing the
# last link you opened from outside of a browser. In case you care about
# privacy.
# 4. Remote Usage Mode: This will do more things when I replace my phone
# with a Pyra, but for now, it will automatically open video links with
# video-dl (see my download-vid.sh script) on the main home computer
# (coming soon)
# 5. Coming eventually: a switch, that you can make into a desktop shortcut,
# that decides whether the computer will bother with trying to open
# links on the main computer, or go with its own local browser.
# 6. Recognizes Google Hangouts links and opens them in a separate
# browser. I added this so I can call someone from another computer and
# get a Chrome window of the call on my main computer.
# 7. Recognizes download-vid.sh links and uses a new download-vid.sh
# feature to ask if you'd rather download it, play it, or open it in
# your browser. At first, I was using youtube-dl -j to check for those
# links, but it made every link take way too long to open, and I'm only
# going to pick the download option when it's specifically a link that
# download-vid.sh supports anyway.
# 8. Automatically converts most mobile links to proper links.

# Now has integration with download-vid.sh to automatically open video
# links that are compatible with youtube-dl according to YOUR choice at
# the time! Download, browser, or video player.

# NOTE: Unlike other dumbscripts, this one assumes it lives in
# $HOME/.mydefaults instead of .dumbscripts, to be consistent with the
# freedesktop standards of your default browser being in .mydefaults. I
# just created a symlink:
# $HOME/.mydefaults/browser.sh -> ../.dumbscripts/browser.sh
# Or you could just keep it in .mydefaults. That's fine, too.

# But, Jimi, why make this whole thing when KDE already has a lot of
# these features?
# Because I like XFCE better than KDE, and KDE was super super buggy
# about deciding when to open links in other programs anyway. Or at
# least KDE 4 was. Like there was NO way to automatically open HTML
# files in a text editor while also opening an image file in your image
# viewer. You had to pick one of those. Por qué no los dos?

# I do some funny stuff with multiple Firefox profiles now
BROWSER="$HOME/.dumbscripts/firefox.sh default"
VIDEO1=$HOME/.dumbscripts/download-vid.sh
VIDEO2="./ --ask"
CHROME="google-chrome-stable --app="
INFO=$HOME/Dropbox/Settings/Scripts
ROUTERUSER=jimi # your username
ROUTER=$(sed -n 1p $INFO/$(sed -n 1p $INFO/ROUTER).info) # IP of main computer & router
NATS=$(sed -n 2p $INFO/ROUTER) # number of NAT networks router has
COMPUTER=$(sed -n 2p $INFO/$(hostname).info) # your external IP
AT_HOME=$(sed -n 2p $INFO/$(sed -n 1p $INFO/ROUTER).info) # external IP of main computer & router
OPS="-i $HOME/.ssh/id_rsa_$(sed -n 1p $INFO/ROUTER) -o StrictHostKeyChecking=no" # SSH options
CMD="DISPLAY=:0 $HOME/.mydefaults/browser.sh $@ &"
# to fix a weird addon that Rambox started giving every outgoing link that resulted in a 404 on every website (now commented out because I no longer use Rambox)
# | sed 's/&h=[a-zA-Z0-9_-]\+\(&s=[0-9]\)\?$//'
RETURN="$HOME/.mydefaults/browser-return"
OPENED="$HOME/.mydefaults/browser-opened"
LOCK="$HOME/.mydefaults/browser-lock"
LOCKTIME=5 # seconds to wait before being willing to open the same link
AUDIO=/usr/bin/mplayer
VIDEO=/usr/bin/smplayer
IMAGE=/usr/bin/ristretto
TORRENT=/usr/bin/transmission-qt
declare -A MEDIA=([".mp3"]=$AUDIO  [".m4a"]=$AUDIO  [".ogg"]=$AUDIO \
                  [".wav"]=$AUDIO  [".flac"]=$AUDIO [".aac"]=$AUDIO \
                  [".alac"]=$VIDEO [".webm"]=$VIDEO [".mp4"]=$VIDEO \
                  [".mkv"]=$VIDEO  [".flv"]=$VIDEO  [".avi"]=$VIDEO \
                  [".jpg"]=$IMAGE  [".jpeg"]=$IMAGE [".png"]=$IMAGE \
                  [".gif"]=$IMAGE  [".torrent"]=$TORRENT [".webp"]=$CHROME)

# record the initial link, too, so it's easier to see what went wrong
echo "$1" > "$OPENED"
LINK="$(echo -e $(echo $1 | sed 's/%/\\x/g') | sed 's|http.*://.*\.facebook\.com/l\.php?u=||' | sed 's|http.*://l\.messenger\.com/l\.php?u=||' | sed 's|http.*://www\.google\.com/url?\(hl=en&\)\?q=||' | sed 's|http.*://steamcommunity\.com/linkfilter/?url=||' | sed 's_\(http.*://\(en\.\)\?\)\(mobile\|m\)\._\1_' | sed 's/&source=gmail.*//' | sed 's/&sa=.*\(&\|\?\|$\)//' | sed 's/&h=.*\(&\|\?\|$\)//')"

# Check for remote use mode: "if computer is not at home" (heh)
#if [ $(hostname) != $(sed -n 1p $INFO/ROUTER) ] && [ $COMPUTER != $AT_HOME ]
#then something
#fi

# Weird quirk: virt-manager from libvirt will open https://libvirt.org/schemas/domain/qemu/1.0
# when it launches if you set that as the namespace of a machine (to enable qemu:commandline)
# The page gives a 404 anyway so, no reason to ever browse to it.
if [ "$LINK" = "https://libvirt.org/schemas/domain/qemu/1.0" ]
then exit
fi

# Check if string contains a defined media extension after its last /
function MEDIA-contains() {
  for i in "${!MEDIA[@]}"; do
    if echo "$1" | cut -d'/' -s -f1- --output-delimiter=$'\n' | tail -1 | grep -qFi "$i"; then
      # account for those dang giffy's
      if echo "$1" | cut -d'/' -s -f1- --output-delimiter=$'\n' | tail -1 | grep -qFi ".gifv"
      then return 1
      fi
      echo "$i"
      return 0
    fi
  done
  return 1
}

# Link-opening logic
function open-link() {
  # have to remove lockfile this soon, or else the last opening of the
  # same link will never get to delete the last lockfile
  rm -f "$LOCK" || true
  # if link has been opened within past 2 seconds, just stop
  if [ -f "$OPENED" ]; then
    if [ "$1" = "$(sed -n 1p "$OPENED")" ]; then
      echo "$(expr $(stat -c %y "$OPENED" | sed "s/$(date +%Y-%m-%d\ %H:%M:)\([0-9][0-9]\).*/\1/") + 0 2>/dev/null)"
      echo "$(expr $(date +%S) - 2)"
      if [ "$(expr $(stat -c %y "$OPENED" | sed "s/$(date +%Y-%m-%d\ %H:%M:)\([0-9][0-9]\).*/\1/") + 0 2>/dev/null)" \
      -gt "$(expr $(date +%S) - $LOCKTIME)" ] &>/dev/null
      then exit
      else rm "$OPENED" || true
      fi
    else rm "$OPENED" || true
    fi
  fi
  echo "$LINK" >> "$OPENED"
  # open link according to what it is
  LINK="$(echo $LINK | sed 's/(/\\(/g' | sed 's/)/\\)/g')" # weird bug that popped up recently
  local CMD="\"$LINK\""
  local EXT=$(MEDIA-contains "$LINK")
  if [ "$EXT" = "" ]; then
    if [[ "$LINK" =~ "https://hangouts.google.com/call/" ]] \
    || [[ "$LINK" =~ "https://hangouts.google.com/el/CONVERSATION" ]]
    then CMD="$CHROME$CMD"
    elif video-dl --compatible "$LINK"
    then CMD="$VIDEO1 $CMD $VIDEO2"
    else CMD="$BROWSER $CMD"
    fi
  elif video-dl --compatible "$LINK"
  then CMD="$VIDEO1 $CMD $VIDEO2"
  else CMD="${MEDIA[$EXT]} $CMD"
  fi
  if [ "$1" = "return" ]; then
    # open it in the computer that clicked because ROUTER is busy
    CMD="/usr/bin/ssh $OPS $(sed -n 1p $INFO/$(<"$RETURN").info) DISPLAY=:0 $CMD"
  fi
  eval "$CMD" & disown
}

# have to only open one link at a time for the "Double-click proof" to
# actually work
while [ -f "$LOCK" ] && kill -0 $(<"$LOCK"); do sleep 0.2; done
echo $$ | tee "$LOCK"
# Routing logic & actual execution
if [ $(hostname) = "$(sed -n 1p $INFO/ROUTER)" ]; then
  if [[ $(lsusb | grep Logitech) =~ "Mouse" ]] \
  || [[ $(lsusb | grep Logitech) =~ "Unifying Receiver" ]]; then
    open-link
  else
    open-link return
  fi
  rm "$RETURN" || true
else
  FOUND_ROUTER="false"
  echo $(hostname) > "$RETURN"
  if nc -zw1 $ROUTER 22; then
    FOUND_ROUTER="true"
    scp $OPS "$RETURN" $ROUTERUSER@$ROUTER:/home/$ROUTERUSER/.mydefaults
    ssh $OPS $ROUTERUSER@$ROUTER "$CMD" &
  else
    for ((i=0; i<$NATS; i+=1))
    do
      if nc -zw1 10.42.$i.1 22; then
        FOUND_ROUTER="true"
        scp $OPS "$RETURN" $ROUTERUSER@10.42.$i.1:/home/$ROUTERUSER/.mydefaults
        ssh $OPS $ROUTERUSER@10.42.$i.1 "$CMD" &
        break
      fi
    done
  fi
  if [ "$FOUND_ROUTER" = "false" ]; then
    open-link
  fi
  rm "$RETURN" || true
fi

rm -f "$LOCK" || true
rm -f "$RETURN" || true
