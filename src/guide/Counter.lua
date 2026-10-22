-- Grind counter rules: which kills count toward a grind's `count`. Pure: the player feeds it the fields the client
-- reads from the combat log, or the XP chat line where the client keeps the combat log from addons.
local ADDON, ns = ...

local K = {}
ns.guideCounter = K

-- Unit flag affiliation bits (COMBATLOG_OBJECT_AFFILIATION_*): 1 mine (the player and their pet), 2 party, 4 raid,
-- 8 outsider. Only the player, their pet and the party earn kill credit.
local CREDITED = 4

-- The creature id in a unit GUID ("Creature-0-5250-0-14-2955-0000123ABC" gives 2955); nil for players, pets and
-- anything else that is not a creature.
function K.npcID(guid)
  if type(guid) ~= "string" then return nil end
  local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

-- The creature a combat log event credits as a kill to the player, their pet or their party; nil otherwise.
function K.credit(subevent, sourceFlags, destGUID)
  if subevent ~= "PARTY_KILL" or type(sourceFlags) ~= "number" then return nil end
  if sourceFlags % CREDITED == 0 then return nil end
  return K.npcID(destGUID)
end

-- The creature an XP chat line names ("Plainstrider dies, you gain 45 experience."), read with the client's own
-- format string (COMBATLOG_XPGAIN_FIRSTPERSON, "%s dies, you gain %d experience."). The group, raid and rested lines
-- add to its end, so it is matched from the start only. nil for any other line (quest and exploration XP name no
-- creature).
function K.xpKillName(text, format)
  if type(text) ~= "string" or type(format) ~= "string" then return nil end
  local pattern = format:gsub("%%%d*%$?s", "\1"):gsub("%%%d*%$?d", "\2")
  if not pattern:find("\1", 1, true) then return nil end
  pattern = pattern:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("\1", "(.-)"):gsub("\2", "%%d+")
  local name = text:match("^" .. pattern)
  if name and name ~= "" then return name end
end

-- Whether a Grind call takes kills at all (a count grind; a level grind counts nothing).
local function counting(call)
  return call.kind == "Grind" and call.count and not call.level
end

-- Whether a kill of creature `npc` counts for a Grind call: one of its targets, or any creature when it names none.
function K.counts(call, npc)
  if not counting(call) then return false end
  if not call.npc then return true end
  for _, id in ipairs(call.npc) do
    if id == npc then return true end
  end
  return false
end

-- Whether a kill of a creature called `name` counts for a Grind call: the name the guide gives one of its targets
-- (`names.CREATURE`), or any creature when it names none. The XP line names the creature only, so every target of
-- that name matches.
function K.countsByName(call, name, names)
  if not counting(call) then return false end
  if not call.npc then return true end
  local list = type(names) == "table" and names.CREATURE
  if type(list) ~= "table" then return false end
  for _, id in ipairs(call.npc) do
    if list[id] == name then return true end
  end
  return false
end
