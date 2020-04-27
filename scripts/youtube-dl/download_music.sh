#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/youtube-dl/select_music_directory.sh
source "$CO"/scripts/youtube-dl/select_music_directory.sh
# shellcheck source=scripts/sqlite3/firefox_music_bookmarks.sh
source "$CO"/scripts/sqlite3/firefox_music_bookmarks.sh
# shellcheck source=scripts/eyed3/tag_mp3.sh
source "$CO"/scripts/eyed3/tag_mp3.sh

# Downloads music from the Firefox music folder.
# Outputs:
#   - Download progress.
function download_music() {
  info "Downloading music from Firefox music bookmark folder."
  local -ra MUSIC_LIST=$(get_bookmark_urls "Listening List")
  for URL in $MUSIC_LIST; do
    info "Getting info about \"$URL\" and selecting music directory."
    if ! DOWNLOAD_DIR=$(select_music_directory "$(youtube-dl --get-title "$URL")"); then
      error "Music directory selection failed ($DOWNLOAD_DIR)."
      return 1
    fi
    info "Downloading to \"$DOWNLOAD_DIR\"."
    local -r OUTPUT_STR="$DOWNLOAD_DIR/%(title)s.%(ext)s"
    if ! youtube-dl -q -o "$OUTPUT_STR" -x --audio-format mp3 --embed-thumbnail "$URL"; then
      error "An error occured while downloading the file."
      return 1
    fi
    # Force MP3 here because otherwise it might return video formats, for YouTube videos.
    local -r FILE_PATH=$(youtube-dl -o "$DOWNLOAD_DIR/%(title)s.mp3" --get-filename "$URL")
    info "Tagging metadata."
    tag_mp3 "$FILE_PATH"
    info "Removing bookmark."
    remove_firefox_bookmark "$URL"
  done
}
