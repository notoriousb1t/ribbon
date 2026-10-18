local H = require("tests.helpers.addon")

describe("TomTom layer", function()
  describe("ParseWay", function()
    local ctx = H.use({})

    it("parses coordinates only", function()
      local zone, x, y, desc = ctx.ns.ParseWay("48.2 42.9")
      expect(zone).toBe("")
      expect(x).toBe(48.2)
      expect(y).toBe(42.9)
      expect(desc).toBe("")
    end)

    it("parses a description", function()
      local zone, x, y, desc = ctx.ns.ParseWay("48.2 42.9 Anvil Mar")
      expect(zone).toBe("")
      expect(desc).toBe("Anvil Mar")
    end)

    it("parses a zone name and comma-separated coordinates", function()
      local zone, x, y, desc = ctx.ns.ParseWay("Stormwind City 48.2, 42.9 trainer")
      expect(zone).toBe("Stormwind City")
      expect(x).toBe(48.2)
      expect(y).toBe(42.9)
      expect(desc).toBe("trainer")
    end)

    it("returns nil when there are no coordinates", function()
      expect(ctx.ns.ParseWay("hello")).toBeNil()
      expect(ctx.ns.ParseWay("")).toBeNil()
      expect(ctx.ns.ParseWay(nil)).toBeNil()
      expect(ctx.ns.ParseWay("48")).toBeNil()
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

  describe("when TomTom is absent", function()
    local ctx = H.use({ boot = true })

    it("installs a TomTom global", function()
      expect(TomTom).toBeTruthy()
      expect(type(TomTom.AddZWaypoint)).toBe("function")
    end)

    it("AddZWaypoint creates a waypoint from a uiMapID zone", function()
      local uid = TomTom:AddZWaypoint(1415, 1453, 50, 50, "Bank")
      expect(ctx.ns:GetWaypoint(uid).title).toBe("Bank")
      expect(ctx.ns:GetWaypoint(uid).mapID).toBe(1453)
    end)

    it("AddZWaypoint returns nil for an unresolvable zone", function()
      expect(TomTom:AddZWaypoint(1, 7, 50, 50, "x")).toBeNil()
    end)

    it("AddWaypoint uses the current zone", function()
      local uid = TomTom:AddWaypoint(50, 50, "Here")
      expect(ctx.ns:GetWaypoint(uid).mapID).toBe(1453)
    end)

    it("RemoveWaypoint and ClearAllWaypoints route to the registry", function()
      local a = TomTom:AddWaypoint(50, 50, "A")
      TomTom:AddWaypoint(40, 40, "B")
      TomTom:RemoveWaypoint(a)
      expect(ctx.ns:GetWaypoint(a)).toBeNil()
      TomTom:ClearAllWaypoints()
      expect(next(ctx.ns.waypoints)).toBeNil()
    end)

    it("registers /way and creates a waypoint", function()
      expect(SLASH_RIBBONWAY1).toBe("/way")
      SlashCmdList.RIBBONWAY("Stormwind City 50 50 Auction House")
      local wp = ctx.ns:GetWaypoint(1)
      expect(wp.title).toBe("Auction House")
      expect(ctx.world:output()).toContain("waypoint 1 set")
    end)

    it("/way without a zone uses the current zone", function()
      SlashCmdList.RIBBONWAY("50 50")
      expect(ctx.ns:GetWaypoint(1).mapID).toBe(1453)
      expect(ctx.ns:GetWaypoint(1).title).toBe("Waypoint")
    end)

    it("/way reports bad input without creating anything", function()
      SlashCmdList.RIBBONWAY("nonsense")
      expect(ctx.world:output()).toContain("usage")
      SlashCmdList.RIBBONWAY("Atlantis 50 50")
      expect(ctx.world:output()).toContain("unknown zone")
      expect(next(ctx.ns.waypoints)).toBeNil()
    end)
  end)

  describe("when the real TomTom is loaded", function()
    local existing = {}
    local ctx = H.use({
      boot = true,
      world = function() _G.TomTom = existing end,
    })

    it("leaves the TomTom global and /way alone", function()
      expect(TomTom).toBe(existing)
      expect(SlashCmdList.RIBBONWAY).toBeNil()
    end)
  end)

  describe("when /way is already registered by another addon", function()
    local ctx = H.use({
      boot = true,
      world = function() _G.hash_SlashCmdList["/WAY"] = function() end end,
    })

    it("does not take over /way but still provides the TomTom global", function()
      expect(SlashCmdList.RIBBONWAY).toBeNil()
      expect(TomTom).toBeTruthy()
    end)
  end)
end)
