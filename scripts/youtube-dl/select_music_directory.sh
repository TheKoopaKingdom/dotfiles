#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh

declare -r MUSIC_DIRECTORY=$HOME/Music/

# Tests whether a field is valid.
# Arguments:
#   - The input string.
# Outputs:
#   - 0 if the string is invalid.
#   - 1 if the string is valid.
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
#   - The title of the song.
# Outputs:
#   - Selection progress, or an error if one occurred.
# Returns:
#   - 0 if successful.
#   - 1 if the music directory wasn't found.
#   - 2 if the user canceled.
#   - 3 if an error occured while processing the directory.
function select_music_directory() {
  local -r song_title=$(sanitize_zenity "$1")

  if [[ ! -d "$MUSIC_DIRECTORY" ]]; then
    echo "Music directory \"$MUSIC_DIRECTORY\" not found."
    return 1
  fi

  local -a categories
  local -a parent_categories
  while read -r category_directory_path; do
    # Find will first output the starting point.
    if [[ "$category_directory_path" = "$MUSIC_DIRECTORY" ]]; then
      continue
    # Ignore directories left by file synchronization.
    # .debris   MEGA
    elif [[ $category_directory_path == *".debris"* ]]; then
      continue
    fi
    local has_subdirectories=false
    # Check if the category has subcategories.
    while read -r subcategory_directory_path; do
      # Find will first output the starting point, again.
      if [[ "$subcategory_directory_path" = "$category_directory_path" ]]; then
        continue
      # Check if the directory is just a disc folder. Regex:
      # Disc    Match the word Disc.
      # \ *     Match 0 or more spaces (\ used to escape the space, for Bash.)
      # [0-9]+  Match a number one or more times.
      elif [[ $subcategory_directory_path =~ Disc\ *[0-9]+ ]]; then
        continue
      fi
      local categories+=("$(basename "$subcategory_directory_path")")
      local parent_categories+=("$(basename "$category_directory_path")")
      has_subdirectories=true
      # Don't run the while loop in a subshell.
    done <<<"$(find "$category_directory_path" -maxdepth 1 -type d)"
    if [[ $has_subdirectories = false ]]; then
      local categories+=("$(basename "$category_directory_path")")
      local parent_categories+=("")
    fi
    # Don't run the while loop in a subshell.
  done <<<"$(find "$MUSIC_DIRECTORY" -maxdepth 1 -type d)"
  local -a args
  for ((index = 0; index < ${#categories[@]}; ++index)); do
    args+=(FALSE "${categories[index]}")
    if [[ "${parent_categories[index]}" ]]; then
      args+=("${parent_categories[index]}")
    else
      args+=(" ")
    fi
  done
  local new_category=false
  while true; do
    local -a category_input
    category_input="$(zenity --width 1500 --height 1200 \
      --list --radiolist \
      --title "Select a Category" \
      --text "Select a category from the list below for the song \"$song_title\"." \
      --column "" --column "Category Name" --column "Parent Category Name" \
      --print-column 2,3 \
      TRUE "Make a new category" " " "${args[@]}")"
    local category_name
    category_name=$(echo "$category_input" | cut -d'|' -f1)
    local category_name_valid
    category_name_valid=$(validate_input "$category_name")
    local parent_category_name
    parent_category_name=$(echo "$category_input" | cut -d'|' -f2)
    local parent_category_name_valid
    parent_category_name_valid=$(validate_input "$parent_category_name")
    if [[ "$category_name" = "Make a new category" ]]; then
      new_category=true
      break
    # If there's a category without a parent.
    elif [[ $category_name_valid -eq 1 ]] && [[ $parent_category_name_valid -eq 1 ]]; then
      local category_path=$MUSIC_DIRECTORY$parent_category_name/$category_name
      break
    elif [[ $category_name_valid -eq 1 ]] && [[ $parent_category_name_valid -eq 0 ]]; then
      local category_path=$MUSIC_DIRECTORY$category_name
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
    printf "Music Artists" | xclip -selection clipboard
    while true; do
      # shellcheck disable=2155
      local -a new_category_input
      new_category_input=$(zenity --width 1500 --height 1000 \
        --forms \
        --title "Add a Category" \
        --text "Enter information for the category to put \"$song_title\" in.". \
        --add-entry "Category Name" \
        --add-entry "Parent Category (Optional)")
      local category_name
      category_name=$(echo "$new_category_input" | cut -d'|' -f1)
      local category_name_valid
      category_name_valid=$(validate_input "$category_name")
      local parent_category_name
      parent_category_name=$(echo "$new_category_input" | cut -d'|' -f2)
      local parent_category_name_valid
      parent_category_name_valid=$(validate_input "$parent_category_name")
      if [[ $category_name_valid -eq 1 ]] && [[ $parent_category_name_valid -eq 1 ]]; then
        local category_path=$MUSIC_DIRECTORY$parent_category_name/$category_name
        break
      elif [[ $category_name_valid -eq 1 ]] && [[ $parent_category_name_valid -eq 0 ]]; then
        local category_path=$MUSIC_DIRECTORY$category_name
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
    mkdir "$category_path"
  fi

  if [[ -z "$category_path" ]]; then
    echo "Category path not set."
    return 3
  fi
  if [[ ! -d "$category_path" ]]; then
    echo "Category path not found."
    return 3
  fi
  echo "$category_path"
  return 0
}
