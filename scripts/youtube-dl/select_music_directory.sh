#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/bash/config.template.sh
source "$CO"/scripts/bash/config.sh

# Makes sure a field isn't empty
# Arguments:
#  - The input string.
function validate_input() {
  local -r INPUT=$1
  # If the string is empty/unset, or just consists of a space.
  if [[ -z $INPUT ]]; then
    echo 0
  else
    echo 1
  fi
}

# Selects a music directory using Zenity. Scans category directories in the $MUSIC_DIRECTORY
# directory, and also subcategories.
# Arguments:
#  - The title of the song.
# Outputs:
#   - Selection progress.
function select_music_directory() {
  if [[ -z "$MUSIC_DIRECTORY" ]]; then
    echo "\"MUSIC_DIRECTORY\" variable not set."
    return 1
  elif [[ ! -d "$MUSIC_DIRECTORY" ]]; then
    echo "Music directory \"$MUSIC_DIRECTORY\" not found."
    return 1
  fi

  local -a CATEGORIES
  local -a PARENT_CATEGORIES
  while read -r CATEGORY_DIRECTORY_PATH; do
    # Find will first output the starting point.
    if [[ "$CATEGORY_DIRECTORY_PATH" = "$MUSIC_DIRECTORY" ]]; then
      continue
    # Ignore directories left by file synchronization.
    # .debris   MEGA
    elif [[ $CATEGORY_DIRECTORY_PATH == *".debris"* ]]; then
      continue
    fi
    local has_subdirectories=false
    # Check if the category has subcategories.
    while read -r SUBCATEGORY_DIRECTORY_PATH; do
      # Find will first output the starting point, again.
      if [[ "$SUBCATEGORY_DIRECTORY_PATH" = "$CATEGORY_DIRECTORY_PATH" ]]; then
        continue
      # Check if the directory is just a disc folder. Regex:
      # Disc    Match the word Disc.
      # \ *     Match 0 or more spaces (\ used to escape the space, for Bash.)
      # [0-9]+  Match a number one or more times.
      elif [[ $SUBCATEGORY_DIRECTORY_PATH =~ Disc\ *[0-9]+ ]]; then
        continue
      fi
      debug "Subcategory $SUBCATEGORY_DIRECTORY_PATH."
      local CATEGORIES+=("$(basename "$SUBCATEGORY_DIRECTORY_PATH")")
      local PARENT_CATEGORIES+=("$(basename "$CATEGORY_DIRECTORY_PATH")")
      has_subdirectories=true
      # Don't run the while loop in a subshell.
    done <<<"$(find "$CATEGORY_DIRECTORY_PATH" -maxdepth 1 -type d)"
    if [[ $has_subdirectories = false ]]; then
      debug "Category $CATEGORY_DIRECTORY_PATH."
      local CATEGORIES+=("$(basename "$CATEGORY_DIRECTORY_PATH")")
      local PARENT_CATEGORIES+=("")
    fi
    # Don't run the while loop in a subshell.
  done <<<"$(find "$MUSIC_DIRECTORY" -maxdepth 1 -type d)"
  local -a args
  for ((INDEX = 0; INDEX < ${#CATEGORIES[@]}; ++INDEX)); do
    args+=(FALSE "${CATEGORIES[INDEX]}")
    if [[ "${PARENT_CATEGORIES[INDEX]}" ]]; then
      args+=("${PARENT_CATEGORIES[INDEX]}")
    else
      args+=(" ")
    fi
  done
  local new_category=false
  while true; do
    # TODO: escape &s
    local -r CATEGORY_INPUT=$(zenity --width 1000 --height 500 \
      --list --radiolist \
      --title "Select a Category" \
      --text "Select a category from the list below for the song \"$1\"." \
      --column "" --column "Category Name" --column "Parent Category Name" \
      --print-column 2,3 \
      TRUE "Make a new category" " " "${args[@]}")
    local -r CATEGORY_NAME=$(echo "$CATEGORY_INPUT" | cut -d'|' -f1)
    local -r CATEGORY_NAME_VALID=$(validate_input "$CATEGORY_NAME")
    local -r PARENT_CATEGORY_NAME=$(echo "$CATEGORY_INPUT" | cut -d'|' -f2)
    local -r PARENT_CATEGORY_NAME_VALID=$(validate_input "$PARENT_CATEGORY_NAME")
    # debug "Category name: \"$CATEGORY_NAME\". Parent category name: \"$PARENT_CATEGORY_NAME\""
    # If the user wants to make a new category.
    if [[ "$CATEGORY_NAME" = "Make a new category" ]]; then
      debug "New category selected."
      new_category=true
      break
    # If there's a category without a parent.
    elif [[ $CATEGORY_NAME_VALID -eq 1 ]] && [[ $PARENT_CATEGORY_NAME_VALID -eq 1 ]]; then
      debug "Category and parent selected."
      local -r CATEGORY_PATH=$MUSIC_DIRECTORY$PARENT_CATEGORY_NAME/$CATEGORY_NAME
      break
    elif [[ $CATEGORY_NAME_VALID -eq 1 ]] && [[ $PARENT_CATEGORY_NAME_VALID -eq 0 ]]; then
      debug "Category selected, not parent."
      local -r CATEGORY_PATH=$MUSIC_DIRECTORY$CATEGORY_NAME
      break
    # If, nothing was checked, or cancel was clicked.
    else
      # Prompt for exit.
      # If the user doesn't want to exit.
      if [[ "$(prompt_exit)" -eq 1 ]]; then
        # Open up the list dialog again.
        continue
      # If the user does want to exit.
      else
        echo "Dialog exited."
        return 1
      fi
    fi
  done

  if $new_category; then
    debug "Making new category \"$CATEGORY_NAME\""
    while true; do
      local -ra NEW_CATEGORY_INPUT=$(zenity --width 1000 --height 500 \
        --forms \
        --title "Add a Category" \
        --text "Enter information for the category to put \"$1\" in.". \
        --add-entry "Category Name" \
        --add-entry "Parent Category (Optional)")
      local -r CATEGORY_NAME=$(echo "$NEW_CATEGORY_INPUT" | cut -d'|' -f1)
      local -r CATEGORY_NAME_VALID=$(validate_input "$CATEGORY_NAME")
      local -r PARENT_CATEGORY_NAME=$(echo "$NEW_CATEGORY_INPUT" | cut -d'|' -f2)
      local -r PARENT_CATEGORY_NAME_VALID=$(validate_input "$PARENT_CATEGORY_NAME")
      debug "Category name: \"$CATEGORY_NAME\"$CATEGORY_NAME_VALID. Parent category name: \"$PARENT_CATEGORY_NAME\""
      if [[ $CATEGORY_NAME_VALID -eq 1 ]] && [[ $PARENT_CATEGORY_NAME_VALID -eq 1 ]]; then
        # debug "Category and parent exist."
        local -r CATEGORY_PATH=$MUSIC_DIRECTORY$PARENT_CATEGORY_NAME/$CATEGORY_NAME
        break
      elif [[ $CATEGORY_NAME_VALID -eq 1 ]] && [[ $PARENT_CATEGORY_NAME_VALID -eq 0 ]]; then
        # debug "Category exists, no parent."
        local -r CATEGORY_PATH=$MUSIC_DIRECTORY$CATEGORY_NAME
        break
      else
        # Prompt for exit.
        # If the user doesn't want to exit.
        if [[ "$(prompt_exit)" -eq 1 ]]; then
          # Open up the list dialog again.
          continue
        # If the user does want to exit.
        else
          return 1
        fi
      fi
    done
    mkdir "$CATEGORY_PATH"
  fi

  if [[ -z "$CATEGORY_PATH" ]]; then
    echo "Category path not set."
    return 1
  fi
  debug "Category path: \"$CATEGORY_PATH\"."
  if [[ ! -d "$CATEGORY_PATH" ]]; then
    echo "Category path not found."
    return 1
  fi
  echo "$CATEGORY_PATH"
}
