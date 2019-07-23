#!/bin/bash

####################################################################################################
### State Variables
####################################################################################################
export DEBUG=false

####################################################################################################
### Color Variables
####################################################################################################

# Only define these once per source.
NORMAL="$(tput sgr0)"
BOLD=$(tput bold)
WHITE="$(tput setaf 7)"
GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
BLUE="$(tput setaf 4)"
RED=$(tput setaf 1)

####################################################################################################
### Printing Utilities
####################################################################################################

info_section()
{
  printf "[${WHITE}Section${NORMAL}] ${BOLD}%s${NORMAL}\n" "$*"
}

info()
{
  printf "[${GREEN}Info${NORMAL}   ] %s\n" "$*"
}

config()
{
  QUESTION=$1
  VARIABLE_NAME=$2

  read -rp "[${CYAN}Config${NORMAL} ] $QUESTION" PROMPT
  if [[ $PROMPT = "y" ]]; then
    export "$VARIABLE_NAME"=true
  else
    export "$VARIABLE_NAME"=false
  fi
}

debug()
{
  if [[ $DEBUG = true ]]; then
    printf "[${BLUE}Debug${NORMAL}  ] %s\n" "$*"
  fi
}

error()
{
  printf "[${RED}Error${NORMAL}  ] %s\n" "$*"
}