#!/bin/bash
# Copies the live Omarchy customizations from this computer into the repo.
# Run it, review `git status`, then commit and push.
set -euo pipefail
cd "$(dirname "$0")"

state="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"

# Shell plugins (without the original authors' .git folders).
plugins=(bibek.lock skyhonnor.performance bruno.bar bruno.clock bruno.control bruno.music bruno.osd bruno.workspaces)
for p in "${plugins[@]}"; do
  mkdir -p "plugins/$p"
  rsync -a --exclude .git "$HOME/.config/omarchy/plugins/$p/" "plugins/$p/"
done

# Config files.
mkdir -p config/omarchy config/hypr
cp "$HOME/.config/omarchy/shell.json" config/omarchy/shell.json
cp "$HOME/.config/omarchy/lock.json" config/omarchy/lock.json
cp "$HOME/.config/hypr/hyprland.lua" config/hypr/hyprland.lua

# Omarchy toggles (glassy windows, no gaps, rounded corners, screensaver off...).
mkdir -p state/toggles
rsync -a "$state/toggles/" state/toggles/

# Theme name and the background picked inside it.
omarchy theme current > state/theme
basename "$(readlink -f "$state/current/background")" > state/background

# Weather location, only when one was set by hand (otherwise it is found by IP).
if [[ -s $state/settings/weather.json ]]; then
  mkdir -p state/settings
  cp "$state/settings/weather.json" state/settings/weather.json
fi
