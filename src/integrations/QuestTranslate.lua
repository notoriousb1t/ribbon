-- Quest translation: pure functions that turn the engine's quest tracking data into what Ribbon shows.
-- No client calls.
local ADDON, ns = ...

local T = {}
ns.questTranslate = T

-- The map point of a quest from GetQuestsOnMap entries, as 0-100 coordinates; nil when not listed.
function T.pickPoint(points, questID)
  for _, p in ipairs(points or {}) do
    if p.questID == questID and type(p.x) == "number" and type(p.y) == "number" then
      return { x = p.x * 100, y = p.y * 100, isQuestStart = p.isQuestStart and true or false }
    end
  end
end

-- accept for a quest to pick up, kill or loot while a monster or item objective is unfinished, and
-- the quest turn-in icon for everything else (all objectives done, talk or deliver objectives,
-- exploration, no objectives).
function T.iconFor(point, objectives)
  if point.isQuestStart then return "accept" end
  for _, o in ipairs(type(objectives) == "table" and objectives or {}) do
    if not o.finished then
      if o.type == "monster" then return "kill" end
      if o.type == "item" then return "loot" end
      break
    end
  end
  return "turnin"
end

-- Identity of what is mirrored; a change replaces the Ribbon waypoint.
function T.key(questID, mapID, x, y, icon)
  return string.format("%d:%d:%.2f:%.2f:%s", questID, mapID, x, y, icon)
end
