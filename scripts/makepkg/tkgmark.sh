#!/bin/bash

# Copyright 2019 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/makepkg/repos.sh
source "$CO"/scripts/makepkg/repos.sh

# Prints the current TkG Linux Kernel configuration, for benchmarking purposes.
# Outputs:
#   - A selection of variables from the TkG Linux configuration.
function tkgmark() {
  # shellcheck source=config/tkg/linux57-tkg.cfg
  source "$CO"/config/tkg/linux$KERNEL_VER-tkg.cfg
  echo "$_cpusched, $_sched_yield_type, $_rr_interval, $_tickless, $_voluntary_preempt, ${_irq_threading:-"N/A"}, ${_smt_nice:-"N/A"}, ${_runqueue_sharing:-"N/A"}, $_timer_freq"
}
