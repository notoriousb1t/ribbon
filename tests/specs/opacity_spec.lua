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
          local isTick = o == parts.dial.face
          for _, t in ipairs(parts.ticks) do if t == o then isTick = true end end
          if not isTick then out[#out + 1] = calls[#calls][1] end
        end
      end
      return out
    end

    beforeEach(function() parts = ctx.ns.compass.parts end)

    it("defaults to 60 percent, saved with the other settings", function()
      expect(RibbonDB.compass.opacity).toBe(0.6)
    end)

    it("applies the opacity to the ribbon textures (band, edges and caps)", function()
      local alphas = chromeTextures()
      expect(#alphas).toBe(5)
      for _, a in ipairs(alphas) do expect(a).toBe(0.6) end
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
      expect(RibbonDB.compass.opacity).toBe(0.6)
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
      expect(RibbonDB.compass.opacity).toBe(0.6)
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

  describe("the compass dial", function()
    local ctx = H.use({ boot = true })

    it("is see-through by default and keeps its needle solid", function()
      local parts = ctx.ns.compass.parts
      expect(RibbonDB.compass.dialOpacity).toBe(0.7)
      local calls = parts.dial.face.SetAlpha.calls
      expect(calls[#calls][1]).toBe(0.7)
      expect(parts.needle.SetAlpha.calls[1]).toBeNil()
    end)

    it("changes with /ribbon compass dial (a percentage), within bounds", function()
      ctx.ns.commands.compass("dial 40")
      expect(RibbonDB.compass.dialOpacity).toBe(0.4)
      ctx.ns.commands.compass("dial 5")
      expect(RibbonDB.compass.dialOpacity).toBe(0.2)
    end)

    it("hides the degree ticks under it, whatever its opacity", function()
      local parts = ctx.ns.compass.parts
      ctx.world:placePlayer(1453, 50, 50, 0)
      ctx.world:update(0.04)
      local half = ctx.ns.compassStyle.dial.size / 2
      local hidden, shown = 0, 0
      for _, tick in ipairs(parts.ticks) do
        local p = tick.SetPoint.calls[#tick.SetPoint.calls]
        if tick:IsShown() then
          shown = shown + 1
          expect(math.abs(p[4])).toBeGreaterThan(half - 0.0001)
        else
          hidden = hidden + 1
        end
      end
      expect(shown).toBeGreaterThan(0)
      expect(hidden).toBeGreaterThan(0)
    end)
  end)

  describe("the old ribbon default", function()
    it("moves to the new one once, for a player who never changed it", function()
      local ns = H.load({ boot = true, world = function() RibbonDB = { compass = { opacity = 0.75 } } end })
      expect(RibbonDB.compass.opacity).toBe(0.6)
      expect(RibbonDB.compass.opacityMigrated).toBe(true)
    end)

    it("leaves a value the player chose, and does not migrate twice", function()
      H.load({ boot = true, world = function() RibbonDB = { compass = { opacity = 0.9 } } end })
      expect(RibbonDB.compass.opacity).toBe(0.9)
      H.load({ boot = true, world = function() RibbonDB = { compass = { opacity = 0.75, opacityMigrated = true } } end })
      expect(RibbonDB.compass.opacity).toBe(0.75)
    end)
  end)
end)
