#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# Set functions and aliases.

# Reloads this script.
# Globals Exported:
#   - Everything exported in this script.
function r() {
  clear
  # shellcheck source=scripts/bash/bash_rc.sh
  source ~/.bashrc
}

# Exports the contents of an "ENV" file.
# Arguments:
#   - The path to the "ENV" file.
function export-env() {
  set -o allexport
  # shellcheck source=/dev/null
  source "$1"
  set +o allexport
}

# Downloads an MP4.
# Arguments:
#   - The URL.
#   - The name of the video.
function d() {
  local -r MP4=$HOME/Videos/MP4s/$2.mp4
  if [ -f "$MP4" ]; then
    echo "already exists lol"
  else
    youtube-dl "$1" -f mp4 -o "$MP4"
  fi
}

# Strips leading "v" from all Git tags.
# Outputs:
#   - Git output, and tag status.
function retag() {
  local -a tags
  echo retag
  tags=$(git tag -l)
  while IFS= read -r tag; do
    if [[ $tag =~ ^v.+$ ]]; then
      message=$(git tag -l -n1 --format='%(contents)' "$tag" | head -n1)
      echo "Fixing $tag ($message)"
      local tag_new=${tag#v}
      git tag -f "$tag_new" "$tag"^{} -m "$message" &&
        git tag -d "$tag" &&
        git push origin :refs/tags/"$tag" &&
        git push --tags
    fi
  done <<<"$tags"
}

function wnea() {
  echo who needs eclipse anyways

  # build.
  javac -d Build Source/**/*.java

  # run.
  local -r main_class_file=$(grep "public static void main" . -rl | head -1)
  local -r main_class=$(basename "$main_class_file" | cut -d. -f1)
  java -cp Build "apcs/$main_class"
}

alias lss='/usr/bin/ls --color=auto'
# Replace ls with LSDeluxe.
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'

alias g=git
alias gdiff="git diff --no-index"
alias p=phoronix-test-suite
alias play='DISPLAY= mpv --really-quiet -vo caca'

# Customize the prompt.

# This can't be readonly because this script can be ran more than once in the same environment.
declare -a QUOTES=(
  # Neon Genesis Evangelion.
  #   "Understanding 100% of everything is impossible. That’s why we spend all our lives trying to
  # understand the thinking of others. That’s what makes life so interesting."
  "Sometimes you need a little wishful thinking just to keep on living."
  "Part of growing up means finding a way to interact with others while distancing pain."
  "Never underestimate the ability of the human animal to adapt to its environment."
  "Any new position from which you view your reality will change your perception of its nature. \
It's all literally a matter of perspective."
  "Your truth can be changed simply by the way you accept it. That's how fragile the truth for a \
human is."
  "Anywhere can be paradise, as long as you have the will to live."
  "Humans constantly feel pain in their hearts. Because the heart is so sensitive to pain, humans \
also feel that to live is to suffer."
  "I'm so fucked up."
  # "Kimochi warui."
  # Mob Psycho 100
  "The biggest distinguishing feature of humans is how rich and varied their emotions are. These \
emotions are the reason they thrive and also the reason they fight."
  "You should realize that you're only able to survive thanks to the help of others."
  # The Great Gatsby
  "It is invariably saddening to look through new eyes at things upon which you have expended \
your own powers of adjustment."
  # Duvet - Bôa
  "I am falling
I am fading
I have lost it all
Help me to breathe"
  "I am hurting
I have lost it all
I am losing
Help me to breathe"
  # I'm With You - Avril Lavigne
  "It's a damn cold night
Trying to figure out this life
Won't you take me by the hand?"
  "I don't know who you are
But I, I'm with you"
)
echo "${QUOTES[$RANDOM % ${#QUOTES[@]}]}" | lolcat -F 0.01

# TODO: Reenable a prompt here.

# Don't use Agnoster for login shells, because VTYs lack ligature font support by default.
#if [[ $- == *i* ]]; then
# shellcheck source=scripts/bash/agnoster_bash.sh
#source "$CO"/scripts/bash/agnoster_bash.sh
#fi
