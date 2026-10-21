local H = require("tests.helpers.addon")

local YD_PER_Y = 11.5834
local TRACK_HEIGHT = 28

describe("Marker size by distance", function()
  local ns = H.pure({ "core/Geometry.lua", "compass/Layout.lua", "compass/Style.lua" })
  local L = ns.compassLayout
  local cfg = ns.compassStyle.marker

  describe("markerSize", function()
    it("is the maximum at the near distance and closer", function()
      expect(L.markerSize(cfg.nearYd, false, cfg)).toBe(cfg.max)
      expect(L.markerSize(5, false, cfg)).toBe(cfg.max)
      expect(L.markerSize(0, false, cfg)).toBe(cfg.max)
    end)

    it("is the minimum at the far distance and beyond", function()
      expect(L.markerSize(cfg.farYd, false, cfg)).toBe(cfg.min)
      expect(L.markerSize(5000, false, cfg)).toBe(cfg.min)
    end)

    it("makes a very close marker taller than the ribbon and a far one smaller than the default", function()
      expect(L.markerSize(10, false, cfg)).toBeGreaterThan(TRACK_HEIGHT)
      expect(L.markerSize(2000, false, cfg)).toBeLessThan(cfg.default)
    end)

    it("never grows with distance", function()
      local previous = math.huge
      for _, d in ipairs({ 0, 10, 15, 25, 50, 100, 200, 400, 800, 1200, 3000 }) do
        local size = L.markerSize(d, false, cfg)
        expect(size <= previous).toBe(true)
        previous = size
      end
    end)

    it("shrinks by equal steps for each doubling of distance (logarithmic)", function()
      local a = L.markerSize(50, false, cfg)
      local b = L.markerSize(100, false, cfg)
      local c = L.markerSize(200, false, cfg)
      expect(math.abs((a - b) - (b - c))).toBeLessThan(3)   -- sizes are even, so steps are 2 px
    end)

    it("uses the default size when the distance is unknown", function()
      expect(L.markerSize(nil, false, cfg)).toBe(cfg.default)
    end)

    it("adds the focus boost on top of the distance size", function()
      expect(L.markerSize(100, true, cfg)).toBe(L.markerSize(100, false, cfg) + cfg.focusBoost)
      expect(L.markerSize(nil, true, cfg)).toBe(cfg.default + cfg.focusBoost)
    end)

    it("returns whole pixels", function()
      for _, d in ipairs({ 17, 33, 77, 123, 456 }) do
        local size = L.markerSize(d, false, cfg)
        expect(size).toBe(math.floor(size))
      end
    end)
  end)

  describe("style", function()
    it("has sane bounds", function()
      expect(cfg.min).toBeGreaterThan(8)
      expect(cfg.max).toBeGreaterThan(TRACK_HEIGHT)
      expect(cfg.nearYd).toBeLessThan(cfg.farYd)
      expect(cfg.default >= cfg.min and cfg.default <= cfg.max).toBe(true)
    end)
  end)

  describe("placements", function()
    local function wp(uid, dist)
      return { uid = uid, delta = 0, compass = true, dist = dist, title = "w" .. uid }
    end

    it("carry a size from each waypoint's distance", function()
      local placements = L.markers({ wp(1, 10), wp(2, 300), wp(3, 2000) }, 140, 600, 20, nil, cfg)
      expect(placements[1].size).toBeGreaterThan(placements[2].size)
      expect(placements[2].size).toBeGreaterThan(placements[3].size)
    end)

    it("fall back to a fixed size without a configuration", function()
      local placements = L.markers({ wp(1, 10) }, 140, 600)
      expect(placements[1].size).toBe(20)
    end)
  end)

  describe("compass view", function()
    local ctx = H.use({ boot = true })
    local parts

    local function frameTick() ctx.world:update(0.04) end
    local function lastSize(marker)
      local calls = marker.SetSize.calls
      return calls[#calls][1]
    end

    beforeEach(function()
      ctx.world:placePlayer(1453, 61.99, 70.58, 0)
      parts = ctx.ns.compass.parts
    end)

    it("draws a very close waypoint taller than the ribbon", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 10 / YD_PER_Y, { title = "Close" })
      frameTick()
      expect(lastSize(parts.markers[1])).toBeGreaterThan(TRACK_HEIGHT)
    end)

    it("draws a far waypoint small", function()
      -- start near the south edge so a point 900 yd north is still on the map
      ctx.world:placePlayer(1453, 61.99, 95, 0)
      ctx.ns:AddWaypoint(1453, 61.99, 95 - 900 / YD_PER_Y, { title = "Far" })
      frameTick()
      expect(lastSize(parts.markers[1])).toBeLessThan(ctx.ns.compassStyle.marker.max / 2 + 2)
    end)

    it("gives every marker an even size, so it centres on the dial", function()
      for _, d in ipairs({ 1, 15, 33, 77, 140, 333, 900, 5000 }) do
        expect(L.markerSize(d, false, cfg) % 2).toBe(0)
        expect(L.markerSize(d, true, cfg) % 2).toBe(0)
      end
    end)

    it("shrinks a marker as the player walks away and grows it as the player approaches", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 100 / YD_PER_Y, { title = "Goal" })
      frameTick()
      local at100 = lastSize(parts.markers[1])
      ctx.world:placePlayer(1453, 61.99, 70.58 + 300 / YD_PER_Y, 0)   -- 400 yd away
      frameTick()
      local at400 = lastSize(parts.markers[1])
      ctx.world:placePlayer(1453, 61.99, 70.58 - 80 / YD_PER_Y, 0)    -- 20 yd away
      frameTick()
      local at20 = lastSize(parts.markers[1])
      expect(at400).toBeLessThan(at100)
      expect(at20).toBeGreaterThan(at100)
    end)

    it("stacks by when a waypoint was added, not by distance", function()
      local function level(m) local c = m.SetFrameLevel.calls return c[#c][1] end
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 500 / YD_PER_Y, { title = "Far" })
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 10 / YD_PER_Y, { title = "Near" })
      frameTick()
      local byTitle = {}
      for _, m in ipairs(parts.markers) do
        local wp = ctx.ns:GetWaypoint(m.uid)
        byTitle[wp.title] = level(m)
      end
      expect(byTitle.Near).toBeGreaterThan(byTitle.Far)   -- added later, so on top, though the other is farther
    end)
  end)

  describe("direction labels", function()
    local ctx = H.use({ boot = true })
    local parts

    beforeEach(function() parts = ctx.ns.compass.parts end)

    it("are outlined and shadowed so they stand out", function()
      for _, h in ipairs({ 0, 45, 90, 135, 180, 225, 270, 315 }) do
        expect(parts.labels[h].SetShadowColor).toHaveBeenCalledWith(0, 0, 0, 1)
        expect(parts.labels[h].SetShadowOffset).toHaveBeenCalledWith(1, -1)
      end
    end)

    it("use the outline font at the label size when the game font is available", function()
      -- the fake client has no fonts, so provide one and rebuild
      local ns, world = H.load({
        world = function(w)
          _G.GameFontHighlight = { GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end }
        end,
        boot = true,
      })
      local labels = ns.compass.parts.labels
      expect(labels[0].SetFont).toHaveBeenCalledWith("Fonts\\FRIZQT__.TTF", ns.compassStyle.labelSize, "OUTLINE")
      expect(labels[90].SetFont).toHaveBeenCalledWith("Fonts\\FRIZQT__.TTF", ns.compassStyle.labelSize, "OUTLINE")
      require("tests.fakes.wow").uninstall()
    end)

    it("keep north red and the rest cream", function()
      local c = ctx.ns.compassStyle.colors
      expect(parts.labels[0].SetTextColor).toHaveBeenCalledWith(unpack(c.north))
      expect(parts.labels[135].SetTextColor).toHaveBeenCalledWith(unpack(c.cream))
    end)
  end)
end)
