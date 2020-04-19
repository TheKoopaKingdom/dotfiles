# Initialization
This document details how the user portion of the booting process works, particularly focusing in on environment variables. In the process of booting up and starting Plasma, the `rc` and `env` files should get ran in the following order:
- Systemd starts the Getty service on VTY 1.
- Getty logs us in, using its [configuration](/config/systemd-overrides/getty-autologin.conf).
- PAM for our user loads pam_env, which loads our [`env` file](/config/pam-environment.env), which sets environmental variables used by all programs.
  - This sets `COMET_OBSERVATORY`. The libraries in `scripts` may assume that this variable is set at all times, either by this environment variable, or by a `/bin` script, for root scripts.
- Bash runs the [Bash profile](/scripts/bash/bash_profile.sh), which starts X if the conditions are right.
  - If the conditions aren't right, then we opt to treat this as a normal terminal, and run the [Bash RC file](/scripts/bash/bash_rc.sh).
  - Wayland could be implemented at this point.
- X runs the [X RC file](/scripts/x/x_rc.sh), which runs the [DE prelaunch script](/bin/before-de-launch) and starts KDE Plasma.

Further reading:
- https://wiki.archlinux.org/index.php/Arch_boot_process
- https://wiki.archlinux.org/index.php/Getty#Automatic_login_to_virtual_console
- https://wiki.archlinux.org/index.php/Environment_variables#Per_user
- https://wiki.archlinux.org/index.php/Systemd/User#Environment_variables