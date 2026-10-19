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

local function env()
  return { quest = ns.client.questStatus, objective = objective, level = S.who.level }
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
  ns.db.guide[S.who.key] = entry and { guide = S.guide.id, chapter = entry.chapter, step = entry.index } or { guide = S.guide.id, finished = true }
end

local function saved()
  local all = ns.db and ns.db.guide
  local mine = all and all[S.who.key]
  if mine and mine.guide == S.guide.id then return mine end
end

-- Waypoints of the current step -------------------------------------------------------

local function clearWaypoints()
  for _, w in pairs(S.waypoints) do ns:RemoveWaypoint(w.uid) end
  S.waypoints = {}
  S.arrived = {}
end

local function location(group)
  if group.at then return group.at.map, group.at.x, group.at.y end
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
    local map, x, y = location(group)
    if map then
      local lines = text.lines(group, S.guide.names, e, state)
      if #lines > 0 then
        local detail = {}
        for i = 2, #lines do detail[#detail + 1] = lines[i] end
        out[gi] = { map = map, x = x, y = y, title = lines[1], description = detail, icon = text.icon(group) }
      end
    end
  end
  return out
end

local function syncWaypoints(entry)
  local want = desired(entry)
  for gi, w in pairs(S.waypoints) do
    local d = want[gi]
    if not d or d.map ~= w.map or d.x ~= w.x or d.y ~= w.y then
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
        wp.title = ns.OneLine(d.title)
        wp.description = ns.NormalizeDescription(d.description)
      end
    else
      local uid = ns:AddWaypoint(d.map, d.x, d.y, {
        title = d.title, description = d.description, icon = d.icon,
        lines = { "Guide: " .. (chapterName(entry) or S.guide.title) },
      })
      if uid then S.waypoints[gi] = { uid = uid, map = d.map, x = d.x, y = d.y } end
    end
  end
end

-- Moving ----------------------------------------------------------------------------

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
    ns:Fire("GUIDE_STEP_CHANGED", entry, i)
  else
    ns:Fire("GUIDE_FINISHED")
  end
end

-- The guide gains chapters while its files load (and the character's class or race can change what is visible), so
-- the plan is rebuilt lazily: any use of the player first catches up, keeping the saved position.
local function replan()
  S.dirty = false
  S.who = ns.client.character()
  S.view = planner.view(S.guide, S.who)
  S.flat = planner.flatten(S.view)
  local i
  if S.finished and #S.flat > 0 then
    i = #S.flat + 1
  else
    i = planner.locate(S.flat, S.pos) or 1
  end
  local pos, finished = S.pos, S.finished
  setCursor(i)
  if #S.flat == 0 then S.pos, S.finished = pos, finished end
end

local function ensure()
  if S and S.dirty then replan() end
end

-- The step the client says is finished, or one whose every located group has been reached when the client can say
-- nothing (travel, flight points, training).
local function stepComplete(entry)
  local done = planner.stepDone(entry.step, env())
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
  local i = S.cursor
  for _ = 1, 500 do
    local entry = S.flat[i]
    if not entry or not stepComplete(entry) then break end
    i = i + 1
    S.arrived = {}
  end
  if i ~= S.cursor then
    setCursor(i)
  elseif S.flat[S.cursor] then
    syncWaypoints(S.flat[S.cursor])
  end
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
  if S then setCursor(1) end
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
  S = { guide = guide, who = ns.client.character(), view = {}, flat = {}, cursor = 1, waypoints = {}, arrived = {}, dirty = true }
  local mine = saved()
  if mine and mine.finished then
    S.finished = true
  elseif mine then
    S.pos = { chapter = mine.chapter, step = mine.step }
  end
  ns:Every(POLL, Pl.refresh)
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

local function tryStart()
  if ns.guide and ns.ready then Pl.start(ns.guide) end
end

ns:On("INIT", tryStart)
ns:On("GUIDE_REGISTERED", tryStart)

-- /ribbon guide [skip|prev|reset|list|errors]
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
  else
    ns:Print("guide commands: list, skip, prev, reset, status, errors")
    return
  end
  local entry = S.flat[S.cursor]
  ns:Print(entry and string.format("step %d of %d: %s", S.cursor, #S.flat, text.summary(entry.step, S.guide.names, env())) or "guide finished.")
end
