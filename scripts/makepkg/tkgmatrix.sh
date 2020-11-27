#!/bin/bash

# Copyright 2020 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/bash/file_utils.sh
source "$CO"/scripts/bash/file_utils.sh
# shellcheck source=scripts/makepkg/repos.sh
source "$CO"/scripts/makepkg/repos.sh

export KERNEL_VER=57

# Builds a "matrix" of TkG configurations, with each TkG variable having a set of mutations, for
# benchmarking purposes. This function can build all of the mutations needed, taking into account
# duplicate builds, as well as parameters that can be modified at runtime or boot time. Usage:
#   - Construct the TIER associative arrays with the desired variable names and space separated
# values.
#   - Use "tkgmatrix print" to verify that the matrix and baseline are correct.
#   - Use "tkgmatrix build" to make a build for every unique mutation. For the baseline mutations,
# only one build will be created. For the rest, symlinks will be created.
#   - Boot into the baseline build.
#   - Use "tkgmatrix bench" to benchmark the baseline.
#   - For the remaining mutations, depending on their type:
#     - Install their package and reboot.
#     - Change the kernel parameters and reboot.
#     - Use sysctl to change the parameter.
# and then use "tkgmatrix bench" again to benchmark that change.
#
# The configuration in ~/.config/frogminer/ will be used as the baseline, the "default" set of
# variables, so make sure they are sane! Also make sure that none of the relevant variables have a
# comment at the end of the line, as this script will consume everything after the `=` because
# parsing is hard, and having Bash parse it for us would get complciated.
#
# When building, a tkgmark section will be appended to the frogminer configuration file, sourcing a
# file with the mutated variables. This script should remove it upon completion.
#
# Globals Read:
#   - AUR_DIR: The directory where the repositories are located. In this case, this is just used for
# storing the builds (although build_repo does build $AUR_DIR/linux-tkg).
# Globals Exported:
#   - PKGDEST: The last directory to have a build saved to.
# Arguments:
#   - The subcommand to run, one of:
#     - "help", to print the usage message.
#     - "print", to print the matrix of TkG variable mutations, whether they have a benchmark,
# whether belong to the baseline, and the method for changing it, if it's anything other than
# installing the build.
#     - "build", to make a build for all of the mutations which require separate builds.
#     - "bench", to run a benchmark for the current installed mutation(s). The first time this is
# ran, symlinks will be created for baseline "duplicates". After that, this shouldn't be a concern.
# Outputs:
#   - makepkg output.
function tkgmatrix() {
  local -r subcommand=$1

  if [[ -z $subcommand || $subcommand = "-h" || $subcommand = "--help" ||
    $subcommand = "help" ]]; then
    info "Usage: tkgmatrix { help | print | build | bench }"
    if [[ -z $subcommand ]]; then
      return 2
    else
      return 0
    fi
  fi

  section "Initializing"

  local -rA TIER_1=(["_cpusched"]="pds MuQSS")
  local -rA TIER_2=(
    ["_sched_yield_type"]="0 1 2"               # Baseline: 0
    ["_rr_interval"]="default 1 2 3 4"          # Baseline: default
    ["_tickless"]="0 1 2"                       # Baseline: 0
    ["_voluntary_preempt"]="true false"         # Baseline: true
    ["_irq_threading"]="true false"             # Baseline: false
    ["_smt_nice"]="true false"                  # Baseline: true
    ["_runqueue_sharing"]="none smt mc-llc all" # Baseline: smt
    ["_timer_freq"]="100 500 750 1000"          # Baseline: 100.
  )

  if [[ ! -d $AUR_DIR ]]; then
    error "AUR directory \"$AUR_DIR\" not found."
    return 1
  fi
  tkgmatrix_dir="$AUR_DIR"/tkgmatrix
  mkdir -p "$tkgmatrix_dir" && safe_cd "$tkgmatrix_dir"

  local -r frogminer_cfg_file=$HOME/.config/frogminer/linux-tkg.cfg
  if [[ ! -f "$frogminer_cfg_file" ]]; then
    error "linux-tkg configuration \"$frogminer_cfg_file\" not found."
    return 1
  fi

  # If we are printing, print the paths being used.
  if [[ $subcommand = "print" ]]; then
    info "tkgmatrix directory: $tkgmatrix_dir"
    info "frogminer customization file: $frogminer_cfg_file"

  # If we are building, prep the frogminer cfg for sourcing the tkgmatrix cfg.
  elif [[ $subcommand = "build" ]]; then
    info "Adding tkgmatrix lines to the linux-tkg configuration."

    local -r common_sed_args=(-i --follow-symlinks "$frogminer_cfg_file")
    # Remove any existing tkgmatrix source lines, so that nothing will break when the PKGBUILD
    # sources the cfg.
    sed -E '/source.+tkgmatrix/d' "${common_sed_args[@]}"

    # Add a line to source our cfg file that we'll be changing for different mutations.
    local -r tkgmatrix_cfg_file=tkgmatrix.cfg
    local -r TAG="#### TKGMATRIX ####"
    echo "
$TAG
# Any text at or below the TKGMATRIX tag is subject for deletion by tkgmatrix!

source $tkgmatrix_dir/$tkgmatrix_cfg_file" >>"$frogminer_cfg_file"

  # If we are benchmarking, detect the permutation currently being used.
  elif [[ $subcommand = "bench" ]]; then
    local -r mangohud_cfg=$HOME/.config/MangoHud/MangoHud.conf
    local -r mangohud_cfg_orig=$mangohud_cfg.orig
    local move_mangohud_cfg_back=false
    if [[ -f "$mangohud_cfg_orig" ]]; then
      error "MangoHud backup configuration exists at \"$mangohud_cfg_orig\", unsure of what to do."
      return 1
    fi
    if [[ -f $mangohud_cfg ]]; then
      info "MangoHud configuration exists at \"$mangohud_cfg\", backing up."
      move_mangohud_cfg_back=true
      mv "$mangohud_cfg" "$mangohud_cfg_orig"
    fi

    # First, read the installed TkG configuration.

    # Use uname to determine what the $pkgbase for this TkG install is.
    local -r release=$(uname -r)
    local -r release_ver=$(echo "$release" | cut -d "." -f 1-2 | tr -d ".")
    if [[ $release_ver != "$KERNEL_VER" ]]; then
      error "Installed version $release_ver differs from expected version $KERNEL_VER."
      # return 1
    fi
    local installed_cfg
    installed_cfg="/usr/share/doc/linux${release_ver}-\
$(echo "$release" | cut -d '-' -f 3)-$(echo "$release" | cut -d '-' -f 4)/customization.cfg"
    if [[ ! -f $installed_cfg ]]; then
      installed_cfg=/usr/share/doc/linux-tkgmatrix/customization.cfg
      if [[ ! -f $installed_cfg ]]; then
        error "Installed configuration for kernel release $release not found."
        return 1
      fi
    fi
    source "$installed_cfg"

    # Next, read kernel parameters that can override the installed configuration.

    # See: https://stackoverflow.com/a/30524524.
    if grep -q "rqshare" /proc/cmdline; then
      # shellcheck disable=2034
      local -r _runqueue_sharing=$(sed -e 's/^.*rqshare=//' -e 's/ .*$//' </proc/cmdline)
    fi

    # Finally, read sysctl parameters that override the kernel parameters.

    # Map the actual RR values to the TkG RR variable values.
    # shellcheck disable=2034
    local -r _rr_interval_tmp=$(sysctl -n kernel.rr_interval || true)
    case $_rr_interval_tmp in
    2)
      local -r _rr_interval=1
      ;;
    4)
      local -r _rr_interval=2
      ;;
    6)
      local -r _rr_interval=3
      ;;
    8)
      # shellcheck disable=2034
      local -r _rr_interval=4
      ;;
    esac
    # shellcheck disable=2034
    local -r _sched_yield_type=$(sysctl -n kernel.yield_type || true)
  fi

  section "Traversing the matrix"

  for upper_variable_name in "${!TIER_1[@]}"; do
    for upper_variable_value in ${TIER_1[${upper_variable_name}]}; do
      local upper="$upper_variable_name"="$upper_variable_value"

      # Path to the build/benchmark for this upper tier variable's baseline (e.g. PDS baseline).
      if [[ $subcommand = "build" ]]; then
        local upper_baseline_build=""
      elif [[ $subcommand = "bench" ]]; then
        local upper_baseline_bench=""
      fi

      for lower_variable_name in "${!TIER_2[@]}"; do
        if [[ $upper_variable_value != "MuQSS" ]] && [[ $lower_variable_name = "_irq_threading" ||
          $lower_variable_name = "_runqueue_sharing" ]]; then
          continue
        fi

        [[ $lower_variable_name = "_runqueue_sharing" ]]
        local is_kernel_parameter=$?

        [[ $lower_variable_name = "_rr_interval" || $lower_variable_name = "_sched_yield_type" ]]
        local is_sysctl_parameter=$?

        for lower_variable_value in ${TIER_2[${lower_variable_name}]}; do
          local lower="$lower_variable_name"="$lower_variable_value"
          local build_dir=builds/"$upper"/"$lower"
          local bench_dir=benchmarks/"$upper"/"$lower"

          # For _rr_interval, ignore mutations that are already covered by _rr_interval=default.
          if [[ "$lower_variable_name" = "_rr_interval" ]]; then
            if [[ $upper_variable_value = "pds" && $lower_variable_value = "2" ]]; then
              continue
            fi
            if [[ $upper_variable_value = "MuQSS" && $lower_variable_value = "3" ]]; then
              continue
            fi
          fi

          # Check if this mutation is part of the baseline. Recall that the ~/.config/frogminer\
          # linuxXX/customization.cfg values are the baseline values.
          # I don't like how sloppy this is, using Regex and then cut, but I don't know grep's perl
          # mode well enough to use that to just capture the value, without any comments.
          [[ ${lower_variable_value} = "$(grep -oP "^$lower_variable_name=\K.+" \
            "$frogminer_cfg_file" | tr -d '"')" ]]
          local is_baseline=$?

          # Print the current mutation.
          if [[ $subcommand = "print" ]]; then
            printf "  %15s %25s" "$upper" "$lower"
            # See: https://stackoverflow.com/a/34195247.
            if compgen -G "$bench_dir/*.csv" >/dev/null; then
              printf " %s✔%s" "$GREEN" "$RESET"
            else
              printf " %s✘%s" "$RED" "$RESET"
            fi
            if [[ $is_baseline -eq 0 ]]; then
              printf " (%sBaseline%s)" "$CYAN" "$RESET"
            else
              # Add padding for:
              #       (Baseline)
              printf "           "
            fi
            if [[ $is_sysctl_parameter -eq 0 ]]; then
              printf " (%ssysctl Parameter%s)" "$MAGENTA" "$RESET"
            elif [[ $is_kernel_parameter -eq 0 ]]; then
              printf " (%sKernel Parameter%s)" "$MAGENTA" "$RESET"
            else
              printf " (%scfg Parameter%s)" "$MAGENTA" "$RESET"
            fi
            printf "\n"

          # Build the current mutation.
          elif [[ $subcommand = "build" ]]; then
            if [[ $is_sysctl_parameter -eq 0 ]]; then
              info "Not building \"$upper $lower\", can be controlled by sysctl."
            elif [[ $is_kernel_parameter -eq 0 ]]; then
              info "Not building \"$upper $lower\", can be controlled by a kernel parameter."
            else
              compgen -G "$build_dir/*.pkg.*" >/dev/null
              exists=$?
              if [[ $is_baseline -eq 0 ]]; then
                if [[ $exists -eq 0 ]]; then
                  info "Not building \"$upper $lower\", is part of a baseline that is already \
built."
                  continue
                fi
                if [[ -n $upper_baseline_build ]]; then
                  info "Not building \"$upper $lower\", can reuse baseline build \
\"$upper_baseline_build\"."
                  # If we have a situation where the directories are created, but without any *.pkg*
                  # files, we will get to this code, so force symlink creation.
                  ln -sTf "$upper_baseline_build" "$build_dir"
                  continue
                fi
              fi
              if [[ $exists -eq 0 ]]; then
                read -p "[${CYAN}Prompt${RESET} ] Build for \"$upper $lower\" already exists at \
\"$build_dir\". Overwrite? [y/n] " -n 1 -r overwrite_prompt
                echo
                if [[ ! $overwrite_prompt =~ ^[Yy]$ ]]; then
                  info "Not building \"$upper $lower\", overwrite declined."
                  continue
                fi
              fi
              info "Building \"$upper $lower\"."
              mkdir -p "$build_dir"
              echo "# Generated by tkgmatrix.

# Set a custom pkgbase, so that tkgmatrix builds all conflict with each other.
_custom_pkgbase=linux-tkgmatrix
# Set the upper mutation.
$upper
# Set the lower mutation.
$lower" >"$tkgmatrix_cfg_file"
              PKGDEST=$(realpath "$build_dir") build_repo linux-tkg false
              if [[ $is_baseline -eq 0 ]]; then
                # We are already in the directory for the upper tier, so all the link needs is the
                # lower tier directory name, in order to resolve.
                upper_baseline_build=$lower
              fi
            fi

          # Benchmark the current mutation.
          elif [[ $subcommand = "bench" ]]; then
            debug "$upper_variable_name: ${!upper_variable_name} == $upper_variable_value"
            debug "$lower_variable_name: ${!lower_variable_name} == $lower_variable_value"
            # Check if the mutation currently running equals the mutation of this loop iter.
            # See: https://stackoverflow.com/a/18124325.
            if [[ ${!upper_variable_name} = "$upper_variable_value" ]]; then
              if [[ ${!lower_variable_name} = "$lower_variable_value" ]]; then
                compgen -G "$bench_dir/*.csv" >/dev/null
                exists=$?
                if [[ $is_baseline -eq 0 ]]; then
                  # If this mutation is a baseline and has a benchmark dir already, it is safe to
                  # ignore without asking.
                  if [[ $exists -eq 0 ]]; then
                    info "Not benchmarking \"$upper $lower\", is part of a baseline that has \
already been benchmarked."
                    continue
                  fi

                  if [[ -n $upper_baseline_bench ]]; then
                    info "Not benchmarking \"$upper $lower\", can reuse baseline benchmark \
\"$upper_baseline_bench\"."
                    # See above for why -f is used.
                    ln -sTf "$upper_baseline_bench" "$bench_dir"
                    continue
                  fi
                fi
                if [[ $exists -eq 0 ]]; then
                  read -p "[${CYAN}Prompt${RESET} ] Benchmark for \"$upper $lower\" already exists \
at \"$bench_dir\". Continue? [y/n] " -n 1 -r overwrite_prompt
                  echo
                  if [[ ! $overwrite_prompt =~ ^[Yy]$ ]]; then
                    info "Not benchmarking \"$upper $lower\", declined."
                    continue
                  fi
                fi

                info "Benchmarking ${upper_variable_name} = $upper_variable_value & \
${lower_variable_name} = $lower_variable_value."
                mkdir -p "$bench_dir"
                # For MangoHud, we have to resolve the full path to the output directory.
                # Additionally, the program process is not a child of this process, because Steam,
                # so using environment variables seems to be out of the question - use the
                # configuration file instead.
                echo "# Generated by tkgmatrix.

# Set the output directory.
output_folder=$(realpath "$bench_dir")" >"$mangohud_cfg"

                # If we are using the MANGOHUD_CONFIG envvar, we need to escape the "=" characters.
                # bench_dir_real=$(realpath "$bench_dir")
                # export MANGOHUD_CONFIG="position=top-right,output_folder=${bench_dir_real//=/\\=}"
                steam -applaunch 271590
                info "Waiting for program to start."
                local -a pids
                until pids=$(pidof GTA5.exe); do
                  sleep 1
                done
                info "Waiting for program ($pids) to exit."
                for pid in "${pids[@]}"; do
                  while [[ -e /proc/$pid ]]; do
                    sleep 1
                  done
                done

                if [[ $is_baseline -eq 0 ]]; then
                  # Only the adjacent directory name is needed to resolve the symlink.
                  upper_baseline_bench=$lower
                fi
              fi
            fi
          fi
        done
      done
    done
  done

  if [[ $subcommand = "print" ]]; then
    info "How to test mutations:
  - For sysctl parameters, run \"sudo sysctl kernel.\$parameter=\$value\".
  - For kernel parameters, run \"sudo update-efi normal \$parameter=\$value\"
  - For cfg parameters, run \"pikaur -U \$build && sudo update-efi normal\"."
  fi

  section "Uninitializing"

  # Clean up.
  if [[ $subcommand = "build" ]]; then
    info "Removing tkgmatrix lines from the linux-tkg configuration."

    rm "$tkgmatrix_cfg_file"
    # Stop processing the text file as soon as the tag is reached. See:
    # https://stackoverflow.com/a/5227429.
    sed -n "/$TAG/q;p" "${common_sed_args[@]}"
    # Remove the extraneous newline that this creates.
    sed -z '$ s/\n$//' "${common_sed_args[@]}"
  elif [[ $subcommand = "bench" ]]; then
    if [[ $move_mangohud_cfg_back = true ]]; then
      info "Moving MangoHud configuration back."
      mv "$mangohud_cfg_orig" "$mangohud_cfg"
    else
      # If there were no benchmarks to be ran, then the configuration file wasn't created, so don't
      # error on failure.
      rm "$mangohud_cfg" || true
    fi
  fi

  safe_cd -
}
