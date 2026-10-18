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
    ns:Print(string.format("#%d %s (%d, %.1f %.1f) %s", wp.uid, wp.title, wp.mapID, wp.x, wp.y,
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

local HELP = "commands: clear, show, list, remove <uid>, compass [show|hide|toggle|lock|unlock|reset|width <n>|fov <n>], guide [show|hide|toggle], debug"

function ns.HandleSlash(msg)
  if not ns.ready then
    local missing = ns.missing
    ns:Print("dormant" .. (missing and #missing > 0 and (", missing: " .. table.concat(missing, ", ")) or "") .. ".")
    return
  end
  local cmd, args = string.match(msg or "", "^(%S*)%s*(.-)$")
  local fn = cmds[string.lower(cmd or "")]
  if fn then fn(args) else ns:Print(HELP) end
end

SLASH_RIBBON1 = "/ribbon"
SlashCmdList["RIBBON"] = ns.HandleSlash
