local H = require("tests.helpers.addon")

describe("Client adapter", function()
  local ctx = H.use({ files = { "core/Client.lua" } })
  local client

  beforeEach(function() client = ctx.ns.client end)

  describe("probe", function()
    it("reports nothing missing on a complete client", function()
      expect(client.probe()).toEqual({})
    end)

    it("lists each missing required API", function()
      ctx.world:removeApi("GetPlayerFacing")
      ctx.world:removeApi("C_Map.GetWorldPosFromMapPos")
      expect(client.probe()).toEqual({ "GetPlayerFacing", "C_Map.GetWorldPosFromMapPos" })
    end)

    it("reports every C_Map API when C_Map is gone", function()
      _G.C_Map = nil
      expect(#client.probe()).toBe(4)
    end)
  end)

  describe("facing", function()
    it("returns the facing in radians", function()
      ctx.world.player.facing = 1.5
      expect(client.facing()).toBe(1.5)
    end)

    it("returns nil when the API errors or returns a non-number", function()
      _G.GetPlayerFacing = function() error("boom") end
      expect(client.facing()).toBeNil()
      _G.GetPlayerFacing = function() return nil end
      expect(client.facing()).toBeNil()
    end)
  end)

  describe("playerWorld", function()
    it("returns first, second and instance", function()
      ctx.world.player.first, ctx.world.player.second, ctx.world.player.instance = -8813.4, 645.9, 0
      local f, s, inst = client.playerWorld()
      expect(f).toBe(-8813.4)
      expect(s).toBe(645.9)
      expect(inst).toBe(0)
    end)

    it("returns nil when position is unavailable or reads 0, 0", function()
      ctx.world.player.noPosition = true
      expect(client.playerWorld()).toBeNil()
      ctx.world.player.noPosition = false
      ctx.world.player.first, ctx.world.player.second = 0, 0
      expect(client.playerWorld()).toBeNil()
    end)
  end)

  describe("toWorld", function()
    it("converts zone coordinates to world yards in the player's frame", function()
      ctx.world:placePlayer(1453, 61.99, 70.58)
      local f, s, inst = client.toWorld(1453, 61.99, 70.58)
      expect(f).toBeCloseTo(ctx.world.player.first, 6)
      expect(s).toBeCloseTo(ctx.world.player.second, 6)
      expect(inst).toBe(0)
    end)

    it("returns nil for an unknown map", function()
      expect(client.toWorld(99999, 50, 50)).toBeNil()
    end)

    it("makes a zone wider (second axis) than it is tall (first axis), as measured", function()
      local f1, s1 = client.toWorld(1453, 0, 0)
      local f2, s2 = client.toWorld(1453, 100, 100)
      expect(math.abs(s2 - s1)).toBeGreaterThan(math.abs(f2 - f1))
    end)
  end)

  describe("map position", function()
    it("returns the best map and the player's coordinates 0-100", function()
      ctx.world:placePlayer(1453, 61.99, 70.58)
      local mapID, x, y = client.playerMapPosition()
      expect(mapID).toBe(1453)
      expect(x).toBeCloseTo(61.99, 4)
      expect(y).toBeCloseTo(70.58, 4)
    end)

    it("returns nil without a map or position", function()
      ctx.world.player.mapID = nil
      expect(client.playerMapPosition()).toBeNil()
    end)
  end)

  describe("maps", function()
    it("describes a map and validates ids", function()
      expect(client.mapInfo(1453).name).toBe("Stormwind City")
      expect(client.isValidMap(1453)).toBe(true)
      expect(client.isValidMap(99999)).toBe(false)
      expect(client.isValidMap("1453")).toBe(false)
    end)

    it("lists descendant maps of a root", function()
      local names = {}
      for _, m in ipairs(client.mapChildren(1415)) do names[#names + 1] = m.name end
      expect(names).toContain("Stormwind City")
    end)

    it("returns an empty list when the API fails", function()
      _G.C_Map.GetMapChildrenInfo = function() error("boom") end
      expect(client.mapChildren(1415)).toEqual({})
    end)
  end)
end)
