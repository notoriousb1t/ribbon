-- Guide player: follows the registered guide, advances as the quest log changes, and shows the current step on
-- the compass and map through the waypoint API. Nothing here exists until a guide is registered and the addon is
-- ready (the module only wires itself on GUIDE_REGISTERED and INIT).
--
-- The player reads the quest log (read-only, polled twice a second like the other bridges), keeps one position per
-- character in RibbonDB.guide, and lets the player move by hand: skip, previous, jump.
local ADDON, ns = ...

local Pl = {}
ns.guidePlayer = Pl

local planner = ns.guidePlanner
local text = ns.guideText

local POLL = 0.5

-- State of the running player; nil until start().
local S

local function objective(questID, index)
  local o = ns.client.questObjectives(questID)[index]
  if o then return { have = o.numFulfilled, need = o.numRequired, finished = o.finished } end
end

-- Kills counted for a Grind call (S.kills, keyed by the call's place in the guide).
local function kills(call)
  local key = S.callKey[call]
  return key and S.kills[key] or 0
end

-- Whether the client saw a Train, Fp or Home call done (S.marks, keyed like the kills). A Home is also done while the
-- hearthstone is already set at its inn.
local function marked(call)
  local key = S.callKey[call]
  if key and S.marks[key] then return true end
  if call.kind == "Home" then
    local bind = ns.client.bindLocation()
    return bind ~= nil and string.lower(bind) == string.lower(call.node)
  end
  return false
end

local function env()
  return { quest = ns.client.questStatus, objective = objective, itemCount = ns.client.itemCount, level = S.who.level, xp = S.who.xp, kills = kills, marked = marked }
end

-- Whether a call of the current guide is done, open or manual, for the map pins of a step's objectives.
function Pl.callState(call)
  return S and planner.callState(call, env()) or "open"
end

local function chapterName(entry)
  local ch = S.guide.chapters[entry.chapter]
  return ch and ch.name
end

-- Saved position -----------------------------------------------------------------

local function save()
  if not (S and ns.db) then return end
  ns.db.guide = ns.db.guide or {}
  local entry = S.flat[S.cursor]
  local kills = next(S.kills) and S.kills or nil
  local marks = next(S.marks) and S.marks or nil
  local record = entry and { guide = S.guide.id, chapter = entry.chapter, step = entry.index, kills = kills, marks = marks }
    or { guide = S.guide.id, finished = true, kills = kills, marks = marks }
  ns.db.guide[S.who.key] = record   -- the guide in use (the one earlier versions kept)
  -- ... and the same under its id, so a character who switches guides finds each one where they left it.
  ns.db.guideBy = ns.db.guideBy or {}
  ns.db.guideBy[S.who.key] = ns.db.guideBy[S.who.key] or {}
  ns.db.guideBy[S.who.key][S.guide.id] = record
end

local function saved(guide)
  guide = guide or S.guide
  local by = ns.db and ns.db.guideBy
  local own = by and by[S.who.key] and by[S.who.key][guide.id]
  if own then return own end
  local all = ns.db and ns.db.guide
  local mine = all and all[S.who.key]
  if mine and mine.guide == guide.id then return mine end
end

-- Takes a guide's saved position, kills and marks into the state (a fresh start when it has none).
local function loadSaved(guide)
  S.kills, S.marks, S.pos, S.finished = {}, {}, nil, nil
  local mine = saved(guide)
  if mine and type(mine.kills) == "table" then S.kills = mine.kills end
  if mine and type(mine.marks) == "table" then S.marks = mine.marks end
  if mine and mine.finished then
    S.finished = true
  elseif mine then
    S.pos = { chapter = mine.chapter, step = mine.step }
  end
end

-- Waypoints of the current step -------------------------------------------------------

local function clearWaypoints()
  for _, w in pairs(S.waypoints) do ns:RemoveWaypoint(w.uid) end
  S.waypoints = {}
  S.arrived = {}
end

local function location(group)
  if group.at then return group.at.map, group.at.x, group.at.y, group.at.z end
  if group.loop then
    local p = group.loop.points[1]
    return group.loop.map, p[1], p[2]
  end
end

-- Titles and descriptions the compass shows for each located group still open.
local function desired(entry)
  local out = {}
  local e = env()
  local state = function(call) return planner.callState(call, e) end
  for gi, group in ipairs(entry.step.groups) do
    local map, x, y, z = location(group)
    if map then
      local lines = text.lines(group, S.guide.names, e, state)
      if #lines > 0 then
        local detail = {}
        for i = 2, #lines do detail[#detail + 1] = lines[i] end
        local title = lines[1]
        if entry.step.skippable then title = "(skippable) " .. title end
        out[gi] = { map = map, x = x, y = y, z = z, title = title, description = detail, icon = text.icon(group), radius = planner.arrivalRadius(group) }
      end
    end
  end
  return out
end

local function syncWaypoints(entry)
  local want = desired(entry)
  for gi, w in pairs(S.waypoints) do
    local d = want[gi]
    if not d or d.map ~= w.map or d.x ~= w.x or d.y ~= w.y or d.z ~= w.z then
      ns:RemoveWaypoint(w.uid)
      S.waypoints[gi] = nil
    end
  end
  for gi, d in pairs(want) do
    local w = S.waypoints[gi]
    if w then
      -- Progress changes the text in place ("Kill Plainstrider (3/7)"), not the waypoint.
      local wp = ns:GetWaypoint(w.uid)
      if wp then
        local title, description = ns.OneLine(d.title), ns.NormalizeDescription(d.description)
        if title ~= wp.title or table.concat(description, "|") ~= table.concat(wp.description or {}, "|") then
          wp.title, wp.description = title, description
          ns:Fire("WAYPOINT_CHANGED", wp)
        end
      end
    else
      local uid = ns:AddWaypoint(d.map, d.x, d.y, {
        title = d.title, description = d.description, icon = d.icon, arrival_distance = d.radius, z = d.z,
        lines = { "Guide: " .. (chapterName(entry) or S.guide.title) },
      })
      if uid then
        S.waypoints[gi] = { uid = uid, map = d.map, x = d.x, y = d.y, z = d.z }
      else
        -- The client could not place it (unknown map, no world position). Say so once, or the step just stalls.
        local key = string.format("%d:%d:%s:%s", S.cursor, gi, tostring(d.map), tostring(d.x))
        if not S.unplaced[key] then
          S.unplaced[key] = true
          ns:Print(string.format("cannot place \"%s\" (map %s, %.2f %.2f); use /ribbon guide skip to move on.", ns.OneLine(d.title), tostring(d.map), d.x, d.y))
        end
      end
    end
  end
end

-- Moving ----------------------------------------------------------------------------

-- Focus the first waypoint of the current step, so the compass captions the active step rather than whatever else is
-- nearest. Done once per step (not on every poll, and not when the plan is rebuilt around the same step), so a
-- waypoint the player focuses by hand stays focused until the step changes.
local function focusStep(entry)
  local key = entry.chapter .. ":" .. entry.index
  -- Rebuilding the plan around the same step recreates its waypoints (and drops the focus with them), so refocus then.
  if S.focusKey == key and ns.focus ~= nil then return end
  S.focusKey = key
  local first
  for gi in pairs(S.waypoints) do
    if not first or gi < first then first = gi end
  end
  if first then ns:SetFocus(S.waypoints[first].uid) end
end

local function setCursor(i)
  clearWaypoints()
  S.cursor = i
  local entry = S.flat[i]
  S.pos = entry and planner.positionOf(entry) or nil
  S.finished = entry == nil
  if #S.flat == 0 then return end   -- nothing loaded yet: keep the saved position, say nothing
  save()
  if entry then
    syncWaypoints(entry)
    focusStep(entry)
    ns:Fire("GUIDE_STEP_CHANGED", entry, i)
  else
    ns:Fire("GUIDE_FINISHED")
  end
end

-- Calls whose progress the player keeps: grind kills, and the marks of trainer, flight path and inn calls.
local KEYED = { Grind = true, Train = true, Fp = true, Home = true }

-- The guide gains chapters while its files load (and the character's class or race can change what is visible), so
-- the plan is rebuilt lazily: any use of the player first catches up, keeping the saved position.
local function replan()
  S.dirty = false
  S.who = ns.client.character()
  S.view = planner.view(S.guide, S.who)
  S.flat = planner.flatten(S.view)
  -- Grind counts and marks are saved under "chapter:step:group:call", the same guide position the saved cursor uses.
  S.callKey = {}
  for _, entry in ipairs(S.flat) do
    for gi, group in ipairs(entry.step.groups) do
      for ci, call in ipairs(group.calls) do
        if KEYED[call.kind] then S.callKey[call] = table.concat({ entry.chapter, entry.index, gi, ci }, ":") end
      end
    end
  end
  local i
  if S.finished and #S.flat > 0 then
    i = #S.flat + 1
  else
    -- A saved position past the last visible step (guide shortened, chapters hidden for this character) lands on the
    -- last step instead of restarting the guide and overwriting the save.
    i = planner.locate(S.flat, S.pos) or math.max(1, #S.flat)
  end
  local pos, finished = S.pos, S.finished
  setCursor(i)
  if #S.flat == 0 then S.pos, S.finished = pos, finished end
end

local function ensure()
  if S and S.dirty then replan() end
end

-- The step the client says is finished (a gated grind once its XP gate is met), or one whose every located group has
-- been reached when the client can say nothing (travel, flight points, training).
local function stepComplete(i)
  local entry = S.flat[i]
  local e = env()
  local done = planner.stepDone(entry.step, e)
  if done ~= true and planner.npcStepPassed(S.flat, i, e) then return true end
  if done ~= nil then return done end
  local located = 0
  for gi, group in ipairs(entry.step.groups) do
    if location(group) then
      located = located + 1
      if not S.arrived[gi] then return false end
    end
  end
  return located > 0
end

-- One poll: advance past finished steps (a character with the quests already done skips ahead) and refresh text.
function Pl.refresh()
  if not S then return end
  ensure()
  local who = ns.client.character()
  S.who.level = who.level or S.who.level
  S.who.xp = who.xp or S.who.xp
  local i = S.cursor
  local advance = not ns.guideSettings or ns.guideSettings.get("autoAdvance")
  for _ = 1, 500 do
    if not advance then break end
    if not S.flat[i] or not stepComplete(i) then break end
    i = i + 1
    S.arrived = {}
  end
  if i ~= S.cursor then
    setCursor(i)
  elseif S.flat[S.cursor] then
    syncWaypoints(S.flat[S.cursor])
  end
end

-- Whether the current step already deals with a quest (any call that names it), so the tracked-quest bridge need not
-- show the same quest a second time.
function Pl.coversQuest(questID)
  if not S then return false end
  ensure()
  local entry = S.flat[S.cursor]
  if not entry then return false end
  for _, group in ipairs(entry.step.groups) do
    for _, call in ipairs(group.calls) do
      if call.quest == questID then return true end
    end
  end
  return false
end

function Pl.skip()
  ensure()
  if not S or S.cursor > #S.flat then return end
  setCursor(S.cursor + 1)
end

function Pl.prev()
  ensure()
  if not S then return end
  setCursor(math.max(1, S.cursor - 1))
end

-- Jump to a step by its guide position (chapter index, step index); the first visible step after it if that one is
-- not visible to this character.
function Pl.jump(chapter, step)
  ensure()
  if not S then return false end
  local i = planner.locate(S.flat, { chapter = chapter, step = step })
  if not i then return false end
  setCursor(i)
  return true
end

function Pl.jumpToChapter(chapter)
  ensure()
  if not S then return false end
  local i = planner.firstOfChapter(S.flat, chapter)
  if not i then return false end
  setCursor(i)
  return true
end

function Pl.reset()
  ensure()
  if not S then return end
  S.kills, S.marks = {}, {}
  setCursor(1)
end

-- Yards within which a flight master's map opening counts for the current Fp step.
local NEAR = 40

local function near(gi)
  if S.arrived[gi] then return true end
  local w = S.waypoints[gi]
  local wp = w and ns:GetWaypoint(w.uid)
  return wp ~= nil and wp.dist ~= nil and wp.dist <= NEAR
end

-- Mark the current step's calls of `kind` that `accept(call, gi)` takes.
local function mark(kind, accept)
  ensure()
  local entry = S.flat[S.cursor]
  if not entry then return end
  local changed = false
  for gi, group in ipairs(entry.step.groups) do
    for _, call in ipairs(group.calls) do
      local key = S.callKey[call]
      if call.kind == kind and key and not S.marks[key] and accept(call, gi) then
        S.marks[key] = true
        changed = true
      end
    end
  end
  if changed then
    save()
    Pl.refresh()
  end
end

-- Opening the trainer's dialog is the train step (the NPC must be the step's trainer when both are known); a flight
-- master's map opened at the step, or the "new flight path" message, is the flight path; binding is the inn.
local function onNpcEvent(event, a, b)
  if not S then return end
  if event == "TRAINER_SHOW" then
    local npc = ns.guideCounter.npcID(ns.client.npcGUID())
    mark("Train", function(call) return call.npc == nil or npc == nil or call.npc == npc end)
  elseif event == "TAXIMAP_OPENED" then
    mark("Fp", function(_, gi) return near(gi) end)
  elseif event == "UI_INFO_MESSAGE" then
    -- (messageType, message) on the modern client, (message) on an older one.
    if ns.client.isNewFlightPath(b) or ns.client.isNewFlightPath(a) then mark("Fp", function() return true end) end
  elseif event == "HEARTHSTONE_BOUND" then
    mark("Home", function() return true end)
  end
end

-- A credited kill: count it for every open Grind of the current step that `counts(call)` says it is a target of. A
-- gated grind's count is an estimate, so its kills keep counting past it.
local function countKill(counts)
  if not S then return end
  ensure()
  local entry = S.flat[S.cursor]
  if not entry then return end
  local counted = false
  for _, group in ipairs(entry.step.groups) do
    for _, call in ipairs(group.calls) do
      local key = S.callKey[call]
      if key and counts(call) and (call.gate or (S.kills[key] or 0) < call.count) then
        S.kills[key] = (S.kills[key] or 0) + 1
        counted = true
      end
    end
  end
  if counted then
    save()
    Pl.refresh()
  end
end

-- A kill from the combat log, by creature id.
local function onCombat(subevent, sourceFlags, destGUID)
  local npc = ns.guideCounter.credit(subevent, sourceFlags, destGUID)
  if npc then countKill(function(call) return ns.guideCounter.counts(call, npc) end) end
end

-- A kill from the XP chat line (a client that keeps its combat log from addons), by creature name.
local function onKillXP(text, format)
  local name = ns.guideCounter.xpKillName(text, format)
  if name then countKill(function(call) return ns.guideCounter.countsByName(call, name, S.guide.names) end) end
end

-- Read-only access for the views.
function Pl.state()
  ensure()
  return S
end

function Pl.current()
  ensure()
  if S then return S.flat[S.cursor], S.cursor end
end

-- The environment the views use to write text and outline states.
function Pl.env()
  ensure()
  return S and env()
end

-- Start / commands -------------------------------------------------------------------

function Pl.start(guide)
  if S then return end
  S = { guide = guide, who = ns.client.character(), view = {}, flat = {}, cursor = 1, waypoints = {}, arrived = {}, unplaced = {},
    kills = {}, marks = {}, callKey = {}, dirty = true }
  ns.guide = guide
  loadSaved(guide)
  ns:Every(POLL, Pl.refresh)
  if not ns.client.watchCombatLog(onCombat) then ns.client.watchKillXP(onKillXP) end
  ns.client.watchEvents({ "TRAINER_SHOW", "TAXIMAP_OPENED", "UI_INFO_MESSAGE", "HEARTHSTONE_BOUND" }, onNpcEvent)
  Pl.refresh()
  ns:Fire("GUIDE_STARTED", S)
end

-- Chapters arrive while the guide's files load.
ns:On("GUIDE_CHAPTER_ADDED", function()
  if S then S.dirty = true end
end)

ns:On("WAYPOINT_ARRIVED", function(wp)
  if not S then return end
  for gi, w in pairs(S.waypoints) do
    if w.uid == wp.uid then S.arrived[gi] = true end
  end
end)

-- Which guide -----------------------------------------------------------------------

-- The guide the player picked by hand for this character (an id), or nil for "automatic".
function Pl.choice()
  local who = S and S.who or ns.client.character()
  local all = ns.db and ns.db.guideChoice
  return all and all[who.key] or nil
end

-- The guides with how well each fits the character, best first (see Planner.rankGuides).
function Pl.ranked()
  return planner.rankGuides(ns.guides, S and S.who or ns.client.character())
end

-- The guide to use now: the player's pick if it is registered, else the best fit. Second result: the best fit.
function Pl.pick()
  return planner.chooseGuide(ns.guides, S and S.who or ns.client.character(), Pl.choice())
end

-- Moves the running player to another registered guide, keeping each guide's own saved position.
function Pl.switch(guide)
  if not (S and guide) or S.guide == guide then return false end
  ensure()
  if #S.flat > 0 then save() end   -- a guide whose chapters have not arrived has no position to keep
  clearWaypoints()
  S.guide = guide
  ns.guide = guide
  loadSaved(guide)
  S.view, S.flat, S.callKey, S.cursor, S.dirty = {}, {}, {}, 1, true
  Pl.refresh()
  ns:Fire("GUIDE_SWITCHED", guide)
  return true
end

-- The player's pick: a registered guide id, or nil (or "auto") to follow the best fit again. Returns false for an unknown id.
function Pl.choose(id)
  if id == "auto" or id == "" then id = nil end
  if id ~= nil then
    local known = false
    for _, g in ipairs(ns.guides) do known = known or g.id == id end
    if not known then return false end
  end
  if ns.db then
    ns.db.guideChoice = ns.db.guideChoice or {}
    ns.db.guideChoice[(S and S.who or ns.client.character()).key] = id
  end
  local guide = Pl.pick()
  if S then
    if not Pl.switch(guide) then ns:Fire("GUIDE_SWITCHED", guide) end   -- the picker redraws even when the guide stays
  elseif guide and ns.ready then
    Pl.start(guide)
  end
  return true
end

local function tryStart()
  if not ns.ready then return end
  if ns.guides and #ns.guides > 0 then
    local guide = Pl.pick()
    if not guide then return end
    if S then Pl.switch(guide) else Pl.start(guide) end
  elseif ns.guide then
    Pl.start(ns.guide)
  end
end

ns:On("INIT", tryStart)
ns:On("GUIDE_REGISTERED", tryStart)

-- /ribbon guide [skip|prev|reset|list|errors|use]
local base = ns.commands.guide
ns.commands.guide = function(args)
  args = string.lower(args or "")
  if not S then return base(args) end
  if args == "skip" or args == "next" then
    Pl.skip()
  elseif args == "prev" or args == "back" then
    Pl.prev()
  elseif args == "reset" then
    Pl.reset()
  elseif args == "errors" or args == "status" then
    return base(args)
  elseif args == "list" or args == "" then
    if ns.guideBrowser then ns.guideBrowser.toggle() end
    return
  elseif args == "use" or args:match("^use%s") or args == "guides" then
    local wanted = args:match("^use%s+(.-)%s*$")
    if wanted then
      local id = wanted
      -- A title or a start of an id works too ("use hunter").
      for _, g in ipairs(ns.guides) do
        if string.lower(g.id) == wanted or string.lower(g.title) == wanted then id = g.id end
      end
      if id == wanted and wanted ~= "auto" then
        for _, g in ipairs(ns.guides) do
          if id == wanted and (string.find(string.lower(g.id), wanted, 1, true) or string.find(string.lower(g.title), wanted, 1, true)) then id = g.id end
        end
      end
      if not Pl.choose(id) then
        ns:Print("no guide '" .. wanted .. "'; /ribbon guide use lists them.")
        return
      end
    end
    local recommended = select(2, Pl.pick())
    for _, r in ipairs(Pl.ranked()) do
      local g = r.guide
      ns:Print(string.format("%s%s (%s)%s%s", S.guide == g and "* " or "  ", g.title, g.id,
        planner.lockText(g.only) ~= "" and (" for " .. planner.lockText(g.only)) or "", g == recommended and ", recommended" or (r.eligible and "" or ", not for this character")))
    end
    ns:Print(Pl.choice() and ("chosen: " .. Pl.choice() .. " (/ribbon guide use auto to follow the best fit)") or "automatic: following the best fit.")
    return
  else
    ns:Print("guide commands: list, skip, prev, reset, status, errors, use [guide|auto]")
    return
  end
  local entry = S.flat[S.cursor]
  ns:Print(entry and string.format("step %d of %d: %s", S.cursor, #S.flat, text.summary(entry.step, S.guide.names, env())) or "guide finished.")
end
