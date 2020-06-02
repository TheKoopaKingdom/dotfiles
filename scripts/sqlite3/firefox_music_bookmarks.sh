#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/bash/config.template.sh
source "$CO"/scripts/bash/config.sh

declare -r FIREFOX_PLACES_DATABASE="$FIREFOX_USER_DIRECTORY"/places.sqlite

# Gets the ID of a Firefox folder.
# Arguments:
#   - The name of the folder.
# Outputs:
#   - The ID of the folder, which can be used to further index the database.
function get_firefox_folder_id() {
  local -r folder_name=$1

  # Grab the ID of the first first music folder.
  # Disable ShellCheck error for echoing commands because here it's necessary, to return the value.
  # shellcheck disable=SC2005
  echo "$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT id FROM 'moz_bookmarks' WHERE title='$folder_name' \
  AND type=2 LIMIT 0,1")"
}

# Concatenates all bookmarks in the a folder of the Firefox places SQLite database.
# Arguments:
#   - The name of the folder.
# Outputs:
#   - The list of bookmark URLs in the folder, delimited with spaces.
function get_bookmark_urls() {
  local -r folder_name=$1

  local -r music_id=$(get_firefox_folder_id "$folder_name")
  # Get a list of the URL IDs in the music folder.
  local -r url_ids=$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT fk FROM 'moz_bookmarks' WHERE parent=$music_id")
  local -a list=""
  for url_id in $url_ids; do
    # Lookup the URL from the current ID, and append it to the list.
    list+=$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT url FROM 'moz_places' WHERE id=$url_id")
    # Append a space to the list.
    list+=" "
  done
  echo "$list"
}

# Removes a bookmark in a folder, from a URL.
# Arguments:
#   - The folder containing the URL.
#   - The URL to be removed.
# Outputs:
#   - Bookmark removal progress.
function remove_firefox_bookmark() {
  local -r folder=$1
  local -r url=$2

  info "Removing bookmark \"$URL\"."
  local -r url_id=$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT id FROM 'moz_places' WHERE url='$url'")
  local -r music_id=$(get_firefox_folder_id "$folder")
  debug "URL ID: $url_id. Music folder ID: $music_id"
  sqlite3 "$FIREFOX_PLACES_DATABASE" "DELETE FROM 'moz_bookmarks' WHERE fk=$url_id AND parent='$music_id'"
}
