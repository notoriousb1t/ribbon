local H = require("tests.helpers.addon")

describe("Ribbon opacity", function()
  describe("style", function()
    local S = H.pure({ "compass/Style.lua" }).compassStyle

    it("has sensible bounds around the default", function()
      expect(S.opacity.min).toBeGreaterThan(0)
      expect(S.opacity.max).toBe(1)
      expect(S.opacity.default >= S.opacity.min and S.opacity.default < S.opacity.max).toBe(true)
    end)
  end)

  describe("view", function()
    local ctx = H.use({ boot = true })
    local parts

    -- The textures that make up the ribbon: the band, its two edges and the two caps.
    local function chromeTextures()
      local out = {}
      for _, o in ipairs(ctx.world.objects) do
        if o.kind == "Texture" and o.SetAlpha and #o.SetAlpha.calls > 0 and o ~= parts.captionPlate then
          local calls = o.SetAlpha.calls
          -- ticks also set alpha; the ribbon textures are the ones that are not ticks
          local isTick = false
          for _, t in ipairs(parts.ticks) do if t == o then isTick = true end end
          if not isTick then out[#out + 1] = calls[#calls][1] end
        end
      end
      return out
    end

    beforeEach(function() parts = ctx.ns.compass.parts end)

    it("defaults to 75 percent, saved with the other settings", function()
      expect(RibbonDB.compass.opacity).toBe(0.75)
    end)

    it("applies the opacity to the ribbon textures (band, edges and caps)", function()
      local alphas = chromeTextures()
      expect(#alphas).toBe(5)
      for _, a in ipairs(alphas) do expect(a).toBe(0.75) end
    end)

    it("changes the ribbon with /ribbon compass opacity (a percentage)", function()
      ctx.ns.commands.compass("opacity 50")
      expect(RibbonDB.compass.opacity).toBe(0.5)
      for _, a in ipairs(chromeTextures()) do expect(a).toBe(0.5) end
    end)

    it("keeps the opacity between 20 and 100 percent", function()
      ctx.ns.commands.compass("opacity 5")
      expect(RibbonDB.compass.opacity).toBe(0.2)
      ctx.ns.commands.compass("opacity 250")
      expect(RibbonDB.compass.opacity).toBe(1)
    end)

    it("returns to the default on reset", function()
      ctx.ns.commands.compass("opacity 40")
      ctx.ns.commands.compass("reset")
      expect(RibbonDB.compass.opacity).toBe(0.75)
    end)

    it("leaves the caption plate, dial and text opaque", function()
      ctx.ns.commands.compass("opacity 30")
      expect(parts.captionPlate.SetAlpha).never.toHaveBeenCalled()
      expect(parts.dial.SetAlpha).never.toHaveBeenCalled()
      expect(parts.targetText.SetAlpha).never.toHaveBeenCalled()
    end)

    it("prints usage including opacity for unknown input", function()
      ctx.ns.commands.compass("opacity")
      expect(ctx.world:output()).toContain("opacity <20-100>")
    end)
  end)

  describe("a saved setting from before opacity existed", function()
    local ctx = H.use({
      boot = true,
      world = function() RibbonDB = { compass = { width = 700 } } end,
    })

    it("gets the default opacity and keeps its other values", function()
      expect(RibbonDB.compass.opacity).toBe(0.75)
      expect(RibbonDB.compass.width).toBe(700)
    end)
  end)

  describe("a saved opacity outside the allowed range", function()
    local ctx = H.use({
      boot = true,
      world = function() RibbonDB = { compass = { opacity = 7 } } end,
    })

    it("is clamped when applied", function()
      expect(RibbonDB.compass.opacity).toBe(1)
    end)
  end)
end)
