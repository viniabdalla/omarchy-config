-- Change the default Omarchy look'n'feel.

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

-- Compact spacing between tiled windows and screen edges.
hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 4,
  },
})

-- >>> lacquer managed block >>>
-- Written by Lacquer. Safe to hand-edit: Lacquer re-reads this block
-- every time it opens, and only ever rewrites what's between the fences.
hl.config({
  cursor = {
    hide_on_key_press = false,
    inactive_timeout = 0,
  },

  decoration = {
    rounding = 0,
    rounding_power = 2,

    blur = {
      enabled = false,
    },

    glow = {
      enabled = false,
      range = 12,
    },

    shadow = {
      enabled = false,
      range = 20,
      sharp = false,
    },
  },

  general = {
    border_size = 1,
    gaps_out = 2,
    gaps_workspaces = 0,
    layout = "dwindle",

    snap = {
      enabled = false,
    },
  },
})

hl.animation({ leaf = "borderangle", enabled = false })
-- <<< lacquer managed block <<<
