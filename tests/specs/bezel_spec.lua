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
    it("shows just the guide's title, in the middle of the bar", function()
      local d = open()
      expect(d.title.SetText).toHaveBeenCalledWith("Test Guide")
      expect(d.title.SetPoint).toHaveBeenCalledWith("CENTER", d.strip, "CENTER", 0, 0)
      expect(d.progress).toBeNil()           -- no "Step n of x"
    end)

    it("closes from the bezel-styled button on the title bar", function()
      local d = open()
      expect(d.close.bg.SetTexture).toHaveBeenCalledWith(S.textures.bezelButton)
      d.close:Trigger("OnClick")
      expect(d:IsShown()).toBe(false)
      expect(RibbonDB.guideDock).toBe(false)
    end)

    it("has no Start chapter or Skip step buttons", function()
      local d = open()
      expect(d.start).toBeNil()
      expect(d.skip).toBeNil()
    end)

    it("draws the close X as two bars crossed at the button's exact centre", function()
      local d = open()
      expect(#d.close.bars).toBe(2)
      local angles = {}
      for _, bar in ipairs(d.close.bars) do
        expect(bar.SetPoint).toHaveBeenCalledWith("CENTER", d.close, "CENTER", 0, 0)
        angles[#angles + 1] = bar.SetRotation.calls[1][1]
      end
      table.sort(angles)
      expect(angles[1]).toBeCloseTo(-math.pi / 4, 6)
      expect(angles[2]).toBeCloseTo(math.pi / 4, 6)
    end)

    it("lets the columns run down to the bezel now that there are no buttons", function()
      local d = open()
      expect(d.leftScroll.SetPoint).toHaveBeenCalledWith("BOTTOMLEFT", d, "BOTTOMLEFT", S.bezel.band + 6, 22)
    end)
  end)

  describe("map button", function()
    it("is a blue version of the map's quest log toggle, stacked above it", function()
      ctx.ns.map.guideButton = nil
      RibbonGuideMapButton = nil
      WorldMapFrame.SidePanelToggle = { GetObjectType = function() return "Frame" end }
      ctx.ns.map.createGuideButton()
      local b = ctx.ns.map.guideButton
      expect(b.bezel.SetTexture).toHaveBeenCalledWith(S.textures.panelToggle)
      expect(b.bezel.SetTexCoord).toHaveBeenCalledWith(0, 1, S.toggle.rows[1], S.toggle.rows[2])
      expect(b.SetSize).toHaveBeenCalledWith(S.toggle.width, S.toggle.height)
      expect(b.SetPoint).toHaveBeenCalledWith("BOTTOM", WorldMapFrame.SidePanelToggle, "TOP", 0, 6)
      WorldMapFrame.SidePanelToggle = nil
    end)

    it("is 4:3 like the map's toggle and the cropped texture is not stretched", function()
      expect(S.toggle.width / S.toggle.height).toBeCloseTo(4 / 3, 1)
      expect((S.toggle.rows[2] - S.toggle.rows[1]) * 128).toBe(96)       -- 128 wide, 96 tall in the file
    end)

    it("has a caret on the left and the middle of the compass on the right", function()
      local b = ctx.ns.map.guideButton
      expect(b.caret.SetTexture).toHaveBeenCalledWith(S.textures.panelCaret)
      expect(b.caret.SetPoint).toHaveBeenCalledWith("LEFT", b, "LEFT", 6, 0)
      expect(b.icon.SetTexture).toHaveBeenCalledWith(S.textures.needle)
      expect(b.icon.SetPoint).toHaveBeenCalledWith("RIGHT", b, "RIGHT", -4, 0)
    end)

    it("falls back to the map's bottom right corner without that toggle", function()
      local b = ctx.ns.map.guideButton
      expect(b.SetPoint).toHaveBeenCalledWith("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -10, 40)
    end)

    it("points its caret left while the panel is closed and right while it is open", function()
      local b = ctx.ns.map.guideButton
      local function last() local c = b.caret.SetTexCoord.calls return { unpack(c[#c], 1, 4) } end
      expect(last()).toEqual({ 0, 1, 0, 1 })
      b:Trigger("OnClick")
      expect(last()).toEqual({ 1, 0, 0, 1 })
      b:Trigger("OnClick")
      expect(last()).toEqual({ 0, 1, 0, 1 })
    end)
  end)

  describe("taking turns with the map's quest log", function()
    local function fakeQuestLog()
      local clicks, hooks = 0, {}
      local shown = true
      local qmf = {
        IsShown = function() return shown end,
        HookScript = function(self, name, fn) hooks[name] = fn end,
      }
      WorldMapFrame.SidePanelToggle = {
        GetObjectType = function() return "Frame" end,
        CloseButton = { Click = function() clicks = clicks + 1; shown = false end },
        OpenButton = { HookScript = function(self, name, fn) hooks.openClick = fn end },
      }
      _G.QuestMapFrame = qmf
      ctx.ns.map.linkQuestLog()
      return {
        clicks = function() return clicks end, hooks = hooks,
        open = function() shown = true end,
      }
    end
    local function cleanup() WorldMapFrame.SidePanelToggle = nil _G.QuestMapFrame = nil end

    it("closes the map's quest log when the guide panel opens", function()
      local q = fakeQuestLog()
      ctx.ns.guideBrowser.toggleDock()
      expect(dock():IsShown()).toBe(true)
      expect(q.clicks()).toBe(1)
      cleanup()
    end)

    it("does not touch the quest log when it is already closed", function()
      local q = fakeQuestLog()
      _G.QuestMapFrame.IsShown = function() return false end
      ctx.ns.guideBrowser.toggleDock()
      expect(q.clicks()).toBe(0)
      cleanup()
    end)

    it("closes the guide panel when the map's quest log opens, by showing or by its open button", function()
      local q = fakeQuestLog()
      ctx.ns.guideBrowser.toggleDock()
      expect(dock():IsShown()).toBe(true)
      q.open()
      q.hooks.OnShow()
      expect(dock():IsShown()).toBe(false)
      ctx.ns.guideBrowser.toggleDock()
      q.open()
      q.hooks.openClick()
      expect(dock():IsShown()).toBe(false)
      cleanup()
    end)

    it("does not close itself while it is the one closing the quest log", function()
      local q = fakeQuestLog()
      WorldMapFrame.SidePanelToggle.CloseButton.Click = function() q.hooks.OnShow() end   -- a close that re-fires the hook
      ctx.ns.guideBrowser.toggleDock()
      expect(dock():IsShown()).toBe(true)
      cleanup()
    end)

    it("links the hooks only once however often it is asked", function()
      local q = fakeQuestLog()
      local count = 0
      _G.QuestMapFrame.HookScript = function() count = count + 1 end
      ctx.ns.map.linkQuestLog()
      ctx.ns.map.linkQuestLog()
      expect(count).toBe(0)       -- already linked by fakeQuestLog
      cleanup()
    end)
  end)

  describe("opening at the step", function()
    it("scrolls the chapter list and the step list to the player's place when the panel opens", function()
      Ribbon.Guide("g2", { schema = 1 })     -- (the one guide is already registered; this is refused and ignored)
      ctx.ns.guidePlayer.jump(1, 2)
      local d = open()
      expect(d.rightScroll.SetVerticalScroll).toHaveBeenCalled()
      expect(d.leftScroll.SetVerticalScroll).toHaveBeenCalled()
    end)

    it("centres a row in its column and never scrolls above the top", function()
      local d = open()
      d.rightScroll.GetHeight = function() return 200 end
      d.rightScroll.GetVerticalScrollRange = function() return 1000 end
      d.rightScroll.SetVerticalScroll.calls = {}
      ctx.ns.guidePlayer.jump(1, 2)                     -- step 2 of the chapter
      local calls = d.rightScroll.SetVerticalScroll.calls
      expect(calls[#calls][1]).toBe(0)                   -- row 2 is 20 px down: inside the first screenful
    end)

    it("follows the step as it changes", function()
      local d = open()
      d.rightScroll.SetVerticalScroll.calls = {}
      ctx.ns.guidePlayer.skip()
      expect(#d.rightScroll.SetVerticalScroll.calls).toBeGreaterThan(0)
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
