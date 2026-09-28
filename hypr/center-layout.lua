-- Local "center" layout: the hub window sits in the middle, the other tiled
-- windows surround it. Toggled per workspace by ~/.local/bin/toggle-center-mode
-- (SUPER + ALT + O). Touches no gaps/borders/global settings.

local hub_file = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/center-mode/hub"

local MAX_ROWS = 3

local function norm(addr)
  return tostring(addr or ""):lower():gsub("^0x", "")
end

local function read_hub()
  local f = io.open(hub_file, "r")
  if not f then
    return nil
  end
  local s = f:read("*l")
  f:close()
  return s and norm(s) or nil
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

hl.layout.register("center", {
  recalculate = function(ctx)
    local a = ctx.area
    local targets = ctx.targets
    if #targets == 0 then
      return
    end

    local want = read_hub()
    local active = hl.get_active_window()
    local active_addr = active and norm(active.address) or nil

    local hub
    for _, t in ipairs(targets) do
      if t.window and want and norm(t.window.address) == want then
        hub = t
      end
    end
    if not hub then
      for _, t in ipairs(targets) do
        if t.window and active_addr and norm(t.window.address) == active_addr then
          hub = t
        end
      end
    end
    hub = hub or targets[1]

    local others = {}
    for _, t in ipairs(targets) do
      if t ~= hub then
        others[#others + 1] = t
      end
    end

    if #others == 0 then
      -- Alone: a comfortable centered window rather than fullscreen-tiled.
      local w, h = a.w * 0.5, a.h
      hub:place({ x = a.x + (a.w - w) / 2, y = a.y + (a.h - h) / 2, w = w, h = h })
      return
    end

    -- Center box: wide enough to be the focus, leaving room around it.
    local cw, ch = a.w * 0.5, a.h
    local cx, cy = a.x + (a.w - cw) / 2, a.y + (a.h - ch) / 2
    hub:place({ x = cx, y = a.y, w = cw, h = a.h })

    -- Regions: full-height left/right columns beside the hub.
    local left = { x = a.x, y = a.y, w = cx - a.x, h = a.h }
    local right = { x = cx + cw, y = a.y, w = a.x + a.w - (cx + cw), h = a.h }

    -- Hub spans the full height, so only left/right columns exist.
    -- Fill order: right, left, then repeat.
    local order = { right, left }
    local vertical = { true, true }
    local n = #others
    local nregions = math.min(n, 2)
    local buckets = {}
    for r = 1, nregions do
      buckets[r] = {}
    end
    for i, t in ipairs(others) do
      local r = (i - 1) % nregions + 1
      table.insert(buckets[r], t)
    end
    -- Each side holds up to MAX_ROWS windows per column; beyond that it grows
    -- extra columns, with windows spread evenly across them.
    for r = 1, nregions do
      local list = buckets[r]
      local k = #list
      local cols = math.ceil(k / MAX_ROWS)
      local idx = 1
      for c = 1, cols do
        local rows = math.floor(k / cols) + (c <= k % cols and 1 or 0)
        local colbox = slice(order[r], c, cols, false)
        for i = 1, rows do
          list[idx]:place(slice(colbox, i, rows, true))
          idx = idx + 1
        end
      end
    end
  end,
})
