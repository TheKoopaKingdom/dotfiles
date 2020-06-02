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
      debug "Subcategory $subcategory_directory_path."
      local categories+=("$(basename "$subcategory_directory_path")")
      local parent_categories+=("$(basename "$category_directory_path")")
      has_subdirectories=true
      # Don't run the while loop in a subshell.
    done <<<"$(find "$category_directory_path" -maxdepth 1 -type d)"
    if [[ $has_subdirectories = false ]]; then
      debug "Category $category_directory_path."
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
    # TODO: escape &s
    local -r category_input=$(zenity --width 1000 --height 500 \
      --list --radiolist \
      --title "Select a Category" \
      --text "Select a category from the list below for the song \"$1\"." \
      --column "" --column "Category Name" --column "Parent Category Name" \
      --print-column 2,3 \
      TRUE "Make a new category" " " "${args[@]}")
    local -r category_name=$(echo "$category_input" | cut -d'|' -f1)
    local -r category_name_valid=$(validate_input "$category_name")
    local -r parent_category_name=$(echo "$category_input" | cut -d'|' -f2)
    local -r parent_category_name_valid=$(validate_input "$parent_category_name")
    # debug "Category name: \"$category_name\". Parent category name: \"$parent_category_name\""
    # If the user wants to make a new category.
    if [[ "$category_name" = "Make a new category" ]]; then
      debug "New category selected."
      new_category=true
      break
    # If there's a category without a parent.
    elif [[ $category_name_valid -eq 1 ]] && [[ $parent_category_name_valid -eq 1 ]]; then
      debug "Category and parent selected."
      local -r category_path=$MUSIC_DIRECTORY$parent_category_name/$category_name
      break
    elif [[ $category_name_valid -eq 1 ]] && [[ $parent_category_name_valid -eq 0 ]]; then
      debug "Category selected, not parent."
      local -r category_path=$MUSIC_DIRECTORY$category_name
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
    debug "Making new category \"$category_name\""
    while true; do
      local -ra new_category_input=$(zenity --width 1000 --height 500 \
        --forms \
        --title "Add a Category" \
        --text "Enter information for the category to put \"$1\" in.". \
        --add-entry "Category Name" \
        --add-entry "Parent Category (Optional)")
      local -r category_name=$(echo "$new_category_input" | cut -d'|' -f1)
      local -r category_name_valid=$(validate_input "$category_name")
      local -r parent_category_name=$(echo "$new_category_input" | cut -d'|' -f2)
      local -r parent_category_name_valid=$(validate_input "$parent_category_name")
      debug "Category name: \"$category_name\"$category_name_valid. Parent category name: \"$parent_category_name\""
      if [[ $category_name_valid -eq 1 ]] && [[ $parent_category_name_valid -eq 1 ]]; then
        # debug "Category and parent exist."
        local -r category_path=$MUSIC_DIRECTORY$parent_category_name/$category_name
        break
      elif [[ $category_name_valid -eq 1 ]] && [[ $parent_category_name_valid -eq 0 ]]; then
        # debug "Category exists, no parent."
        local -r category_path=$MUSIC_DIRECTORY$category_name
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
    return 1
  fi
  debug "Category path: \"$category_path\"."
  if [[ ! -d "$category_path" ]]; then
    echo "Category path not found."
    return 1
  fi
  echo "$category_path"
}
