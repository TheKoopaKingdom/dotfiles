#!/bin/bash

# If the systemd graphical target unit is active, the display isn't setup, and the first virtual
# console is active, start X.
if systemctl -q is-active graphical.target && [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  exec startx &> /dev/null
fi