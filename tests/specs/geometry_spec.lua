local H = require("tests.helpers.addon")

describe("Geometry", function()
  local geo = H.pure({ "core/Geometry.lua" }).geometry
  local PI = math.pi

  describe("wrap", function()
    it("leaves angles inside [-pi, pi] alone", function()
      expect(geo.wrap(1)).toBe(1)
      expect(geo.wrap(-3)).toBe(-3)
    end)

    it("wraps larger angles back into range", function()
      expect(geo.wrap(PI + 0.5)).toBeCloseTo(-PI + 0.5, 6)
      expect(geo.wrap(-PI - 0.5)).toBeCloseTo(PI - 0.5, 6)
      expect(geo.wrap(5 * PI)).toBeCloseTo(PI, 6)
    end)
  end)

  describe("wrapDeg", function()
    it("wraps degrees into [-180, 180]", function()
      expect(geo.wrapDeg(190)).toBe(-170)
      expect(geo.wrapDeg(-190)).toBe(170)
      expect(geo.wrapDeg(720)).toBe(0)
    end)
  end)

  describe("heading", function()
    it("is zero when facing north", function()
      expect(geo.heading(0)).toBe(0)
    end)

    it("turns clockwise as facing grows counter-clockwise", function()
      -- Facing a quarter turn left (west) is heading 270 = -90.
      expect(geo.heading(PI / 2)).toBeCloseTo(-90, 6)
      -- Measured on the beta client: facing 4.8129 -> 6.2266 after a quarter turn left.
      expect(geo.heading(6.2266173362732)).toBeCloseTo(geo.wrapDeg(-math.deg(6.2266173362732)), 6)
    end)
  end)

  describe("bearing", function()
    it("is zero delta for a target straight ahead (north)", function()
      local dist, delta = geo.bearing(0, 0, 100, 0, 0)
      expect(dist).toBeCloseTo(100, 6)
      expect(delta).toBeCloseTo(0, 6)
    end)

    it("puts a target to the west on the left (positive) when facing north", function()
      local _, delta = geo.bearing(0, 0, 0, 100, 0)
      expect(delta).toBeCloseTo(PI / 2, 6)
    end)

    it("puts a target to the east on the right (negative) when facing north", function()
      local _, delta = geo.bearing(0, 0, 0, -100, 0)
      expect(delta).toBeCloseTo(-PI / 2, 6)
    end)

    it("measures the target relative to facing", function()
      -- Facing west, a target to the west is straight ahead.
      local _, delta = geo.bearing(0, 0, 0, 100, PI / 2)
      expect(delta).toBeCloseTo(0, 6)
      -- Facing south, a target to the north is behind: |delta| = pi.
      local _, behind = geo.bearing(0, 0, 100, 0, PI)
      expect(math.abs(behind)).toBeCloseTo(PI, 6)
    end)

    it("returns distance only when facing is unknown", function()
      local dist, delta = geo.bearing(0, 0, 3, 4, nil)
      expect(dist).toBe(5)
      expect(delta).toBeNil()
    end)
  end)

  describe("markerOffset", function()
    local fov = math.rad(140)

    it("centres a target straight ahead", function()
      local x, edge = geo.markerOffset(0, fov, 600)
      expect(x).toBe(0)
      expect(edge).toBe(false)
    end)

    it("draws a target on the left to the left of centre", function()
      local x = geo.markerOffset(math.rad(35), fov, 600)
      expect(x).toBeCloseTo(-150, 6)
    end)

    it("draws a target on the right to the right of centre", function()
      local x = geo.markerOffset(math.rad(-35), fov, 600)
      expect(x).toBeCloseTo(150, 6)
    end)

    it("clamps targets outside the field of view to the edge", function()
      local left, leftEdge = geo.markerOffset(math.rad(120), fov, 600)
      local right, rightEdge = geo.markerOffset(math.rad(-120), fov, 600)
      expect(left).toBe(-300)
      expect(right).toBe(300)
      expect(leftEdge).toBe(true)
      expect(rightEdge).toBe(true)
    end)
  end)

  describe("clamp", function()
    it("limits a value to a range", function()
      expect(geo.clamp(5, 1, 10)).toBe(5)
      expect(geo.clamp(0, 1, 10)).toBe(1)
      expect(geo.clamp(99, 1, 10)).toBe(10)
    end)
  end)
end)
