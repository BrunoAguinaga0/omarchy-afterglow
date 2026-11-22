-- Change the default Omarchy look'n'feel.

-- Opt another application in to Omarchy's standard transparency.
-- Find its class with: hyprctl clients
-- o.transparent_window("my-app")
-- o.transparent_window("my-app", "0.9 0.85") -- Custom active/inactive opacity.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- ── Retoques (22/11/2026) ──
-- Windows float like the bar islands: 8 px of air around and between them.
hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 8,
  },
})

-- Short, quick motion: windows rise a little as they open, workspaces slide,
-- and notifications slide in from the side.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.5, bezier = "easeOutQuint", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.5, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "easeOutQuint", style = "slidefade 12%" })
hl.layer_rule({
  match = { namespace = "^omarchy-notifications$" },
  animation = "slide right",
})

-- The Super+Space menu pops in a little, like windows.
hl.layer_rule({
  match = { namespace = "^omarchy-menu$" },
  animation = "popin 92%",
})

-- The orange border marks the focused window only when there is more than one:
-- a lone tiled window on its workspace goes without it.
hl.window_rule({
  name = "bruno-lone-window-no-border",
  match = { workspace = "w[tv1]", float = false },
  border_size = 0,
})

-- The window you are not using dims a little; the focused one stays bright.
hl.config({
  decoration = {
    dim_inactive = true,
    dim_strength = 0.14,
  },
})
