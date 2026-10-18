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

-- Short description lines for the caption: the unfinished objectives ("Boar slain: 3/8"); when every
-- objective is done, the quest's own hand-in text (log objectives, "Bring X to Y"), else "Ready to
-- turn in". Empty when the quest has no objectives.
function T.description(objectives)
  local all = type(objectives) == "table" and objectives or {}
  local lines = {}
  local function text(o) return type(o.text) == "string" and o.text ~= "" and o.text or nil end
  for _, o in ipairs(all) do
    if not o.finished and text(o) then lines[#lines + 1] = text(o) end
  end
  if #lines > 0 then return lines end
  for _, o in ipairs(all) do
    if o.type == "log" and text(o) then lines[#lines + 1] = text(o) end
  end
  if #lines == 0 and #all > 0 then lines[1] = "Ready to turn in" end
  return lines
end

-- Identity of what is mirrored; a change replaces the Ribbon waypoint.
function T.key(questID, mapID, x, y, icon)
  return string.format("%d:%d:%.2f:%.2f:%s", questID, mapID, x, y, icon)
end
