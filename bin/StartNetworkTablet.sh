#!/bin/bash
sudo echo "Starting GfxTablet, please enter your password:"
sudo networktablet
xinput map-to-output "$( xinput list --id-only "Network Tablet" )" HDMI1
notify-send "GfxTablet" "GfxTablet is now running."
