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
      expect(T.fromArrow(arrow(element), ctx)).toEqual({ mapID = 1453, x = 64.6, y = 37.2, title = "Furen", description = {} })
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

  it("builds a key from where the target is, not from its changing text", function()
    local a = T.key({ mapID = 1453, x = 50, y = 25, title = "A" })
    expect(a).toBe("1453:50.00:25.00")
    expect(T.key({ mapID = 1453, x = 50, y = 25, title = "B" })).toBe(a)
    expect(T.key({ mapID = 1453, x = 51, y = 25, title = "A" })).never.toBe(a)
    expect(T.key({ mapID = 1439, x = 50, y = 25, title = "A" })).never.toBe(a)
  end)

  describe("step text", function()
    local function stepElement(texts, extra)
      local step = { elements = {}, index = 19 }
      local arrow = { zone = 1453, x = 45.5, y = 77.4, step = step }
      step.elements[1] = arrow
      for _, text in ipairs(texts) do step.elements[#step.elements + 1] = { text = text } end
      for k, v in pairs(extra or {}) do arrow[k] = v end
      return arrow
    end

    it("lists the step's text lines in order", function()
      local e = stepElement({ "Kill Sharptusk Thornmantle", "Collect Thornmantle's Head" })
      expect(T.stepLines(e)).toEqual({ "Kill Sharptusk Thornmantle", "Collect Thornmantle's Head" })
    end)

    it("includes the arrow element's own text", function()
      local e = stepElement({ "Second line" }, { text = "First line" })
      expect(T.stepLines(e)).toEqual({ "First line", "Second line" })
    end)

    it("leaves out finished, skipped and hidden lines", function()
      local e = stepElement({ "keep" })
      e.step.elements[#e.step.elements + 1] = { text = "done", completed = true }
      e.step.elements[#e.step.elements + 1] = { text = "skipped", skip = true }
      e.step.elements[#e.step.elements + 1] = { text = "hidden", hidden = true }
      expect(T.stepLines(e)).toEqual({ "keep" })
    end)

    it("leaves out RXP's generated 'Go to' line and duplicates", function()
      local e = stepElement({ "Go to 45.5,77.4 (Ashenvale)", "Kill the boar", "Kill the boar" })
      expect(T.stepLines(e)).toEqual({ "Kill the boar" })
    end)

    it("strips markup from each line", function()
      local e = stepElement({ "|cffffd200Kill|r RXP_ENEMY_the boar|r |T1:0|t" })
      expect(T.stepLines(e)).toEqual({ "Kill the boar" })
    end)

    it("is empty when there is no step text", function()
      expect(T.stepLines({ zone = 1453, x = 1, y = 1 })).toEqual({})
      expect(T.stepLines(stepElement({}))).toEqual({})
    end)

    it("uses the first step line as the headline when the element has no title", function()
      local e = stepElement({ "Kill Sharptusk Thornmantle", "Collect the head" })
      expect(T.title(e)).toBe("Kill Sharptusk Thornmantle")
      expect(T.description(e)).toEqual({ "Collect the head" })
    end)

    it("prefers the element's own title (a quest name) and describes it with the step text", function()
      local e = stepElement({ "Kill Sharptusk Thornmantle" }, { title = "Break Sharptusk!" })
      expect(T.title(e)).toBe("Break Sharptusk!")
      expect(T.description(e)).toEqual({ "Kill Sharptusk Thornmantle" })
    end)

    it("uses the step name only when there is no text at all", function()
      expect(T.title(stepElement({}))).toBe("Step 19")
    end)

    it("does not repeat the headline in the description", function()
      local e = stepElement({ "Only line" })
      expect(T.title(e)).toBe("Only line")
      expect(T.description(e)).toEqual({})
    end)

    it("puts the text lines into the request", function()
      local ctx = { isValidMap = function(id) return id == 1453 end }
      local e = stepElement({ "Kill Sharptusk Thornmantle", "Collect the head" })
      local req = T.fromArrow({ shown = true, element = e }, ctx)
      expect(req.title).toBe("Kill Sharptusk Thornmantle")
      expect(req.description).toEqual({ "Collect the head" })
    end)
  end)
end)
