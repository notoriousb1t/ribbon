-- Client adapter: the only module that calls client position and map APIs.
-- Every call is wrapped in pcall and returns nil when the API is missing or fails, so the rest of
-- the addon is pure logic over plain values. Specs replace these functions with spies.
local ADDON, ns = ...

local client = {}
ns.client = client

-- Names of required client APIs that are missing; an empty list means the addon can run.
function client.probe()
  local missing = {}
  local function need(ok, name) if not ok then missing[#missing + 1] = name end end
  need(type(GetPlayerFacing) == "function", "GetPlayerFacing")
  need(type(UnitPosition) == "function", "UnitPosition")
  need(type(CreateVector2D) == "function", "CreateVector2D")
  need(C_Map and C_Map.GetWorldPosFromMapPos, "C_Map.GetWorldPosFromMapPos")
  need(C_Map and C_Map.GetBestMapForUnit, "C_Map.GetBestMapForUnit")
  need(C_Map and C_Map.GetPlayerMapPosition, "C_Map.GetPlayerMapPosition")
  need(C_Map and C_Map.GetMapInfo, "C_Map.GetMapInfo")
  return missing
end

-- Facing in radians: 0 = north, increasing counter-clockwise.
function client.facing()
  local ok, f = pcall(GetPlayerFacing)
  if ok and type(f) == "number" then return f end
end

-- Player world position in yards: first (north-positive), second (west-positive), instanceID.
function client.playerWorld()
  local ok, a, b, _, inst = pcall(UnitPosition, "player")
  if ok and a and b and not (a == 0 and b == 0) then return a, b, inst end
end

-- Zone coordinate (0-100) to world yards: first, second, instanceID.
function client.toWorld(mapID, x, y)
  local ok, inst, vec = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x / 100, y / 100))
  if ok and vec and vec.x and vec.y then return vec.x, vec.y, inst end
end

function client.currentMap()
  local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  if ok then return mapID end
end

-- Player position in the best map: mapID, x (0-100), y (0-100).
function client.playerMapPosition()
  local mapID = client.currentMap()
  if not mapID then return end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
  if ok and pos and pos.x and pos.y and not (pos.x == 0 and pos.y == 0) then
    return mapID, pos.x * 100, pos.y * 100
  end
end

-- { mapID, name, parentMapID } or nil.
function client.mapInfo(mapID)
  if type(mapID) ~= "number" then return nil end
  local ok, info = pcall(C_Map.GetMapInfo, mapID)
  if ok then return info end
end

function client.isValidMap(mapID)
  return client.mapInfo(mapID) ~= nil
end

-- Descendant maps of a root map as a list of { mapID, name }.
function client.mapChildren(rootID)
  local ok, children = pcall(C_Map.GetMapChildrenInfo, rootID, nil, true)
  if ok and type(children) == "table" then return children end
  return {}
end
