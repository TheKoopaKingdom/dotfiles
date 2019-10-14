#!/bin/sh

# Source system xinitrc scripts.
if [ -d /etc/X11/xinit/xinitrc.d ] ; then
 for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
  # shellcheck disable=1090
  [ -x "$f" ] && . "$f"
 done
 unset f
fi

# Disable Energy Star features.
xset -dpms
# Disable screen blanking.
xset s off

# Use the XDG portal for GTK applications. This allows for things like Firefox (GTK) using KDE file
# dialogs.
export GTK_USE_PORTAL=1
# Use Ksshaskpass for SSH askpass needs.
export SSH_ASKPASS='/usr/bin/ksshaskpass'

# Start KDE Plasma.
exec startkde
