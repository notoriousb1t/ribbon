-- Text coordinates: "/ribbon [zone] <x> <y> [description]" creates a waypoint.
-- Zone names resolve to uiMapIDs through the client adapter.
local ADDON, ns = ...

local ROOT_MAPS = { 1414, 1415 }

-- uiMapID, or a (localized) zone name, or nil.
function ns.ResolveMap(zone)
  if type(zone) == "number" then
    return ns.client.isValidMap(zone) and zone or nil
  end
  if type(zone) ~= "string" or zone == "" then return nil end
  local wanted = string.lower(zone)
  for _, root in ipairs(ROOT_MAPS) do
    local info = ns.client.mapInfo(root)
    if info and string.lower(info.name or "") == wanted then return root end
    for _, child in ipairs(ns.client.mapChildren(root)) do
      if string.lower(child.name or "") == wanted then return child.mapID end
    end
  end
end

-- "[zone] x y [description]" (x and y may be separated by spaces or a comma).
-- Returns zone ("" when omitted), x, y, description; nil when it does not parse.
function ns.ParseCoords(msg)
  msg = strtrim(msg or "")
  local zone, x, y, desc = msg:match("^(.-)%s*([%d%.]+)[,%s]+([%d%.]+)%s*(.*)$")
  if not x or not tonumber(x) or not tonumber(y) then return end
  return zone, tonumber(x), tonumber(y), desc
end

-- Create a waypoint from text and tell the user what happened.
function ns.HandleCoords(msg)
  local zone, x, y, desc = ns.ParseCoords(msg)
  if not x then
    ns:Print("usage: /ribbon [zone] <x> <y> [description]")
    return
  end
  local mapID
  if zone == "" then mapID = ns.client.currentMap() else mapID = ns.ResolveMap(zone) end
  if not mapID then
    ns:Print("unknown zone: " .. tostring(zone))
    return
  end
  local uid = ns:AddWaypoint(mapID, x, y, { title = (desc ~= "" and desc) or "Waypoint" })
  if uid then
    ns:Print(string.format("waypoint %d set at %.2f, %.2f", uid, x, y))
  else
    ns:Print("could not set that waypoint.")
  end
end
