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
require("hypr.center-layout")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- Equatorial automation stays hidden until explicitly requested.
o.window("^equatorial-scraper$", {
  workspace = "special:equatorial silent",
  no_initial_focus = true,
  suppress_event = "activate activatefocus maximize",
})
o.bind("SUPER + ALT + E", "Mostrar/ocultar Equatorial", "hyprctl dispatch togglespecialworkspace equatorial")

-- o.window("qemu", { workspace = "5" })

-- Keep Steam in a clean tiled layout on its own workspace.
o.window("steam", { tile = true, idle_inhibit = "fullscreen" })
o.window({ class = "steam", title = "Steam" }, { tile = true })
o.window({ class = "steam", title = "Friends List" }, { tile = true })

-- Added by hyprmoncfg: its generated monitor rules load last, so nothing before this can override the applied layout.
do local path = os.getenv("HOME") .. "/.config/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end

require("hypr.floating-mode")
