#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/bash/config.template.sh
source "$CO"/scripts/bash/config.sh

readonly FIREFOX_PLACES_DATABASE="$FIREFOX_USER_DIRECTORY"/places.sqlite

# Gets the ID of a Firefox folder.
# Arguments:
#   - The name of the folder.
# Outputs:
#   - The ID of the folder, which can be used to further index the database.
function get_firefox_folder_id() {
  local -r FOLDER_NAME=$1

  # Grab the ID of the first first music folder.
  # Disable ShellCheck error for echoing commands because here it's necessary, to return the value.
  # shellcheck disable=SC2005
  echo "$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT id FROM 'moz_bookmarks' WHERE title='$FOLDER_NAME' \
  AND type=2 LIMIT 0,1")"
}

# Concatenates all bookmarks in the a folder of the Firefox places SQLite database.
# Arguments:
#   - The name of the folder.
# Outputs:
#   - The list of bookmark URLs in the folder, delimited with spaces.
function get_bookmark_urls() {
  local -r FOLDER_NAME=$1

  local -r MUSIC_ID=$(get_firefox_folder_id "$FOLDER_NAME")
  # Get a list of the URL IDs in the music folder.
  local -r URL_IDS=$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT fk FROM 'moz_bookmarks' WHERE parent=$MUSIC_ID")
  local -a list=""
  for URL_ID in $URL_IDS; do
    # Lookup the URL from the current ID, and append it to the list.
    list+=$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT url FROM 'moz_places' WHERE id=$URL_ID")
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
  local -r FOLDER=$1
  local -r URL=$2

  info "Removing bookmark \"$URL\"."
  local -r URL_ID=$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT id FROM 'moz_places' WHERE url='$URL'")
  local -r MUSIC_ID=$(get_firefox_folder_id "$FOLDER")
  debug "URL ID: $URL_ID. Music folder ID: $MUSIC_ID"
  sqlite3 "$FIREFOX_PLACES_DATABASE" "DELETE FROM 'moz_bookmarks' WHERE fk=$URL_ID AND parent='$MUSIC_ID'"
}
