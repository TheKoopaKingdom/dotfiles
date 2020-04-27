#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh

# Copies a file, checking to see if it's already updated or not.
# Arguments:
#   - The source file path.
#   - The destination file paths.
# Outputs:
#   - Copy feedback.
function safe_cp() {
  local -r SOURCE=$1
  local -r DESTINATION=$2

  if cmp "$SOURCE" "$DESTINATION" >/dev/null 2>&1; then
    verbose "$DESTINATION is already copied."
  else
    info "Copying file $SOURCE => $DESTINATION."
    if [[ $DRY_RUN = false ]]; then
      install -D "$SOURCE" "$DESTINATION"
    fi
  fi
}

# Links one file to another and resolves conflicts.
# Arguments:
# - The target file path.
# - The link file path.
# Outputs:
#   - Link feedback.
function safe_ln() {
  local -r TARGET=$1
  local -r LINK_NAME=$2

  if [[ -L "$LINK_NAME" ]] && cmp "$TARGET" "$LINK_NAME" >/dev/null 2>&1; then
    verbose "$LINK_NAME is already updated."
  else
    local -r TARGET_PARENT_DIRECTORY=$(dirname "$TARGET")
    # Handle conflicts with nonexistent target parent directories. This is a pretty unlikely
    # scenario, but possible if the path will later be populated with files.
    if ! [[ -d "$TARGET_PARENT_DIRECTORY" ]]; then
      info "Making target parent directory $TARGET_PARENT_DIRECTORY."
      if [[ $DRY_RUN = false ]]; then
        mkdir -p "$TARGET_PARENT_DIRECTORY"
      fi
    fi

    # Handle conflicts with preexisting files or directories.
    if [[ -f "$LINK_NAME" ]] || [[ -d "$LINK_NAME" ]]; then
      local -r COMMON_STR="Path $LINK_NAME exists"
      if [[ -L "$LINK_NAME" ]]; then
        info "$COMMON_STR, is a link. Overwriting."
      else
        local -r LINK_NAME_OLD="$LINK_NAME.old"
        info ", isn't a link. Moving to $LINK_NAME_OLD."
        if [[ $DRY_RUN = false ]]; then
          mv "$LINK_NAME" "$LINK_NAME_OLD"
        fi
      fi

    # Handle conflcits with nonexistent link name parent directories.
    else
      local -r LINK_NAME_PARENT_DIRECTORY=$(dirname "$LINK_NAME")
      info "Making link name parent directory $LINK_NAME_PARENT_DIRECTORY."
      if [[ -L "$LINK_NAME_PARENT_DIRECTORY" ]]; then
        info "Parent directory $LINK_NAME_PARENT_DIRECTORY is a link, overwriting."
        rm "$LINK_NAME_PARENT_DIRECTORY"
      fi
      if [[ $DRY_RUN = false ]]; then
        mkdir -p "$LINK_NAME_PARENT_DIRECTORY"
      fi
    fi

    info "Creating link to target $TARGET at $LINK_NAME."

    if [[ $DRY_RUN = false ]]; then
      debug "Executing ln -sf \"$TARGET\" \"$LINK_NAME\""
      ln -sf "$TARGET" "$LINK_NAME"
    fi
  fi
}
