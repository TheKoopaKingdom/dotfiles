#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# If the systemd graphical target unit is active, the display isn't setup, and the first virtual
# console is active, start X. See /docs/Init.md.
if systemctl -q is-active graphical.target && [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  startx -- -keeptty &>"$HOME/.local/share/xorg/startx.log"
else
  # shellcheck source=scripts/bash/bash_rc.sh
  "$CO"/scripts/bash/bash_rc.sh
fi
