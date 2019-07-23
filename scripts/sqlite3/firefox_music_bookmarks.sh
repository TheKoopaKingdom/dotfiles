#!/bin/bash

# Dependencies:
#  - "scripts/bash/common.sh"
#  - "scripts/bash/config.sh"

FIREFOX_PLACES_DATABASE="$FIREFOX_USER_DIRECTORY"/places.sqlite

# Gets the ID of a Firefox folder named 'Music".
get_music_folder_id()
{
  # Grab the ID of the first first music folder.
  # Disable ShellCheck error for echoing commands because here it's necessary, to return the value.
  # shellcheck disable=SC2005
  echo "$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT id FROM 'moz_bookmarks' WHERE title='Music' \
  AND type=2 LIMIT 0,1")"
}

# Removes a bookmark from a URL.
# Arguments:
#  - The URL to be removed.
remove_bookmark()
{
  info "Removing bookmark \"$1\"."
  URL_ID=$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT id FROM 'moz_places' WHERE url='$1'")
  MUSIC_ID=$(get_music_folder_id)
  debug "URL ID: $URL_ID. Music folder ID: $MUSIC_ID"
  sqlite3 "$FIREFOX_PLACES_DATABASE" "DELETE FROM 'moz_bookmarks' WHERE fk=$URL_ID AND parent='$MUSIC_ID'"
}

# Concatenates all bookmarks in the 'Music' folder of the Firefox places SQLite database.
get_music_list()
{
  MUSIC_ID=$(get_music_folder_id)
  # Get a list of the URL IDs in the music folder.
  URL_IDS=$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT fk FROM 'moz_bookmarks' WHERE parent=$MUSIC_ID")
  LIST=""
  for URL_ID in $URL_IDS; do
    # Lookup the URL from the current ID, and append it to the list.
    LIST+=$(sqlite3 "$FIREFOX_PLACES_DATABASE" "SELECT url FROM 'moz_places' WHERE id=$URL_ID")
    # Append a space to the list.
    LIST+=" "
  done
  echo "$LIST"
}
