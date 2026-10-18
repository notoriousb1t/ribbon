local H = require("tests.helpers.addon")

local YD_PER_Y = 11.5834

describe("Focus", function()
  describe("layout", function()
    local ns = H.pure({ "core/Geometry.lua", "compass/Layout.lua" })
    local L = ns.compassLayout

    local function wp(uid)
      return { uid = uid, delta = 0, compass = true, dist = 10 * uid, title = "w" .. uid }
    end

    it("flags only the focused placement", function()
      local placements = L.markers({ wp(1), wp(2), wp(3) }, 140, 600, 20, 2)
      expect(placements[1].focused).toBe(false)
      expect(placements[2].focused).toBe(true)
      expect(placements[3].focused).toBe(false)
    end)

    it("flags nothing without a focus", function()
      local placements = L.markers({ wp(1), wp(2) }, 140, 600)
      expect(placements[1].focused).toBe(false)
    end)

    it("draws the focused waypoint even beyond the marker limit", function()
      local list = {}
      for i = 1, 30 do list[i] = wp(i) end
      local placements, label = L.markers(list, 140, 600, 5, 28)
      expect(#placements).toBe(6)
      expect(placements[6].wp.uid).toBe(28)
      expect(placements[6].focused).toBe(true)
      expect(label.uid).toBe(28)
    end)

    it("ignores a focus that cannot be drawn", function()
      local hidden = wp(2)
      hidden.delta = nil
      local _, label = L.markers({ wp(1), hidden }, 140, 600, 20, 2)
      expect(label.uid).toBe(1)
    end)
  end)

  describe("compass view", function()
    local ctx = H.use({ boot = true })
    local parts, near, far

    local function frameTick() ctx.world:update(0.04) end
    local function lastCaption()
      local calls = parts.targetText.SetText.calls
      return calls[#calls][1]
    end
    local function lastSize(marker)
      local calls = marker.SetSize.calls
      return calls[#calls]
    end

    beforeEach(function()
      ctx.world:placePlayer(1453, 61.99, 70.58, 0)
      parts = ctx.ns.compass.parts
      near = ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 20 / YD_PER_Y, { title = "Near" })
      far = ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 90 / YD_PER_Y, { title = "Far" })
      frameTick()
    end)

    it("captions the nearest waypoint until one is focused", function()
      expect(lastCaption()).toBe("Near - 20 yd")
    end)

    it("registers left and right clicks on the markers", function()
      expect(parts.markers[1].RegisterForClicks).toHaveBeenCalledWith("LeftButtonUp", "RightButtonUp")
    end)

    it("focuses a marker on left-click and shows its name under the bar", function()
      -- markers are drawn nearest first, so the second one is Far
      parts.markers[2]:Trigger("OnClick", "LeftButton")
      expect(ctx.ns.focus).toBe(far)
      frameTick()
      expect(lastCaption()).toBe("Far - 90 yd")
    end)

    it("makes the focused marker larger", function()
      parts.markers[2]:Trigger("OnClick", "LeftButton")
      frameTick()
      local L, cfg = ctx.ns.compassLayout, ctx.ns.compassStyle.marker
      local farSize = L.markerSize(ctx.ns:GetWaypoint(far).dist, true, cfg)
      local nearSize = L.markerSize(ctx.ns:GetWaypoint(near).dist, false, cfg)
      expect(lastSize(parts.markers[2])).toEqual({ n = 2, farSize, farSize })
      expect(lastSize(parts.markers[1])).toEqual({ n = 2, nearSize, nearSize })
      -- the focus adds the boost to what the distance alone would give
      expect(farSize).toBe(L.markerSize(ctx.ns:GetWaypoint(far).dist, false, cfg) + cfg.focusBoost)
    end)

    it("draws the focused marker above the others", function()
      parts.markers[2]:Trigger("OnClick", "LeftButton")
      frameTick()
      local function level(m) local c = m.SetFrameLevel.calls return c[#c][1] end
      expect(level(parts.markers[2])).toBeGreaterThan(level(parts.markers[1]))
    end)

    it("goes back to the nearest when the focused marker is clicked again", function()
      parts.markers[2]:Trigger("OnClick", "LeftButton")
      parts.markers[2]:Trigger("OnClick", "LeftButton")
      expect(ctx.ns.focus).toBeNil()
      frameTick()
      expect(lastCaption()).toBe("Near - 20 yd")
    end)

    it("moves focus to another marker when it is clicked", function()
      parts.markers[2]:Trigger("OnClick", "LeftButton")
      parts.markers[1]:Trigger("OnClick", "LeftButton")
      expect(ctx.ns.focus).toBe(near)
    end)

    it("does not hide the waypoint on a left-click", function()
      parts.markers[1]:Trigger("OnClick", "LeftButton")
      expect(ctx.ns:GetWaypoint(near).visible).toBe(true)
    end)

    it("still hides the waypoint on right-click", function()
      parts.markers[1]:Trigger("OnClick", "RightButton")
      expect(ctx.ns:GetWaypoint(near).visible).toBe(false)
    end)

    it("clears the focus when the focused waypoint is hidden", function()
      parts.markers[2]:Trigger("OnClick", "LeftButton")
      parts.markers[2]:Trigger("OnClick", "RightButton")
      expect(ctx.ns.focus).toBeNil()
      frameTick()
      expect(lastCaption()).toBe("Near - 20 yd")
    end)

    it("mentions focusing in the tooltip", function()
      parts.markers[1]:Trigger("OnEnter")
      expect(GameTooltip.AddLine).toHaveBeenCalledWith("Click to focus, right-click to hide", 0.5, 0.5, 0.5)
    end)
  end)
end)
