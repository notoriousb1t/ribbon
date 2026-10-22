local H = require("tests.helpers.addon")

-- The same addon on the Classic Era client (world:classicEra() in the fakes): what Forever reads through C_QuestLog,
-- C_SuperTrack and the old gossip globals comes from the quest log rows and C_GossipInfo instead.

local function classic(world) world:classicEra() end

describe("Classic Era", function()
  describe("client flavor", function()
    local ctx = H.use({ files = { "core/Client.lua" } })

    it("tells Forever, Classic Era and retail apart, and nil for any other client", function()
      local client = ctx.ns.client
      expect(client.flavor()).toBe("FOREVER")
      _G.WOW_PROJECT_ID = _G.WOW_PROJECT_CLASSIC
      expect(client.flavor()).toBe("CLASSIC")
      _G.WOW_PROJECT_ID = _G.WOW_PROJECT_MAINLINE
      expect(client.flavor()).toBe("RETAIL")
      _G.WOW_PROJECT_ID = 5
      expect(client.flavor()).toBeNil()
      _G.WOW_PROJECT_ID = nil
      expect(client.flavor()).toBeNil()
    end)

    it("is part of the character", function()
      expect(ctx.ns.client.character().flavor).toBe("FOREVER")
    end)
  end)

  describe("client quest log", function()
    local ctx = H.use({ files = { "core/Client.lua" }, world = classic })
    local client
    beforeEach(function() client = ctx.ns.client end)

    it("reports CLASSIC", function()
      expect(client.flavor()).toBe("CLASSIC")
      expect(client.character().flavor).toBe("CLASSIC")
    end)

    it("reads a quest's title through C_QuestLog.GetQuestInfo", function()
      ctx.world.quest.titles[747] = "The Hunt Begins"
      expect(client.questTitle(747)).toBe("The Hunt Begins")
      expect(client.questTitle(748)).toBeNil()
    end)

    it("falls back to the quest log row for the title", function()
      _G.C_QuestLog.GetQuestInfo = nil
      ctx.world.quest.titles[747] = "The Hunt Begins"
      ctx.world.quest.log[747] = { complete = false }
      expect(client.questTitle(747)).toBe("The Hunt Begins")
      expect(client.questTitle(748)).toBeNil()
    end)

    it("reads a quest's status from the quest log rows", function()
      expect(client.questStatus(747)).toBe("none")
      ctx.world.quest.log[747] = { complete = false }
      ctx.world.quest.log[750] = { complete = true }
      expect(client.questStatus(747)).toBe("active")
      expect(client.questStatus(750)).toBe("complete")
      ctx.world.quest.log[747] = nil
      ctx.world.quest.done[747] = true
      expect(client.questStatus(747)).toBe("done")
    end)

    it("takes the first watched quest as the tracked one", function()
      expect(client.superTrackedQuestID()).toBeNil()
      ctx.world.quest.log[747] = { complete = false }
      ctx.world.quest.log[750] = { complete = false }
      ctx.world.quest.watched = { 750, 747 }
      expect(client.superTrackedQuestID()).toBe(750)
    end)

    it("finds a finished quest log entry by title", function()
      ctx.world.quest.titles[747] = "The Hunt Begins"
      ctx.world.quest.titles[750] = "The Hunt Continues"
      ctx.world.quest.log[747] = { complete = false }
      ctx.world.quest.log[750] = { complete = true }
      expect(client.questLogEntryComplete("The Hunt Continues")).toBe(true)
      expect(client.questLogEntryComplete("The Hunt Begins")).toBe(false)
      expect(client.questLogEntryComplete("Nope")).toBe(false)
    end)

    it("lists gossip quests from C_GossipInfo and picks them by questID", function()
      ctx.world.gossip.active = { { title = "A", questID = 11, isComplete = false }, { title = "B", questID = 12, isComplete = true } }
      ctx.world.gossip.available = { { title = "C", questID = 13 } }
      local q = client.gossipQuests()
      expect(q.active[2]).toEqual({ index = 2, title = "B", complete = true, questID = 12 })
      expect(q.available[1].questID).toBe(13)
      client.selectGossipQuest("active", q.active[2])
      client.selectGossipQuest("available", q.available[1])
      expect(ctx.world.gossipPicked).toEqual({ { "active", 12 }, { "available", 13 } })
    end)

    it("lists nothing when C_GossipInfo is missing or fails", function()
      _G.C_GossipInfo = nil
      expect(client.gossipQuests()).toEqual({ active = {}, available = {} })
      _G.C_GossipInfo = { GetActiveQuests = function() error("boom") end }
      expect(client.gossipQuests()).toEqual({ active = {}, available = {} })
    end)
  end)

  describe("guide", function()
    local ctx = H.use({ boot = true, world = classic })

    local function start()
      Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
        :Step():Goto(1453, 50, 50):Accept(747)
        :Step():Goto(1453, 52, 52):Accept(750)
        :Done()
    end

    it("advances when the quest log shows the quest", function()
      start()
      ctx.world.quest.log[747] = { complete = false }
      ctx.ns.guidePlayer.refresh()
      local _, cursor = ctx.ns.guidePlayer.current()
      expect(cursor).toBe(2)
    end)

    it("answers a gossip window: a finished quest first, then an offered one", function()
      start()
      _G.IsShiftKeyDown = function() return false end
      ctx.world.gossip.active = { { title = "A", questID = 11, isComplete = false }, { title = "B", questID = 12, isComplete = true } }
      ctx.world.gossip.available = { { title = "C", questID = 13 } }
      ctx.ns.guideSettings.handle("GOSSIP_SHOW")
      expect(ctx.world.gossipPicked).toEqual({ { "active", 12 } })
      ctx.world.gossip.active = {}
      ctx.ns.guideSettings.handle("GOSSIP_SHOW")
      expect(ctx.world.gossipPicked[2]).toEqual({ "available", 13 })
    end)

    it("leaves the in-world marker out of the settings menu", function()
      start()
      expect(ctx.ns.worldPin.supported()).toBe(false)
      local keys = {}
      for _, o in ipairs(ctx.ns.guideSettings.available()) do keys[#keys + 1] = o.key end
      expect(keys).toEqual({ "autoAdvance", "autoQuest", "spawnDots" })
      ctx.ns.guideBrowser.toggleDock()
      expect(#ctx.ns.guideBrowser.dock().menu.rows).toBe(3)
    end)
  end)

  describe("flavor locks", function()
    local ctx = H.use({ boot = true })

    local function build()
      local R = Ribbon.Guide("g", { title = "Test Guide", schema = 1 })
      R:Chapter("Start", { flavor = "FOREVER" }):Step():Goto(1453, 50, 50):Accept(1):Done()
      R:Chapter("Start", { flavor = "CLASSIC" }):Step():Goto(1453, 51, 51):Accept(2):Done()
      R:Chapter("Shared"):Step():Goto(1453, 52, 52):Accept(3)
        :Step():Only{ flavor = "CLASSIC" }:Goto(1453, 53, 53):Accept(4)
        :Done()
      return R
    end

    it("keeps same-named chapters of two flavors apart", function()
      expect(#build().chapters).toBe(3)
    end)

    it("shows each client its own flavor's chapters and steps, and unlocked ones to all", function()
      local guide = build()
      local P = ctx.ns.guidePlanner
      local function seen(flavor)
        local out = {}
        for _, s in ipairs(P.flatten(P.view(guide, { flavor = flavor }))) do out[#out + 1] = s.chapter .. ":" .. s.index end
        return out
      end
      expect(seen("FOREVER")).toEqual({ "1:1", "3:1" })
      expect(seen("CLASSIC")).toEqual({ "2:1", "3:1", "3:2" })
      expect(seen(nil)).toEqual({ "3:1" })
    end)
  end)

  describe("on Forever", function()
    local ctx = H.use({ boot = true })

    it("keeps the in-world marker when the client has user waypoints", function()
      _G.C_Map.SetUserWaypoint = function() end
      _G.C_Map.ClearUserWaypoint = function() end
      expect(#ctx.ns.guideSettings.available()).toBe(4)
    end)

    it("still picks gossip quests through the old globals, by index", function()
      local picked = {}
      _G.GetNumGossipActiveQuests = function() return 1 end
      _G.GetGossipActiveQuests = function() return "A", 5, false, true end
      _G.GetNumGossipAvailableQuests = function() return 0 end
      _G.SelectGossipActiveQuest = function(i) picked[#picked + 1] = i end
      _G.C_GossipInfo = { SelectActiveQuest = function() error("must not be used") end }
      local q = ctx.ns.client.gossipQuests()
      expect(q.active[1].questID).toBeNil()
      ctx.ns.client.selectGossipQuest("active", q.active[1])
      expect(picked).toEqual({ 1 })
    end)
  end)
end)
