local H = require("tests.helpers.addon")

describe("Quest translation", function()
  local T = H.pure({ "integrations/QuestTranslate.lua" }).questTranslate

  describe("pickPoint", function()
    local points = {
      { questID = 1, x = 0.5, y = 0.25 },
      { questID = 2, x = 0.1, y = 0.2, isQuestStart = true },
    }

    it("returns the quest point as 0-100 coordinates", function()
      expect(T.pickPoint(points, 1)).toEqual({ x = 50, y = 25, isQuestStart = false })
    end)

    it("carries the quest-start flag", function()
      expect(T.pickPoint(points, 2).isQuestStart).toBe(true)
    end)

    it("returns nil when the quest is not listed or the list is missing", function()
      expect(T.pickPoint(points, 99)).toBeNil()
      expect(T.pickPoint(nil, 1)).toBeNil()
      expect(T.pickPoint({ { questID = 1 } }, 1)).toBeNil()
    end)
  end)

  describe("iconFor", function()
    local point = { isQuestStart = false }

    it("is accept for a quest to pick up", function()
      expect(T.iconFor({ isQuestStart = true }, {})).toBe("accept")
    end)

    it("is turnin when every objective is finished", function()
      expect(T.iconFor(point, { { finished = true, type = "log" } })).toBe("turnin")
    end)

    it("follows the first unfinished objective", function()
      expect(T.iconFor(point, { { finished = true, type = "item" }, { finished = false, type = "monster" } })).toBe("kill")
      expect(T.iconFor(point, { { finished = false, type = "item" } })).toBe("loot")
      expect(T.iconFor(point, { { finished = false, type = "object" } })).toBe("turnin")
      expect(T.iconFor(point, { { finished = false, type = "log" } })).toBe("turnin")
    end)

    it("uses the turn-in icon without objectives, never the treasure map", function()
      expect(T.iconFor(point, {})).toBe("turnin")
      expect(T.iconFor(point, nil)).toBe("turnin")
    end)
  end)

  it("builds a key that changes with the quest, place and icon", function()
    local a = T.key(1, 1453, 50, 25, "kill")
    expect(a).toBe("1:1453:50.00:25.00:kill")
    expect(T.key(1, 1453, 50, 25, "turnin")).never.toBe(a)
    expect(T.key(2, 1453, 50, 25, "kill")).never.toBe(a)
  end)
end)
