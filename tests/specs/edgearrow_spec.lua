local H = require("tests.helpers.addon")

local YD_PER_X, YD_PER_Y = 17.375, 11.5834

describe("Off-screen markers and arrows", function()
  describe("geometry markerOffset", function()
    local geo = H.pure({ "core/Geometry.lua" }).geometry
    local fov = math.rad(140)

    it("holds a marker `inset` pixels inside the bar's end", function()
      local x, edge = geo.markerOffset(math.rad(120), fov, 600, 40)
      expect(x).toBe(-260)
      expect(edge).toBe(true)
      local right = geo.markerOffset(math.rad(-120), fov, 600, 40)
      expect(right).toBe(260)
    end)

    it("reports which side an off-screen marker is on", function()
      local _, _, left = geo.markerOffset(math.rad(100), fov, 600)
      local _, _, right = geo.markerOffset(math.rad(-100), fov, 600)
      expect(left).toBe("left")
      expect(right).toBe("right")
    end)

    it("reports no side inside the field of view", function()
      local _, edge, side = geo.markerOffset(math.rad(30), fov, 600, 40)
      expect(edge).toBe(false)
      expect(side).toBeNil()
    end)

    it("also keeps in-view markers inside the inset so nothing crosses an off-screen one", function()
      -- 69 degrees is inside +/-70 but its offset (295.7) is beyond the 260 limit
      local x, edge = geo.markerOffset(math.rad(-69), fov, 600, 40)
      expect(x).toBe(260)
      expect(edge).toBe(false)
    end)

    it("is unchanged without an inset", function()
      expect(geo.markerOffset(math.rad(35), fov, 600)).toBeCloseTo(-150, 6)
      expect(geo.markerOffset(math.rad(120), fov, 600)).toBe(-300)
    end)
  end)

  describe("layout", function()
    local ns = H.pure({ "core/Geometry.lua", "compass/Layout.lua", "compass/Style.lua" })
    local L, cfg = ns.compassLayout, ns.compassStyle.marker

    local function wp(uid, delta, dist)
      return { uid = uid, delta = delta, compass = true, dist = dist or 100, title = "w" .. uid }
    end

    it("insets by half the marker, the padding and the arrow", function()
      local placements = L.markers({ wp(1, math.rad(120)) }, 140, 600, 20, nil, cfg)
      local size = placements[1].size
      expect(placements[1].x).toBeCloseTo(-(300 - (size / 2 + cfg.pad + cfg.arrow + 1)), 6)
    end)

    it("gives a larger marker a larger inset", function()
      local near = L.markers({ wp(1, math.rad(120), 5) }, 140, 600, 20, nil, cfg)[1]
      local far = L.markers({ wp(1, math.rad(120), 1000) }, 140, 600, 20, nil, cfg)[1]
      expect(math.abs(near.x)).toBeLessThan(math.abs(far.x))
    end)

    it("marks the side of each off-screen placement", function()
      local placements = L.markers({ wp(1, math.rad(100)), wp(2, math.rad(-100)), wp(3, 0) }, 140, 600, 20, nil, cfg)
      expect(placements[1].side).toBe("left")
      expect(placements[2].side).toBe("right")
      expect(placements[3].side).toBeNil()
    end)

    it("does not inset without a configuration", function()
      local placements = L.markers({ wp(1, math.rad(120)) }, 140, 600)
      expect(placements[1].x).toBe(-300)
    end)
  end)

  describe("style", function()
    local S = H.pure({ "compass/Style.lua" }).compassStyle

    it("keeps far markers at least 18 px", function()
      expect(S.marker.min).toBeGreaterThan(17)
    end)

    it("has an edge arrow texture", function()
      expect(S.textures.edgeArrow).toBe("Interface\\AddOns\\Ribbon\\textures\\edge-arrow")
      local f = io.open("src/textures/edge-arrow.tga", "rb")
      expect(f).toBeTruthy()
      f:close()
    end)

    it("makes the edge markers fainter than the in-view ones but still clearly visible", function()
      expect(S.marker.edgeAlpha).toBeGreaterThan(0.5)
      expect(S.marker.edgeAlpha).toBeLessThan(1)
    end)
  end)

  describe("compass view", function()
    local ctx = H.use({ boot = true })
    local parts

    local function frameTick() ctx.world:update(0.04) end
    local function lastPoint(frame)
      local c = frame.SetPoint.calls[#frame.SetPoint.calls]
      return { unpack(c, 1, c.n) }
    end

    beforeEach(function()
      ctx.world:placePlayer(1453, 61.99, 95, 0)   -- facing north
      parts = ctx.ns.compass.parts
    end)

    it("shows no arrow for a waypoint in view", function()
      ctx.ns:AddWaypoint(1453, 61.99, 95 - 100 / YD_PER_Y, { title = "Ahead" })
      frameTick()
      expect(parts.markers[1].arrow:IsShown()).toBe(false)
    end)

    it("shows a left-pointing arrow on the outer side of a waypoint to the left", function()
      ctx.ns:AddWaypoint(1453, 61.99 - 300 / YD_PER_X, 95 - 10 / YD_PER_Y, { title = "West" })   -- due west
      frameTick()
      local m = parts.markers[1]
      expect(m.arrow:IsShown()).toBe(true)
      expect(m.arrow.SetTexCoord).toHaveBeenCalledWith(1, 0, 0, 1)   -- flipped: points left
      expect(lastPoint(m.arrow)).toEqual({ "RIGHT", m, "LEFT", -1, 0 })
      expect(lastPoint(m)[4]).toBeLessThan(0)
    end)

    it("shows a right-pointing arrow on the outer side of a waypoint to the right", function()
      ctx.ns:AddWaypoint(1453, 61.99 + 300 / YD_PER_X, 95 - 10 / YD_PER_Y, { title = "East" })   -- due east
      frameTick()
      local m = parts.markers[1]
      expect(m.arrow:IsShown()).toBe(true)
      expect(m.arrow.SetTexCoord).toHaveBeenCalledWith(0, 1, 0, 1)
      expect(lastPoint(m.arrow)).toEqual({ "LEFT", m, "RIGHT", 1, 0 })
      expect(lastPoint(m)[4]).toBeGreaterThan(0)
    end)

    it("uses the arrow texture and size from the style", function()
      ctx.ns:AddWaypoint(1453, 61.99 - 300 / YD_PER_X, 95, { title = "West" })
      frameTick()
      local m = parts.markers[1]
      local S = ctx.ns.compassStyle
      expect(m.arrow.SetTexture).toHaveBeenCalledWith(S.textures.edgeArrow)
      expect(m.arrow.SetSize).toHaveBeenCalledWith(S.marker.arrow, S.marker.arrow)
    end)

    it("keeps the marker and its arrow inside the bar", function()
      ctx.ns:AddWaypoint(1453, 61.99 - 300 / YD_PER_X, 95, { title = "West" })
      frameTick()
      local m = parts.markers[1]
      local c = ctx.ns.compassStyle.marker
      local size = m.SetSize.calls[#m.SetSize.calls][1]
      local x = lastPoint(m)[4]
      expect(x - size / 2 - c.arrow - 1 >= -300).toBe(true)   -- the arrow's far edge is within the bar
    end)

    it("fades an off-screen marker to the edge opacity", function()
      ctx.ns:AddWaypoint(1453, 61.99 - 300 / YD_PER_X, 95, { title = "West" })
      frameTick()
      expect(parts.markers[1].SetAlpha).toHaveBeenCalledWith(ctx.ns.compassStyle.marker.edgeAlpha)
    end)

    it("hides the arrow again when the player turns toward the waypoint", function()
      ctx.ns:AddWaypoint(1453, 61.99 - 300 / YD_PER_X, 95 - 10 / YD_PER_Y, { title = "West" })
      frameTick()
      expect(parts.markers[1].arrow:IsShown()).toBe(true)
      ctx.world.player.facing = math.pi / 2   -- now facing west
      frameTick()
      expect(parts.markers[1].arrow:IsShown()).toBe(false)
    end)

    it("keeps far markers readable: even a far waypoint is at least 18 px", function()
      ctx.ns:AddWaypoint(1453, 61.99, 95 - 1000 / YD_PER_Y, { title = "Far" })
      frameTick()
      local m = parts.markers[1]
      expect(m.SetSize.calls[#m.SetSize.calls][1]).toBeGreaterThan(17)
    end)
  end)
end)
