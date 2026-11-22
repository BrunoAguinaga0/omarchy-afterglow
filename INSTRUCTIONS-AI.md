# Instructions for an AI: apply Omarchy Afterglow

*[Leer en español](INSTRUCCIONES-IA.md)*

You are an assistant with access to a terminal on a computer running **Omarchy** (Arch Linux + Hyprland). Your task is to apply the **visual design** from the repo `https://github.com/BrunoAguinaga0/omarchy-afterglow` on top of the user's Omarchy, without overwriting their personal settings (monitors, keyboard, keybindings, apps, dock, lock timings, etc.).

Follow the steps in order, verify each one and tell the user if anything fails. Do not invent design changes: everything you need is in the repo.

> **Do not run `restore.sh`.** It is the author's script to restore *their own* full computer: it replaces `hyprland.lua`, `shell.json` and Omarchy's toggles wholesale, personal preferences included. This guide applies only the visual part, file by file.

## What it looks like

- **Ristretto theme** with the `3-industrial-moon.webp` wallpaper. The design follows any theme's colors: when the user switches themes, the menu, notifications, prompt and fastfetch recolor themselves.
- **Bar at the top in floating glass islands** (`bruno.bar`):
  - Left: menu button (`bruno.menu`) and workspaces with an animated pill and icons of the open apps (`bruno.workspaces`).
  - Center: clock (`bruno.clock`) that moves to the right when music plays, and a mini player (`bruno.music`) that takes over the island, with the cover, a glow in the cover's colors and a menu on hover.
  - Right: tray, performance in a single icon (`skyhonnor.performance`), keyboard layout, indicators, updates, weather, clock (only with music) and control center (`bruno.control`: network, sound, night light, do not disturb).
- **Super + Space menu** redesigned: search field with a magnifier, icons in small squares, separators and a keyboard hint.
- **Lock screen** `bibek.lock`: music card, a color aura that pulses with the music, weather, a "now playing" notice and its own screensaver (the cover large with the aura, or a clock without music) instead of Omarchy's terminal screensaver.
- **Volume and brightness notices** redesigned (`bruno.osd`).
- **Windows**: frosted glass, 18 px rounded corners, 4/8 px gaps, dimmed inactive window, no border with a single window, "popin" animations and smooth slides.
- **Terminal** `foot` with wide padding, `starship` prompt in pills and a compact `fastfetch` with a square logo.
- **Cursor** Catppuccin Mocha Dark and Plymouth **boot screen** "bruno" (blurred wallpaper, glass card, rounded password field).

## Requirements

| Requirement | For | How to check / install |
|---|---|---|
| Omarchy with a Hyprland session running | Everything | `omarchy version`. The design was made on **4.5.0-3** (November 2026) |
| `git`, `rsync`, `jq`, `python3` | Cloning, copying, editing JSON, color hook | `pacman -Q git rsync jq python` (ship with Omarchy) |
| `cava` | Aura and glow that react to the music | `omarchy pkg add cava` |
| `starship`, `fastfetch`, `foot` | Terminal and prompt | Ship with Omarchy; if missing: `omarchy pkg add starship fastfetch foot` |
| Fonts `adwaita-fonts` and `ttf-jetbrains-mono-nerd` | Terminal and prompt symbols | `fc-list \| grep -i -E "adwaita mono\|jetbrainsmono nerd"` |
| `yay` | Cursor from the AUR | `command -v yay` (ships with Omarchy) |
| `sudo` | Cursor and boot screen | The user types their password |
| A player with MPRIS (Spotify, Chromium, mpv…) | Music showing in the bar and the lock screen | Any works |

**Omarchy version:** `bruno.bar`, `bruno.clock`, `bruno.osd`, `bruno.workspaces`, `bruno.menu` and `bibek.lock` are modified copies of Omarchy plugins (see `clonedFrom` in their `manifest.json`). If the user runs a much newer version than 4.5.0, warn them that some may not load.

## Steps

Before replacing any file, make a copy `file.bak.<timestamp>`. Use a single timestamp for everything:

```bash
stamp=$(date +%s)
bak() { [[ -e $1 ]] && cp -a "$1" "$1.bak.$stamp"; return 0; }
```

### 1. Checks and dependencies

```bash
omarchy version
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && echo "Hyprland OK"
omarchy pkg add cava
```

### 2. Clone the repo

```bash
repo=$(mktemp -d)/omarchy-afterglow
git clone --depth 1 https://github.com/BrunoAguinaga0/omarchy-afterglow.git "$repo"
```

### 3. Plugins

```bash
plugins_dir=~/.config/omarchy/plugins
mkdir -p "$plugins_dir"
for dir in "$repo"/plugins/*/; do
  name=$(basename "$dir")
  bak "$plugins_dir/$name"
  mkdir -p "$plugins_dir/$name"
  rsync -a "$dir" "$plugins_dir/$name/"
done
```

### 4. Bar and active plugins (`shell.json`)

Do not replace the file: copy only the bar and the plugin lists, and leave the user's dock, lock timings and everything else as they are.

```bash
shell=~/.config/omarchy/shell.json
bak "$shell"
[[ -s $shell ]] || echo '{"version":1}' > "$shell"
jq --slurpfile d "$repo/config/omarchy/shell.json" '
  .bar = $d[0].bar
  | .plugins = $d[0].plugins
  | .disabledPlugins = $d[0].disabledPlugins
  | .cloneSourceRestores = $d[0].cloneSourceRestores
' "$shell" > "$shell.tmp" && mv "$shell.tmp" "$shell"
```

The design's tray includes `superwhisper.panel` (a dictation app). If the user doesn't have Superwhisper (`ls /opt/superwhisper` fails), remove it:

```bash
jq '.bar.layout.tray |= map(select(.id != "superwhisper.panel"))' "$shell" > "$shell.tmp" && mv "$shell.tmp" "$shell"
```

### 5. Visual files copied as a whole

```bash
for f in omarchy/shell.toml omarchy/lock.json hypr/looknfeel.lua starship.toml fastfetch/config.jsonc fastfetch/logo.txt; do
  bak ~/.config/$f
  mkdir -p "$(dirname ~/.config/$f)"
  cp "$repo/config/$f" ~/.config/$f
done
```

- `shell.toml`: glass and borders for the menu, notifications and bar panels (network, Bluetooth, audio, display, weather…).
- `lock.json`: lock screen time format and aura style (`halo`).
- `looknfeel.lua`: gaps, animations, dimmed inactive window and no border with a single window. If the user had their own settings there, show them the `.bak` and offer to append them at the end.

The fastfetch labels are in Spanish. If the user prefers English, translate the `key` values in `~/.config/fastfetch/config.jsonc` after copying.

### 6. Terminal (`foot.ini`)

Change only the font and padding; the rest of the file belongs to the user:

```bash
foot=~/.config/foot/foot.ini
bak "$foot"
sed -i -E 's|^font=.*|font=Adwaita Mono:size=9,JetBrainsMono Nerd Font:size=9|; s|^pad=.*|pad=24x20|' "$foot"
grep -q '^font=' "$foot" || sed -i '/^\[main\]/a font=Adwaita Mono:size=9,JetBrainsMono Nerd Font:size=9' "$foot"
grep -q '^pad=' "$foot" || sed -i '/^\[main\]/a pad=24x20' "$foot"
```

### 7. Rounded corners and cursor (`hyprland.lua`)

Do not copy the repo's `hyprland.lua`: it contains the author's personal rules. Append **only** this block to the end of the user's `~/.config/hypr/hyprland.lua`. It must come after `require("default.hypr.toggles")` so it wins over the theme's rounding. If it's already there, don't duplicate it:

```bash
hypr=~/.config/hypr/hyprland.lua
bak "$hypr"
grep -q 'rounding = 18' "$hypr" || cat >> "$hypr" <<'LUA'

-- Rounded corners even with the no-gaps toggle on (it forces rounding = 0).
hl.config({
  decoration = {
    rounding = 18,
    rounding_power = 2,
  },
})

-- Cursor: Catppuccin Mocha Dark (AUR catppuccin-cursors-mocha).
hl.env("XCURSOR_THEME", "catppuccin-mocha-dark-cursors")
hl.env("HYPRCURSOR_THEME", "catppuccin-mocha-dark-cursors")
LUA
```

### 8. Glass and corners (Omarchy toggles)

Add only the visual toggles, without removing the ones the user already has (don't use `--delete`):

```bash
toggles="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr"
mkdir -p "$toggles"
cp "$repo"/state/toggles/hypr/{bar-glassy,window-glassy,corners-rounded}.lua "$toggles/"
```

Also turn off Omarchy's (terminal) screensaver: the `bibek.lock` lock screen ships its own screensaver (the cover large with the aura, or a clock without music) that replaces it. If both stay on, both show up.

```bash
cp "$repo/state/toggles/screensaver-off" "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/"
```

The screensaver shows after `idle.screensaver` seconds of inactivity, from the user's `shell.json`. Don't change their timings.

### 9. Hook that recolors on every theme change

```bash
hooks=~/.config/omarchy/hooks/theme-set.d
mkdir -p "$hooks"
cp "$repo/config/omarchy/hooks/theme-set.d/bruno-colors" "$hooks/"
chmod +x "$hooks/bruno-colors"
```

### 10. Theme and wallpaper

```bash
hyprctl reload
omarchy theme set ristretto
omarchy theme bg set "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme/backgrounds/3-industrial-moon.webp"
"$hooks/bruno-colors"
omarchy restart shell
```

If the user prefers another theme, skip `theme set` and `bg set`: the design takes its colors from whatever theme they have.

### 11. Cursor and boot screen (needs sudo)

Copy the files and ask the user to run the installer **themselves** in their terminal, since it asks for a password:

```bash
mkdir -p ~/.config/omarchy/plymouth
rsync -a "$repo/config/omarchy/plymouth/" ~/.config/omarchy/plymouth/
echo "Run: ~/.config/omarchy/plymouth/install.sh"
```

It installs `catppuccin-cursors-mocha` from the AUR, makes it the default cursor, installs the Plymouth theme `bruno` into `/usr/share/plymouth/themes/bruno` and rebuilds the initramfs. The boot screen shows on the next reboot. To go back to Omarchy's: `omarchy plymouth set by theme ristretto`.

## Verify

```bash
omarchy theme current                                          # → Ristretto (if applied)
ls ~/.config/omarchy/plugins                                   # → bibek.lock, bruno.*, skyhonnor.performance
jq -r '.bar.id, (.disabledPlugins|join(","))' ~/.config/omarchy/shell.json   # → bruno.bar / omarchy.lock,omarchy.osd,omarchy.menu
ls "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr"  # → bar-glassy, window-glassy, corners-rounded
ls "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/screensaver-off"  # exists
command -v cava
```

And visually, with the user:

- The bar is at the top, in glass islands, with the clock in the middle.
- With music playing: the clock moves to the right, the player takes the center and its colors follow the cover.
- `Super + Space` opens the redesigned menu.
- Locking (`omarchy-system-lock`) shows the music card and the aura.
- Raising the volume shows the redesigned notice.
- `omarchy-shell lock screensaver` shows the cover screensaver (the same command closes it).
- A new terminal shows the pill prompt and wide padding.

If a plugin doesn't show up, check the logs (`journalctl --user -b | grep -i -E "qml|plugin" | tail -50`) and validate it with `omarchy plugin validate ~/.config/omarchy/plugins/<id>`.

## Don't

- Don't run the repo's `restore.sh` or `sync.sh`: they are the author's, for their own computer.
- Don't copy `hypr/hyprland.lua`, `hypr/monitors.lua`, `hypr/input.lua`, `hypr/bindings.lua` or `hypr/autostart.lua`.
- Don't change the user's dock, lock timings, weather or keybindings.
- Don't "improve" the plugins or colors: the goal is the design as it is.
- Don't delete the `*.bak.*` files; they are how to roll back.

## Undo

Every replaced file has its `*.bak.<stamp>`: copy it over the current one. For the plugins, delete the `bruno.*`, `bibek.lock` and `skyhonnor.performance` folders from `~/.config/omarchy/plugins` and restore `shell.json` from its `.bak`. Then: `hyprctl reload && omarchy restart shell`.

## Credits

- `bibek.lock`: based on [omarchy-better-lock](https://github.com/BibekBhusal0/omarchy-better-lock) by Bibek Bhusal (MIT).
- `skyhonnor.performance`: [omarchy-performance](https://github.com/SkyHonnor/omarchy-performance) (MIT), with the `compact` option.
- `bruno.bar`, `bruno.clock`, `bruno.menu`, `bruno.osd`, `bruno.workspaces`: modified from Omarchy's plugins.
