-- Suppression rules accumulate: an empty later rule cannot undo the default.
-- Scope the default loader's blanket maximize suppression to other apps.
return function(load_defaults)
  local original = hl.window_rule
  hl.window_rule = function(rule)
    if rule.match and rule.match.class == ".*" and rule.suppress_event == "maximize" then
      local copy, match = {}, {}
      for key, value in pairs(rule) do copy[key] = value end
      for key, value in pairs(rule.match) do match[key] = value end
      match.class = "negative:^google-chrome$"
      copy.match = match
      return original(copy)
    end
    return original(rule)
  end
  local ok, problem = pcall(load_defaults)
  hl.window_rule = original
  if not ok then error(problem) end
  original({ match = { class = "^google-chrome$" }, sync_fullscreen = true })
end
