#!/bin/bash

# Copyright 2020 Comet Observatory
# Licensed under GPLv3.
# Refer to License.txt file included.

# shellcheck source=scripts/bash/common.sh
source "$CO"/scripts/bash/common.sh

# Sends a SIGTERM to mpv, and waits a second for it to close.
function quit_mpv() {
  pkill mpv
  sleep 1
}

# Crops the thumbnail for an audio file, and optional trim the beginning and end.
# Arguments:
#   - The path to the audio file.
#   - Whether to crop the album art.
#   - Whether to prompt to trim the audio.
# Outputs:
#   - Any ffmpeg/ImageMagick output.
# Returns:
#   - 0 if successful.
#   - 1 if an error occurred.
function trim() {
  local -r audio=$1
  local -r audio_extensionless=${audio%.*}
  local -r crop=$2
  local -r trim=$3
  local -r song_name=$(sanitize_zenity "${audio_extensionless##*/}")
  local -r thumbnail=$audio_extensionless.jpg
  local -r audio_tmp=/tmp/trim-$(basename "$audio")

  # -vsync 2 is used to stop warnings about framerate.
  local -r FFMPEG_OPTS=(-nostdin -hide_banner -loglevel warning -y -vsync 2)
  local -r MPV_OPTS=(--no-terminal --player-operation-mode=pseudo-gui --loop-file=inf)

  # Extract the thumbnail from the MP3. We do this first because trimming the audio with ffmpeg
  # seems to lose the thumbnail.
  ffmpeg "${FFMPEG_OPTS[@]}" -i "$audio" -c copy "$thumbnail"
  if [[ $crop = true ]]; then
    # Crop the thumbnail to a square. The largest thumbnails that we will be working with are
    # 1280x720.
    convert "$thumbnail" -resize "720^>" -gravity center \
      -crop 720x720+0+0 -strip "$thumbnail"
  fi

  while true; do
    if [[ $trim = true ]]; then
      # Preview the original audio. Within the context of download_music, we already have it open in
      # firefox, so this isn't really needed here.
      if [[ $(ask "Move the beginning of the song ($song_name)?") -eq 0 ]]; then
        local beginning
        beginning=$(zenity --width 300 --entry \
          --title="Song Beginning" \
          --text="Where does the song begin?" \
          --entry-text="0:00")
      fi
      if [[ $(ask "Move the end of the song ($song_name)?") -eq 0 ]]; then
        local end
        end=$(zenity --width 300 --entry \
          --title="Song Ending" \
          --text="Where does the song end?")
      fi
    fi
    if [[ -z $beginning ]] && [[ -z $end ]]; then
      break
    else
      quit_mpv
      verbose "Processing audio."
      # Reencode the audio with different start and/or end times.
      if ! ffmpeg "${FFMPEG_OPTS[@]}" -i "$audio" \
        ${beginning+-ss $beginning} ${end+-to $end} "$audio_tmp"; then
        return 1
      fi
      # Preview the trimmed audio.
      mpv "${MPV_OPTS[@]}" "$audio_tmp" &
      if [[ $(ask "Is this good?") -ne 0 ]]; then
        quit_mpv
        unset beginning
        unset end
        continue
      else
        mv "$audio_tmp" "$audio"
        break
      fi
    fi
  done

  # Remove the audio trim tmp file if it exists, as we will be using it as an image crop tmp file.
  rm -f "$audio_tmp"
  # Embed the cropped thumbnail.
  ffmpeg "${FFMPEG_OPTS[@]}" -i "$audio" -i "$thumbnail" \
    -map 0:0 -map 1:0 -c copy -id3v2_version 3 \
    -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (Front)" "$audio_tmp"
  mv "$audio_tmp" "$audio"
  rm -f "$thumbnail"

  quit_mpv
  return 0
}
