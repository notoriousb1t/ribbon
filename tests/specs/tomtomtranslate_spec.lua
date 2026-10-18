local H = require("tests.helpers.addon")

describe("TomTom translation", function()
  local T = H.pure({ "integrations/TomTomTranslate.lua" }).tomtomTranslate
  local tomtom = {}
  local ctx

  local function args(...) return { n = select("#", ...), ... } end

  beforeEach(function()
    ctx = { tomtom = tomtom, isValidMap = function(id) return id == 1453 or id == 1439 end }
  end)

  describe("key", function()
    it("rounds coordinates to two decimals and includes the title", function()
      expect(T.key(1453, 50, 25.004, "Anvil")).toBe("1453:50.00:25.00:Anvil")
      expect(T.key(1453, 50, 25.006)).toBe("1453:50.00:25.01:")
    end)

    it("tells waypoints with different titles at one spot apart", function()
      expect(T.key(1453, 50, 25, "A")).never.toBe(T.key(1453, 50, 25, "B"))
    end)

    it("builds a key from a request", function()
      expect(T.keyOf({ mapID = 1453, x = 50, y = 25, title = "Anvil" })).toBe("1453:50.00:25.00:Anvil")
    end)
  end)

  describe("fromAddWaypoint(m, x, y, opts)", function()
    it("converts fractions to 0-100 and takes the title from opts", function()
      local req = T.fromAddWaypoint(args(1453, 0.5, 0.25, { title = "Anvil" }), ctx)
      expect(req).toEqual({ mapID = 1453, x = 50, y = 25, title = "Anvil" })
    end)

    it("drops a leading self", function()
      local req = T.fromAddWaypoint(args(tomtom, 1453, 0.5, 0.25), ctx)
      expect(req.mapID).toBe(1453)
      expect(req.title).toBeNil()
    end)

    it("ignores an empty title and non-table opts", function()
      expect(T.fromAddWaypoint(args(1453, 0.5, 0.5, { title = "" }), ctx).title).toBeNil()
      expect(T.fromAddWaypoint(args(1453, 0.5, 0.5, "text"), ctx).title).toBeNil()
    end)

    it("rejects an unknown map", function()
      local req, reason = T.fromAddWaypoint(args(99999, 0.5, 0.5), ctx)
      expect(req).toBeNil()
      expect(reason).toBe("unknown map")
    end)

    it("rejects values outside the 0-1 range TomTom uses", function()
      expect(T.fromAddWaypoint(args(1453, 50, 25), ctx)).toBeNil()
      expect(T.fromAddWaypoint(args(1453, -0.1, 0.5), ctx)).toBeNil()
    end)

    it("rejects non-numeric input without raising", function()
      expect(T.fromAddWaypoint(args("a", "b", "c"), ctx)).toBeNil()
      expect(T.fromAddWaypoint(args(), ctx)).toBeNil()
      expect(T.fromAddWaypoint(args(nil, nil), ctx)).toBeNil()
    end)
  end)

  describe("fromUID", function()
    it("reads TomTom's { m, x, y, title = ... } handle", function()
      expect(T.fromUID({ 1453, 0.5, 0.25, title = "Anvil", from = "TomTom/way" }, ctx))
        .toEqual({ mapID = 1453, x = 50, y = 25, title = "Anvil" })
    end)

    it("returns nil for anything else", function()
      expect(T.fromUID("handle", ctx)).toBeNil()
      expect(T.fromUID({}, ctx)).toBeNil()
      expect(T.fromUID(nil, ctx)).toBeNil()
      expect(T.fromUID({ 99999, 0.5, 0.5 }, ctx)).toBeNil()
    end)
  end)
end)
