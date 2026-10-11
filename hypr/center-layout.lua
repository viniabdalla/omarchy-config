-- Local center/focus-left layouts: main widths start at 50%/70%.
-- Cycled per workspace by ~/.local/bin/toggle-center-mode
-- (SUPER + L). Touches no gaps/borders/global settings.

local state_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/center-mode/"

local settings_dir = (os.getenv("OLM_CONFIG_DIR")
  or ((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/omarchy/layout-manager")) .. "/"
local config_dir = settings_dir .. "layouts/"

local MAX_ROWS = 3
local MIN_HUB_WIDTH = 0.25
local MAX_HUB_WIDTH = 0.8
local MIN_COLUMN_WIDTH = 0.04
-- Per-layout defaults, written by omarchy-layout-manager (key=value files).
-- Missing or invalid files fall back to the built-in values; the CLI reports errors.
local FALLBACK_SETTINGS = {
  center = { width = 50, main_step = 20, side_step = 20 },
  ["focus-left"] = { width = 70, main_step = 20, side_step = 20 },
}

local function layout_settings(mode)
  local fallback = FALLBACK_SETTINGS[mode]
  if not fallback then return nil end
  local file = io.open(config_dir .. mode .. ".conf", "r")
  if not file then return fallback end
  local values = {}
  for line in file:lines() do
    local key, value = line:match("^%s*([%w_]+)%s*=%s*(%d+)%s*$")
    if key then values[key] = tonumber(value) end
  end
  file:close()
  local width, main_step, side_step = values.width_percent, values.main_step_px, values.side_step_px
  if not (width and main_step and side_step) then return fallback end
  if width < 25 or width > 80 or main_step < 5 or main_step > 100 or side_step < 5 or side_step > 100 then
    return fallback
  end
  return { width = width, main_step = main_step, side_step = side_step }
end

local function default_hub_width(mode)
  local settings = layout_settings(mode)
  return settings and settings.width / 100 or 0.5
end
local hub_widths = {}
local window_sides = {}

local function clamp_width(value)
  return math.max(MIN_HUB_WIDTH, math.min(MAX_HUB_WIDTH, value))
end

local function workspace_id(ctx)
  for _, target in ipairs(ctx.targets) do
    if target.window and target.window.workspace then
      return tostring(target.window.workspace.id)
    end
  end
end

local function hub_width(ctx, mode)
  local id = workspace_id(ctx)
  if not id then return default_hub_width(mode) end
  local key = id .. "." .. mode
  if hub_widths[key] then return hub_widths[key] end
  local file = io.open(state_dir .. key .. ".width", "r")
  local value = file and tonumber(file:read("*l")) or nil
  if file then file:close() end
  -- Only a stored width is cached; the default is re-read so saved defaults apply
  -- the next time a workspace without its own width is laid out.
  if not value then return default_hub_width(mode) end
  hub_widths[key] = clamp_width(value)
  return hub_widths[key]
end

local function save_hub_width(id, mode, value)
  local key = id .. "." .. mode
  hub_widths[key] = value
  local file = io.open(state_dir .. key .. ".width", "w")
  if file then
    file:write(value, "\n")
    file:close()
  end
end

local function resize_lane(ctx, mode, sides, selected, pixels)
  local id = workspace_id(ctx)
  if not id or ctx.area.w <= 0 then return false end

  local counts = { left = 0, right = 0 }
  for _, info in pairs(sides or {}) do
    if info.side ~= "hub" then
      counts[info.side] = math.max(counts[info.side], info.columns or 1)
    end
  end
  if mode == "center" and counts.right > 0 then counts.left = math.max(1, counts.left) end
  local side_count = counts.left + counts.right
  local delta = pixels / ctx.area.w
  if selected.side ~= "hub" then
    if counts[selected.side] == 0 then return false end
    delta = -side_count * delta
  end
  local max_hub = math.min(MAX_HUB_WIDTH, 1 - side_count * MIN_COLUMN_WIDTH)
  local new_hub = math.max(MIN_HUB_WIDTH, math.min(max_hub, hub_width(ctx, mode) + delta))
  save_hub_width(id, mode, new_hub)
  return true
end

local function norm(addr)
  return tostring(addr or ""):lower():gsub("^0x", "")
end

local function hub_path(ctx)
  for _, target in ipairs(ctx.targets) do
    if target.window and target.window.workspace then
      return state_dir .. tostring(target.window.workspace.id) .. ".hub"
    end
  end
end

local function read_hub(ctx)
  local path = hub_path(ctx)
  local f = path and io.open(path, "r")
  if not f then
    return nil
  end
  local s = f:read("*l")
  f:close()
  return s and norm(s) or nil
end

local function find_hub(ctx)
  local want = read_hub(ctx)
  local active = hl.get_active_window()
  local active_addr = active and norm(active.address) or nil
  for _, target in ipairs(ctx.targets) do
    if target.window and want and norm(target.window.address) == want then
      return target
    end
  end
  for _, target in ipairs(ctx.targets) do
    if target.window and active_addr and norm(target.window.address) == active_addr then
      return target
    end
  end
  return ctx.targets[1]
end

local function target_side(ctx, mode, address)
  local hub = find_hub(ctx)
  if not hub or not hub.window then return nil end
  if norm(hub.window.address) == norm(address) then return "hub" end
  local index = 0
  for _, target in ipairs(ctx.targets) do
    if target ~= hub then
      index = index + 1
      if target.window and norm(target.window.address) == norm(address) then
        return (mode == "focus-left" or index % 2 == 1) and "right" or "left"
      end
    end
  end
end

-- Split a box into k equal cells along one axis.
local function slice(box, i, k, vertical)
  if vertical then
    local h = box.h / k
    return { x = box.x, y = box.y + (i - 1) * h, w = box.w, h = h }
  end
  local w = box.w / k
  return { x = box.x + (i - 1) * w, y = box.y, w = w, h = box.h }
end

local function register_layout(name, focus_left)
hl.layout.register(name, {
  layout_msg = function(ctx, msg)
    local fraction = msg:match("^set%-hub%-width ([+-]?%d+%.?%d*)$")
    if fraction then
      local id = workspace_id(ctx)
      if not id then return false end
      save_hub_width(id, name, clamp_width(tonumber(fraction)))
      return true
    end
    if msg == "relayout" then return true end
    local address, amount = msg:match("^resize%-target%-px (%S+) ([+-]?%d+%.?%d*)$")
    if amount then
      local id = workspace_id(ctx)
      local sides = id and window_sides[id .. "." .. name] or nil
      local info = sides and sides[norm(address)] or nil
      if not info then
        local side = target_side(ctx, name, address)
        if side then info = { side = side, column = 1, columns = 1 } end
      end
      if info then return resize_lane(ctx, name, sides, info, tonumber(amount)) end
      return false
    end
    local pixels = tonumber(msg:match("^resize%-hub%-px ([+-]?%d+%.?%d*)$"))
    if pixels then
      local id = workspace_id(ctx)
      local sides = id and window_sides[id .. "." .. name] or nil
      return resize_lane(ctx, name, sides, { side = "hub" }, pixels)
    end
    if msg ~= "cycle-hub" then return end
    local targets = {}
    for _, target in ipairs(ctx.targets) do
      if target.window then targets[#targets + 1] = target end
    end
    if #targets == 0 then return true end
    -- Keep cycling order independent of focus and visual placement.
    table.sort(targets, function(a, b)
      return norm(a.window.address) < norm(b.window.address)
    end)
    local active = hl.get_active_window()
    local current = read_hub(ctx) or (active and norm(active.address))
    local index = 0
    for i, target in ipairs(targets) do
      if norm(target.window.address) == current then index = i; break end
    end
    local next_window = targets[index % #targets + 1].window
    local file = assert(io.open(hub_path(ctx), "w"))
    file:write(next_window.address, "\n")
    file:close()
    hl.dispatch(hl.dsp.focus({ window = "address:" .. next_window.address }))
    return true
  end,
  recalculate = function(ctx)
    local a = ctx.area
    local targets = ctx.targets
    if #targets == 0 then
      return
    end

    local hub = find_hub(ctx)

    local others = {}
    for _, t in ipairs(targets) do
      if t ~= hub then
        others[#others + 1] = t
      end
    end

    local id = workspace_id(ctx)
    local sides
    if id then
      sides = {}
      if hub.window then sides[norm(hub.window.address)] = { side = "hub" } end
      window_sides[id .. "." .. name] = sides
    end

    if #others == 0 then
      -- Alone: a comfortable centered window rather than fullscreen-tiled.
      local w, h = a.w * hub_width(ctx, name), a.h
      hub:place({ x = focus_left and a.x or a.x + (a.w - w) / 2, y = a.y + (a.h - h) / 2, w = w, h = h })
      return
    end

    -- Fill order: right, left, then repeat. All side columns share one width.
    local n = #others
    local nregions = math.min(n, focus_left and 1 or 2)
    local buckets = {}
    for r = 1, nregions do
      buckets[r] = {}
    end
    for i, t in ipairs(others) do
      local r = (i - 1) % nregions + 1
      table.insert(buckets[r], t)
    end
    local right_cols = math.ceil(#buckets[1] / MAX_ROWS)
    local left_cols = focus_left and 0 or (buckets[2] and math.ceil(#buckets[2] / MAX_ROWS) or 1)
    local side_cols = right_cols + left_cols
    local cw = a.w * hub_width(ctx, name)
    local side_width = (a.w - cw) / side_cols
    local cx = a.x + left_cols * side_width
    hub:place({ x = cx, y = a.y, w = cw, h = a.h })

    local left = { x = a.x, y = a.y, w = left_cols * side_width, h = a.h }
    local right = { x = cx + cw, y = a.y, w = right_cols * side_width, h = a.h }
    local order = focus_left and { right } or { right, left }

    -- Each side holds up to MAX_ROWS windows per column; beyond that it grows
    -- extra columns, with windows spread evenly across them.
    for r = 1, nregions do
      local list = buckets[r]
      local k = #list
      local cols = math.ceil(k / MAX_ROWS)
      local side = (focus_left or r == 1) and "right" or "left"
      local idx = 1
      for c = 1, cols do
        local rows = math.floor(k / cols) + (c <= k % cols and 1 or 0)
        local colbox = slice(order[r], c, cols, false)
        for i = 1, rows do
          local target = list[idx]
          if sides and target.window then
            sides[norm(target.window.address)] = { side = side, column = c, columns = cols }
          end
          target:place(slice(colbox, i, rows, true))
          idx = idx + 1
        end
      end
    end
  end,
})

end

register_layout("center", false)
register_layout("focus-left", true)

-- Saved layouts ---------------------------------------------------------------
-- <ws>.saved (written by `omarchy-layout-manager apply-layout`): first line the layout's slug,
-- then one "address x y w h" line per slot, the rects being fractions of the layout area.
-- A window keeps the slot it was given; windows that appeared since take free slots in order,
-- and when there are more windows than slots the extras stack on the last slot.
local function read_saved_slots(id)
  local file = io.open(state_dir .. id .. ".saved", "r")
  if not file then return nil end
  file:read("*l")
  local slots = {}
  for line in file:lines() do
    local address, x, y, w, h = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*$")
    x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h)
    if address and x and y and w and h and w > 0 and h > 0 then
      slots[#slots + 1] = { address = (norm(address)), x = x, y = y, w = w, h = h }
    end
  end
  file:close()
  return slots
end

hl.layout.register("saved", {
  layout_msg = function(ctx, msg)
    if msg == "relayout" then return true end
    if msg == "cycle-hub" then
      hl.dispatch(hl.dsp.window.cycle_next())
      return true
    end
  end,
  recalculate = function(ctx)
    local a, targets = ctx.area, ctx.targets
    if #targets == 0 then return end
    local id = workspace_id(ctx)
    local slots = id and read_saved_slots(id) or nil
    if not slots or #slots == 0 then
      for i, target in ipairs(targets) do target:place(slice(a, i, #targets, false)) end
      return
    end
    local by_address = {}
    for i, slot in ipairs(slots) do by_address[slot.address] = i end
    local taken, assigned, pending = {}, {}, {}
    for _, target in ipairs(targets) do
      local i = target.window and by_address[(norm(target.window.address))]
      if i and not taken[i] then
        taken[i] = true
        assigned[target] = i
      else
        pending[#pending + 1] = target
      end
    end
    local free = {}
    for i = 1, #slots do if not taken[i] then free[#free + 1] = i end end
    for n, target in ipairs(pending) do assigned[target] = free[n] or #slots end
    for _, target in ipairs(targets) do
      local slot = slots[assigned[target]]
      target:place({ x = a.x + slot.x * a.w, y = a.y + slot.y * a.h, w = slot.w * a.w, h = slot.h * a.h })
    end
  end,
})

-- Restore each workspace's selected mode after a config reload.
center_mode_rules = {}
for _, ws in ipairs(hl.get_workspaces()) do
  local file = io.open(state_dir .. tostring(ws.id) .. ".mode", "r")
  if file then
    local mode = file:read("*l")
    file:close()
    if mode == "center" or mode == "focus-left" or mode == "saved" then
      center_mode_rules[tostring(ws.id)] = hl.workspace_rule({
        workspace = tostring(ws.id), layout = "lua:" .. mode,
      })
    end
  end
end

local pointer_timer
local previous_no_warps

-- Suppress pointer warping only while this shortcut swaps the main window.
function center_mode_cycle_window()
  local ws = hl.get_active_workspace()
  if not ws then return end
  if ws.tiled_layout ~= "lua:center" and ws.tiled_layout ~= "lua:focus-left" then
    hl.dispatch(hl.dsp.window.cycle_next())
    return
  end
  if previous_no_warps == nil then
    previous_no_warps = hl.get_config("cursor:no_warps")
  end
  hl.config({ cursor = { no_warps = true } })
  local ok, err = pcall(function() hl.dispatch(hl.dsp.layout("cycle-hub")) end)
  if pointer_timer then pointer_timer:set_enabled(false) end
  pointer_timer = hl.timer(function()
    hl.config({ cursor = { no_warps = previous_no_warps } })
    previous_no_warps = nil
    pointer_timer = nil
  end, { timeout = 250, type = "oneshot" })
  if not ok then error(err) end
end

local function active_center_workspace()
  local ws = hl.get_active_workspace()
  if ws and (ws.tiled_layout == "lua:center" or ws.tiled_layout == "lua:focus-left") then
    return ws
  end
end

local function current_mode(ws)
  local file = io.open(state_dir .. tostring(ws.id) .. ".mode", "r")
  if not file then return ws.tiled_layout:match("^lua:(.+)$") end
  local mode = file:read("*l")
  file:close()
  return mode
end

function center_mode_resize_by(pixels, tiled_pixels)
  local ws = active_center_workspace()
  if ws then
    local active = hl.get_active_window()
    if active then hl.dispatch(hl.dsp.layout("resize-target-px " .. active.address .. " " .. pixels)) end
  else
    hl.dispatch(hl.dsp.window.resize({ x = -(tiled_pixels or pixels), y = 0, relative = true }))
  end
end

-- Super+Plus/Minus: sign is +1 (wider) or -1 (narrower). The step is the layout's
-- main-window increment when the focused window is the hub, otherwise its
-- side-column increment. Tiled keeps its native pixel step.
function center_mode_resize_step(sign, tiled_pixels)
  local ws = active_center_workspace()
  if not ws then
    hl.dispatch(hl.dsp.window.resize({ x = -(sign * tiled_pixels), y = 0, relative = true }))
    return
  end
  local active = hl.get_active_window()
  if not active then return end
  local mode = current_mode(ws)
  local settings = layout_settings(mode)
  if not settings then return end
  local sides = window_sides[tostring(ws.id) .. "." .. mode] or {}
  local info = sides[norm(active.address)]
  local step = (info and info.side ~= "hub") and settings.side_step or settings.main_step
  hl.dispatch(hl.dsp.layout("resize-target-px " .. active.address .. " " .. (sign * step)))
end

local resize_drag
local resize_timer

function center_mode_resize_mouse_stop()
  if resize_timer then resize_timer:set_enabled(false) end
  resize_timer = nil
  resize_drag = nil
end

function center_mode_resize_mouse_start()
  center_mode_resize_mouse_stop()
  local ws = active_center_workspace()
  if not ws then
    hl.dispatch(hl.dsp.window.resize())
    return
  end
  local active = hl.get_active_window()
  if not active then return end
  local mode = current_mode(ws)
  local sides = window_sides[tostring(ws.id) .. "." .. mode] or {}
  local info = sides[norm(active.address)]
  if not info then return end
  local cursor = hl.get_cursor_pos()
  if not cursor then return end
  resize_drag = { workspace = tostring(ws.id), mode = mode, address = active.address, side = info.side, x = cursor.x }
  resize_timer = hl.timer(function()
    local active = active_center_workspace()
    if not resize_drag or not active or tostring(active.id) ~= resize_drag.workspace or current_mode(active) ~= resize_drag.mode then
      center_mode_resize_mouse_stop()
      return
    end
    local now = hl.get_cursor_pos()
    if not now then return end
    local delta = now.x - resize_drag.x
    if math.abs(delta) < 1 then return end
    delta = math.floor(math.abs(delta)) * (delta < 0 and -1 or 1)
    resize_drag.x = resize_drag.x + delta
    local growth = resize_drag.side == "right" and -delta or delta
    hl.dispatch(hl.dsp.layout("resize-target-px " .. resize_drag.address .. " " .. growth))
  end, { timeout = 16, type = "repeat" })
end

-- Shortcuts managed by omarchy-layout-manager ---------------------------------
-- shortcuts.conf (key=value) in the settings dir:
--   cycle_layout=SUPER + L
--   cycle_window=CTRL + ALT + TAB
--   resize_wider=SUPER + EQUAL        (<action>_2=… is the second slot, none = unbound)
--   resize_narrower=SUPER + MINUS
--   replaced=SUPER + X;SUPER + Y     (other binds the user agreed to replace)
-- Applied once the whole config has loaded, and again live by the CLI.
local SHORTCUT_ORDER = { "cycle_layout", "cycle_window", "resize_wider", "resize_narrower" }
local SHORTCUT_DEFAULTS = {
  cycle_layout = "SUPER + L", cycle_window = "CTRL + ALT + TAB",
  resize_wider = "SUPER + EQUAL", resize_narrower = "SUPER + MINUS",
}
local SHORTCUT_DESCRIPTIONS = {
  cycle_layout = "Cycle layout: Focus Center / Focus Left / Tiled",
  cycle_window = "Cycle main window in workspace",
  resize_wider = "Make window wider",
  resize_narrower = "Make window narrower",
}

local function shortcut_dispatcher(action)
  if action == "cycle_layout" then
    return hl.dsp.exec_cmd((os.getenv("HOME") or "") .. "/.local/bin/toggle-center-mode")
  elseif action == "resize_wider" then
    return function() center_mode_resize_step(1, 100) end
  elseif action == "resize_narrower" then
    return function() center_mode_resize_step(-1, 100) end
  end
  return function() center_mode_cycle_window() end
end

local function read_shortcuts()
  -- keys[action] = { slot 1, slot 2 }; "" means unbound.
  local keys, replaced = {}, {}
  for action, value in pairs(SHORTCUT_DEFAULTS) do keys[action] = { value, "" } end
  local file = io.open(settings_dir .. "shortcuts.conf", "r")
  if file then
    for line in file:lines() do
      local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
      if key == "replaced" then
        for raw in value:gmatch("[^;]+") do
          local combo = raw:match("^%s*(.-)%s*$")
          if combo ~= "" then replaced[#replaced + 1] = combo end
        end
      elseif key and value ~= "" then
        local base, slot = key, 1
        local stripped = key:match("^(.-)_2$")
        if stripped then base, slot = stripped, 2 end
        if SHORTCUT_DEFAULTS[base] then
          keys[base][slot] = value:lower() == "none" and "" or value
        end
      end
    end
    file:close()
  end
  return keys, replaced
end

local applied_shortcuts = {}

-- Omarchy binds minus and equal by key code so they work on any keyboard layout; do the same.
local function bind_form(combo)
  local mods, key = combo:match("^(.-)%s*%+%s*([^%s+]+)$")
  local code = key == "MINUS" and 20 or key == "EQUAL" and 21
  if not code then return combo end
  return (mods ~= "" and (mods .. " + ") or "") .. "code:" .. code
end

-- Omarchy binds digits, minus and equal by key code ("SUPER + code:13"); unbinding the
-- named form would leave that bind in place, so clear the code form as well.
local function unbind_combo(combo)
  pcall(hl.unbind, combo)
  local mods, key = combo:match("^(.-)%s*%+%s*([^%s+]+)$")
  if not key then return end
  local code
  if key:match("^%d$") then code = key == "0" and 19 or 9 + tonumber(key)
  elseif key == "MINUS" then code = 20
  elseif key == "EQUAL" then code = 21 end
  if code then pcall(hl.unbind, mods .. " + code:" .. code) end
end

function olm_apply_shortcuts()
  local keys, replaced = read_shortcuts()
  for _, combo in ipairs(applied_shortcuts) do unbind_combo(combo) end
  applied_shortcuts = {}
  for _, combo in ipairs(replaced) do unbind_combo(combo) end
  for _, action in ipairs(SHORTCUT_ORDER) do
    for slot = 1, 2 do
      local combo = keys[action][slot]
      if combo ~= "" then
        unbind_combo(combo)
        hl.bind(bind_form(combo), shortcut_dispatcher(action), { description = SHORTCUT_DESCRIPTIONS[action] })
        applied_shortcuts[#applied_shortcuts + 1] = combo
      end
    end
  end
end

-- While the panel records a new shortcut, an empty submap disables every global bind so
-- the pressed combination reaches the panel instead of triggering its current action.
-- A timer always leaves the submap again, even if the panel never says so.
-- Mouse buttons and scroll are named by Hyprland itself while recording; the combination is
-- written to a file the panel polls. Left/right click are never captured, and middle click
-- and scroll need a modifier so ordinary clicking and scrolling keep working.
function olm_record_capture(combo)
  local file = io.open(state_dir .. "capture-result", "w")
  if file then file:write(combo, "\n"); file:close() end
end

local MODIFIER_NAMES = { "SUPER", "CTRL", "ALT", "SHIFT" }

-- Calls bind_fn(combo) for every modifier combination of every key in `keys`
-- ({ name, needs_modifier } entries), in the canonical SUPER, CTRL, ALT, SHIFT order.
local function each_mouse_combo(keys, bind_fn)
  for mask = 0, 15 do
    local parts = {}
    for i, name in ipairs(MODIFIER_NAMES) do
      if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then parts[#parts + 1] = name end
    end
    for _, entry in ipairs(keys) do
      if mask ~= 0 or not entry[2] then
        parts[#parts + 1] = entry[1]
        bind_fn(table.concat(parts, " + "))
        parts[#parts] = nil
      end
    end
  end
end

local CAPTURE_KEYS = {
  { "mouse:274", true }, { "mouse:275", false }, { "mouse:276", false }, { "mouse:277", false },
  { "mouse:278", false }, { "mouse:279", false }, { "mouse_up", true }, { "mouse_down", true },
  { "mouse_left", true }, { "mouse_right", true },
}

hl.define_submap("olm-capture", function()
  hl.bind("SUPER + F24", hl.dsp.exec_cmd("true"))
  each_mouse_combo(CAPTURE_KEYS, function(combo)
    hl.bind(combo, function() olm_record_capture(combo) end)
  end)
end)

-- Diagnostic listening mode (scripts/monitor.sh): logs every extra mouse button and scroll
-- direction Hyprland sees, with or without modifiers, for a few seconds. Left and right
-- click are not bindable here, so they keep working.
function olm_record_spy(combo)
  local file = io.open(state_dir .. "spy.log", "a")
  if file then file:write(os.date("%H:%M:%S"), " ", combo, "\n"); file:close() end
end

hl.define_submap("olm-spy", function()
  hl.bind("SUPER + F24", hl.dsp.exec_cmd("true"))
  local keys = { { "mouse_up", false }, { "mouse_down", false }, { "mouse_left", false }, { "mouse_right", false } }
  for button = 274, 290 do keys[#keys + 1] = { "mouse:" .. button, false } end
  each_mouse_combo(keys, function(combo)
    hl.bind(combo, function() olm_record_spy(combo) end)
  end)
end)

local capture_timer

function olm_capture(on)
  if capture_timer then capture_timer:set_enabled(false); capture_timer = nil end
  if on then
    os.remove(state_dir .. "capture-result")
    hl.dispatch(hl.dsp.submap("olm-capture"))
    capture_timer = hl.timer(function()
      capture_timer = nil
      hl.dispatch(hl.dsp.submap("reset"))
    end, { timeout = 20000, type = "oneshot" })
  elseif hl.get_current_submap() == "olm-capture" then
    hl.dispatch(hl.dsp.submap("reset"))
  end
end

local spy_timer

function olm_spy(on)
  if spy_timer then spy_timer:set_enabled(false); spy_timer = nil end
  if on then
    hl.dispatch(hl.dsp.submap("olm-spy"))
    spy_timer = hl.timer(function()
      spy_timer = nil
      hl.dispatch(hl.dsp.submap("reset"))
    end, { timeout = 15000, type = "oneshot" })
  elseif hl.get_current_submap() == "olm-spy" then
    hl.dispatch(hl.dsp.submap("reset"))
  end
end

hl.timer(function() olm_apply_shortcuts() end, { timeout = 1, type = "oneshot" })
