#!/bin/bash

# Copies a file, checking to see if it's already updated or not. Supports dry run.
# Arguments:
#   - The source file path.
#   - The destination file paths.
#   - The owner to set the destination to (optional).
#   - The permission to set the destination to (optional).
#  set the destination to.
function safe_cp()
{
  SOURCE=$1

  if cmp "$SOURCE" "$2" >/dev/null 2>&1; then
    verbose "$2 is already copied."
  else
    info "Copying file $SOURCE => $2."
    if [[ $DRY_RUN = false ]]; then
      install -D "$SOURCE" "$2"
    fi
  fi
  if [[ -n $3 ]]; then
    if [[ $(stat -c "%U:%G" "$2") != "$3" || $(stat -c "%U" "$2") != "$3" ]]; then
      info "Setting owner of $2 to $3."
      if [[ $DRY_RUN = false ]]; then
        chown "$3" "$2"
      fi
    fi
  fi
  if [[ -n $4 ]]; then
  # TODO: Check before doing it.
    info "Setting permissions of $2 to $4."
    if [[ $DRY_RUN = false ]]; then
      chmod "$4" "$2"
    fi
  fi
}

# Links one file to another and resolves conflicts. Supports dry run.
# Arguments:
# - The target file path.
# - The link file path.
# - The owner to set the destination to (optional).
# - The permission to set the destination to (optional).
function safe_ln()
{
  TARGET=$1
  LINK_NAME=$2
  OWNER=$3
  PERMISSION=$4

  if [[ -L "$LINK_NAME" ]] && cmp "$TARGET" "$LINK_NAME" >/dev/null 2>&1; then
    verbose "$LINK_NAME is already updated."
    return
  else
    TARGET_PARENT_DIRECTORY=$(dirname "$TARGET")
    # Make sure the target's parent directory exists.
    if ! [ -d "$TARGET_PARENT_DIRECTORY" ]; then
      info "Making target parent directory $PARENT_DIRECTORY."
      if [[ $DRY_RUN = false ]]; then
        mkdir -p "$TARGET_PARENT_DIRECTORY"
      fi
    fi
    LINK_NAME_PARENT_DIRECTORY=$(dirname "$LINK_NAME")
    # Make sure the link name's parent directory exists.
    if ! [ -d "$" ]; then
      info "Making link name parent directory $LINK_NAME_PARENT_DIRECTORY."
      if [[ $DRY_RUN = false ]]; then
        mkdir -p "$LINK_NAME_PARENT_DIRECTORY"
      fi
    fi
    if [ -f "$LINK_NAME" ] || [ -d "$LINK_NAME" ]; then
      LINK_NAME_OLD="$LINK_NAME.old"
      info "File or directory to be linked $NAME exists, moving to $LINK_NAME_OLD."
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
  if [[ -n $OWNER ]]; then
    if [[ $(stat -c "%U:%G" "$LINK_NAME") != "$OWNER" && $(stat -c "%U" "$LINK_NAME") != "$OWNER" ]]; then
      info "Setting owner of $LINK_NAME to $OWNER."
      if [[ $DRY_RUN = false ]]; then
        chown "$OWNER" "$LINK_NAME"
      fi
    fi
  fi
  if [[ -n $PERMISSION ]]; then
    info "Setting permissions of $LINK_NAME to $PERMISSION."
    if [[ $DRY_RUN = false ]]; then
      chmod "$PERMISSION" "$LINK_NAME"
    fi
  fi
}
