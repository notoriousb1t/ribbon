-- Guide text: the caption and outline lines, written from the data and the guide's name tables.
-- Pure. Nothing here is authored: a call becomes "Kill Plainstrider (3/7)" from its ids and the quest log.
local ADDON, ns = ...

local T = {}
ns.guideText = T

local function name(names, kind, id, fallback)
  local list = names and names[kind]
  return (list and list[id]) or (fallback .. " " .. tostring(id))
end

-- " (3/7)" like the quest tracker's objectives: the client's progress while the quest is active and it reports any,
-- else "0 of the count needed" (" (0/7)").
local function progress(call, env)
  if call.quest and call.index and env and env.quest(call.quest) == "active" then
    local o = env.objective(call.quest, call.index)
    if o and o.need then return string.format(" (%d/%d)", o.have or 0, o.need) end
  end
  return call.count and string.format(" (%d/%d)", 0, call.count) or ""
end

local function list(names, kind, ids)
  local out = {}
  for _, id in ipairs(ids or {}) do out[#out + 1] = name(names, kind, id, kind:lower()) end
  return table.concat(out, ", ")
end

-- One call as a line of text.
function T.line(call, names, env, group)
  local k = call.kind
  if k == "Accept" then
    local who = call.npc and (" from " .. name(names, "NPC", call.npc, "npc")) or ""
    return "Accept " .. name(names, "QUEST", call.quest, "quest") .. who
  elseif k == "Turnin" then
    local who = call.npc and (" to " .. name(names, "NPC", call.npc, "npc")) or ""
    return "Turn in " .. name(names, "QUEST", call.quest, "quest") .. who
  elseif k == "Kill" then
    return "Kill " .. name(names, "CREATURE", call.creature, "creature") .. progress(call, env)
  elseif k == "Loot" then
    return "Collect " .. name(names, "ITEM", call.item, "item") .. progress(call, env)
  elseif k == "Collect" then
    return "Loot " .. name(names, "ITEM", call.item, "item")
  elseif k == "Use" then
    return "Use " .. name(names, "ITEM", call.item, "item")
  elseif k == "Interact" then
    return "Use " .. name(names, "OBJECT", call.object, "object") .. progress(call, env)
  elseif k == "Explore" then
    if call.npc then return "Find " .. name(names, "NPC", call.npc, "npc") end
    return "Explore for " .. name(names, "QUEST", call.quest, "quest")
  elseif k == "Grind" then
    local targets = list(names, "CREATURE", call.npc)
    local what = targets ~= "" and targets or "monsters"
    if call.level then
      return string.format("Grind %s to level %d", what, call.level)
    end
    return string.format("Kill %d %s", call.count or 0, what)
  elseif k == "Ding" then
    return "Reach level " .. call.level
  elseif k == "Fp" then
    return "Get the " .. call.node .. " flight path"
  elseif k == "Fly" then
    return "Fly to " .. call.node
  elseif k == "Hearth" then
    return "Hearth to " .. call.node
  elseif k == "Home" then
    return "Set your hearthstone at " .. call.node
  elseif k == "Train" then
    local who = call.npc and (" from " .. name(names, "NPC", call.npc, "npc")) or ""
    return "Train " .. table.concat(call.abilities or {}, ", ") .. who
  elseif k == "Deathwarp" then
    return "Die and respawn at the spirit healer"
  elseif k == "Skip" then
    return "Skip " .. name(names, "QUEST", call.quest, "quest")
  elseif k == "Enter" then
    return "Travel to " .. name(names, "MAP", call.map, "zone")
  elseif k == "Subzone" then
    return "Enter " .. call.name
  elseif k == "Travel" then
    local at = group and #group.calls == 1 and group.at
    return at and ("Travel to " .. name(names, "MAP", at.map, "zone")) or "Travel"
  end
  return k
end

-- Lines for a group's calls, leaving out those already done. `state(call)` is "done"/"open"/"manual" (optional).
function T.lines(group, names, env, state)
  local out = {}
  for _, call in ipairs(group.calls) do
    local finished = state and state(call) == "done"
    -- "Travel" is only a marker; when the group has other calls (Enter, Subzone) they carry the text.
    local marker = call.kind == "Travel" and #group.calls > 1
    if not finished and not marker then out[#out + 1] = T.line(call, names, env, group) end
  end
  return out
end

-- A chapter name split at its arrow for display: "11-12 Sentinel Hill (Westfall) -> Report to Gryan" gives the place
-- ("11-12 Sentinel Hill (Westfall)") and the goal ("Report to Gryan"). The goal is nil when there is none.
function T.chapterParts(name)
  name = tostring(name or "")
  local place, goal = name:match("^(.-)%s*\226\134\146%s*(.+)$")   -- the arrow as UTF-8 bytes (Lua 5.1 has no \x)
  if place and place ~= "" then return place, goal end
  return name, nil
end

-- The call kind that decides a group's map icon.
local ICON = {
  Accept = "accept", Turnin = "turnin", Kill = "kill", Grind = "grind",
  Loot = "loot", Collect = "loot", Interact = "loot", Use = "loot",
  Fp = "fp", Fly = "fp", Hearth = "hearth", Home = "hearth", Train = "train", Ding = "ding",
}

function T.icon(group)
  for _, call in ipairs(group.calls) do
    if ICON[call.kind] then return ICON[call.kind] end
  end
  return "poi"
end

-- Everything a step says, for searching: the line of every call of every group, with no progress counts.
function T.fullText(step, names)
  local out = {}
  for _, g in ipairs(step.groups or {}) do
    for _, line in ipairs(T.lines(g, names, nil, nil)) do out[#out + 1] = line end
  end
  return table.concat(out, " ")
end

-- The icon a step is shown with in a list: the first group whose calls have an icon of their own, else the plain map
-- point. (A step that accepts a quest and then kills for it is drawn as the accept.)
function T.stepIcon(step)
  for _, g in ipairs(step.groups or {}) do
    local icon = T.icon(g)
    if icon ~= "poi" then return icon end
  end
  return "poi"
end

-- A whole step on one line, for the outline: its first two lines.
function T.summary(step, names, env)
  local out = {}
  for _, g in ipairs(step.groups) do
    for _, call in ipairs(g.calls) do
      if #out < 2 then out[#out + 1] = T.line(call, names, env, g) end
    end
  end
  if #out == 0 then return "Step" end
  return table.concat(out, ", ")
end
