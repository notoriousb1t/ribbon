local H = require("tests.helpers.addon")

describe("Probe formatting", function()
  local F = H.pure({ "probe/Format.lua" }).probeFormat

  describe("serialize", function()
    it("formats scalars", function()
      expect(F.serialize(nil)).toBe("nil")
      expect(F.serialize(5)).toBe("5")
      expect(F.serialize(true)).toBe("true")
      expect(F.serialize("a b")).toBe('"a b"')
    end)

    it("shows functions by a marker", function()
      expect(F.serialize(print)).toBe("<function>")
    end)

    it("sorts table keys so output is stable", function()
      expect(F.serialize({ b = 2, a = 1 })).toBe("{a=1, b=2}")
    end)

    it("formats array entries by index", function()
      expect(F.serialize({ 10, 20 })).toBe("{[1]=10, [2]=20}")
    end)

    it("expands nested tables to the depth limit", function()
      local v = { a = { b = { c = 1 } } }
      expect(F.serialize(v, { depth = 2 })).toBe("{a={b={...}}}")
      expect(F.serialize(v, { depth = 3 })).toBe("{a={b={c=1}}}")
    end)

    it("can omit function members", function()
      expect(F.serialize({ x = 1, f = print }, { skipFunctions = true })).toBe("{x=1}")
      expect(F.serialize({ x = 1, f = print })).toBe("{f=<function>, x=1}")
    end)

    it("truncates very large tables", function()
      local big = {}
      for i = 1, 100 do big[i] = i end
      expect(F.serialize(big)).toContain("... (60 more)")
    end)

    it("copes with a table that contains itself", function()
      local t = {}
      t.self = t
      expect(F.serialize(t)).toBe("{self={self={...}}}")
    end)
  end)

  describe("list", function()
    it("joins packed results, keeping nils", function()
      expect(F.list({ n = 3, 1, nil, "x" })).toBe('1, nil, "x"')
    end)

    it("is empty for no results", function()
      expect(F.list({ n = 0 })).toBe("")
    end)
  end)
end)
