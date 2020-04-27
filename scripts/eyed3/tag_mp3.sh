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
  readonly MP3=$1

  if [[ -z "$MP3" ]]; then
    error "First argument (MP3 file path) not passed."
    return 1
  elif [[ ! -f "$MP3" ]]; then
    error "MP3 file \"$MP3\" not found."
    return 1
  fi

  local -r TITLE=$(basename -s .mp3 "$MP3")
  local -r WINDOW_TITLE="Enter Metedata for $TITLE"
  printf "%s" "$TITLE" | xclip -selection clipboard

  local -r METADATA_INPUT=$(zenity --width 1000 --height 500 \
    --forms \
    --title "$WINDOW_TITLE" \
    --text "Enter metadata for \"$1\". Blank fields will not be added." \
    --add-entry "Title (%b will be substituted for the MP3 basename)" \
    --add-entry "Artist(s)" \
    --add-entry "Album")
  local title_input
  title_input=$(echo "$METADATA_INPUT" | cut -d'|' -f1)
  local -r ARTIST_INPUT=$(echo "$METADATA_INPUT" | cut -d'|' -f2)
  local -r ALBUM_INPUT=$(echo "$METADATA_INPUT" | cut -d'|' -f3)

  if [[ -n "$ARTIST_INPUT" ]]; then
    eyeD3 -Qa "$ARTIST_INPUT" "$MP3"
  fi
  if [[ -n "$ALBUM_INPUT" ]]; then
    eyeD3 -QA "$ALBUM_INPUT" "$MP3"
  fi
  if [[ -n "$title_input" ]]; then
    title_input=${title_input//%b/$TITLE}
    eyeD3 -Qt "$title_input" "$MP3"
    rename "$TITLE" "$title_input" "$MP3"
  fi
}
