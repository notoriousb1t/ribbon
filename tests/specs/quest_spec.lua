local H = require("tests.helpers.addon")

local STORMWIND = 1453

-- The tracked quest: a turn-in in the Dwarven District, like the one measured on the beta client.
local function track(world, opts)
  opts = opts or {}
  local q = world.quest
  q.tracked = opts.id or 1338
  q.titles[q.tracked] = opts.title or "Stormpike's Order"
  q.points[STORMWIND] = { {
    questID = q.tracked, x = opts.x or 0.646, y = opts.y or 0.372, isQuestStart = opts.isQuestStart,
  } }
  q.objectives[q.tracked] = opts.objectives or { { finished = true, type = "log" } }
end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

describe("Quest bridge", function()
  local ctx = H.use({ boot = true })

  -- One bridge tick: the registry measures the distance, then the bridge refreshes.
  local function tick() ctx.world:update(0.3) end

  describe("tracked quest on the compass", function()
    it("adds nothing when no quest is tracked", function()
      tick()
      expect(count(ctx.ns.waypoints)).toBe(0)
    end)

    it("mirrors the tracked quest with its title and map point, compass only", function()
      track(ctx.world)
      tick()
      local wp = ctx.ns:GetWaypoint(1)
      expect(wp.title).toBe("Stormpike's Order")
      expect(wp.mapID).toBe(STORMWIND)
      expect(wp.x).toBeCloseTo(64.6, 4)
      expect(wp.y).toBeCloseTo(37.2, 4)
      expect(wp.compass).toBe(true)
      expect(wp.minimap).toBe(false)
      expect(wp.worldmap).toBe(false)
    end)

    it("picks the icon from the quest's state", function()
      track(ctx.world, { objectives = { { finished = true, type = "log" } } })
      tick()
      expect(ctx.ns:GetWaypoint(1).icon).toBe("turnin")
    end)

    it("uses the kill icon for an unfinished monster objective", function()
      track(ctx.world, { objectives = { { finished = false, type = "monster" } } })
      tick()
      expect(ctx.ns:GetWaypoint(1).icon).toBe("kill")
    end)

    it("uses the accept icon for a quest to pick up", function()
      track(ctx.world, { isQuestStart = true, objectives = {} })
      tick()
      expect(ctx.ns:GetWaypoint(1).icon).toBe("accept")
    end)

    it("falls back to a generic title", function()
      track(ctx.world)
      ctx.world.quest.titles[1338] = nil
      tick()
      expect(ctx.ns:GetWaypoint(1).title).toBe("Quest 1338")
    end)

    it("does not duplicate the waypoint on later refreshes", function()
      track(ctx.world)
      tick()
      tick()
      tick()
      expect(count(ctx.ns.waypoints)).toBe(1)
    end)

    it("removes the waypoint when the quest is no longer tracked", function()
      track(ctx.world)
      tick()
      ctx.world.quest.tracked = 0
      tick()
      expect(count(ctx.ns.waypoints)).toBe(0)
    end)

    it("replaces the waypoint when a different quest is tracked", function()
      track(ctx.world)
      tick()
      track(ctx.world, { id = 77, title = "Other Quest", x = 0.3, y = 0.3 })
      tick()
      expect(count(ctx.ns.waypoints)).toBe(1)
      expect(ctx.ns:GetWaypoint(2).title).toBe("Other Quest")
    end)

    it("replaces the waypoint when the quest's state changes the icon", function()
      track(ctx.world, { objectives = { { finished = false, type = "monster" } } })
      tick()
      ctx.world.quest.objectives[1338] = { { finished = true, type = "monster" } }
      tick()
      expect(count(ctx.ns.waypoints)).toBe(1)
      expect(ctx.ns:GetWaypoint(2).icon).toBe("turnin")
    end)

    it("shows nothing when the quest point is not on the current map", function()
      track(ctx.world)
      ctx.world.quest.points[STORMWIND] = {}
      tick()
      expect(count(ctx.ns.waypoints)).toBe(0)
    end)

    it("leaves other waypoints alone", function()
      local own = ctx.ns:AddWaypoint(STORMWIND, 10, 10, { title = "Mine" })
      track(ctx.world)
      tick()
      ctx.world.quest.tracked = 0
      tick()
      expect(ctx.ns:GetWaypoint(own)).toBeTruthy()
    end)
  end)

  describe("events", function()
    it("reacts to a tracking change at once, without waiting for the ticker", function()
      track(ctx.world)
      ctx.world:fireEvent("SUPER_TRACKING_CHANGED")
      expect(ctx.ns:GetWaypoint(1)).toBeTruthy()
    end)

    it("reports an error in a refresh instead of throwing into the game", function()
      spyOn(ctx.ns.questBridge, "refresh"):andCall(function() error("refresh failed") end)
      expect(function() ctx.world:fireEvent("QUEST_LOG_UPDATE") end).never.toThrow()
      expect(ctx.world.errors[1]).toMatch("refresh failed")
    end)
  end)
end)

describe("Quest bridge on a client without the quest events", function()
  local ctx = H.use({
    boot = true,
    world = function(w)
      w.unknownEvents = {
        SUPER_TRACKING_CHANGED = true, QUEST_POI_UPDATE = true,
        QUEST_LOG_UPDATE = true, ZONE_CHANGED_NEW_AREA = true,
      }
    end,
  })

  it("still works from the ticker", function()
    track(ctx.world)
    ctx.world:update(0.3)
    expect(ctx.ns:GetWaypoint(1).title).toBe("Stormpike's Order")
  end)
end)
