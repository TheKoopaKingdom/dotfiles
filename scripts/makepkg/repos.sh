#!/bin/bash

# Copyright 2020 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh
# shellcheck source=scripts/bash/file_utils.sh
source "$CO"/scripts/bash/file_utils.sh

declare AUR_DIR=$HOME/Documents/AUR
declare COM_PATCH_DIR=$AUR_DIR/community-patches
declare -A REPOS=(
  ["community-patches"]="https://github.com/Frogging-Family/community-patches.git"
  ["linux-tkg"]="https://github.com/Frogging-Family/linux-tkg.git"
  ["nvidia-all"]="https://github.com/Frogging-Family/nvidia-all.git"
  ["wine-tkg-git/proton-tkg"]="https://github.com/Frogging-Family/wine-tkg-git.git"
)

# Checks for the existence of the Git repositories of custom packages. This function assumes that
# the working directory is the AUR directory.
# Globals Read:
#   - REPOS: An associative array mapping directories to Git repositories.
# Outputs:
#   - Cloning progress, if there are any nonexistent repositories.
function check_repos() {
  for repo in "${!REPOS[@]}"; do
    if [[ ! -d "$repo" ]]; then
      info "Repo \"$repo\" not found, cloning."
      git clone --recursive "${REPOS[${repo}]}"
    fi
  done
}

# Updates a repository. New commits and the files they change are shown for the repo, and for the
# corresponding community patch directory, if applicable. Differences made to the given files are
# shown, and the external configuration file is opened in VSCode. If this is ran for the community
# patch directory, the usual change outputting will be forgone.
# Globals Read:
#   - AUR_DIR: The directory where the repositories are located.
# Arguments:
#   - Any files *within the repo* to show the differences of, since the last pull.
# Outputs:
#   - New commits and files changed.
function update_repo() {
  local -r repo=$1
  # Use basename to strip the repo of any prefixes, such as "linux-tkg".
  local -r repo_base=$(basename "$repo")
  shift
  local -r diff_files=("$@")

  safe_cd "$AUR_DIR"/"$repo"

  # This is the easiest, least destructive way of preventing:
  #
  # error: cannot pull with rebase: You have unstaged changes.
  # error: please commit or stash them.
  verbose "Stashing any local changes."
  git stash >/dev/null

  verbose "Pulling changes."
  git pull -q origin master

  # We don't want to review changes while updating the community patches itself, but when updating
  # the other repos for which it is a peripheral of.
  if [[ "$repo" != "community-patches" ]]; then
    info "Showing $repo_base changes:"
    git --no-pager log --stat "@{1}.." -- . || true

    local com_patch_repo_dir=$COM_PATCH_DIR/$repo_base
    # Adjust for linux-tkg.
    if [[ $repo_base = linux-tkg ]]; then
      # Source the linux-tkg configuration to get the target kernel version, $_version.
      source "$HOME"/.config/frogminer/linux-tkg.cfg
      # Adjust the community patch dir to look for this kernel version. Strip the '.'(s).
      com_patch_repo_dir=${com_patch_repo_dir//$repo_base/linux"${_version//./}"-tkg}
    # Adjust for proton-tkg.
    elif [[ $repo_base = proton-tkg ]]; then
      # Use the wine-tkg-git directory.
      com_patch_repo_dir=${com_patch_repo_dir//$repo_base/wine-tkg-git}
    # Adjust for dxvk-tools.
    elif [[ $repo_base = dxvk-tools ]]; then
      # Strip the "-tools".
      com_patch_repo_dir=${com_patch_repo_dir//$repo_base/repo_base%-tools}
    fi

    if [[ -d $com_patch_repo_dir ]]; then
      info "Showing $repo_base community patch changes:"
      safe_cd "$com_patch_repo_dir"
      # Allow failure in case the repo was just cloned.
      # Store this in a variable so we can tell later, if there have been community patch changes.
      community_patch_changes=$(git --no-pager -c color.ui=always log --stat "@{1}.." -- .) || true
      if [[ -n $community_patch_changes ]]; then
        echo "$community_patch_changes"
      fi
      safe_cd -
    fi
  fi

  if [[ ${#diff_files[@]} -ne 0 ]]; then
    # Only view the configuration and configuration diff if there has been a change to it, or if
    # there has been a change to the community patches.
    if [[ -n $(git diff "@{1}.." "${diff_files[@]}") || -n "$community_patch_changes" ]]; then
      local cfg_name=$repo_base
      if [[ $repo == "dxvk-tools" ]]; then
        cfg_name="updxvk"
      elif [[ $repo == "wine-tkg-git/wine-tkg-git" ]]; then
        cfg_name="wine-tkg"
      elif [[ $repo == "wine-tkg-git/proton-tkg" ]]; then
        cfg_name="proton-tkg"
      fi
      local -r config_file=$HOME/.config/frogminer/$cfg_name.cfg
      if [[ -f "$config_file" ]]; then
        verbose "Opening configuration."
        code "$config_file"
      fi
      info "Viewing config changes."
      git difftool -y "@{1}.." "${diff_files[@]}"
    fi
  fi

  if [[ "$repo" != "community-patches" ]]; then
    pause
  fi

  safe_cd -
}

# Builds a repository, using makepkg. Previously built packages and logs are cleared first.
# Globals Read:
#   - AUR_DIR: See update_repo().
# Arguments:
#   - The repository to enter, relative to AUR_DIR.
#   - (Optional) Whether to install the build. Defaults to true.
# Outputs:
#   - makepkg output.
function build_repo() {
  local -r repo=$1
  local -r install=${2-true}
  install_arg=""
  if [[ $install = true ]]; then
    install_arg="i"
  fi

  safe_cd "$AUR_DIR/$repo"

  verbose "Cleaning old packages and build logs."
  rm -f ./*.pkg.* ./*.log
  verbose "Building."
  makepkg -sf$install_arg --noconfirm

  safe_cd -
}

# Builds DXVK using updxvk from dxvk-tools.
# Outputs:
#   - updxvk output.
function build_dxvk() {
  local -r REPO=dxvk-tools

  safe_cd "$AUR_DIR/$REPO"

  verbose "Building DXVK."
  ./updxvk build
  verbose "Installing DXVK."
  ./updxvk proton-tkg

  safe_cd -
}
