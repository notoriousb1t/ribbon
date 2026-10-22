local H = require("tests.helpers.addon")

-- Combat log unit flags: the player (mine), a party member, a raid member outside the party, a stranger.
local MINE, PARTY, RAID, OUTSIDER = 0x511, 0x512, 0x514, 0x548

local function guid(npc) return "Creature-0-5250-0-14-" .. npc .. "-0000123ABC" end

local function build(R)
  R:Names({ CREATURE = { [2955] = "Plainstrider", [2956] = "Adult Plainstrider" }, MAP = { [1453] = "Stormwind City" } })
  R:Chapter("Grinds")
    :Step()
      :Goto(1453, 50.00, 50.00)
      :Grind(1453, 50.00, 50.00, 40, { npc = { 2955, 2956 }, count = 3 })
    :Step()
      :Goto(1453, 60.00, 60.00)
      :Grind(1453, 60.00, 60.00, 40, { npc = { 2955 }, count = 2 })
    :Done()
  return R
end

local function title(ns)
  for _, wp in pairs(ns.waypoints) do return wp.title end
end

describe("Grind counter", function()
  describe("rules", function()
    local K = H.pure({ "guide/Counter.lua" }).guideCounter

    it("reads the creature id from a creature or vehicle GUID, nothing from a player or pet", function()
      expect(K.npcID(guid(2955))).toBe(2955)
      expect(K.npcID("Vehicle-0-5250-0-14-1234-0000123ABC")).toBe(1234)
      expect(K.npcID("Player-5250-0A1B2C3D")).toBeNil()
      expect(K.npcID("Pet-0-5250-0-14-416-0100123ABC")).toBeNil()
      expect(K.npcID(nil)).toBeNil()
    end)

    it("credits a PARTY_KILL by the player, their pet or their party only", function()
      expect(K.credit("PARTY_KILL", MINE, guid(2955))).toBe(2955)
      expect(K.credit("PARTY_KILL", PARTY, guid(2955))).toBe(2955)
      expect(K.credit("PARTY_KILL", RAID, guid(2955))).toBeNil()
      expect(K.credit("PARTY_KILL", OUTSIDER, guid(2955))).toBeNil()
      expect(K.credit("UNIT_DIED", MINE, guid(2955))).toBeNil()
    end)

    it("counts a grind's targets, or any creature when it names none; never a level grind", function()
      expect(K.counts({ kind = "Grind", npc = { 1, 2 }, count = 5 }, 2)).toBe(true)
      expect(K.counts({ kind = "Grind", npc = { 1, 2 }, count = 5 }, 3)).toBe(false)
      expect(K.counts({ kind = "Grind", count = 5 }, 3)).toBe(true)
      expect(K.counts({ kind = "Grind", npc = { 1 }, level = 8 }, 1)).toBe(false)
      expect(K.counts({ kind = "Kill", count = 5 }, 1)).toBe(false)
    end)

    it("reads the creature from an XP kill line, with or without a bonus, by the client's format", function()
      local EN = "%s dies, you gain %d experience."
      expect(K.xpKillName("Plainstrider dies, you gain 45 experience.", EN)).toBe("Plainstrider")
      expect(K.xpKillName("Adult Plainstrider dies, you gain 60 experience. (+12 group bonus)", EN)).toBe("Adult Plainstrider")
      expect(K.xpKillName("Mr. Smite (Elite) dies, you gain 300 experience. (+150 exp Rested bonus)", EN)).toBe("Mr. Smite (Elite)")
      expect(K.xpKillName("You gain 120 experience.", EN)).toBeNil()
      expect(K.xpKillName("Plainstrider dies, you gain 45 experience.", "You gain %d experience.")).toBeNil()
      expect(K.xpKillName("Kodo stirbt, Ihr bekommt 45 Erfahrung.", "%1$s stirbt, Ihr bekommt %2$d Erfahrung.")).toBe("Kodo")
      expect(K.xpKillName(nil, EN)).toBeNil()
    end)

    it("counts a kill by name when the guide names one of the grind's targets so", function()
      local names = { CREATURE = { [1] = "Plainstrider", [2] = "Adult Plainstrider" } }
      expect(K.countsByName({ kind = "Grind", npc = { 1, 2 }, count = 5 }, "Adult Plainstrider", names)).toBe(true)
      expect(K.countsByName({ kind = "Grind", npc = { 1 }, count = 5 }, "Adult Plainstrider", names)).toBe(false)
      expect(K.countsByName({ kind = "Grind", count = 5 }, "Kodo", names)).toBe(true)
      expect(K.countsByName({ kind = "Grind", npc = { 1 }, count = 5 }, "Plainstrider", nil)).toBe(false)
      expect(K.countsByName({ kind = "Grind", npc = { 1 }, level = 8 }, "Plainstrider", names)).toBe(false)
    end)
  end)

  describe("planner and text", function()
    local ns = H.pure({ "guide/Planner.lua", "guide/Text.lua" })
    local P, T = ns.guidePlanner, ns.guideText
    local grind = { kind = "Grind", npc = { 2955 }, count = 3 }
    local function env(n) return { quest = function() return "none" end, objective = function() end, kills = function() return n end } end
    local step = { groups = { { calls = { grind } } } }

    it("a count grind is open until the count is reached", function()
      expect(P.stepDone(step, env(2))).toBe(false)
      expect(P.stepDone(step, env(3))).toBe(true)
    end)

    it("shows the count as progress", function()
      expect(T.line(grind, { CREATURE = { [2955] = "Plainstrider" } }, env(2))).toBe("Kill Plainstrider (2/3)")
    end)
  end)

  describe("in the player, from the combat log (Classic Era)", function()
    local ctx = H.use({ boot = true, world = function(w) w:classicEra() end })
    local function kill(npc, flags) ctx.world:combatEvent({ subevent = "PARTY_KILL", sourceFlags = flags or MINE, destGUID = guid(npc) }) end
    local function cursor() local _, i = ctx.ns.guidePlayer.current() return i end
    beforeEach(function() build(Ribbon.Guide("g", { schema = 1 })) end)

    it("does not advance on arriving at the grind", function()
      for _, wp in pairs(ctx.ns.waypoints) do ctx.ns:Fire("WAYPOINT_ARRIVED", wp) end
      ctx.ns.guidePlayer.refresh()
      expect(cursor()).toBe(1)
      expect(title(ctx.ns)).toBe("Kill Plainstrider, Adult Plainstrider (0/3)")
    end)

    it("counts credited kills of its targets and advances at the count", function()
      kill(2955)
      kill(2956, PARTY)
      expect(title(ctx.ns)).toBe("Kill Plainstrider, Adult Plainstrider (2/3)")
      kill(9999)                 -- not a target
      kill(2955, OUTSIDER)       -- someone else's kill
      expect(cursor()).toBe(1)
      kill(2955)
      expect(cursor()).toBe(2)
      expect(title(ctx.ns)).toBe("Kill Plainstrider (0/2)")
    end)

    it("keeps the count across a reload", function()
      kill(2955)
      kill(2955)
      local db = RibbonDB
      local ns = H.load({ boot = true, world = function(w) w:classicEra() RibbonDB = db end })
      build(Ribbon.Guide("g", { schema = 1 }))
      local _, i = ns.guidePlayer.current()
      expect(i).toBe(1)
      expect(title(ns)).toBe("Kill Plainstrider, Adult Plainstrider (2/3)")
    end)

    it("keeps a step's count when the player goes back to it, and reset clears it", function()
      kill(2955)
      ctx.ns.guidePlayer.skip()
      ctx.ns.guidePlayer.prev()
      expect(title(ctx.ns)).toBe("Kill Plainstrider, Adult Plainstrider (1/3)")
      ctx.ns.guidePlayer.reset()
      expect(title(ctx.ns)).toBe("Kill Plainstrider, Adult Plainstrider (0/3)")
    end)

    it("reads the event's arguments on a client without CombatLogGetCurrentEventInfo", function()
      _G.CombatLogGetCurrentEventInfo = nil
      ctx.world:fireEvent("COMBAT_LOG_EVENT_UNFILTERED", 0, "PARTY_KILL", false, "Player-1-1", "me", MINE, 0, guid(2955), "Plainstrider", 0, 0)
      expect(title(ctx.ns)).toBe("Kill Plainstrider, Adult Plainstrider (1/3)")
    end)
  end)

  describe("in the player, from the XP chat line (Forever, combat log kept from addons)", function()
    local ctx = H.use({ boot = true })
    local function cursor() local _, i = ctx.ns.guidePlayer.current() return i end
    beforeEach(function() build(Ribbon.Guide("g", { schema = 1 })) end)

    it("never registers the combat log, which the client forbids", function()
      expect(#ctx.world.forbidden).toBe(0)
      expect(#ctx.world:framesWhere(function(o) return o.state.events.COMBAT_LOG_EVENT_UNFILTERED end)).toBe(0)
    end)

    it("counts each XP line naming a target, and advances at the count", function()
      ctx.world:killXP("Plainstrider")
      ctx.world:killXP("Adult Plainstrider", 60, " (+12 group bonus)")
      expect(title(ctx.ns)).toBe("Kill Plainstrider, Adult Plainstrider (2/3)")
      ctx.world:killXP("Kodo")                                          -- not a target
      ctx.world:fireEvent("CHAT_MSG_COMBAT_XP_GAIN", "You gain 120 experience.")   -- quest XP, no kill
      expect(cursor()).toBe(1)
      ctx.world:killXP("Plainstrider")
      expect(cursor()).toBe(2)
      expect(title(ctx.ns)).toBe("Kill Plainstrider (0/2)")
      expect(#ctx.world.errors).toBe(0)
    end)

    it("skips a secret line", function()
      _G.issecretvalue = function() return true end
      ctx.world:killXP("Plainstrider")
      ctx.ns.guidePlayer.refresh()
      expect(title(ctx.ns)).toBe("Kill Plainstrider, Adult Plainstrider (0/3)")
    end)
  end)

  describe("passing a gated grind", function()
    local P = H.pure({ "guide/Planner.lua" }).guidePlanner
    local function grind(gate) return { groups = { { calls = { { kind = "Grind", npc = { 1 }, count = 9, gate = gate } } } } } end
    local function env(level, xp, accepted)
      return { level = level, xp = xp, kills = function() return 0 end, objective = function() end,
        quest = function(id) return id == 7 and accepted and "active" or "none" end }
    end

    it("is done once the gate is met, whatever the next quest step", function()
      expect(P.stepDone(grind({ level = 5, xp = 100 }), env(5, 100, false))).toBe(true)
      expect(P.stepDone(grind({ level = 5, xp = 100 }), env(6, 0, false))).toBe(true)
      expect(P.stepDone(grind({ level = 5, xp = 100 }), env(5, 99, true))).toBe(false)
      expect(P.stepDone(grind({ level = 5 }), env(5, 0, false))).toBe(true)
    end)

    it("is not done by its count alone, which is an estimate", function()
      local e = env(5, 0, false)
      e.kills = function() return 20 end
      expect(P.stepDone(grind({ level = 6 }), e)).toBe(false)
    end)

    it("leaves a grind without a gate to its count", function()
      expect(P.stepDone(grind(nil), env(60, 0, true))).toBe(false)
    end)

    it("writes the count as an estimate", function()
      local T = H.pure({ "guide/Text.lua" }).guideText
      local call = grind({ level = 5 }).groups[1].calls[1]
      local names = { CREATURE = { [1] = "Plainstrider" } }
      expect(T.line(call, names, { kills = function() return 12 end })).toBe("Kill Plainstrider (12/~9)")
      expect(T.line(call, names)).toBe("Kill ~9 Plainstrider")
    end)
  end)

  describe("a gated grind in the player", function()
    local ctx = H.use({ boot = true })
    local function cursor() local _, i = ctx.ns.guidePlayer.current() return i end
    beforeEach(function()
      ctx.world.character.level, ctx.world.character.xp = 2, 50
      local R = Ribbon.Guide("g", { schema = 1 })
      R:Names({ CREATURE = { [2955] = "Plainstrider" } })
      R:Chapter("Gate")
        :Step():Goto(1453, 50.00, 50.00):Grind(1453, 50.00, 50.00, 40, { npc = { 2955 }, count = 9, gate = { level = 2, xp = 100 } })
        :Step():Goto(1453, 52.00, 52.00):Accept(747)
        :Step():Goto(1453, 54.00, 54.00):Turnin(747)
        :Done()
    end)

    it("stays on the grind while the gate is not met, though the next quest is accepted", function()
      ctx.world.quest.log[747] = { complete = false }
      ctx.ns.guidePlayer.refresh()
      expect(cursor()).toBe(1)
    end)

    it("passes the grind as soon as the gate is met, mid-grind", function()
      ctx.world:killXP("Plainstrider")
      expect(cursor()).toBe(1)
      ctx.world.character.xp = 100
      ctx.ns.guidePlayer.refresh()
      expect(cursor()).toBe(2)
    end)

    it("moves past the grind and a done quest step after it once the gate is met", function()
      ctx.world.character.xp = 100
      ctx.world.quest.log[747] = { complete = false }
      ctx.ns.guidePlayer.refresh()
      expect(cursor()).toBe(3)
    end)

    it("shows the kills against the estimated count, past it while the gate is not met", function()
      for _ = 1, 10 do ctx.world:killXP("Plainstrider") end
      expect(cursor()).toBe(1)
      expect(title(ctx.ns)).toBe("Kill Plainstrider (10/~9)")
    end)
  end)

  describe("on a client without the combat log event", function()
    local ctx = H.use({ boot = true, world = function(w) w:classicEra() w.unknownEvents.COMBAT_LOG_EVENT_UNFILTERED = true end })

    it("still runs the guide, the grind waiting for a skip", function()
      build(Ribbon.Guide("g", { schema = 1 }))
      expect(#ctx.world.errors).toBe(0)
      local _, i = ctx.ns.guidePlayer.current()
      expect(i).toBe(1)
    end)
  end)
end)
