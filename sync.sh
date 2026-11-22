#!/bin/bash
# Copies the live Omarchy customizations from ~/.config into this repo.
# Run it, review `git status`, then commit and push.
set -euo pipefail
cd "$(dirname "$0")"

plugins=(bibek.lock skyhonnor.performance bruno.bar bruno.clock bruno.control bruno.music bruno.osd bruno.workspaces)
for p in "${plugins[@]}"; do
  mkdir -p "plugins/$p"
  rsync -a --exclude .git "$HOME/.config/omarchy/plugins/$p/" "plugins/$p/"
done

mkdir -p config/omarchy config/hypr
cp "$HOME/.config/omarchy/shell.json" config/omarchy/shell.json
cp "$HOME/.config/omarchy/lock.json" config/omarchy/lock.json
cp "$HOME/.config/hypr/hyprland.lua" config/hypr/hyprland.lua
