local H = require("tests.helpers.addon")

local function build(R)
  R:Chapter("Camp Narache", { levels = { 1, 5 } })
    :Step():Goto(1453, 50, 50):Accept(1)
    :Step():Goto(1453, 51, 51):Accept(2)
    :Done()
  return R
end

describe("Guide panel bezel and map button", function()
  local ctx = H.use({ boot = true })
  local S
  local function dock() return ctx.ns.guideBrowser.dock() end
  local function open()
    ctx.ns.guideBrowser.toggleDock()
    return dock()
  end

  beforeEach(function()
    S = ctx.ns.compassStyle
    build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 }))
  end)

  describe("bezel", function()
    it("has four corners drawn from one texture, flipped, and four tiling edges", function()
      local d = open()
      expect(#d.bezel).toBe(4)
      local flips = {}
      for _, c in ipairs(d.bezel) do
        expect(c.SetTexture).toHaveBeenCalledWith(S.textures.bezelCorner, "REPEAT", "REPEAT")
        expect(c.SetSize).toHaveBeenCalledWith(S.bezel.corner, S.bezel.corner)
        flips[#flips + 1] = table.concat(c.SetTexCoord.calls[1], ",", 1, 4)
      end
      table.sort(flips)
      expect(flips).toEqual({ "0,1,0,1", "0,1,1,0", "1,0,0,1", "1,0,1,0" })
      expect(d.bezel.top.SetTexture).toHaveBeenCalledWith(S.textures.bezelEdgeH, "REPEAT", "REPEAT")
      expect(d.bezel.left.SetTexture).toHaveBeenCalledWith(S.textures.bezelEdgeV, "REPEAT", "REPEAT")
      expect(d.bezel.top.SetHeight).toHaveBeenCalledWith(S.bezel.band)
      expect(d.bezel.left.SetWidth).toHaveBeenCalledWith(S.bezel.band)
    end)

    it("tiles the edges to the frame's size and shows only the band of each", function()
      local d = open()
      d.GetWidth = function() return 466 end
      d.GetHeight = function() return 600 end
      d.layoutBezel()
      local band = S.bezel.bandFraction
      local nx, ny = (466 - 2 * S.bezel.corner) / S.bezel.corner, (600 - 2 * S.bezel.corner) / S.bezel.corner
      local function last(t) local c = t.SetTexCoord.calls return c[#c] end
      expect(last(d.bezel.top)).toEqual({ 0, nx, 0, band, n = 4 })
      expect(last(d.bezel.bottom)).toEqual({ 0, nx, band, 0, n = 4 })
      expect(last(d.bezel.left)).toEqual({ 0, band, 0, ny, n = 4 })
      expect(last(d.bezel.right)).toEqual({ band, 0, 0, ny, n = 4 })
    end)

    it("re-tiles when the map resizes the panel", function()
      local d = open()
      expect(d:GetScript("OnSizeChanged")).toBe(d.layoutBezel)
    end)

    it("uses blue tones", function()
      local d = open()
      local c = d.strip.SetColorTexture.calls[1]
      expect(c[3]).toBeGreaterThan(c[1])   -- blue over red in the title bar
    end)
  end)

  describe("title bar and buttons", function()
    it("shows the guide's title in the middle and the step at the left", function()
      local d = open()
      expect(d.title.SetText).toHaveBeenCalledWith("Test Guide")
      expect(d.title.SetPoint).toHaveBeenCalledWith("CENTER", d.strip, "CENTER", 0, 0)
      expect(d.progress.SetPoint).toHaveBeenCalledWith("LEFT", d.strip, "LEFT", 8, 0)
    end)

    it("closes from the bezel-styled button on the title bar", function()
      local d = open()
      expect(d.close.bg.SetTexture).toHaveBeenCalledWith(S.textures.bezelButton)
      d.close:Trigger("OnClick")
      expect(d:IsShown()).toBe(false)
      expect(RibbonDB.guideDock).toBe(false)
    end)

    it("has flat blue Start chapter and Skip step buttons that glow on hover", function()
      local d = open()
      expect(d.start.text.SetText).toHaveBeenCalledWith("Start chapter")
      expect(d.skip.text.SetText).toHaveBeenCalledWith("Skip step")
      local c = d.start.bg.SetColorTexture.calls[1]
      expect(c[3]).toBeGreaterThan(c[1])
      d.start:Trigger("OnEnter")
      expect(d.start.glow:IsShown()).toBe(true)
      d.start:Trigger("OnLeave")
      expect(d.start.glow:IsShown()).toBe(false)
    end)
  end)

  describe("map button", function()
    it("is a blue bezel button stacked above the map's own quest log toggle", function()
      ctx.ns.map.guideButton = nil
      RibbonGuideMapButton = nil
      WorldMapFrame.SidePanelToggle = { GetObjectType = function() return "Frame" end }
      ctx.ns.map.createGuideButton()
      local b = ctx.ns.map.guideButton
      expect(b.bezel.SetTexture).toHaveBeenCalledWith(S.textures.bezelButton)
      expect(b.SetPoint).toHaveBeenCalledWith("BOTTOM", WorldMapFrame.SidePanelToggle, "TOP", 0, 6)
      WorldMapFrame.SidePanelToggle = nil
    end)

    it("falls back to the map's bottom right corner without that toggle", function()
      local b = ctx.ns.map.guideButton
      expect(b.SetPoint).toHaveBeenCalledWith("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -10, 40)
    end)

    it("wears the bright blue ring while the panel is open", function()
      local b = ctx.ns.map.guideButton
      expect(b.active:IsShown()).toBe(false)
      b:Trigger("OnClick")
      expect(b.active:IsShown()).toBe(true)
      local c = S.focusRing.color
      expect(b.active.SetVertexColor).toHaveBeenCalledWith(c[1], c[2], c[3])
      b:Trigger("OnClick")
      expect(b.active:IsShown()).toBe(false)
    end)
  end)

  describe("opening from the compass and commands", function()
    it("opens the map as well when it is closed", function()
      local toggled = 0
      _G.ToggleWorldMap = function() toggled = toggled + 1 end
      WorldMapFrame:Hide()
      ctx.ns.guideBrowser.toggle()
      expect(dock():IsShown()).toBe(true)
      expect(toggled).toBe(1)
      _G.ToggleWorldMap = nil
    end)

    it("just shows the panel when the map is already open, and the next call closes it", function()
      local toggled = 0
      _G.ToggleWorldMap = function() toggled = toggled + 1 end
      WorldMapFrame:Show()
      ctx.ns.guideBrowser.toggle()
      expect(dock():IsShown()).toBe(true)
      expect(toggled).toBe(0)
      ctx.ns.guideBrowser.toggle()
      expect(dock():IsShown()).toBe(false)
      _G.ToggleWorldMap = nil
    end)

    it("has no floating dialog any more", function()
      expect(ctx.ns.guideBrowser.frame).toBeNil()
      expect(RibbonGuideBrowser).toBeNil()
    end)
  end)
end)
