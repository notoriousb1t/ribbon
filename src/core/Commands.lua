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
end

-- Status of the registered guide. The command exists always but is not advertised until a guide is registered.
cmds.guide = function(args)
  local guide = ns.guide
  if not guide then
    ns:Print("no guide installed.")
    return
  end
  if string.lower(args or "") == "errors" then
    if #guide.errors == 0 then ns:Print("no guide errors.") end
    for _, e in ipairs(guide.errors) do ns:Print(e) end
    return
  end
  ns:Print(string.format("%s: %d chapters%s.", guide.title, #guide.chapters,
    #guide.errors > 0 and string.format(", %d errors (/ribbon guide errors)", #guide.errors) or ""))
end

local function help()
  return "commands: [zone] <x> <y> [description], clear, show, list, remove <uid>, compass [show|hide|toggle|lock|unlock|reset|width <n>|fov <n>], debug"
    .. (ns.guide and ", guide [list|skip|prev|reset|status|errors]" or "")
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
