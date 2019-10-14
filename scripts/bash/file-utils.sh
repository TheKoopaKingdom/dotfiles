#!/bin/bash

# Copies a file, checking to see if it's already updated or not.
# Arguments:
#   - The source file path.
#   - The destination file paths.
# Outputs;
#   - Copy feedback.
function safe_cp()
{
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
# Outputs;
#   - Link feedback.
function safe_ln()
{
  local -r TARGET=$1
  local -r LINK_NAME=$2

  if [[ -L "$LINK_NAME" ]] && cmp "$TARGET" "$LINK_NAME" >/dev/null 2>&1; then
    verbose "$LINK_NAME is already updated."
    return
  else
    local -r TARGET_PARENT_DIRECTORY=$(dirname "$TARGET")
    # Make sure the target's parent directory exists.
    if ! [ -d "$TARGET_PARENT_DIRECTORY" ]; then
      info "Making target parent directory $PARENT_DIRECTORY."
      if [[ $DRY_RUN = false ]]; then
        mkdir -p "$TARGET_PARENT_DIRECTORY"
      fi
    fi
    local -r LINK_NAME_PARENT_DIRECTORY=$(dirname "$LINK_NAME")
    # Make sure the link name's parent directory exists.
    if ! [ -d "$LINK_NAME_PARENT_DIRECTORY" ]; then
      info "Making link name parent directory $LINK_NAME_PARENT_DIRECTORY."
      if [[ $DRY_RUN = false ]]; then
        mkdir -p "$LINK_NAME_PARENT_DIRECTORY"
      fi
    fi
    if [ -f "$LINK_NAME" ] || [ -d "$LINK_NAME" ]; then
      local -r LINK_NAME_OLD="$LINK_NAME.old"
      info "File or directory to be linked $LINK_NAME exists, moving to $LINK_NAME_OLD."
      if [[ $DRY_RUN = false ]]; then
        mv "$LINK_NAME" "$LINK_NAME_OLD"
      fi
    fi

    info "Creating link to target $TARGET at $LINK_NAME."

    if [[ $DRY_RUN = false ]]; then
      debug "Executing ln -sf \"$TARGET\" \"$LINK_NAME\""
      ln -sf "$TARGET" "$LINK_NAME"
    fi
  fi
}
