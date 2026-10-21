local H = require("tests.helpers.addon")

-- Stormwind City (1453) is about 1737 yd wide: one map unit east is about 17 yd.
local function build(R)
  R:Names({ QUEST = { [747] = "The Hunt Begins" }, NPC = { [2980] = "Grull Hawkwind" }, MAP = { [1453] = "Stormwind City" } })
  R:Chapter("Town")
    :Step():Goto(1453, 50.00, 50.00):Train(2980, { "Charge" })
    :Step():Goto(1453, 52.00, 52.00):Fp("Crossroads")
    :Step():Goto(1453, 54.00, 54.00):Home("Crossroads")
    :Step():Goto(1453, 56.00, 56.00):Hearth("Crossroads")
    :Step():Goto(1453, 58.00, 58.00):Deathwarp()
    :Step():Goto(1453, 60.00, 60.00):Accept(747)
    :Step():Goto(1453, 62.00, 62.00):Turnin(747)
    :Done()
  return R
end

local function npc(id) return "Creature-0-5250-0-14-" .. id .. "-0000123ABC" end

describe("Trainer, flight path, inn and hearth steps", function()
  local ctx = H.use({ boot = true })
  local function cursor() local _, i = ctx.ns.guidePlayer.current() return i end
  local function at(x, y)
    ctx.world:placePlayer(1453, x, y, 0)
    ctx.ns:UpdateGeometry()
    ctx.ns.guidePlayer.refresh()
  end
  beforeEach(function() build(Ribbon.Guide("g", { schema = 1 })) end)

  it("a train step waits for the trainer's dialog, not arrival", function()
    at(50, 50)
    expect(cursor()).toBe(1)
    ctx.world.npcGUID = npc(9999)                     -- another trainer
    ctx.world:fireEvent("TRAINER_SHOW")
    expect(cursor()).toBe(1)
    ctx.world.npcGUID = npc(2980)
    ctx.world:fireEvent("TRAINER_SHOW")
    expect(cursor()).toBe(2)
  end)

  it("a train step takes any trainer when the client cannot say which one it is", function()
    ctx.world.npcGUID = nil
    ctx.world:fireEvent("TRAINER_SHOW")
    expect(cursor()).toBe(2)
  end)

  it("a flight path step takes a flight master's map opened at the step, or the new flight path message anywhere", function()
    ctx.ns.guidePlayer.jump(1, 2)
    at(60, 60)
    ctx.world:fireEvent("TAXIMAP_OPENED")             -- some other flight master
    expect(cursor()).toBe(2)
    at(52.4, 52)
    expect(cursor()).toBe(2)                          -- arriving is not enough
    ctx.world:fireEvent("TAXIMAP_OPENED")
    expect(cursor()).toBe(3)
    ctx.ns.guidePlayer.prev()
    at(60, 60)
    expect(cursor()).toBe(3)                          -- marked: it stays done
    ctx.ns.guidePlayer.reset()
    ctx.ns.guidePlayer.jump(1, 2)
    ctx.world:fireEvent("UI_INFO_MESSAGE", 0, "New flight path discovered!")
    expect(cursor()).toBe(3)
  end)

  it("an inn step waits for the hearthstone to be set there", function()
    ctx.ns.guidePlayer.jump(1, 3)
    at(54, 54)
    expect(cursor()).toBe(3)
    ctx.world:fireEvent("HEARTHSTONE_BOUND")
    expect(cursor()).toBe(4)
  end)

  it("an inn step is done while the hearthstone is already set at its inn", function()
    ctx.ns.guidePlayer.jump(1, 3)
    ctx.world.bind = "crossroads"
    ctx.ns.guidePlayer.refresh()
    expect(cursor()).toBe(4)
  end)

  it("a hearth step is done within 25 yd of its innkeeper", function()
    ctx.ns.guidePlayer.jump(1, 4)
    at(57.8, 56)                                      -- about 31 yd off
    expect(cursor()).toBe(4)
    at(57.2, 56)                                      -- about 21 yd off
    expect(cursor()).toBe(5)
  end)

  it("keeps the marks across a reload", function()
    ctx.world:fireEvent("TRAINER_SHOW")
    ctx.ns.guidePlayer.prev()
    local db = RibbonDB
    local ns = H.load({ boot = true, world = function() RibbonDB = db end })
    build(Ribbon.Guide("g", { schema = 1 }))
    ns.guidePlayer.refresh()                          -- the next poll
    local _, i = ns.guidePlayer.current()
    expect(i).toBe(2)
  end)

  it("are all passed once a quest step after them is done", function()
    ctx.world.quest.log[747] = { complete = false }
    ctx.ns.guidePlayer.refresh()
    expect(cursor()).toBe(7)
  end)

  describe("the later step rule", function()
    local P = H.pure({ "guide/Planner.lua" }).guidePlanner
    local function step(kind, opts)
      local call = opts or {}
      call.kind = kind
      return { step = { groups = { { calls = { call } } } } }
    end
    local function env(level) return { level = level, quest = function(id) return id == 7 and "active" or "none" end,
      objective = function() end, kills = function() return 0 end, marked = function() return false end } end

    it("counts quest steps only, not level or grind steps", function()
      expect(P.npcStepPassed({ step("Train", { npc = 1 }), step("Ding", { level = 2 }) }, 1, env(9))).toBe(false)
      expect(P.npcStepPassed({ step("Fp", { node = "X" }), step("Grind", { level = 2 }) }, 1, env(9))).toBe(false)
      expect(P.npcStepPassed({ step("Home", { node = "X" }), step("Accept", { quest = 7 }) }, 1, env(1))).toBe(true)
    end)

    it("looks P.LOOKAHEAD steps ahead and no further", function()
      local flat = { step("Hearth", { node = "X" }) }
      for _ = 1, P.LOOKAHEAD do flat[#flat + 1] = step("Accept", { quest = 8 }) end
      flat[#flat + 1] = step("Accept", { quest = 7 })
      expect(P.npcStepPassed(flat, 1, env(1))).toBe(false)
      table.remove(flat, 2)
      expect(P.npcStepPassed(flat, 1, env(1))).toBe(true)
    end)

    it("never passes a step with a quest call in it", function()
      expect(P.npcStepPassed({ step("Accept", { quest = 8 }), step("Accept", { quest = 7 }) }, 1, env(1))).toBe(false)
    end)
  end)
end)
