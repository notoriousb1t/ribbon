local H = require("tests.helpers.addon")

describe("Guide rows", function()
  local R = H.pure({ "guide/Rows.lua" }).guideRows

  describe("distanceText", function()
    it("shows yards, 'here' on arrival, and a dash without a distance", function()
      expect(R.distanceText({ dist = 42.9 })).toBe("42 yd")
      expect(R.distanceText({ dist = 1, arrived = true })).toBe("here")
      expect(R.distanceText({})).toBe("--")
    end)
  end)

  describe("build", function()
    local list = {
      { uid = 1, icon = "accept", title = "A", dist = 10 },
      { uid = 2, icon = "kill", title = "B", dist = 20 },
      { uid = 3, icon = "loot", title = "C", dist = 30 },
    }

    it("creates one row per waypoint, nearest first", function()
      local rows = R.build(list, 6)
      expect(#rows).toBe(3)
      expect(rows[1]).toEqual({ uid = 1, icon = "accept", title = "A", distance = "10 yd", focused = false })
    end)

    it("limits the rows", function()
      expect(#R.build(list, 2)).toBe(2)
    end)

    it("marks the focused waypoint", function()
      local rows = R.build(list, 6, 2)
      expect(rows[2].focused).toBe(true)
      expect(rows[1].focused).toBe(false)
    end)
  end)

  describe("shouldShow", function()
    it("shows when enabled and there is a waypoint or a header", function()
      expect(R.shouldShow(true, 1, nil)).toBe(true)
      expect(R.shouldShow(true, 0, "Intro")).toBe(true)
    end)

    it("hides when disabled or empty", function()
      expect(R.shouldShow(false, 3, "Intro")).toBe(false)
      expect(R.shouldShow(true, 0, nil)).toBe(false)
    end)
  end)
end)
