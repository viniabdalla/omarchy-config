-- Omarchy 4.5's floating workspace mode, with the marcho78 title bar instead of Omarchy's.
-- The mode draws bars only if /usr/lib/omarchy-hyprland-titlebars/titlebars.so is readable,
-- and would otherwise configure whichever hyprbars is loaded with its own look and buttons.
-- Hide that one file from it; every other io.open passes through untouched.
local omarchy_titlebars = "/usr/lib/omarchy-hyprland-titlebars/titlebars.so"
local original_open = io.open
io.open = function(path, ...)
  if path == omarchy_titlebars then return nil, "hidden: marcho78.titlebars owns the title bars" end
  return original_open(path, ...)
end
