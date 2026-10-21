-- Guide planner: which chapters and steps a character sees, where they are, and when a step is done.
-- Pure: it reads the guide data and a plain description of the character; the client is injected as `env`.
local ADDON, ns = ...

local P = {}
ns.guidePlanner = P

-- Class, race and faction tokens compare without case, spaces or underscores ("NIGHT_ELF" == "NightElf"), and the
-- client calls Undead "Scourge".
function P.norm(s)
  if s == nil then return nil end
  return (tostring(s):upper():gsub("[%s_%-]", ""))
end

local RACE_ALIAS = { SCOURGE = "UNDEAD" }

local function race(s)
  local n = P.norm(s)
  return RACE_ALIAS[n] or n
end

local NORMALISE = { class = P.norm, race = race, faction = P.norm }

-- Does `who` ({ class, race, faction }) satisfy `lock` ({ class =, race =, faction = }, each a token or a list)?
-- A lock on something the client did not report cannot be shown to match.
function P.matches(lock, who)
  if not lock then return true end
  who = who or {}
  for key, norm in pairs(NORMALISE) do
    local want = lock[key]
    if want ~= nil then
      local have = norm(who[key])
      local list = type(want) == "table" and want or { want }
      local ok = false
      for _, w in ipairs(list) do
        if have ~= nil and norm(w) == have then ok = true end
      end
      if not ok then return false end
    end
  end
  return true
end

-- A step as this character sees it: its locked groups removed, or nil when nothing is left.
function P.filterStep(step, who)
  if not P.matches(step.only, who) then return nil end
  local groups = {}
  for _, g in ipairs(step.groups) do
    if P.matches(g.only, who) then groups[#groups + 1] = g end
  end
  if #step.groups > 0 and #groups == 0 then return nil end
  return { groups = groups, skippable = step.skippable }
end

-- The chapters this character can see, each with its visible steps:
--   { { index = <chapter>, name =, steps = { { chapter =, index =, step = } } } }
-- `chapter` and `index` are positions in the guide as registered, so a saved position survives a change of character.
function P.view(guide, who)
  local out = {}
  for ci, ch in ipairs(guide.chapters) do
    local opts = ch.opts or {}
    if P.matches({ race = opts.race, faction = opts.faction }, who) then
      local steps = {}
      for si, step in ipairs(ch.steps) do
        local visible = P.filterStep(step, who)
        if visible then steps[#steps + 1] = { chapter = ci, index = si, step = visible } end
      end
      if #steps > 0 then out[#out + 1] = { index = ci, name = ch.name, levels = opts.levels, steps = steps } end
    end
  end
  return out
end

-- Every visible step in route order.
function P.flatten(view)
  local flat = {}
  for _, ch in ipairs(view) do
    for _, s in ipairs(ch.steps) do flat[#flat + 1] = s end
  end
  return flat
end

-- Index in `flat` of the step at `pos` ({ chapter =, step = }), or the first visible step after it. nil at the end.
function P.locate(flat, pos)
  if not pos then return #flat > 0 and 1 or nil end
  for i, s in ipairs(flat) do
    if s.chapter > pos.chapter or (s.chapter == pos.chapter and s.index >= pos.step) then return i end
  end
end

function P.positionOf(entry) return { chapter = entry.chapter, step = entry.index } end

-- Where each chapter and step stands relative to the current step (flat index `cursor`), for the outline:
-- "done" (passed), "current" or "todo". Returns chapters = { [chapter index] = state } and
-- steps = { [flat index] = state }.
function P.outline(view, flat, cursor)
  local steps, chapters = {}, {}
  for i = 1, #flat do
    steps[i] = (cursor == nil and "done") or (i < cursor and "done") or (i == cursor and "current") or "todo"
  end
  local base = 0
  for _, ch in ipairs(view) do
    local first, last = base + 1, base + #ch.steps
    if cursor == nil or cursor > last then
      chapters[ch.index] = "done"
    elseif cursor >= first then
      chapters[ch.index] = "current"
    else
      chapters[ch.index] = "todo"
    end
    base = last
  end
  return { chapters = chapters, steps = steps }
end

-- Position-based progress: the steps before the cursor count as done. Returns
--   { done =, total =, fraction =, chapters = { [chapter index] = { done =, total =, fraction = } } }
-- `cursor` is the flat index of the current step (#flat + 1 once finished; nil counts as finished).
function P.progress(view, flat, cursor)
  local total = #flat
  local done = cursor == nil and total or math.max(0, math.min(total, cursor - 1))
  local out = { done = done, total = total, fraction = total > 0 and done / total or 0, chapters = {} }
  local base = 0
  for _, ch in ipairs(view) do
    local n = #ch.steps
    local d = math.max(0, math.min(n, done - base))
    out.chapters[ch.index] = { done = d, total = n, fraction = n > 0 and d / n or 0 }
    base = base + n
  end
  return out
end

-- Flat index of the first step of a chapter (guide chapter index), or nil.
function P.firstOfChapter(flat, chapter)
  for i, s in ipairs(flat) do
    if s.chapter == chapter then return i end
  end
end

-- Arrival radius in yards for a group's waypoint. Travel points ("get to this zone", search areas) are coarse, so they
-- accept a wide margin; points where you deal with an NPC (flight path, trainer, inn) get a medium one; every other
-- group keeps the registry default (5 yd) because its quest calls decide completion, not arrival.
P.RADIUS = { travel = 25, npc = 10 }

local TRAVEL_CALLS = { Travel = true, Enter = true, Subzone = true }
local NPC_CALLS = { Fp = true, Fly = true, Hearth = true, Home = true, Train = true }

function P.arrivalRadius(group)
  if group.loop then return P.RADIUS.travel end
  local travel, npc = false, false
  for _, call in ipairs(group.calls) do
    if TRAVEL_CALLS[call.kind] then travel = true
    elseif NPC_CALLS[call.kind] then npc = true
    else return nil end
  end
  if npc then return P.RADIUS.npc end
  if travel then return P.RADIUS.travel end
end

-- Completion ---------------------------------------------------------------------

local QUEST_DONE = { active = true, complete = true, done = true }

-- "done", "open" or "manual" (nothing the client can tell us) for one call.
-- env: quest(id) -> "none"|"active"|"complete"|"done"; objective(quest, index) -> { have, need, finished } or nil;
--      level -> number.
local function callState(call, env)
  local kind = call.kind
  if kind == "Accept" then
    return QUEST_DONE[env.quest(call.quest)] and "done" or "open"
  elseif kind == "Turnin" then
    return env.quest(call.quest) == "done" and "done" or "open"
  elseif kind == "Kill" or kind == "Loot" or kind == "Interact" or kind == "Explore" or kind == "Collect" then
    if not call.quest then return "manual" end
    local q = env.quest(call.quest)
    if q == "done" or q == "complete" then return "done" end
    if q == "active" and call.index then
      local o = env.objective(call.quest, call.index)
      if o and o.finished then return "done" end
    end
    return "open"
  elseif kind == "Ding" then
    return (env.level or 0) >= call.level and "done" or "open"
  elseif kind == "Grind" then
    if call.level then return (env.level or 0) >= call.level and "done" or "open" end
    return "manual"   -- a kill count needs the counter
  end
  return "manual"
end

P.callState = callState

-- true when every call the client can judge is done, false when one is open, nil when none can be judged
-- (travel, flight points, training: the player moves on by arriving or by skipping).
function P.stepDone(step, env)
  local judged = false
  for _, g in ipairs(step.groups) do
    for _, call in ipairs(g.calls) do
      local s = callState(call, env)
      if s == "open" then return false end
      if s == "done" then judged = true end
    end
  end
  if judged then return true end
  return nil
end
