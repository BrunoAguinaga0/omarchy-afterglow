# Config files kept in this repo, as paths under ~/.config.
# Shared by sync.sh (copies them in) and restore.sh (copies them out).
config_files=(
  omarchy/shell.json    # bar layout, idle, active plugins
  omarchy/shell.toml    # glass and borders for the menu and notifications
  omarchy/lock.json     # lock screen options
  hypr/hyprland.lua     # rounded corners
  hypr/looknfeel.lua    # gaps, animations, dimmed inactive window, border rule
  foot/foot.ini         # terminal padding and font fallback
  starship.toml         # prompt in pills
  fastfetch/config.jsonc
  fastfetch/logo.txt
)

# Folders kept in this repo, also under ~/.config (mirrored with rsync).
config_dirs=(
  omarchy/hooks/theme-set.d   # bruno-colors: recolors menu, prompt and fastfetch on theme change
  omarchy/plymouth            # "bruno" boot screen and install.sh (cursor + boot screen, needs sudo)
)
