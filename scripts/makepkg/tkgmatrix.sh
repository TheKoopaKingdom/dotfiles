#!/bin/bash

# Copyright 2020 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/makepkg/repos.sh
source "$CO"/scripts/makepkg/repos.sh

# Builds a "matrix" of TkG configurations, saving them all to $AUR_DIR/tkgmatrix. To use this, you
# must add a line at the *end* of your TkG Linux configuration to source tkgmatrix.cfg, like so:
#   # shellcheck disable=1090
#   source "$HOME"/Documents/AUR/tkgmatrix/tkgmatrix.cfg
# Globals Read:
#   - AUR_DIR: The directory where the repositories are located. In this case, this is just used for
# storing the builds (although build_repo does build $AUR_DIR/linux-tkg).
# Globals Exported:
#   - PKGDEST: The last directory to have a build saved to.
# Outputs:
#   - makepkg output.
function tkgmatrix() {
  local -rA TIER_1=(["_cpusched"]="pds muqss")
  local -rA TIER_2=(
    ["_sched_yield_type"]="0 1 2"
    ["_rr_interval"]="1 2 3 4"
    ["_tickless"]="0 1 2"
    ["_voluntary_preempt"]="true false"
    ["_irq_threading"]="true false"
    ["_smt_nice"]="true false"
    ["_runqueue_sharing"]="none smt mc-llc all"
    ["_timer_freq"]="100 500 750 1000"
  )

  cd "$AUR_DIR" || return 1
  mkdir -p tkgmatrix && cd tkgmatrix || return 1

  for upper_variable_name in "${!TIER_1[@]}"; do
    for upper_variable_value in ${TIER_1[${upper_variable_name}]}; do
      upper="$upper_variable_name"="$upper_variable_value"
      for lower_variable_name in "${!TIER_2[@]}"; do
        if [[ $upper_variable_value != "muqss" ]] && [[ $lower_variable_name = "_irq_threading" || \
        $lower_variable_name = "_runqueue_sharing" ]]; then
          continue
        fi
        for lower_variable_value in ${TIER_2[${lower_variable_name}]}; do
          lower="$lower_variable_name"="$lower_variable_value"
          local PKGDEST="$upper"/"$lower"
          mkdir -p "$PKGDEST"
          PKGDEST=$(realpath "$PKGDEST")
          export PKGDEST
          echo "pkgbase=linux-tkgmatrix" >tkgmatrix.cfg
          echo "$upper" >>tkgmatrix.cfg
          echo "$lower" >>tkgmatrix.cfg
          build_repo linux-tkg/linux"$KERNEL_VER"-tkg false
        done
      done
    done
  done
}

tkgmatrix
