local H = require("tests.helpers.addon")

describe("Text coordinates", function()
  describe("ParseCoords", function()
    local ctx = H.use({})

    it("parses coordinates only", function()
      local zone, x, y, desc = ctx.ns.ParseCoords("48.2 42.9")
      expect(zone).toBe("")
      expect(x).toBe(48.2)
      expect(y).toBe(42.9)
      expect(desc).toBe("")
    end)

    it("parses a description", function()
      local zone, x, y, desc = ctx.ns.ParseCoords("48.2 42.9 Anvil Mar")
      expect(zone).toBe("")
      expect(desc).toBe("Anvil Mar")
    end)

    it("parses a zone name and comma-separated coordinates", function()
      local zone, x, y, desc = ctx.ns.ParseCoords("Stormwind City 48.2, 42.9 trainer")
      expect(zone).toBe("Stormwind City")
      expect(x).toBe(48.2)
      expect(y).toBe(42.9)
      expect(desc).toBe("trainer")
    end)

    it("returns nil when there are no coordinates", function()
      expect(ctx.ns.ParseCoords("hello")).toBeNil()
      expect(ctx.ns.ParseCoords("")).toBeNil()
      expect(ctx.ns.ParseCoords(nil)).toBeNil()
      expect(ctx.ns.ParseCoords("48")).toBeNil()
    end)
  end)

  describe("ResolveMap", function()
    local ctx = H.use({ boot = true })

    it("accepts a valid uiMapID and rejects an invalid one", function()
      expect(ctx.ns.ResolveMap(1453)).toBe(1453)
      expect(ctx.ns.ResolveMap(99999)).toBeNil()
    end)

    it("finds a zone by name, ignoring case", function()
      expect(ctx.ns.ResolveMap("stormwind city")).toBe(1453)
      expect(ctx.ns.ResolveMap("Darkshore")).toBe(1439)
    end)

    it("finds a continent by name", function()
      expect(ctx.ns.ResolveMap("Eastern Kingdoms")).toBe(1415)
    end)

    it("returns nil for an unknown or empty name", function()
      expect(ctx.ns.ResolveMap("Atlantis")).toBeNil()
      expect(ctx.ns.ResolveMap("")).toBeNil()
      expect(ctx.ns.ResolveMap(nil)).toBeNil()
    end)
  end)

  describe("HandleCoords", function()
    local ctx = H.use({ boot = true })

    it("creates a waypoint in a named zone with a description", function()
      ctx.ns.HandleCoords("Stormwind City 50 50 Auction House")
      expect(ctx.ns:GetWaypoint(1).title).toBe("Auction House")
      expect(ctx.ns:GetWaypoint(1).mapID).toBe(1453)
      expect(ctx.world:output()).toContain("waypoint 1 set")
    end)

    it("uses the current zone and a default title when omitted", function()
      ctx.ns.HandleCoords("50 50")
      expect(ctx.ns:GetWaypoint(1).mapID).toBe(1453)
      expect(ctx.ns:GetWaypoint(1).title).toBe("Waypoint")
    end)

    it("reports bad input without creating anything", function()
      ctx.ns.HandleCoords("nonsense")
      expect(ctx.world:output()).toContain("usage")
      ctx.ns.HandleCoords("Atlantis 50 50")
      expect(ctx.world:output()).toContain("unknown zone")
      expect(next(ctx.ns.waypoints)).toBeNil()
    end)

    it("reports a coordinate the registry rejects", function()
      ctx.ns.HandleCoords("150 50")
      expect(ctx.world:output()).toContain("could not set")
    end)
  end)

  describe("TomTom is ignored", function()
    local existing = {}
    local ctx = H.use({
      boot = true,
      world = function() _G.TomTom = existing end,
    })

    it("never installs or replaces the TomTom global", function()
      expect(TomTom).toBe(existing)
    end)

    it("never registers /way", function()
      expect(SlashCmdList.RIBBONWAY).toBeNil()
      expect(SLASH_RIBBONWAY1).toBeNil()
    end)
  end)

  describe("without TomTom", function()
    local ctx = H.use({ boot = true })

    it("does not create a TomTom global or /way", function()
      expect(TomTom).toBeNil()
      expect(SlashCmdList.RIBBONWAY).toBeNil()
    end)
  end)
end)
