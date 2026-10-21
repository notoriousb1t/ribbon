-- Guide builder: the chained calls a generated guide file makes (see docs/guide-plan.md).
--
--   local R = Ribbon.Guide("forever-horde", { title = "...", schema = 1 })
--   R:Chapter("1-11 Mulgore", { levels = { 1, 11 } })
--     :Step()
--       :Goto(MAP.MULGORE, 44.50, 77.50)
--       :Accept(QUEST.THE_HUNT_BEGINS):At(NPC.GRULL_HAWKWIND)
--     :Done()
--
-- Pure data: no client calls and no frames, so a guide file can run at load time, before the client is
-- ready. Every call validates its arguments and records an error instead of raising; a chapter with an
-- error is skipped, the rest of the guide still loads. Registering the first guide is what makes the guide
-- layer exist at all: until then nothing in Ribbon knows about guides.
local ADDON, ns = ...

local B = { SCHEMA = 1, MAX_POINTS = 500 }
ns.guideBuilder = B

-- Validation ------------------------------------------------------------------

local function isId(v) return type(v) == "number" and v >= 1 and v == math.floor(v) end

-- 0-100 with at most two decimals.
local function isCoord(v)
  return type(v) == "number" and v >= 0 and v <= 100 and math.abs(v * 100 - math.floor(v * 100 + 0.5)) < 1e-6
end

local function isText(v) return type(v) == "string" and v ~= "" end

local function isIdList(v)
  if type(v) ~= "table" then return false end
  for _, id in ipairs(v) do
    if not isId(id) then return false end
  end
  return true
end

local function isPoints(v, min)
  if type(v) ~= "table" or #v < (min or 1) or #v > B.MAX_POINTS then return false end
  for _, p in ipairs(v) do
    if type(p) ~= "table" or not isCoord(p[1]) or not isCoord(p[2]) then return false end
  end
  return true
end

B.isId, B.isCoord, B.isPoints = isId, isCoord, isPoints

-- Chapter cursor ----------------------------------------------------------------

local methods = {}
local Cursor = {}
Cursor.__index = function(_, name)
  if methods[name] then return methods[name] end
  -- Lower-case names are the cursor's own fields (bad, last): unset ones are nil, not calls.
  if type(name) ~= "string" or not name:match("^%u") then return nil end
  -- A misspelt call must not raise: record it and keep the chain alive.
  return function(self)
    self:fail(name, "is not a guide call")
    return self
  end
end

function methods:fail(call, message)
  self.bad = true
  self.errors[#self.errors + 1] = string.format("%s, step %d: :%s %s", self.name, #self.steps, call, message)
end

-- True when `ok`; otherwise records the error.
local function need(self, call, ok, message)
  if not ok then self:fail(call, message) end
  return ok
end

local function currentStep(self, call)
  local step = self.steps[#self.steps]
  if not step then self:fail(call, "needs :Step() first") end
  return step
end

-- The located group of the current step; a call before any :Goto goes in a group with no location.
local function currentGroup(self, call)
  local step = currentStep(self, call)
  if not step then return nil end
  local g = step.groups[#step.groups]
  if not g then
    g = { calls = {} }
    step.groups[1] = g
  end
  return g
end

local function add(self, call, data)
  local g = currentGroup(self, call)
  if not g then return end
  data.kind = call
  g.calls[#g.calls + 1] = data
  self.last = data
end

local function options(self, call, opts)
  if opts == nil then return {} end
  if not need(self, call, type(opts) == "table", "options must be a table") then return nil end
  if opts.quest ~= nil and not need(self, call, isId(opts.quest), "quest must be an id") then return nil end
  if opts.index ~= nil and not need(self, call, isId(opts.index), "index must be a positive integer") then return nil end
  return opts
end

function methods:Step()
  self.steps[#self.steps + 1] = { groups = {} }
  self.last = nil
  return self
end

function methods:Goto(map, x, y)
  if need(self, "Goto", isId(map), "map must be an id") and need(self, "Goto", isCoord(x) and isCoord(y), "x and y must be 0-100 with at most two decimals") then
    local step = currentStep(self, "Goto")
    if step then step.groups[#step.groups + 1] = { at = { map = map, x = x, y = y }, calls = {} } end
  end
  return self
end

function methods:Loop(map, points)
  if need(self, "Loop", isId(map), "map must be an id") and need(self, "Loop", isPoints(points, 2), "needs a list of at least two {x, y} points") then
    local step = currentStep(self, "Loop")
    if step then step.groups[#step.groups + 1] = { loop = { map = map, points = points }, calls = {} } end
  end
  return self
end

-- Class, race, faction and flavor lock. Right after :Step() it locks the whole step; later it locks the located group
-- before it.
function methods:Only(lock)
  if not need(self, "Only", type(lock) == "table", "needs { class =, race =, faction =, flavor = }") then return self end
  local step = currentStep(self, "Only")
  if not step then return self end
  local g = step.groups[#step.groups]
  if g then g.only = lock else step.only = lock end
  return self
end

function methods:Skippable()
  local step = currentStep(self, "Skippable")
  if step then step.skippable = true end
  return self
end

function methods:Accept(quest)
  if need(self, "Accept", isId(quest), "quest must be an id") then add(self, "Accept", { quest = quest }) end
  return self
end

function methods:Turnin(quest)
  if need(self, "Turnin", isId(quest), "quest must be an id") then add(self, "Turnin", { quest = quest }) end
  return self
end

-- The NPC of the accept or turn-in before it.
function methods:At(npc)
  local last = self.last
  if need(self, "At", last and (last.kind == "Accept" or last.kind == "Turnin"), "must follow :Accept or :Turnin")
    and need(self, "At", isId(npc), "npc must be an id") then
    last.npc = npc
  end
  return self
end

function methods:Collect(item, count, opts)
  opts = options(self, "Collect", opts)
  if opts and need(self, "Collect", isId(item) and isId(count), "item and count must be ids") then
    add(self, "Collect", { item = item, count = count, quest = opts.quest })
  end
  return self
end

function methods:Use(item)
  if need(self, "Use", isId(item), "item must be an id") then add(self, "Use", { item = item }) end
  return self
end

function methods:Kill(creature, count, opts)
  opts = options(self, "Kill", opts)
  if opts and need(self, "Kill", isId(creature) and isId(count), "creature and count must be ids") then
    add(self, "Kill", { creature = creature, count = count, quest = opts.quest, index = opts.index })
  end
  return self
end

function methods:Loot(item, count, opts)
  opts = options(self, "Loot", opts)
  if opts and need(self, "Loot", isId(item) and isId(count), "item and count must be ids")
    and need(self, "Loot", opts.from == nil or isIdList(opts.from), "from must be a list of creature ids")
    and need(self, "Loot", opts.objects == nil or isIdList(opts.objects), "objects must be a list of object ids") then
    add(self, "Loot", { item = item, count = count, quest = opts.quest, index = opts.index, from = opts.from, objects = opts.objects })
  end
  return self
end

function methods:Interact(object, opts)
  opts = options(self, "Interact", opts)
  if opts and need(self, "Interact", isId(object), "object must be an id") then
    add(self, "Interact", { object = object, quest = opts.quest, index = opts.index })
  end
  return self
end

function methods:Explore(quest, opts)
  opts = options(self, "Explore", opts)
  if opts and need(self, "Explore", isId(quest), "quest must be an id")
    and need(self, "Explore", opts.npc == nil or isId(opts.npc), "npc must be an id") then
    add(self, "Explore", { quest = quest, index = opts.index, npc = opts.npc })
  end
  return self
end

-- Map points for the objective call before it.
function methods:Spawns(map, points)
  local last = self.last
  local objective = last and (last.kind == "Kill" or last.kind == "Loot" or last.kind == "Interact" or last.kind == "Grind")
  if need(self, "Spawns", objective, "must follow an objective call")
    and need(self, "Spawns", isId(map), "map must be an id")
    and need(self, "Spawns", isPoints(points), "needs a list of {x, y} points") then
    last.spawns = { map = map, points = points }
  end
  return self
end

local function node(call)
  return function(self, name)
    if need(self, call, isText(name), "needs a flight point or inn name") then add(self, call, { node = name }) end
    return self
  end
end
methods.Fp, methods.Fly, methods.Hearth, methods.Home = node("Fp"), node("Fly"), node("Hearth"), node("Home")

function methods:Ding(level)
  if need(self, "Ding", isId(level) and level <= 60, "level must be 1-60") then add(self, "Ding", { level = level }) end
  return self
end

function methods:Train(npc, abilities)
  if need(self, "Train", npc == nil or isId(npc), "npc must be an id or nil")
    and need(self, "Train", type(abilities) == "table", "needs a list of ability names") then
    add(self, "Train", { npc = npc, abilities = abilities })
  end
  return self
end

function methods:Deathwarp() add(self, "Deathwarp", {}) return self end
function methods:Travel() add(self, "Travel", {}) return self end

function methods:Skip(quest)
  if need(self, "Skip", isId(quest), "quest must be an id") then add(self, "Skip", { quest = quest }) end
  return self
end

function methods:Enter(map)
  if need(self, "Enter", isId(map), "map must be an id") then add(self, "Enter", { map = map }) end
  return self
end

function methods:Subzone(name)
  if need(self, "Subzone", isText(name), "needs a name") then add(self, "Subzone", { name = name }) end
  return self
end

function methods:Grind(map, x, y, radius, opts)
  if not (need(self, "Grind", isId(map), "map must be an id")
    and need(self, "Grind", isCoord(x) and isCoord(y), "x and y must be 0-100 with at most two decimals")
    and need(self, "Grind", isId(radius), "radius must be a positive integer")
    and need(self, "Grind", type(opts) == "table", "needs { npc =, count =, level =, xp =, gate = }")) then
    return self
  end
  local goal = isId(opts.count) or isId(opts.level)
  if need(self, "Grind", goal, "needs a count or a level")
    and need(self, "Grind", opts.npc == nil or isIdList(opts.npc), "npc must be a list of creature ids")
    and need(self, "Grind", opts.xp == nil or isId(opts.xp), "xp must be a positive integer")
    and need(self, "Grind", opts.gate == nil or type(opts.gate) == "table" and isId(opts.gate.level) and opts.gate.level <= 60
      and (opts.gate.xp == nil or isId(opts.gate.xp)), "gate must be { level = 1-60, xp = positive integer }") then
    local gate = opts.gate and { level = opts.gate.level, xp = opts.gate.xp }
    add(self, "Grind", { map = map, x = x, y = y, radius = radius, npc = opts.npc, count = opts.count, level = opts.level, xp = opts.xp, gate = gate })
  end
  return self
end

-- Finishes the chapter. A chapter with an error is dropped and its errors kept on the guide.
function methods:Done()
  local guide = self.guide
  if self.bad then
    for _, e in ipairs(self.errors) do guide.errors[#guide.errors + 1] = e end
    -- One line per guide: a guide with many bad chapters would otherwise flood the chat at login.
    if #guide.errors == #self.errors then
      ns:Print(string.format("guide chapter skipped: %s (more: /ribbon guide errors)", self.errors[1]))
    end
    return guide
  end
  local chapter = { name = self.name, opts = self.opts, steps = self.steps }
  local replaced = false
  -- A chapter is identified by its name, faction and flavor: both factions' guides can each have, say, "Zephras Isle",
  -- and a Forever and a Classic chapter can share a name.
  local function id(opts)
    opts = type(opts) == "table" and opts or {}
    return tostring(opts.faction) .. "/" .. tostring(opts.flavor)
  end
  local key = id(self.opts)
  for i, c in ipairs(guide.chapters) do
    if c.name == self.name and id(c.opts) == key then
      guide.chapters[i] = chapter
      replaced = true
      break
    end
  end
  if not replaced then guide.chapters[#guide.chapters + 1] = chapter end
  ns:Fire("GUIDE_CHAPTER_ADDED", chapter)
  return guide
end

-- Guide ------------------------------------------------------------------------

local Guide = {}
Guide.__index = Guide

function Guide:Chapter(name, opts)
  local cursor = setmetatable({ guide = self, name = tostring(name), opts = opts, steps = {}, errors = {} }, Cursor)
  if not isText(name) then cursor:fail("Chapter", "needs a name") end
  if opts ~= nil and type(opts) ~= "table" then cursor:fail("Chapter", "options must be a table") end
  return cursor
end

local NAME_KINDS = { "MAP", "NPC", "CREATURE", "OBJECT", "ITEM", "QUEST" }

-- Display names of the ids a file uses: { QUEST = { [747] = "The Hunt Begins" }, NPC = ... }. The captions are
-- written from these; the client has no creature-by-id lookup. Bad entries are ignored.
function Guide:Names(list)
  if type(list) ~= "table" then return self end
  for _, kind in ipairs(NAME_KINDS) do
    local entries = list[kind]
    if type(entries) == "table" then
      local dst = self.names[kind]
      for id, name in pairs(entries) do
        if isId(id) and isText(name) then dst[id] = name end
      end
    end
  end
  return self
end

-- A null guide for a refused registration: every call is accepted and does nothing, so a generated file
-- still runs to its end.
local function nullGuide()
  local null = {}
  return setmetatable(null, { __index = function() return function(self) return self end end })
end

-- Ribbon.Guide(id, opts): the guide for `id`, created on first use. There is one guide; a second id is
-- refused. The first call is what registers the guide layer (GUIDE_REGISTERED).
function ns.Guide(id, opts)
  opts = type(opts) == "table" and opts or {}
  if not isText(id) then
    ns:Print("guide refused: the guide id must be a non-empty string.")
    return nullGuide()
  end
  if ns.guide then
    if ns.guide.id == id then return ns.guide end
    ns:Print(string.format("guide '%s' refused: '%s' is already registered (one guide at a time).", id, ns.guide.id))
    return nullGuide()
  end
  if opts.schema ~= B.SCHEMA then
    ns:Print(string.format("guide '%s' refused: it uses format %s and this Ribbon reads format %d.", id, tostring(opts.schema), B.SCHEMA))
    return nullGuide()
  end
  local guide = setmetatable({ id = id, title = isText(opts.title) and opts.title or id, schema = opts.schema, chapters = {}, errors = {},
    names = { MAP = {}, NPC = {}, CREATURE = {}, OBJECT = {}, ITEM = {}, QUEST = {} } }, Guide)
  ns.guide = guide
  ns:Fire("GUIDE_REGISTERED", guide)
  return guide
end
