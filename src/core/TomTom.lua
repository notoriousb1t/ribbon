-- TomTom compatibility layer: registers a TomTom global and /way only when the real addon is absent.
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
function ns.ParseWay(msg)
  msg = strtrim(msg or "")
  local zone, x, y, desc = msg:match("^(.-)%s*([%d%.]+)[,%s]+([%d%.]+)%s*(.*)$")
  if not x or not tonumber(x) or not tonumber(y) then return end
  return zone, tonumber(x), tonumber(y), desc
end

local function installTomTom()
  local api = {}
  -- Real TomTom: c is a continent and z a zone index. This client is addressed by uiMapID, so a
  -- numeric z that is a valid uiMapID is used; anything else returns nil.
  function api:AddZWaypoint(c, z, x, y, desc)
    local mapID = ns.ResolveMap(z)
    if not mapID then return nil end
    return ns:AddWaypoint(mapID, x, y, { title = desc })
  end

  -- Real TomTom: AddWaypoint(x, y, desc) in the current zone.
  function api:AddWaypoint(x, y, desc)
    local mapID = ns.client.currentMap()
    if not mapID then return nil end
    return ns:AddWaypoint(mapID, x, y, { title = desc })
  end

  function api:RemoveWaypoint(uid) ns:RemoveWaypoint(uid) end
  function api:ClearAllWaypoints() ns:ClearAllWaypoints() end
  _G.TomTom = api
end

function ns.HandleWay(msg)
  local zone, x, y, desc = ns.ParseWay(msg)
  if not x then
    ns:Print("usage: /way [zone] <x> <y> [description]")
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
    ns:Print(string.format("waypoint %d set at %.1f, %.1f", uid, x, y))
  else
    ns:Print("could not set that waypoint.")
  end
end

ns:On("INIT", function()
  if TomTom then return end
  installTomTom()
  if hash_SlashCmdList and hash_SlashCmdList["/WAY"] then return end
  SLASH_RIBBONWAY1 = "/way"
  SlashCmdList["RIBBONWAY"] = ns.HandleWay
end)
