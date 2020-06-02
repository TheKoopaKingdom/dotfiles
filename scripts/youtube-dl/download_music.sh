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
  for URL in $(get_bookmark_urls "Listening List"); do
    info "Getting info about \"$URL\" and selecting music directory."
    if ! download_dir=$(select_music_directory "$(youtube-dl --get-title "$URL")"); then
      error "Music directory selection failed ($download_dir)."
      return 1
    fi
    info "Downloading to \"$download_dir\"."
    local -r output_str="$download_dir/%(title)s.%(ext)s"
    if ! youtube-dl -q -o "$output_str" -x --audio-format mp3 --embed-thumbnail "$URL"; then
      error "An error occured while downloading the file."
      return 1
    fi
    # Force MP3 here because otherwise it might return video formats, for YouTube videos.
    local -r FILE_PATH=$(youtube-dl -o "$download_dir/%(title)s.mp3" --get-filename "$URL")
    info "Tagging metadata."
    tag_mp3 "$FILE_PATH"
    info "Removing bookmark."
    remove_firefox_bookmark "$URL"
  done
}
