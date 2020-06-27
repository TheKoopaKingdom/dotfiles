#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh

# Tags a MP3 file with its title, artist, and album.
# Arguments:
#   - The path to the MP3 file.
# Outputs:
#   - Error message if arguments are invalid.
function tag_mp3() {
  local -r mp3=$1

  if [[ -z "$mp3" ]]; then
    error "First argument (MP3 file path) not passed."
    return 1
  elif [[ ! -f "$mp3" ]]; then
    error "MP3 file \"$mp3\" not found."
    return 1
  fi

  local -r title=$(basename -s .mp3 "$mp3")
  local -r window_title="Enter Metedata for $title"
  printf "%s" "$title" | xclip -selection clipboard

  local -r METADATA_INPUT=$(zenity --width 1000 --height 500 \
    --forms \
    --title "$window_title" \
    --text "Enter metadata for \"$(sanitize_zenity "$mp3")\". Blank fields will not be added." \
    --add-entry "Title (%b will be substituted for the MP3 basename)" \
    --add-entry "Artist(s)" \
    --add-entry "Album")
  local title_input
  title_input=$(echo "$METADATA_INPUT" | cut -d'|' -f1)
  local -r artist_input=$(echo "$METADATA_INPUT" | cut -d'|' -f2)
  local -r album_input=$(echo "$METADATA_INPUT" | cut -d'|' -f3)

  if [[ -n "$artist_input" ]]; then
    eyeD3 -Qa "$artist_input" "$mp3"
  fi
  if [[ -n "$album_input" ]]; then
    eyeD3 -QA "$album_input" "$mp3"
  fi
  if [[ -n "$title_input" ]]; then
    title_input=${title_input//%b/$TITLE}
    eyeD3 -Qt "$title_input" "$mp3"
    rename "$TITLE" "$title_input" "$mp3"
  fi
}
