local H = require("tests.helpers.addon")

describe("Multi-line text", function()
  describe("RXP translation", function()
    local T = H.pure({ "integrations/RXPTranslate.lua" }).rxpTranslate

    -- The case from the game: one step text that spans two lines.
    local function dirtStainedMapStep()
      local step = { index = 3, elements = {} }
      local arrow = {
        zone = 1453, x = 45.5, y = 77.4, step = step,
        text = "Loot [Dirt-stained Map] from Dirt-stained Map to start quest\nDirt-stained Map: 0/1",
      }
      step.elements = { arrow, { text = "Accept Attack on Camp Narache" } }
      return arrow
    end

    it("splits a step text with line breaks into separate lines", function()
      expect(T.stepLines(dirtStainedMapStep())).toEqual({
        "Loot [Dirt-stained Map] from Dirt-stained Map to start quest",
        "Dirt-stained Map: 0/1",
        "Accept Attack on Camp Narache",
      })
    end)

    it("uses only the first line as the headline", function()
      expect(T.title(dirtStainedMapStep())).toBe("Loot [Dirt-stained Map] from Dirt-stained Map to start quest")
    end)

    it("moves the other lines into the description", function()
      expect(T.description(dirtStainedMapStep())).toEqual({
        "Dirt-stained Map: 0/1",
        "Accept Attack on Camp Narache",
      })
    end)

    it("handles carriage returns and blank lines", function()
      local e = { zone = 1453, x = 1, y = 1, text = "first\r\n\r\nsecond\n" }
      expect(T.stepLines(e)).toEqual({ "first", "second" })
    end)

    it("takes the first line of a multi-line element title", function()
      local e = { zone = 1453, x = 1, y = 1, title = "Quest Name\nextra", text = "Kill it" }
      expect(T.title(e)).toBe("Quest Name")
    end)

    it("drops the generated 'Go to' line inside a multi-line text", function()
      local e = { zone = 1453, x = 1, y = 1, text = "Go to 45.5,77.4 (Elwynn)\nKill the wolf" }
      expect(T.stepLines(e)).toEqual({ "Kill the wolf" })
    end)
  end)

  describe("registry", function()
    local ctx = H.use({ boot = true })

    it("turns line breaks in a title into spaces", function()
      expect(ctx.ns.OneLine("one\ntwo")).toBe("one two")
      expect(ctx.ns.OneLine("one \r\n  two\n\nthree")).toBe("one two three")
    end)

    it("leaves single-line text alone and trims it", function()
      expect(ctx.ns.OneLine("  plain  ")).toBe("plain")
      expect(ctx.ns.OneLine(42)).toBe("42")
    end)

    it("stores a one-line title on every waypoint", function()
      local uid = ctx.ns:AddWaypoint(1453, 50, 50, { title = "Loot the map\nMap: 0/1" })
      expect(ctx.ns:GetWaypoint(uid).title).toBe("Loot the map Map: 0/1")
    end)
  end)

  describe("caption on the compass", function()
    local ctx = H.use({ boot = true })
    local YD_PER_Y = 11.5834

    local function lastText(fs) local c = fs.SetText.calls return c[#c][1] end

    it("keeps the distance on the first line and the rest in the description", function()
      _G.RXPG_ARROW = nil
      ctx.world:placePlayer(1453, 61.99, 70.58, 0)
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 320 / YD_PER_Y, {
        title = "Loot [Dirt-stained Map] from Dirt-stained Map to start quest",
        description = { "Dirt-stained Map: 0/1", "Accept Attack on Camp Narache" },
      })
      ctx.world:update(0.04)
      local parts = ctx.ns.compass.parts
      expect(lastText(parts.targetText)).toBe("Loot [Dirt-stained Map] from Dirt-stained Map to start quest")
      expect(lastText(parts.targetText)).never.toContain("\n")
      expect(lastText(parts.detailText)).toBe("Dirt-stained Map: 0/1\nAccept Attack on Camp Narache")
    end)
  end)
end)
