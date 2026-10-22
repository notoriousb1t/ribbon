local H = require("tests.helpers.addon")

local function build(R)
  R:Chapter("Camp Narache", { levels = { 1, 5 } })
    :Step():Goto(1453, 50, 50):Accept(1)
    :Step():Goto(1453, 51, 51):Accept(2)
    :Done()
  R:Chapter("Chapter Two \226\134\146 Report in", { levels = { 6, 8 } })
    :Step():Goto(1453, 60, 60):Accept(3)
    :Step():Goto(1453, 61, 61):Accept(4)
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

    it("has a dark title bar and a gold title and rule, like the map", function()
      local d = open()
      local c = d.strip.SetColorTexture.calls[1]
      expect(c[1] + c[2] + c[3]).toBeLessThan(0.5)
      local t = d.title.SetTextColor.calls[1]
      expect(t[1]).toBeGreaterThan(t[3] + 0.4)        -- gold: much more red than blue
    end)

    it("is about as thin as the map's own frame", function()
      expect(S.bezel.band).toBeLessThan(11)
      expect(S.bezel.band).toBeGreaterThan(6)
    end)
  end)

  describe("title bar and buttons", function()
    it("shows just the guide's title, in the middle of the bar", function()
      local d = open()
      expect(d.title.SetText).toHaveBeenCalledWith("Test Guide")
      expect(d.title.SetPoint).toHaveBeenCalledWith("CENTER", d.strip, "CENTER", 0, 0)
      expect(d.progress).toBeNil()           -- no "Step n of x"
    end)

    it("has an X at the top right of the frame", function()
      local d = open()
      expect(d.close:IsShown()).toBe(true)
    end)

    it("still closes through its (hidden) close button's script", function()
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
      expect(d.leftScroll.SetPoint).toHaveBeenCalledWith("BOTTOMLEFT", d, "BOTTOMLEFT", S.bezel.band + 6, S.bezel.band + 8 + S.toggle.loader.height + 2 + 14)
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
      WorldMapFrame.SidePanelToggle = nil
    end)

    it("is the same size as the map's toggle and sits just above it, right edges level", function()
      ctx.ns.map.guideButton = nil
      RibbonGuideMapButton = nil
      local toggle = { GetObjectType = function() return "Frame" end, GetWidth = function() return 31 end, GetHeight = function() return 29 end }
      WorldMapFrame.SidePanelToggle = toggle
      ctx.ns.map.createGuideButton()
      local b = ctx.ns.map.guideButton
      expect(b.SetSize).toHaveBeenCalledWith(31, 29)
      expect(b.SetPoint).toHaveBeenCalledWith("BOTTOMRIGHT", toggle, "TOPRIGHT", 0, S.toggle.gap)
      WorldMapFrame.SidePanelToggle = nil
    end)

    it("lines up again when the map lays itself out later, and falls back to the style's size before then", function()
      ctx.ns.map.guideButton = nil
      RibbonGuideMapButton = nil
      local w, h = 0, 0
      local toggle = { GetObjectType = function() return "Frame" end, GetWidth = function() return w end, GetHeight = function() return h end }
      WorldMapFrame.SidePanelToggle = toggle
      ctx.ns.map.createGuideButton()
      local b = ctx.ns.map.guideButton
      expect(b.SetSize).toHaveBeenCalledWith(S.toggle.width, S.toggle.height)
      w, h = 34, 32
      ctx.ns.map.alignGuideButton()
      expect(b.SetSize).toHaveBeenCalledWith(34, 32)
      expect(WorldMapFrame.HookScript).toHaveBeenCalledWith("OnShow", ctx.ns.map.alignGuideButton)
      WorldMapFrame.SidePanelToggle = nil
    end)

    it("has a caret on the left and the middle of the compass on the right, sized to the button", function()
      local b = ctx.ns.map.guideButton
      local side = math.min(S.toggle.width, S.toggle.height)
      local caret, icon = math.floor(side * S.toggle.caret + 0.5), math.floor(side * S.toggle.icon + 0.5)
      expect(b.caret.SetTexture).toHaveBeenCalledWith(S.textures.panelCaret)
      expect(b.caret.SetSize).toHaveBeenCalledWith(caret, caret)
      expect(b.icon.SetTexture).toHaveBeenCalledWith(S.textures.panelNeedle)
      expect(b.icon.SetSize).toHaveBeenCalledWith(icon, icon)
      expect(caret + icon).toBeLessThan(side + 6)          -- side by side without piling on each other
    end)

    it("falls back to the map's bottom right corner without that toggle", function()
      local b = ctx.ns.map.guideButton
      expect(b.SetPoint).toHaveBeenCalledWith("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -10, 40)
    end)

    it("points its caret like the map's own toggle: left while the panel is out, right while it is put away", function()
      local b = ctx.ns.map.guideButton
      local function last() local c = b.caret.SetTexCoord.calls return { unpack(c[#c], 1, 4) } end
      expect(last()).toEqual({ 1, 0, 0, 1 })       -- closed: points right
      b:Trigger("OnClick")
      expect(last()).toEqual({ 0, 1, 0, 1 })       -- open: points left
      b:Trigger("OnClick")
      expect(last()).toEqual({ 1, 0, 0, 1 })
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
    it("scrolls the step list to the player's step when the panel opens, and the chapter list to the chapter on the way back", function()
      ctx.ns.guidePlayer.jump(1, 2)
      local d = open()
      expect(d.rightScroll.SetVerticalScroll).toHaveBeenCalled()
      ctx.ns.guideBrowser.showChapters()
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

  describe("in the game's own frame style", function()
    local function cleanup() _G.ButtonFrameTemplate_HidePortrait = nil end

    it("uses Blizzard's frame template, with its title text and red close button, when the game has it", function()
      local hidden
      _G.ButtonFrameTemplate_HidePortrait = function(f) hidden = f end
      local d = open()
      expect(d.native).toBe(true)
      expect(hidden).toBe(d)
      expect(d.bezel).toBeNil()                          -- nothing of ours is drawn on top of the template's art
      expect(d.strip).toBeNil()
      d.title:SetText("Chapter Two")
      expect(d.SetTitle).toHaveBeenCalledWith("Chapter Two")
      cleanup()
    end)

    it("hangs the lists from the template's inset and closes from its own close button", function()
      _G.ButtonFrameTemplate_HidePortrait = function() end
      local d = open()
      expect(d.leftScroll.SetPoint).toHaveBeenCalledWith("TOPLEFT", d, "TOPLEFT", 8, -(8 + 26 + 4))
      expect(d.leftScroll.SetPoint).toHaveBeenCalledWith("BOTTOMLEFT", d, "BOTTOMLEFT", 8, 8 + S.toggle.loader.height + 4 + 14)
      d.close:Trigger("OnClick")
      expect(d:IsShown()).toBe(false)
      cleanup()
    end)

    it("goes back with its arrow, which is Ribbon's own button in the game's frame too", function()
      _G.ButtonFrameTemplate_HidePortrait = function() end
      local d = open()
      expect(d.back.fill.SetTexture).toHaveBeenCalledWith(S.textures.markerFill)
      d.back:Trigger("OnClick")
      expect(d.page).toBe("chapters")
      cleanup()
    end)

    it("falls back to the gold bezel when the template cannot be made", function()
      _G.ButtonFrameTemplate_HidePortrait = function() end
      local real = _G.CreateFrame
      _G.CreateFrame = function(kind, name, parent, template)
        if template == "ButtonFrameTemplate" then error("no such template") end
        return real(kind, name, parent, template)
      end
      local d = open()
      _G.CreateFrame = real
      expect(d.native).toBe(false)
      expect(d.bezel).toBeTruthy()
      cleanup()
    end)

    it("draws its own gold bezel without the helper, in the map's dark warm colours", function()
      local d = open()
      expect(d.native).toBe(false)
      local c = d.strip.SetColorTexture.calls[1]
      expect(c[1]).toBeGreaterThan(c[3] - 0.001)          -- warm, not blue
      expect(S.panel.gold[1]).toBeGreaterThan(S.panel.gold[3] + 0.4)
    end)
  end)

  describe("parent list and child page", function()
    it("always opens on the child page: the active chapter's steps with the back arrow", function()
      ctx.ns.guidePlayer.jump(2, 1)
      local d = open()
      expect(d.page).toBe("steps")
      expect(d.rightScroll:IsShown()).toBe(true)
      expect(d.leftScroll:IsShown()).toBe(false)
      expect(d.back:IsShown()).toBe(true)
      expect(d.title.SetText).toHaveBeenCalledWith("Chapter Two")
    end)

    it("goes back to the chapter list with the arrow, hiding itself there", function()
      local d = open()
      d.back:Trigger("OnClick")
      expect(d.page).toBe("chapters")
      expect(d.leftScroll:IsShown()).toBe(true)
      expect(d.rightScroll:IsShown()).toBe(false)
      expect(d.back:IsShown()).toBe(false)
    end)

    it("goes into a chapter by clicking its card", function()
      local d = open()
      d.back:Trigger("OnClick")
      d.leftRows.items[2]:Trigger("OnClick")
      expect(d.page).toBe("steps")
      expect(d.title.SetText).toHaveBeenCalledWith("Chapter Two")
      expect(d.rightRows.items[2]:IsShown()).toBe(true)         -- chapter two has two steps
    end)

    it("opens on the child page again even if it was closed on the list", function()
      local d = open()
      d.back:Trigger("OnClick")
      d.close:Trigger("OnClick")
      ctx.ns.guideBrowser.toggleDock()
      expect(d.page).toBe("steps")
    end)

    it("keeps the page when a step completes, but returns to the active chapter", function()
      local d = open()
      d.back:Trigger("OnClick")
      ctx.ns.guidePlayer.skip()
      expect(d.page).toBe("chapters")
    end)

    it("lays the steps out in rows tall enough for two lines", function()
      local d = open()
      expect(d.rightRows.items[1].SetSize.calls[1][2]).toBe(34)
      expect(d.rightRows.items[1].label.SetMaxLines).toHaveBeenCalledWith(2)
    end)

    it("is one column wide", function()
      local d = open()
      expect(d.SetWidth.calls[1][1]).toBe(300 + 2 * ctx.ns.compassStyle.bezel.band + 12)
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

describe("The map button when the map is maximized", function()
  local H3 = require("tests.helpers.addon")
  local ctx = H3.use({ boot = true })
  beforeEach(function()
    Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
      :Step():Goto(1453, 50, 50):Accept(1):Done()
    WorldMapFrame.SidePanelToggle = { GetObjectType = function() return "Frame" end }
  end)

  it("goes below the map's own toggle, which has no room above it, and above it again once restored", function()
    local b = ctx.ns.map.guideButton
    local toggle = WorldMapFrame.SidePanelToggle
    WorldMapFrame.IsMaximized = function() return true end
    ctx.ns.map.alignGuideButton()
    expect(b.SetPoint).toHaveBeenCalledWith("TOPRIGHT", toggle, "BOTTOMRIGHT", 0, -ctx.ns.compassStyle.toggle.gap)
    WorldMapFrame.IsMaximized = function() return false end
    ctx.ns.map.alignGuideButton()
    expect(b.SetPoint).toHaveBeenCalledWith("BOTTOMRIGHT", toggle, "TOPRIGHT", 0, ctx.ns.compassStyle.toggle.gap)
    WorldMapFrame.IsMaximized = nil
  end)
end)
