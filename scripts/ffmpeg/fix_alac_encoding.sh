#!/bin/bash

# Copyright 2020 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh

declare -r MUSIC_DIRECTORY=$HOME/Music/

# Fixes youtube-dl default filenames.
# Outputs:
#   - Fixing progress.
function fix_alac_encoding() {
  info "Converting music files with ALAC encoding."

  if [[ ! -d "$MUSIC_DIRECTORY" ]]; then
    error "Music directory \"$MUSIC_DIRECTORY\" not found."
    return 1
  fi

  find "$MUSIC_DIRECTORY/" -type f -name '*.m4a' | while read -r file_path; do
    info "Processing $file_path."
    local new_file_path
    new_file_path=${file_path%.*}.flac
    ffmpeg -nostdin -i "$file_path" -acodec flac "$new_file_path"
    rm "$file_path"
  done
  info "Checking finished."
}
