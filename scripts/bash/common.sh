#!/bin/bash

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
export NORMAL

# Printing Utilities

# Prints an info section message.
# Arguments:
#   - Name of the section.
# Outputs:
#   - The section message.
info_section()
{
  printf "[${WHITE}Section${NORMAL}] ${BOLD}%s${NORMAL}\n" "$*"
}

# Prints an info message.
# Arguments:
#   - Info to be printed.
# Outputs:
#   - The info message.
info()
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
config_bool()
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
config_str()
{
  QUESTION=$1
  VARIABLE_NAME=$2
  ANSWER=$3

  MESSAGE="[${CYAN}Config${NORMAL} ] $QUESTION"

  if [[ -n "$ANSWER" ]]; then
    printf "%s %s\n" "$MESSAGE" "$ANSWER"
  else
    read -rp "$MESSAGE " ANSWER
  fi
  
  export "$VARIABLE_NAME"="$ANSWER"
}

# Prints a debug message.
# Globals Read:
#   - (Optional) DEBUG: Whether to print debug info, out of true or false. Default false.
# Arguments:
#   - Debug info to be printed.
# Outputs:
#   - The debug message.
debug()
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
verbose()
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
error()
{
  printf "[${RED}Error${NORMAL}  ] %s\n" "$*"
}

# Other Utilities

# Asks if the directory selection process should be canceled or not.
# Outputs:
#   - 1 if the user wants to exit, else 0.
prompt_exit()
{
  zenity --question --text "The list dialog was closed, or cancel was clicked. Exit?"
  echo $?
}