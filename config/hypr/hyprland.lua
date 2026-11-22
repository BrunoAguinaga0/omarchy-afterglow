-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Rounded corners even with the no-gaps toggle on (it forces rounding = 0).
-- Matches the rounded mockups (18px, plain circular corners).
hl.config({
  decoration = {
    rounding = 18,
    rounding_power = 2,
  },
})

-- Each app on its own workspace: Spotify opens on 3 and Chromium on 2,
-- instead of splitting the workspace you are on. Add "silent" (e.g. "3 silent")
-- to open them there without switching to that workspace.
o.window({ initial_class = "^[Ss]potify$" }, { workspace = "3" })
o.window({ initial_class = "^[Cc]hromium$" }, { workspace = "2" })

-- Cursor: Catppuccin Mocha Dark (AUR catppuccin-cursors-mocha). Until it is
-- installed, the default cursor stays.
hl.env("XCURSOR_THEME", "catppuccin-mocha-dark-cursors")
hl.env("HYPRCURSOR_THEME", "catppuccin-mocha-dark-cursors")
