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

-- A zone coordinate (0-100) of one map as a coordinate (0-100) of another (a zone onto its continent or a neighbour),
-- through world yards; nil when the client cannot place it.
function client.mapPosition(fromMap, x, y, toMap)
  if type(toMap) ~= "number" or not (C_Map and C_Map.GetMapPosFromWorldPos) then return nil end
  local first, second, inst = client.toWorld(fromMap, x, y)
  if not first then return nil end
  local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, inst, CreateVector2D(first, second), toMap)
  if ok and type(pos) == "table" and pos.x and pos.y then return pos.x * 100, pos.y * 100 end
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

-- Combat log -------------------------------------------------------------------------

-- Whether addons may read the combat log. The Forever client (like retail since 12.0) keeps it to the Blizzard UI:
-- registering COMBAT_LOG_EVENT_UNFILTERED, even inside pcall, raises ADDON_ACTION_FORBIDDEN ("blocked from an action
-- only available to the Blizzard UI"; taint.log names this RegisterEvent). Classic Era still hands it out. There is
-- no API to ask, so this goes by flavor; a client of unknown flavor is tried. Without it, kills come from
-- client.watchKillXP.
local function combatLogOpen()
  local flavor = client.flavor()
  return flavor == nil or flavor == "CLASSIC"
end

-- Call fn(subevent, sourceFlags, destGUID) for every combat log event. The modern client hands the fields to
-- CombatLogGetCurrentEventInfo; an older one passes them as the event's arguments. Returns false when the client has
-- no combat log event or keeps it from addons.
function client.watchCombatLog(fn)
  if not combatLogOpen() then return false end
  local frame = CreateFrame("Frame")
  if not pcall(frame.RegisterEvent, frame, "COMBAT_LOG_EVENT_UNFILTERED") then return false end
  frame:SetScript("OnEvent", function(_, _, ...)
    local fields = { ... }
    if type(CombatLogGetCurrentEventInfo) == "function" then
      local r = { pcall(CombatLogGetCurrentEventInfo) }
      if not r[1] then return end
      table.remove(r, 1)
      fields = r
    end
    -- timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, ...
    local ok, err = pcall(fn, fields[2], fields[6], fields[8])
    if not ok then geterrorhandler()(err) end
  end)
  return true
end

-- The client's format of the XP chat line for a kill ("%s dies, you gain %d experience.").
local XP_KILL_FORMAT = "%s dies, you gain %d experience."

-- Call fn(text, format) for each XP chat line (CHAT_MSG_COMBAT_XP_GAIN), with the client's format of the kill line.
-- The kill source on a client whose combat log addons cannot read: every kill the player earns XP for has a line,
-- whatever is targeted (chain pulls, damage over time, pet kills), but it names the creature only, and a grey kill
-- has none. A secret text (12.0 clients in combat) is skipped. Returns false when the client has no such event.
function client.watchKillXP(fn)
  local frame = CreateFrame("Frame")
  if not pcall(frame.RegisterEvent, frame, "CHAT_MSG_COMBAT_XP_GAIN") then return false end
  frame:SetScript("OnEvent", function(_, _, text)
    if type(issecretvalue) == "function" and issecretvalue(text) then return end
    local format = type(_G.COMBATLOG_XPGAIN_FIRSTPERSON) == "string" and _G.COMBATLOG_XPGAIN_FIRSTPERSON or XP_KILL_FORMAT
    local ok, err = pcall(fn, text, format)
    if not ok then geterrorhandler()(err) end
  end)
  return true
end

-- NPC dialogs ------------------------------------------------------------------------

-- Call fn(event, ...) on each of the client events named in `events` the client has: TRAINER_SHOW, TAXIMAP_OPENED,
-- UI_INFO_MESSAGE, HEARTHSTONE_BOUND. An event the client lacks is left out.
function client.watchEvents(events, fn)
  local frame = CreateFrame("Frame")
  for _, e in ipairs(events) do pcall(frame.RegisterEvent, frame, e) end
  frame:SetScript("OnEvent", function(_, event, ...)
    local ok, err = pcall(fn, event, ...)
    if not ok then geterrorhandler()(err) end
  end)
end

-- The GUID of the NPC whose dialog is open (trainer, flight master, innkeeper), or nil.
function client.npcGUID()
  if type(UnitGUID) ~= "function" then return nil end
  local ok, guid = pcall(UnitGUID, "npc")
  if ok and type(guid) == "string" then return guid end
end

-- Where the hearthstone is set (the inn's subzone name, "Thunderbrew Distillery"), or nil.
function client.bindLocation()
  if type(GetBindLocation) ~= "function" then return nil end
  local ok, where = pcall(GetBindLocation)
  if ok and type(where) == "string" and where ~= "" then return where end
end

-- Whether a UI info message is the "new flight path discovered" one.
function client.isNewFlightPath(message)
  return type(message) == "string" and _G.ERR_NEWTAXIPATH ~= nil and message == _G.ERR_NEWTAXIPATH
end

-- Quest tracking -------------------------------------------------------------------

-- Call tbl[name](...) when both exist; returns ok and the first result.
local function safe(tbl, name, ...)
  if type(tbl) ~= "table" or type(tbl[name]) ~= "function" then return false end
  local ok, result = pcall(tbl[name], ...)
  return ok, result
end

-- Call the global `name` when it exists; returns ok and all its results.
local function global(name, ...)
  local fn = _G[name]
  if type(fn) ~= "function" then return false end
  return pcall(fn, ...)
end

-- The quest log row of a quest (GetQuestLogIndexByID, Classic Era's way), or nil when it is not in the log.
local function logIndex(questID)
  local ok, index = global("GetQuestLogIndexByID", questID)
  if ok and type(index) == "number" and index > 0 then return index end
end

-- A quest log row: title, isHeader, isComplete (1 done, -1 failed), questID (GetQuestLogTitle).
local function logRow(index)
  local ok, title, _, _, isHeader, _, isComplete, _, questID = global("GetQuestLogTitle", index)
  if ok then return title, isHeader, isComplete, questID end
end

-- The game's flavor as an upper-case token: "FOREVER", "CLASSIC" (Classic Era) or "RETAIL"; nil for any other client.
function client.flavor()
  local id = _G.WOW_PROJECT_ID
  if id == nil then return nil end
  if id == _G.WOW_PROJECT_CAMELOT then return "FOREVER" end
  if id == _G.WOW_PROJECT_CLASSIC then return "CLASSIC" end
  if id == _G.WOW_PROJECT_MAINLINE then return "RETAIL" end
end

-- The quest the player is tracking on the map (super-tracked), or nil. A client without super-tracking (Classic Era)
-- gives the first quest watched in the objective tracker instead.
function client.superTrackedQuestID()
  if type(C_SuperTrack) == "table" then
    local ok, id = safe(C_SuperTrack, "GetSuperTrackedQuestID")
    if ok and type(id) == "number" and id > 0 then return id end
    return
  end
  local ok, n = global("GetNumQuestWatches")
  if not ok or type(n) ~= "number" or n < 1 then return end
  local okIndex, index = global("GetQuestIndexForWatch", 1)
  if not okIndex or type(index) ~= "number" then return end
  local _, _, _, questID = logRow(index)
  if type(questID) == "number" and questID > 0 then return questID end
end

function client.questTitle(questID)
  local ok, title = safe(C_QuestLog, "GetTitleForQuestID", questID)
  if not ok then ok, title = safe(C_QuestLog, "GetQuestInfo", questID) end
  if not ok then
    local index = logIndex(questID)
    if index then ok, title = true, logRow(index) end
  end
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
  if type(C_QuestLog) == "table" and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
    local inLog, index = safe(C_QuestLog, "GetLogIndexForQuestID", questID)
    if inLog and index then
      local _, complete = safe(C_QuestLog, "IsComplete", questID)
      return complete and "complete" or "active"
    end
    return "none"
  end
  -- Classic Era: the quest log by row.
  local index = logIndex(questID)
  if index then
    local _, _, isComplete = logRow(index)
    return (isComplete == 1 or isComplete == true) and "complete" or "active"
  end
  return "none"
end

-- Is the quest log entry titled `title` finished? (A quest greeting lists active quests by title only.)
function client.questLogEntryComplete(title)
  local ok, n = global("GetNumQuestLogEntries")
  if not ok or type(n) ~= "number" then return false end
  for i = 1, n do
    local t, isHeader, isComplete = logRow(i)
    if not isHeader and t == title then return isComplete == 1 or isComplete == true end
  end
  return false
end

-- Gossip ---------------------------------------------------------------------------

-- The quests a gossip window lists: { active = { { index, title, complete, questID } }, available = { ... } }.
-- The Forever client has the old gossip globals (entries carry an index); Classic Era has only C_GossipInfo (entries
-- carry a questID, which is what its Select functions take).
function client.gossipQuests()
  local active, available = {}, {}
  if type(_G.GetGossipActiveQuests) == "function" or type(_G.GetNumGossipAvailableQuests) == "function" then
    local _, nActive = global("GetNumGossipActiveQuests")
    nActive = tonumber(nActive) or 0
    if nActive > 0 then
      local list = { global("GetGossipActiveQuests") }
      if table.remove(list, 1) ~= true then list = {} end
      local stride = math.floor(#list / nActive)
      for i = 1, nActive do
        local isComplete = list[(i - 1) * stride + 4]
        active[i] = { index = i, title = list[(i - 1) * stride + 1], complete = isComplete == 1 or isComplete == true }
      end
    end
    local _, nAvailable = global("GetNumGossipAvailableQuests")
    for i = 1, tonumber(nAvailable) or 0 do available[i] = { index = i } end
    return { active = active, available = available }
  end
  local function read(name, out)
    local ok, list = safe(C_GossipInfo, name)
    if not ok or type(list) ~= "table" then return end
    for i, q in ipairs(list) do
      out[#out + 1] = { index = i, title = q.title, complete = q.isComplete == true, questID = q.questID }
    end
  end
  read("GetActiveQuests", active)
  read("GetAvailableQuests", available)
  return { active = active, available = available }
end

-- Picks a quest from gossipQuests(); kind is "active" or "available".
function client.selectGossipQuest(kind, entry)
  if type(entry) ~= "table" then return end
  if entry.questID then
    safe(C_GossipInfo, kind == "active" and "SelectActiveQuest" or "SelectAvailableQuest", entry.questID)
  else
    global(kind == "active" and "SelectGossipActiveQuest" or "SelectGossipAvailableQuest", entry.index)
  end
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
  local xp = call(UnitXP, "player")
  -- A character is told apart by its GUID: a character deleted and made again under the same name is a new one, and must
  -- not inherit the old one's place in the guide.
  local guid = call(UnitGUID, "player")
  return {
    class = class and string.upper(class) or nil,
    race = race and string.upper(race) or nil,
    faction = faction and string.upper(faction) or nil,
    level = type(level) == "number" and level or nil,
    xp = type(xp) == "number" and xp or nil,   -- XP into the current level
    flavor = client.flavor(),
    key = type(guid) == "string" and guid ~= "" and guid or ((name or "player") .. "-" .. (realm or "realm")),
  }
end

-- A quest's objectives: a list of { text, type, finished, ... }.
function client.questObjectives(questID)
  local ok, list = safe(C_QuestLog, "GetQuestObjectives", questID)
  if ok and type(list) == "table" then return list end
  return {}
end

