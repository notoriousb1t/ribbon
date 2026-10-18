local H = require("tests.helpers.addon")

describe("Client adapter: quest tracking", function()
  local ctx = H.use({ files = { "core/Client.lua" } })
  local client

  beforeEach(function() client = ctx.ns.client end)

  describe("superTrackedQuestID", function()
    it("returns the tracked quest", function()
      ctx.world.quest.tracked = 1338
      expect(client.superTrackedQuestID()).toBe(1338)
    end)

    it("returns nil for no quest (0) and for a missing API", function()
      ctx.world.quest.tracked = 0
      expect(client.superTrackedQuestID()).toBeNil()
      _G.C_SuperTrack = nil
      expect(client.superTrackedQuestID()).toBeNil()
    end)

    it("returns nil when the API errors", function()
      _G.C_SuperTrack = { GetSuperTrackedQuestID = function() error("boom") end }
      expect(client.superTrackedQuestID()).toBeNil()
    end)
  end)

  describe("questTitle", function()
    it("returns the title, or nil when unknown or empty", function()
      ctx.world.quest.titles[1] = "Wolves"
      ctx.world.quest.titles[2] = ""
      expect(client.questTitle(1)).toBe("Wolves")
      expect(client.questTitle(2)).toBeNil()
      expect(client.questTitle(3)).toBeNil()
    end)
  end)

  describe("questPoints", function()
    it("returns the quest points on a map", function()
      ctx.world.quest.points[1453] = { { questID = 1, x = 0.5, y = 0.5 } }
      expect(client.questPoints(1453)[1].questID).toBe(1)
    end)

    it("returns an empty list for a missing API or an error", function()
      _G.C_QuestLog = nil
      expect(client.questPoints(1453)).toEqual({})
      _G.C_QuestLog = { GetQuestsOnMap = function() error("boom") end }
      expect(client.questPoints(1453)).toEqual({})
    end)
  end)

  describe("questObjectives", function()
    it("returns the objectives, or an empty list", function()
      ctx.world.quest.objectives[1] = { { finished = true } }
      expect(client.questObjectives(1)[1].finished).toBe(true)
      expect(client.questObjectives(2)).toEqual({})
    end)
  end)
end)
