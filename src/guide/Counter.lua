-- Grind counter rules: which combat log kills count toward a grind's `count`. Pure: the player feeds it the fields
-- the client reads from the combat log.
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

-- Whether a kill of creature `npc` counts for a Grind call: one of its targets, or any creature when it names none.
function K.counts(call, npc)
  if call.kind ~= "Grind" or not call.count or call.level then return false end
  if not call.npc then return true end
  for _, id in ipairs(call.npc) do
    if id == npc then return true end
  end
  return false
end
