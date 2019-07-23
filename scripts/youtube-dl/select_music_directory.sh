#!/bin/bash

# Dependencies:
#  - "$DOTFILES/scripts/bash/common.sh"
#  - "$DOTFILES/scripts/bash/config.sh"

# Makes sure a field isn't empty (This function is really sensitive to changes.).
# Arguments:
#  - The input string.
validate_input()
{
  INPUT=$1
  # If the string is empty/unset, or just consists of a space.
  if [[ -z $INPUT ]]; then
    echo 1
  else
    echo 0
  fi
}

# Asks if the directory selection process should be canceled or not.
prompt_exit()
{
  zenity --question --text "The list dialog was closed, or cancel was clicked. Exit?"
  echo $?
}

# Selects a music directory using Zenity. Scans category directories in the $MUSIC_DIRECTORY_PATH
# directory, and also subcategories.
# Arguments:
#  - The title of the song.
select_music_directory()
{
  declare -a CATEGORIES
  declare -a PARENT_CATEGORIES
  while read -r CATEGORY_DIRECTORY_PATH; do
    # Find will first output the starting point.
    if [ "$CATEGORY_DIRECTORY_PATH" = "$MUSIC_DIRECTORY_PATH" ]; then
      continue
    fi
    HAS_SUBDIRECTORIES=false
    # Check if the category has subcategories.
     while read -r SUBCATEGORY_DIRECTORY_PATH; do
      # Find will first output the starting point, again.
      if [ "$SUBCATEGORY_DIRECTORY_PATH" = "$CATEGORY_DIRECTORY_PATH" ]; then
        continue
        # Check if the directory is just a disc folder. Regex:
        # Disc    Match the word Disc.
        # \ *     Match 0 or more spaces (\ used to escape the space, for Bash.)
        # [0-9]+  Match a number one or more times.
      elif [[ $SUBCATEGORY_DIRECTORY_PATH =~ Disc\ *[0-9]+ ]]; then
        continue
      fi
      debug "Subcategory $SUBCATEGORY_DIRECTORY_PATH."
      CATEGORIES+=("$( basename "$SUBCATEGORY_DIRECTORY_PATH" )")
      PARENT_CATEGORIES+=("$( basename "$CATEGORY_DIRECTORY_PATH" )")
      HAS_SUBDIRECTORIES=true
      # Don't run the while loop in a subshell.
    done <<< "$(find "$CATEGORY_DIRECTORY_PATH" -maxdepth 1 -type d)"
    if [ $HAS_SUBDIRECTORIES = false ]; then
      debug "Category $CATEGORY_DIRECTORY_PATH."
      CATEGORIES+=("$( basename "$CATEGORY_DIRECTORY_PATH" )")
      PARENT_CATEGORIES+=("")
    fi
  # Don't run the while loop in a subshell.
  done <<< "$(find "$MUSIC_DIRECTORY_PATH" -maxdepth 1 -type d)"
  declare -a ARGS
  for (( INDEX=0; INDEX<${#CATEGORIES[@]}; ++INDEX )); do
    ARGS+=(FALSE "${CATEGORIES[INDEX]}" )
    if [ "${PARENT_CATEGORIES[INDEX]}" ]; then
      ARGS+=("${PARENT_CATEGORIES[INDEX]}" )
    else
      ARGS+=(" ")
    fi
  done
  NEW_CATEGORY=false
  while true; do
    # TODO: escape &s
    CATEGORY_INPUT=$(zenity --width 1000 --height 500 \
      --list --radiolist \
      --title "Select a Category" \
      --text "Select a category from the list below for the song \"$1\"." \
      --column "" --column "Category Name" --column "Parent Category Name" \
      --print-column 2,3 \
      TRUE "Make a new category" " " "${ARGS[@]}")
    CATEGORY_NAME=$(echo "$CATEGORY_INPUT" | cut -d'|' -f1)
    CATEGORY_NAME_VALID=$(validate_input "$CATEGORY_NAME")
    PARENT_CATEGORY_NAME=$(echo "$CATEGORY_INPUT" | cut -d'|' -f2)
    PARENT_CATEGORY_NAME_VALID=$(validate_input "$PARENT_CATEGORY_NAME")
    debug "Category name: \"$CATEGORY_NAME\". Parent category name: \"$PARENT_CATEGORY_NAME\""
    # If the user wants to make a new category.
    if [ "$CATEGORY_NAME" = "Make a new category" ]; then
      debug "New category selected."
      NEW_CATEGORY=true
      break
    # If there's a category without a parent.
    elif [[ $CATEGORY_NAME_VALID -eq 0 ]] && [[ $PARENT_CATEGORY_NAME_VALID -eq 0 ]]; then
      debug "Category and parent selected."
      CATEGORY_PATH=$MUSIC_DIRECTORY_PATH$PARENT_CATEGORY_NAME/$CATEGORY_NAME
      break
    elif [[ $CATEGORY_NAME_VALID -eq 0 ]] && [[ $PARENT_CATEGORY_NAME_VALID -eq 1 ]]; then
      debug "Category selected, not parent."
      CATEGORY_PATH=$MUSIC_DIRECTORY_PATH$CATEGORY_NAME
      break
    # If, nothing was checked, or cancel was clicked.
    else
      # Prompt for exit.
      # If the user doesn't want to exit.
      if [ "$(prompt_exit)" -eq 1 ]; then
        # Open up the list dialog again.
        continue
      # If the user does want to exit.
      else
        return 1
      fi
    fi
  done

  if $NEW_CATEGORY; then
    debug "Making new category \"$CATEGORY_NAME\""
    while true; do
      NEW_CATEGORY_INPUT=$(zenity --width 1000 --height 500 \
      --forms \
      --title "Add a Category" \
      --text "Enter information for the category to put \"$1\" in.". \
      --add-entry "Category Name" \
      --add-entry "Parent Category (Optional)")
      CATEGORY_NAME=$(echo "$NEW_CATEGORY_INPUT" | cut -d'|' -f1)
      CATEGORY_NAME_VALID=$(validate_input "$CATEGORY_NAME")
      PARENT_CATEGORY_NAME=$(echo "$NEW_CATEGORY_INPUT" | cut -d'|' -f2)
      PARENT_CATEGORY_NAME_VALID=$(validate_input "$PARENT_CATEGORY_NAME")
      debug "Category name: \"$CATEGORY_NAME\"$CATEGORY_NAME_VALID. Parent category name: \"$PARENT_CATEGORY_NAME\""
      if [[ $CATEGORY_NAME_VALID -eq 0 ]] && [[ $PARENT_CATEGORY_NAME_VALID -eq 0 ]]; then
        debug "Category and parent exist."
        CATEGORY_PATH=$MUSIC_DIRECTORY_PATH$PARENT_CATEGORY_NAME/$CATEGORY_NAME
        break
      elif [[ $CATEGORY_NAME_VALID -eq 0 ]] && [[ $PARENT_CATEGORY_NAME_VALID -eq 1 ]]; then
        debug "Category exists, no parent."
        CATEGORY_PATH=$MUSIC_DIRECTORY_PATH$CATEGORY_NAME
        break
      else
        # Prompt for exit.
        # If the user doesn't want to exit.
        if [ "$(prompt_exit)" -eq 1 ]; then
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

  if [ -z "$CATEGORY_PATH" ]; then
    error "Category path not set."
    return 1
  fi
  debug "Category path: \"$CATEGORY_PATH\"."
  if [ ! -d "$CATEGORY_PATH" ]; then
    error "Category path not found."
    return 1
  fi
  echo "$CATEGORY_PATH"
}
