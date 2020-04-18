#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# Color Variables

NORMAL=$(tput sgr0)
export NORMAL
BOLD=$(tput bold)
export BOLD
WHITE=$(tput setaf 7)
export WHITE
GREEN=$(tput setaf 2)
export GREEN
CYAN=$(tput setaf 6)
export CYAN
BLUE=$(tput setaf 4)
export BLUE
MAGENTA=$(tput setaf 5)
export MAGENTA
RED=$(tput setaf 1)
export RED

# Printing Utilities

# Prints an info section message.
# Arguments:
#   - Name of the section.
# Outputs:
#   - The section message.
function info_section()
{
  printf "[${WHITE}Section${NORMAL}] ${BOLD}%s${NORMAL}\n" "$*"
}

# Prints an info message.
# Arguments:
#   - Info to be printed.
# Outputs:
#   - The info message.
function info()
{
  printf "[${GREEN}Info${NORMAL}   ] %s\n" "$*"
}

# Prompts for a boolean configuration value.
# Arguments:
#   - Question to ask.
#   - Name of the variable to put the answer in.
#   - (Optional) Default answer, else prompt.
# Globals Exported:
#   - The configured variable.
# Outputs:
#   - The configuration prompt.
function config_bool()
{
  local -r QUESTION=$1
  local -r VARIABLE_NAME=$2
  local -r ANSWER=$3

  MESSAGE="[${CYAN}Config${NORMAL} ] $QUESTION"

  if [[ -n "$ANSWER" ]]; then
    printf "%s %s\n" "$MESSAGE" "$ANSWER"
  else
    read -rp "$MESSAGE " PROMPT
  fi

  if [[ $PROMPT = "y" || $ANSWER = "y" ]]; then
    export "$VARIABLE_NAME"=true
  else
    export "$VARIABLE_NAME"=false
  fi
}

# Prompts for a string configuration value.
# Arguments:
#   - Question to ask.
#   - Name of the variable to put the answer in.
#   - (Optional) Default answer, else prompt.
# Globals Exported:
#   - The configured variable.
# Outputs:
#   - The configuration prompt.
function config_str()
{
  local -r QUESTION=$1
  local -r VARIABLE_NAME=$2
  local answer=$3

  MESSAGE="[${CYAN}Config${NORMAL} ] $QUESTION"

  if [[ -n "$answer" ]]; then
    printf "%s %s\n" "$MESSAGE" "$answer"
  else
    read -rp "$MESSAGE " answer
  fi
  
  export "$VARIABLE_NAME"="$answer"
}

# Prints a debug message.
# Globals Read:
#   - (Optional) DEBUG: Whether to print debug info, out of true or false. Default false.
# Arguments:
#   - Debug info to be printed.
# Outputs:
#   - The debug message.
function debug()
{
  if [[ $DEBUG = true ]]; then
    printf "[${BLUE}Debug${NORMAL}  ] %s\n" "$*"
  fi
}

# Prints a verbose message.
# Globals Read:
#   - (Optional) VERBOSE: Whether to print verbose info, out of true or false. Default false.
# Arguments:
#   - Verbose info to be printed.
# Outputs:
#   - The verbose message.
function verbose()
{
  if [[ $VERBOSE = true ]]; then
    printf "[${MAGENTA}Verbose${NORMAL}] %s\n" "$*"
  fi
}

# Prints an error message.
# Arguments:
#   - Error to be printed.
# Outputs:
#   - The error message.
function error()
{
  printf "[${RED}Error${NORMAL}  ] %s\n" "$*"
}

# Other Utilities

# Checks the user running the script.
# Globals Read:
#   - DRY_RUN: See setup().
# Arguments:
#   - Whether to require root.
function check_user()
{
  local -r REQUIRE_ROOT=$1

  if [[ $DRY_RUN = false ]]; then
    if [[ $EUID -eq 0 ]]; then
      if [[ $REQUIRE_ROOT = false ]]; then
        error "This script cannot be run as root."
        exit 1
      fi
    else
      if [[ $REQUIRE_ROOT = true ]]; then
        error "This script must be run as root."
        exit 1
      fi
    fi
  fi
}

# Enters the script directory, and sets up a trap to return.
# Arguments:
#   - The name of the script.
function enter_script_dir()
{
  # Enter the script directory so that we can use relative paths.
  pushd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null
  trap popd ERR
}

# Asks if the directory selection process should be canceled or not.
# Outputs:
#   - 1 if the user wants to exit, else 0.
function prompt_exit()
{
  zenity --question --text "The list dialog was closed, or cancel was clicked. Exit?"
  echo $?
}