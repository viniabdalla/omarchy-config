-- Managed by marcho78.titlebars: window title bars from the Title Bars Omarchy plugin.
-- Written by `titlebars setup`; `titlebars uninstall` removes this file.
local plugin = os.getenv("HOME") .. "/.config/omarchy/plugins/marcho78.titlebars"
local module = plugin .. "/hypr/titlebars.lua"
local file = io.open(module, "r")
if file then
  file:close()
  -- Keep plugin problems from breaking the rest of the Hyprland config.
  local chunk, problem = loadfile(module)
  local ok = chunk ~= nil
  if ok then
    ok, problem = pcall(chunk, plugin)
  end
  if not ok then
    hl.notification.create({ text = "Title Bars: " .. tostring(problem), duration = 10000, icon = "error" })
  end
end
