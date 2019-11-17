#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Export environmental variables.

# Set the Comet Observatory path.
export COMET_OBSERVATORY=$HOME/Documents/Projects/Bash/comet-observatory

# Set the PATHt to prioritize ccache, and deprioritize local binaries and secondary toolchains.
export PATH=/usr/lib/ccache/bin/:$PATH:$COMET_OBSERVATORY/bin:/home/kyle/frc2019/roborio/bin

# Set the editor to nano.
export EDITOR=nano

# Disable the Wine menu builder, to prevent creation of desktop entries for Windows programs, Mono,
# to prevent the Mono installation dialog, and Gecko, to prevent the Gecko installation dialog.
export WINEDLLOVERRIDES="winemenubuilder.exe=d;mscoree=d;mshtml=d"

# Execute initialization scripts.

# Export FRC toolchain variables.
# $HOME/frc2019/frccode/frcvars2019.sh

# Set functions and aliases.

# Reloads this script.
# Globals Exported:
#   - Everything exported in this script.
function r
{
  clear
  # shellcheck source=./bash_rc.sh
  source ~/.bashrc
}

# Exports the contents of an "ENV" file.
# Arguments:
#   - The path to the "ENV" file.
function export-env
{
  set -o allexport
  # shellcheck disable=1090
  source "$1"
  set +o allexport
}

# Executes "ls", with color on.
alias ls='ls --color=auto'

# Customize the prompt.

QUOTES=(
  # Neon Genesis Evangelion.
  "Understanding 100% of everything is impossible. That’s why we spend all our lives trying to \
understand the thinking of others. That’s what makes life so interesting."
  "Sometimes you need a little wishful thinking just to keep on living."
  "Part of growing up means finding a way to interact with others while distancing pain."
  "Never underestimate the ability of the human animal to adapt to its environment."
  "Any new position from which you view your reality will change your perception of its nature. \
It's all literally a matter of perspective."
  "Your truth can be changed simply by the way you accept it. That's how fragile the truth for a \
human is."
  "Anywhere can be paradise as long as you have the will to live. After all, you are alive, so you \
will always have the chance to be happy. As long as the Sun, the Moon, and the Earth exist, \
everything will be all right."
  "Humans constantly feel pain in their hearts. Because the heart is so sensitive to pain, humans \
also feel that to live is to suffer."
  "I'm so fucked up."
  "Kimochi warui."
  # Mob Psycho 100
  "The biggest distinguishing feature of humans is how rich and varied their emotions are. These \
emotions are the reason they thrive and also the reason they fight." \
  "You should realize that you're only able to survive thanks to the help of others."
)
echo "${QUOTES[$RANDOM % ${#QUOTES[@]}]}" | lolcat -F 0.01

# shellcheck source=../../externals/agnoster-bash/agnoster.bash
source "$COMET_OBSERVATORY/externals/agnoster-bash/agnoster.bash"