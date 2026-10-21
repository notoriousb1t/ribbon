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

-- Whether the player is in combat.
function client.inCombat()
  if type(UnitAffectingCombat) ~= "function" then return false end
  local ok, v = pcall(UnitAffectingCombat, "player")
  return ok and v and true or false
end

-- Whether the player is dead or a ghost.
function client.isDead()
  if type(UnitIsDeadOrGhost) ~= "function" then return false end
  local ok, v = pcall(UnitIsDeadOrGhost, "player")
  return ok and v and true or false
end

-- Quest tracking -------------------------------------------------------------------

-- Call tbl[name](...) when both exist; returns ok and the first result.
local function safe(tbl, name, ...)
  if type(tbl) ~= "table" or type(tbl[name]) ~= "function" then return false end
  local ok, result = pcall(tbl[name], ...)
  return ok, result
end

-- The quest the player is tracking on the map (super-tracked), or nil.
function client.superTrackedQuestID()
  local ok, id = safe(C_SuperTrack, "GetSuperTrackedQuestID")
  if ok and type(id) == "number" and id > 0 then return id end
end

function client.questTitle(questID)
  local ok, title = safe(C_QuestLog, "GetTitleForQuestID", questID)
  if ok and type(title) == "string" and title ~= "" then return title end
end

-- Quest points on a map: a list of { questID, x, y (0-1), isQuestStart, inProgress }.
function client.questPoints(mapID)
  local ok, list = safe(C_QuestLog, "GetQuestsOnMap", mapID)
  if ok and type(list) == "table" then return list end
  return {}
end

-- Where a quest stands for this character: "done" (turned in), "complete" (ready to turn in), "active" (in the log)
-- or "none".
function client.questStatus(questID)
  local ok, done = safe(C_QuestLog, "IsQuestFlaggedCompleted", questID)
  if ok and done then return "done" end
  local inLog, index = safe(C_QuestLog, "GetLogIndexForQuestID", questID)
  if inLog and index then
    local _, complete = safe(C_QuestLog, "IsComplete", questID)
    return complete and "complete" or "active"
  end
  return "none"
end

-- The player's class, race and faction as upper-case tokens ("WARRIOR", "NightElf" -> "NIGHTELF" is the guide
-- planner's job), plus level and a key that tells characters apart.
function client.character()
  local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local r = { pcall(fn, ...) }
    if r[1] then return r[2], r[3] end
  end
  local _, class = call(UnitClass, "player")
  local _, race = call(UnitRace, "player")
  local faction = call(UnitFactionGroup, "player")
  local name = call(UnitName, "player")
  local realm = call(GetRealmName)
  local level = call(UnitLevel, "player")
  return {
    class = class and string.upper(class) or nil,
    race = race and string.upper(race) or nil,
    faction = faction and string.upper(faction) or nil,
    level = type(level) == "number" and level or nil,
    key = (name or "player") .. "-" .. (realm or "realm"),
  }
end

-- A quest's objectives: a list of { text, type, finished, ... }.
function client.questObjectives(questID)
  local ok, list = safe(C_QuestLog, "GetQuestObjectives", questID)
  if ok and type(list) == "table" then return list end
  return {}
end

