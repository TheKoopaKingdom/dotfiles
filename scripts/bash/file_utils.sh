#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh

# Copies a file, checking to see if it's already updated or not. Supports dry run.
# Globals Read:
#   - DRY_RUN: See setup().
# Arguments:
# - The source file path.
# - The destination file paths.
# - The owner to set the destination to (optional).
# - The permission to set the destination to (optional).
#  set the destination to.
# Returns:
#   None.
safe_cp() {
  local -r source=$1
  local -r destination=$2
  local -r owner=$3
  local -r permission=$4

  if cmp "$source" "$destination" >/dev/null 2>&1; then
    verbose "$destination is already copied."
  else
    info "Copying file $source => $destination."
    if [[ $DRY_RUN = false ]]; then
      PARENT=$(dirname "$destination")
      if [[ ! -d $PARENT ]]; then
        info "Making parent $PARENT."
        mkdir -p "$PARENT"
      fi
      cp "$source" "$destination"
    fi
  fi
  if [[ -n $owner ]]; then
    info "Setting owner of $destination to $owner."
    if [[ $DRY_RUN = false ]]; then
      chown "$owner" "$destination"
    fi
  fi
  if [[ -n $permission ]]; then
    info "Setting permissions of $destination to $permission."
    if [[ $DRY_RUN = false ]]; then
      chmod "$permission" "$destination"
    fi
  fi
}

# Links one file to another and resolves conflicts.
# Globals Read:
#   - DRY_RUN: See setup().
# Arguments:
#   - The target file path.
#   - The link file path.
# Outputs:
#   - Link feedback.
function safe_ln() {
  local -r target=$1
  local -r link_name=$2

  if [[ -L "$link_name" ]] && cmp "$target" "$link_name" >/dev/null 2>&1; then
    verbose "$link_name is already updated."
  else
    local -r target_parent_directory=$(dirname "$target")
    # Handle conflicts with nonexistent target parent directories. This is a pretty unlikely
    # scenario, but possible if the path will later be populated with files.
    if ! [[ -d "$target_parent_directory" ]]; then
      info "Making target parent directory $target_parent_directory."
      if [[ $DRY_RUN = false ]]; then
        mkdir -p "$target_parent_directory"
      fi
    fi

    # Handle conflicts with preexisting files or directories.
    if [[ -f "$link_name" ]] || [[ -d "$link_name" ]]; then
      local -r common_str="Path $link_name exists"
      if [[ -L "$link_name" ]]; then
        info "$common_str, is a link. Overwriting."
      else
        local -r link_name_old="$link_name.old"
        info "$common_str, isn't a link. Moving to $link_name_old."
        if [[ $DRY_RUN = false ]]; then
          mv "$link_name" "$link_name_old"
        fi
      fi

    # Handle conflcits with nonexistent link name parent directories.
    else
      local -r link_name_parent_directory=$(dirname "$link_name")
      info "Making link name parent directory $link_name_parent_directory."
      if [[ -L "$link_name_parent_directory" ]]; then
        info "Parent directory $link_name_parent_directory is a link, overwriting."
        rm "$link_name_parent_directory"
      fi
      if [[ $DRY_RUN = false ]]; then
        mkdir -p "$link_name_parent_directory"
      fi
    fi

    info "Creating link to target $target at $link_name."

    if [[ $DRY_RUN = false ]]; then
      debug "Executing ln -sf \"$target\" \"$link_name\""
      ln -sf "$target" "$link_name"
    fi
  fi
}

# Enters a directory, erroring and exiting if anything goes wrong.
# Arguments:
#   - The directory to change to.
# Outputs:
#   - Change directory feedback.
# Returns:
#   - 1 if an error occurred.
function safe_cd() {
  d=$1
  if ! cd "$d"; then
    error "Unable to enter directory \"$d\"."
    exit 1
  fi
}
