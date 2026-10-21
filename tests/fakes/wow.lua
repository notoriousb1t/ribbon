-- Fake WoW client: the globals Ribbon touches, with a controllable world and recording frames.
-- Every method on a fake frame is a spy (args exclude self), so specs can verify calls:
--   expect(frame.SetPoint).toHaveBeenCalledWith("CENTER", parent, "CENTER", 10, 0)
-- Methods not implemented here are auto-created no-op spies.
local Spy = require("tests.framework.spy")

local Fake = {}
local snapshot

-- Frames -------------------------------------------------------------------

local function newObject(world, kind)
  local o = {
    kind = kind,
    state = { shown = true, alpha = 1, level = 1, points = {}, size = { 0, 0 }, text = "", scripts = {}, events = {}, children = {} },
  }
  o.scripts = o.state.scripts

  local impl = {
    Show = function(self) self.state.shown = true end,
    Hide = function(self) self.state.shown = false end,
    SetShown = function(self, v) self.state.shown = v and true or false end,
    IsShown = function(self) return self.state.shown end,
    IsVisible = function(self) return self.state.shown end,
    SetSize = function(self, w, h) self.state.size = { w, h } end,
    SetWidth = function(self, w) self.state.size[1] = w end,
    SetHeight = function(self, h) self.state.size[2] = h end,
    GetWidth = function(self) return self.state.size[1] end,
    GetHeight = function(self) return self.state.size[2] end,
    SetPoint = function(self, ...) self.state.points[#self.state.points + 1] = { ... } end,
    ClearAllPoints = function(self) self.state.points = {} end,
    GetPoint = function(self)
      local p = self.state.points[1]
      if p then return unpack(p) end
    end,
    SetAlpha = function(self, a) self.state.alpha = a end,
    GetAlpha = function(self) return self.state.alpha end,
    SetText = function(self, t) self.state.text = t end,
    GetText = function(self) return self.state.text end,
    SetTexture = function(self, t) self.state.texture = t end,
    GetTexture = function(self) return self.state.texture end,
    SetFrameLevel = function(self, l) self.state.level = l end,
    GetFrameLevel = function(self) return self.state.level end,
    SetScript = function(self, name, fn) self.state.scripts[name] = fn end,
    GetScript = function(self, name) return self.state.scripts[name] end,
    RegisterEvent = function(self, e)
      if world.unknownEvents and world.unknownEvents[e] then error("Attempt to register unknown event \"" .. e .. "\"") end
      self.state.events[e] = true
    end,
    UnregisterAllEvents = function(self) self.state.events = {} end,
    SetParent = function(self, p) self.state.parent = p end,
    GetParent = function(self) return self.state.parent end,
    CreateTexture = function(self) local o = world:newObject("Texture") o.state.parent = self return o end,
    CreateFontString = function(self) local o = world:newObject("FontString") o.state.parent = self return o end,
    -- Test helpers (not part of the WoW API).
    Trigger = function(self, script, ...)
      local fn = self.state.scripts[script]
      if fn then return fn(self, ...) end
    end,
  }
  for name, fn in pairs(impl) do
    o[name] = Spy.new(fn, true)
    o[name].original = fn
    o[name].mode = "through"
    -- A spy that records args without self but must still call through with self.
    local spy = o[name]
    spy.skipSelf = true
  end

  -- Any other capitalised method is a recording no-op.
  setmetatable(o, {
    __index = function(t, k)
      if type(k) == "string" and k:match("^%u") then
        local s = Spy.new(nil, true)
        rawset(t, k, s)
        return s
      end
    end,
  })
  return o
end

-- World ----------------------------------------------------------------------

local World = {}
World.__index = World

function World:newObject(kind)
  local o = newObject(self, kind)
  self.objects[#self.objects + 1] = o
  return o
end

-- Define a zone map. tl/br are world coordinates of the map's top-left and bottom-right corners.
function World:addMap(id, def)
  def.mapID = id
  def.instance = def.instance or 0
  self.maps[id] = def
end

-- Place the player at map coordinates (0-100) of a map.
function World:placePlayer(mapID, x, y, facing)
  local m = self.maps[mapID]
  self.player.mapID = mapID
  self.player.first = m.tl.first + (y / 100) * (m.br.first - m.tl.first)
  self.player.second = m.tl.second + (x / 100) * (m.br.second - m.tl.second)
  self.player.instance = m.instance
  if facing then self.player.facing = facing end
end

function World:removeApi(path)
  local obj, key = _G, path
  local parent, name = path:match("^(.-)%.([^%.]+)$")
  if parent then
    obj, key = _G[parent], name
  end
  obj[key] = nil
end

-- Fire a client event at every frame registered for it.
function World:fireEvent(event, ...)
  for _, o in ipairs(self.objects) do
    if o.state.events[event] and o.state.scripts.OnEvent then
      o.state.scripts.OnEvent(o, event, ...)
    end
  end
end

-- Run every OnUpdate script once.
function World:update(dt)
  for _, o in ipairs(self.objects) do
    local fn = o.state.scripts.OnUpdate
    if fn then fn(o, dt) end
  end
end

function World:framesWhere(pred)
  local out = {}
  for _, o in ipairs(self.objects) do
    if pred(o) then out[#out + 1] = o end
  end
  return out
end

function World:output() return table.concat(self.printed, "\n") end

local function mapContains(maps, rootID, id)
  local seen = {}
  local cur = maps[id]
  while cur and not seen[cur.mapID] do
    if cur.parent == rootID then return true end
    seen[cur.mapID] = true
    cur = maps[cur.parent]
  end
  return false
end

local function vector(x, y)
  return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end

function Fake.install()
  snapshot = {}
  for k, v in pairs(_G) do snapshot[k] = v end

  local world = setmetatable({
    objects = {}, maps = {}, libs = {}, printed = {}, errors = {}, unknownEvents = {},
    -- tracked: super-tracked questID; points[mapID] = { { questID, x, y (0-1), isQuestStart, inProgress } };
    -- log[id] = { complete = bool } for quests in the log; done[id] = true for quests turned in.
    quest = { tracked = 0, titles = {}, points = {}, objectives = {}, log = {}, done = {} },
    character = { name = "Tester", realm = "Realm", class = "WARRIOR", race = "Tauren", faction = "Horde", level = 1 },
    player = { first = 0, second = 0, instance = 0, facing = 0, mapID = nil, noPosition = false },
  }, World)

  -- Eastern Kingdoms and Stormwind City, using values measured on the Forever beta client.
  world:addMap(1415, { name = "Eastern Kingdoms", parent = 947, tl = { first = 7466.6, second = 16000 }, br = { first = -16000, second = -19199.9 } })
  world:addMap(1453, { name = "Stormwind City", parent = 1415, tl = { first = -7995.83, second = 1722.92 }, br = { first = -9154.17, second = -14.584 } })
  world:addMap(1414, { name = "Kalimdor", parent = 947, instance = 1, tl = { first = 8000, second = 12000 }, br = { first = -12000, second = -12000 } })
  world:addMap(1439, { name = "Darkshore", parent = 1414, instance = 1, tl = { first = 4500, second = 2500 }, br = { first = 1000, second = -2000 } })
  world:placePlayer(1453, 61.99, 70.58, 0)

  -- Frames
  _G.CreateFrame = Spy.new(function(kind, name, parent)
    local f = world:newObject(kind)
    f.state.parent = parent
    f.name = name
    if name then _G[name] = f end
    return f
  end)
  _G.UIParent = world:newObject("Frame")
  _G.GameTooltip = world:newObject("GameTooltip")
  _G.Minimap = world:newObject("Frame")
  _G.WorldMapFrame = world:newObject("Frame")

  -- Player and map APIs
  _G.GetPlayerFacing = function() return world.player.facing end
  _G.UnitPosition = function()
    if world.player.noPosition then return nil end
    return world.player.first, world.player.second, 0, world.player.instance
  end
  _G.CreateVector2D = vector
  _G.C_Map = {
    GetBestMapForUnit = function() return world.player.mapID end,
    GetPlayerMapPosition = function(mapID)
      local m = world.maps[mapID]
      if not m or world.player.noPosition then return nil end
      return vector(
        (world.player.second - m.tl.second) / (m.br.second - m.tl.second),
        (world.player.first - m.tl.first) / (m.br.first - m.tl.first))
    end,
    GetWorldPosFromMapPos = function(mapID, vec)
      local m = world.maps[mapID]
      if not m then return nil end
      return m.instance, vector(
        m.tl.first + vec.y * (m.br.first - m.tl.first),
        m.tl.second + vec.x * (m.br.second - m.tl.second))
    end,
    GetMapInfo = function(mapID)
      local m = world.maps[mapID]
      if not m then return nil end
      return { mapID = mapID, name = m.name, parentMapID = m.parent }
    end,
    GetMapChildrenInfo = function(rootID)
      local out = {}
      for id, m in pairs(world.maps) do
        if mapContains(world.maps, rootID, id) then out[#out + 1] = { mapID = id, name = m.name } end
      end
      table.sort(out, function(a, b) return a.mapID < b.mapID end)
      return out
    end,
  }

  -- Quest tracking: the tracked quest, its title, map points and objectives.
  _G.C_SuperTrack = {
    GetSuperTrackedQuestID = function() return world.quest.tracked end,
  }
  _G.C_QuestLog = {
    GetTitleForQuestID = function(id) return world.quest.titles[id] end,
    GetQuestsOnMap = function(mapID) return world.quest.points[mapID] or {} end,
    GetQuestObjectives = function(id) return world.quest.objectives[id] or {} end,
    IsQuestFlaggedCompleted = function(id) return world.quest.done[id] == true end,
    GetLogIndexForQuestID = function(id) if world.quest.log[id] then return 1 end end,
    IsComplete = function(id) return world.quest.log[id] ~= nil and world.quest.log[id].complete == true end,
  }

  -- The player character.
  local c = world.character
  _G.UnitName = function() return c.name end
  _G.GetRealmName = function() return c.realm end
  _G.UnitClass = function() return c.class:sub(1, 1) .. c.class:sub(2):lower(), c.class end
  _G.UnitRace = function() return c.race, c.race end
  _G.UnitFactionGroup = function() return c.faction, c.faction end
  _G.UnitLevel = function() return c.level end
  _G.UnitAffectingCombat = function() return world.inCombat == true end

  -- Chat, slash commands, libraries
  _G.SlashCmdList = {}
  _G.hash_SlashCmdList = {}
  _G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    world.printed[#world.printed + 1] = table.concat(parts, " ")
  end
  _G.geterrorhandler = function() return function(err) world.errors[#world.errors + 1] = err end end
  _G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  _G.LibStub = function(name) return world.libs[name] end

  -- hooksecurefunc(table, name, fn) / hooksecurefunc(name, fn): fn runs after the original, same arguments.
  _G.hooksecurefunc = function(a, b, c)
    local tbl, name, fn
    if type(a) == "table" then tbl, name, fn = a, b, c else tbl, name, fn = _G, a, b end
    local original = tbl[name]
    tbl[name] = function(...)
      local r = { n = 0 }
      local function pack(...) r.n = select("#", ...) for i = 1, r.n do r[i] = (select(i, ...)) end end
      pack(original(...))
      fn(...)
      return unpack(r, 1, r.n)
    end
  end

  -- HereBeDragons-Pins stand-in.
  local pins = {}
  for _, name in ipairs({ "AddWorldMapIconMap", "RemoveWorldMapIcon", "AddMinimapIconMap", "RemoveMinimapIcon" }) do
    pins[name] = Spy.new(nil, true)
  end
  world.libs["HereBeDragons-Pins-2.0"] = pins
  world.pins = pins
  _G.HBD_PINS_WORLDMAP_SHOW_CONTINENT = 2

  world.worldMapFrame = _G.WorldMapFrame
  RibbonDB = nil
  return world
end

function Fake.uninstall()
  if not snapshot then return end
  for k in pairs(_G) do
    if snapshot[k] == nil then _G[k] = nil end
  end
  for k, v in pairs(snapshot) do _G[k] = v end
  snapshot = nil
end

return Fake
