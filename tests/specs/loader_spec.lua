local H = require("tests.helpers.addon")

-- Chapter one: three steps; chapter two: two steps (5 visible steps in all).
local function build(R)
  R:Chapter("Camp Narache", { levels = { 1, 5 } })
    :Step():Goto(1453, 50, 50):Accept(1)
    :Step():Goto(1453, 51, 51):Accept(2)
    :Step():Goto(1453, 52, 52):Accept(3)
    :Done()
  R:Chapter("Second Place", { levels = { 6, 8 } })
    :Step():Goto(1453, 60, 60):Accept(4)
    :Step():Goto(1453, 61, 61):Accept(5)
    :Done()
  return R
end

describe("Progress on the map button, and the section header", function()
  local ctx = H.use({ boot = true })
  local S
  local function dock() return ctx.ns.guideBrowser.dock() end
  local function open()
    ctx.ns.guideBrowser.toggleDock()
    return dock()
  end
  local function lastCall(spy) return spy.calls[#spy.calls] end
  beforeEach(function()
    S = ctx.ns.compassStyle
    build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 }))
  end)

  describe("the loader bar on the map button", function()
    it("sits along the bottom edge of the button, inside the border", function()
      local b = ctx.ns.map.guideButton
      local l = S.toggle.loader
      expect(b.fill.SetPoint).toHaveBeenCalledWith("BOTTOMLEFT", b, "BOTTOMLEFT", l.inset, l.inset)
      expect(b.track.SetPoint).toHaveBeenCalledWith("BOTTOMRIGHT", b, "BOTTOMRIGHT", -l.inset, l.inset)
      expect(b.fill.SetHeight).toHaveBeenCalledWith(l.height)
    end)

    it("is empty at the start and fills as the player goes through the guide", function()
      local b = ctx.ns.map.guideButton
      expect(b.fill:IsShown()).toBe(false)
      ctx.ns.guidePlayer.jump(2, 1)                          -- 3 of 5 steps done
      local inner = S.toggle.width - 2 * S.toggle.loader.inset
      expect(lastCall(b.fill.SetWidth)[1]).toBeCloseTo(0.6 * inner, 4)
      expect(b.fill:IsShown()).toBe(true)
      ctx.ns.guidePlayer.jump(2, 2)
      expect(lastCall(b.fill.SetWidth)[1]).toBeCloseTo(0.8 * inner, 4)
    end)

    it("is gold on a dark track", function()
      local b = ctx.ns.map.guideButton
      local c = b.fill.SetColorTexture.calls[1]
      expect(c[1]).toBeGreaterThan(c[3] + 0.4)
      expect(b.track.SetColorTexture.calls[1][4]).toBeGreaterThan(0.3)
    end)

    it("follows the button's size", function()
      local b = ctx.ns.map.guideButton
      b.GetWidth = function() return 40 end
      ctx.ns.guidePlayer.jump(2, 1)
      expect(lastCall(b.fill.SetWidth)[1]).toBeCloseTo(0.6 * (40 - 2 * S.toggle.loader.inset), 4)
    end)

    it("reports the guide's and the chapter's progress for its tooltip", function()
      ctx.ns.guidePlayer.jump(1, 2)
      local overall, chapter, name = ctx.ns.guideBrowser.progress()
      expect(overall).toBeCloseTo(1 / 5, 6)
      expect(chapter).toBeCloseTo(1 / 3, 6)
      expect(name).toBe("Camp Narache")
    end)

    it("shows the percentages only on hover", function()
      ctx.ns.guidePlayer.jump(1, 2)
      GameTooltip.AddLine.calls = {}
      ctx.ns.map.guideButton:Trigger("OnEnter")
      local lines = {}
      for _, c in ipairs(GameTooltip.AddLine.calls) do lines[#lines + 1] = c[1] end
      expect(lines[1]).toBe("Guide: 20%")
      expect(lines[2]).toBe("Camp Narache: 33%")
    end)
  end)

  describe("the panel has no progress bar or percentage of its own", function()
    it("has neither the bar nor its text", function()
      local d = open()
      expect(d.overall).toBeNil()
      expect(d.overallText).toBeNil()
    end)

    it("shows a card's percentage only when the mouse is over it", function()
      local d = open()
      ctx.ns.guidePlayer.jump(1, 3)                          -- 2 of 3 done in chapter one
      ctx.ns.guideBrowser.showChapters()
      local card = d.leftRows.items[1]
      expect(card.sub.SetText.calls[#card.sub.SetText.calls][1]).never.toContain("%")
      card:Trigger("OnEnter")
      expect(GameTooltip.SetText).toHaveBeenCalledWith("2 of 3 steps (67%)")
      card:Trigger("OnLeave")
    end)
  end)

  describe("the section header", function()
    it("is called Steps on the child page and Chapters on the list", function()
      local d = open()
      expect(d.header.title.SetText).toHaveBeenCalledWith("Steps")
      ctx.ns.guideBrowser.showChapters()
      expect(d.header.title.SetText).toHaveBeenCalledWith("Chapters")
    end)

    it("folds the list away with its button: a minus while open, a plus while folded", function()
      local d = open()
      expect(d.header.toggle.vertical:IsShown()).toBe(false)     -- a minus
      expect(d.rightScroll:IsShown()).toBe(true)
      d.header.toggle:Trigger("OnClick")
      expect(d.rightScroll:IsShown()).toBe(false)
      expect(d.header.toggle.vertical:IsShown()).toBe(true)       -- a plus
      d.header.toggle:Trigger("OnClick")
      expect(d.rightScroll:IsShown()).toBe(true)
      expect(d.header.toggle.vertical:IsShown()).toBe(false)
    end)

    it("also folds when the whole bar is clicked", function()
      local d = open()
      d.header:Trigger("OnClick")
      expect(d.rightScroll:IsShown()).toBe(false)
    end)

    it("remembers a fold for each page on its own", function()
      local d = open()
      d.header.toggle:Trigger("OnClick")                          -- fold the steps
      ctx.ns.guideBrowser.showChapters()
      expect(d.leftScroll:IsShown()).toBe(true)                   -- the chapters are not folded
      ctx.ns.guideBrowser.showSteps()
      expect(d.rightScroll:IsShown()).toBe(false)
    end)

    it("is a dark bar with a gold border like the quest log's header", function()
      local d = open()
      expect(d.header.bg.SetColorTexture.calls[1][1]).toBeLessThan(0.2)
      expect(d.header.SetHeight).toHaveBeenCalledWith(24)
    end)
  end)

  describe("the button's icons", function()
    it("are bigger now: the needle fills most of the button", function()
      local b = ctx.ns.map.guideButton
      local side = math.min(S.toggle.width, S.toggle.height)
      expect(S.toggle.icon).toBeGreaterThan(0.7)
      expect(b.icon.SetSize).toHaveBeenCalledWith(math.floor(side * S.toggle.icon + 0.5), math.floor(side * S.toggle.icon + 0.5))
    end)
  end)
end)
