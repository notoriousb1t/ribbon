-- Slash commands. Modules add their own entries to ns.commands.
local ADDON, ns = ...

local cmds = ns.commands

cmds.clear = function() ns:HideAll() ns:Print("all waypoints hidden. /ribbon show restores them.") end
cmds.show = function() ns:ShowAll() ns:Print("all waypoints shown.") end
cmds.remove = function(args)
  local uid = tonumber(args)
  if uid and ns:GetWaypoint(uid) then ns:RemoveWaypoint(uid) else ns:Print("no such waypoint.") end
end
cmds.list = function()
  local n = 0
  for _, wp in ipairs(ns:Sorted()) do
    n = n + 1
    ns:Print(string.format("#%d %s (%d, %.2f %.2f) %s", wp.uid, wp.title, wp.mapID, wp.x, wp.y,
      wp.dist and string.format("%d yd", wp.dist) or "no distance"))
  end
  if n == 0 then ns:Print("no visible waypoints.") end
end
cmds.debug = function()
  local f, s, inst = ns.client.playerWorld()
  ns:Print(string.format("world %s, %s instance %s facing %s", tostring(f), tostring(s), tostring(inst), tostring(ns.client.facing())))
  local mapID, x, y = ns.client.playerMapPosition()
  ns:Print(string.format("map %s %s, %s", tostring(mapID), tostring(x), tostring(y)))
  -- Kept in the saved variables too (written on /reload or logout), so a capture can be read from disk.
  if ns.db then
    ns.db.lastDebug = { world = f, subzone = s, instance = inst, map = mapID, x = x, y = y, at = type(_G.time) == "function" and _G.time() or nil }
  end
end

-- Reports which client APIs a screen-space beam at the waypoint would need. Also saved to the saved variables.
cmds.probe = function()
  local function has(tbl, name)
    local t = _G[tbl]
    return type(t) == "table" and type(t[name]) == "function"
  end
  local report = {
    ["C_Map.SetUserWaypoint"] = has("C_Map", "SetUserWaypoint"),
    ["C_SuperTrack.SetSuperTrackedUserWaypoint"] = has("C_SuperTrack", "SetSuperTrackedUserWaypoint"),
    ["C_Navigation.GetFrame"] = has("C_Navigation", "GetFrame"),
    ["C_Navigation.GetDistance"] = has("C_Navigation", "GetDistance"),
    ["C_Navigation.GetTargetState"] = has("C_Navigation", "GetTargetState"),
    ["SuperTrackedFrame"] = type(_G.SuperTrackedFrame) == "table",
  }
  local frame
  if report["C_Navigation.GetFrame"] then
    local ok, f = pcall(_G.C_Navigation.GetFrame)
    frame = ok and f or nil
  end
  report["navFrame (needs an active waypoint)"] = frame ~= nil
  local names = {}
  for k in pairs(report) do names[#names + 1] = k end
  table.sort(names)
  for _, k in ipairs(names) do ns:Print(string.format("%s: %s", k, report[k] and "yes" or "no")) end
  local pin = ns.worldPin and ns.worldPin.status and ns.worldPin.status()
  if pin then
    local keys = {}
    for k in pairs(pin) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do ns:Print(string.format("worldPin.%s: %s", k, tostring(pin[k]))) end
    report.worldPin = pin
  end
  -- Map layering (open the world map first): the frame levels of the fog of war and of Ribbon's pins.
  local map = _G.WorldMapFrame
  if map and type(map.EnumeratePinsByTemplate) == "function" and map:IsShown() then
    local layers = {}
    for _, template in ipairs({ "MapExplorationPinTemplate", "HereBeDragonsPinsTemplate" }) do
      local lo, hi, n = nil, nil, 0
      local ok = pcall(function()
        for pin in map:EnumeratePinsByTemplate(template) do
          local level = pin.icon and pin.icon:GetFrameLevel() or pin:GetFrameLevel()
          lo = lo and math.min(lo, level) or level
          hi = hi and math.max(hi, level) or level
          n = n + 1
        end
      end)
      layers[template] = ok and string.format("%d pins, levels %s-%s", n, tostring(lo), tostring(hi)) or "unavailable"
      ns:Print(string.format("map %s: %s", template, layers[template]))
    end
    -- Which frame-level types this map knows, and the level each gives.
    local manager = map.pinFrameLevelsManager
    if type(manager) == "table" and type(manager.GetValidFrameLevel) == "function" then
      for _, t in ipairs({ "PIN_FRAME_LEVEL_AREA_POI", "PIN_FRAME_LEVEL_WAYPOINT_LOCATION", "PIN_FRAME_LEVEL_SUPER_TRACKED_CONTENT", "PIN_FRAME_LEVEL_GLOBAL_PING", "PIN_FRAME_LEVEL_TOPMOST" }) do
        local ok, level = pcall(manager.GetValidFrameLevel, manager, t)
        layers[t] = ok and tostring(level) or "unknown"
        ns:Print(string.format("map %s: %s", t, layers[t]))
      end
    else
      ns:Print("map pinFrameLevelsManager: not available")
    end
    report.mapLayers = layers
  end
  if ns.db then ns.db.lastProbe = report end
end

-- Status of the registered guide. The command exists always but is not advertised until a guide is registered.
cmds.guide = function(args)
  local guide = ns.guide
  if not guide then
    ns:Print("no guide installed.")
    return
  end
  if string.lower(args or "") == "errors" then
    if #guide.errors == 0 and #guide.ignored == 0 then ns:Print("no guide errors.") end
    for _, e in ipairs(guide.errors) do ns:Print(e) end
    for _, e in ipairs(guide.ignored) do ns:Print(e) end
    return
  end
  ns:Print(string.format("%s: %d chapters%s%s.", guide.title, #guide.chapters,
    #guide.errors > 0 and string.format(", %d errors (/ribbon guide errors)", #guide.errors) or "",
    #guide.ignored > 0 and string.format(", %d ignored calls (/ribbon guide errors)", #guide.ignored) or ""))
end

local function help()
  return "commands: [zone] <x> <y> [description], clear, show, list, remove <uid>, compass [show|hide|toggle|lock|unlock|reset|width <n>|fov <n>], debug"
    .. (ns.guide and ", guide [list|skip|prev|reset|status|errors], guides, dock" or "")
end

function ns.HandleSlash(msg)
  if not ns.ready then
    local missing = ns.missing
    ns:Print("dormant" .. (missing and #missing > 0 and (", missing: " .. table.concat(missing, ", ")) or "") .. ".")
    return
  end
  local cmd, args = string.match(msg or "", "^(%S*)%s*(.-)$")
  local fn = cmds[string.lower(cmd or "")]
  if fn then
    fn(args)
  elseif ns.ParseCoords(msg) then
    ns.HandleCoords(msg)   -- "/ribbon [zone] x y [desc]" creates a waypoint
  else
    ns:Print(help())
  end
end

SLASH_RIBBON1 = "/ribbon"
SlashCmdList["RIBBON"] = ns.HandleSlash
