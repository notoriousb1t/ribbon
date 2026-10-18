local H = require("tests.helpers.addon")

describe("RXP translation", function()
  local T = H.pure({ "integrations/RXPTranslate.lua" }).rxpTranslate
  local ctx = { isValidMap = function(id) return id == 1453 or id == 1439 end }

  local function arrow(element, shown)
    return { shown = shown ~= false, element = element }
  end

  describe("title", function()
    it("uses the element's own title", function()
      expect(T.title({ title = "Anvil Mar" })).toBe("Anvil Mar")
    end)

    it("strips RXP's colour tokens and colour codes", function()
      expect(T.title({ title = "RXP_FRIENDLY_Furen|r" })).toBe("Furen")
      expect(T.title({ title = "|cffff0000Red Name|r" })).toBe("Red Name")
    end)

    it("falls back to the step's arrow text, title or number", function()
      expect(T.title({ step = { arrowtext = "Go north", title = "T", index = 4 } })).toBe("Go north")
      expect(T.title({ step = { title = "Step title", index = 4 } })).toBe("Step title")
      expect(T.title({ step = { index = 4 } })).toBe("Step 4")
    end)

    it("falls back to RestedXP when there is nothing to show", function()
      expect(T.title({})).toBe("RestedXP")
      expect(T.title({ title = "" , step = {} })).toBe("RestedXP")
      expect(T.title({ title = "RXP_FRIENDLY_" })).toBe("RestedXP")
    end)
  end)

  describe("fromArrow", function()
    local element = { zone = 1453, x = 64.6, y = 37.2, title = "Furen" }

    it("translates a shown arrow with a zone target", function()
      expect(T.fromArrow(arrow(element), ctx)).toEqual({ mapID = 1453, x = 64.6, y = 37.2, title = "Furen" })
    end)

    it("is nil when the arrow is hidden or missing", function()
      expect(T.fromArrow(arrow(element, false), ctx)).toBeNil()
      expect(T.fromArrow(nil, ctx)).toBeNil()
      expect(T.fromArrow(arrow(nil), ctx)).toBeNil()
    end)

    it("is nil for a target without zone coordinates (corpse, Spirit Healer)", function()
      expect(T.fromArrow(arrow({ wx = 1, wy = 2, instance = 0, title = "Corpse" }), ctx)).toBeNil()
    end)

    it("is nil for an unknown map or out-of-range coordinates", function()
      expect(T.fromArrow(arrow({ zone = 99999, x = 50, y = 50 }), ctx)).toBeNil()
      expect(T.fromArrow(arrow({ zone = 1453, x = 150, y = 50 }), ctx)).toBeNil()
      expect(T.fromArrow(arrow({ zone = 1453, x = 50, y = -1 }), ctx)).toBeNil()
    end)

    it("is nil for non-numeric fields", function()
      expect(T.fromArrow(arrow({ zone = "1453", x = 50, y = 50 }), ctx)).toBeNil()
    end)
  end)

  it("builds a key that changes with the target and title", function()
    local a = T.key({ mapID = 1453, x = 50, y = 25, title = "A" })
    expect(a).toBe("1453:50.00:25.00:A")
    expect(T.key({ mapID = 1453, x = 50, y = 25, title = "B" })).never.toBe(a)
  end)
end)
