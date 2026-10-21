local H = require("tests.helpers.addon")

-- A two-chapter guide on Stormwind City (1453), which the fake world knows: 3 + 2 visible steps.
local function build(R)
  R:Names({ QUEST = { [1] = "One", [2] = "Two", [3] = "Three", [4] = "Four", [5] = "Five" } })
  R:Chapter("Camp Narache", { levels = { 1, 5 } })
    :Step():Goto(1453, 50, 50):Accept(1)
    :Step():Goto(1453, 51, 51):Accept(2)
    :Step():Goto(1453, 52, 52):Accept(3)
    :Done()
  R:Chapter("11-12 Sentinel Hill (Westfall) \226\134\146 Report to Gryan", { levels = { 11, 12 } })
    :Step():Goto(1453, 60, 60):Accept(4)
    :Step():Goto(1453, 61, 61):Accept(5)
    :Done()
  return R
end

describe("Guide progress", function()
  describe("planner", function()
    local ns = H.pure({ "guide/Planner.lua", "guide/Text.lua" })
    local P, T = ns.guidePlanner, ns.guideText
    local view = {
      { index = 1, name = "a", steps = { {}, {}, {} } },
      { index = 2, name = "b", steps = { {}, {} } },
    }
    local flat = { 1, 2, 3, 4, 5 }

    it("counts the steps before the cursor as done, per chapter and overall", function()
      local p = P.progress(view, flat, 4)       -- on the first step of chapter 2
      expect(p.done).toBe(3)
      expect(p.total).toBe(5)
      expect(p.fraction).toBeCloseTo(0.6, 6)
      expect(p.chapters[1]).toEqual({ done = 3, total = 3, fraction = 1 })
      expect(p.chapters[2]).toEqual({ done = 0, total = 2, fraction = 0 })
    end)

    it("splits a chapter part-way", function()
      local p = P.progress(view, flat, 2)
      expect(p.chapters[1].done).toBe(1)
      expect(p.chapters[1].fraction).toBeCloseTo(1 / 3, 6)
      expect(p.chapters[2].done).toBe(0)
    end)

    it("is complete when finished and empty when there is no guide", function()
      expect(P.progress(view, flat, 6).fraction).toBe(1)
      expect(P.progress(view, flat, nil).done).toBe(5)
      expect(P.progress({}, {}, 1).fraction).toBe(0)
    end)

    it("keeps a chapter's level range on the view", function()
      local guide = { chapters = { { name = "c", opts = { levels = { 1, 5 } }, steps = { { groups = {} } } } } }
      expect(P.view(guide, {})[1].levels).toEqual({ 1, 5 })
    end)

    it("splits a chapter name at its arrow", function()
      local place, goal = T.chapterParts("11-12 Sentinel Hill (Westfall) \226\134\146 Report to Gryan")
      expect(place).toBe("11-12 Sentinel Hill (Westfall)")
      expect(goal).toBe("Report to Gryan")
      local only, none = T.chapterParts("1-11 Teldrassil (NightElf)")
      expect(only).toBe("1-11 Teldrassil (NightElf)")
      expect(none).toBeNil()
    end)
  end)

  describe("panel", function()
    local ctx = H.use({ boot = true })
    beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

    it("gives each chapter card its levels and progress", function()
      ctx.ns.guidePlayer.jump(1, 3)
      local left = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1)
      expect(left[1].levels).toEqual({ 1, 5 })
      expect(left[1].done).toBe(2)
      expect(left[1].total).toBe(3)
      expect(left[2].done).toBe(0)
    end)

    it("writes 'Lv a-b - percent' on the second line", function()
      local B = ctx.ns.guideBrowser
      expect(B.subtitle({ levels = { 12, 14 }, fraction = 0.48 })).toContain("Lv 12-14 - 48%")
      expect(B.subtitle({ levels = { 5, 5 }, fraction = 1 })).toContain("Lv 5 - 100%")
      expect(B.subtitle({ fraction = 0 })).toContain("0%")
    end)

    it("shows the place on the card, the percent in the subtitle and a filled bar", function()
      ctx.ns.guidePlayer.jump(2, 1)               -- chapter 1 is done
      ctx.ns.guideBrowser.toggle()
      local frame = ctx.ns.guideBrowser.frame()
      local card = frame.leftRows.items[2]
      expect(card.label.SetText).toHaveBeenCalled()
      local text = card.label.SetText.calls[#card.label.SetText.calls][1]
      expect(text).toContain("11-12 Sentinel Hill (Westfall)")
      expect(text).never.toContain("Report to Gryan")
      expect(frame.leftRows.items[1].sub.SetText.calls[#frame.leftRows.items[1].sub.SetText.calls][1]).toContain("100%")
      expect(frame.leftRows.items[1].bar.fill:IsShown()).toBe(true)
      expect(frame.leftRows.items[2].bar.fill:IsShown()).toBe(false)
    end)

    it("shows the overall percent of the whole guide", function()
      ctx.ns.guidePlayer.jump(2, 1)               -- 3 of 5 steps done
      ctx.ns.guideBrowser.toggle()
      local frame = ctx.ns.guideBrowser.frame()
      expect(frame.overallText.SetText).toHaveBeenCalledWith("60%")
    end)

    it("opens with /ribbon guides", function()
      SlashCmdList.RIBBON("guides")
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(true)
      SlashCmdList.RIBBON("guides")
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(false)
    end)
  end)

  describe("compass click", function()
    local ctx = H.use({ boot = true })

    it("does nothing without a guide", function()
      ctx.ns.compass.parts.frame:Trigger("OnMouseUp", "LeftButton")
      expect(ctx.ns.guideBrowser.frame()).toBeNil()
    end)

    it("opens the panel on a plain left click and closes it on the next", function()
      build(Ribbon.Guide("g", { schema = 1 }))
      local frame = ctx.ns.compass.parts.frame
      frame:Trigger("OnMouseUp", "LeftButton")
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(true)
      frame:Trigger("OnMouseUp", "LeftButton")
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(false)
    end)

    it("ignores the mouse-up that ends a drag and other buttons", function()
      build(Ribbon.Guide("g", { schema = 1 }))
      local frame = ctx.ns.compass.parts.frame
      frame:Trigger("OnDragStart")
      frame:Trigger("OnDragStop")
      frame:Trigger("OnMouseUp", "LeftButton")
      expect(ctx.ns.guideBrowser.frame()).toBeNil()
      frame:Trigger("OnMouseUp", "LeftButton")      -- the next click is a click again
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(true)
      frame:Trigger("OnMouseUp", "RightButton")
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(true)
    end)
  end)

  describe("map button", function()
    local ctx = H.use({ boot = true })

    it("does not exist without a guide", function()
      expect(ctx.ns.map.guideButton).toBeNil()
    end)

    it("appears once a guide registers and toggles the panel", function()
      build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 }))
      local button = ctx.ns.map.guideButton
      expect(button).toBeTruthy()
      expect(button.icon.SetTexture).toHaveBeenCalledWith("Interface\\AddOns\\Ribbon\\icon")
      button:Trigger("OnClick")
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(true)
      button:Trigger("OnClick")
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(false)
    end)
  end)

  describe("map button when the guide loads first", function()
    it("is there after login", function()
      local ns, world = H.load({})
      build(Ribbon.Guide("early", { schema = 1 }))
      world:fireEvent("PLAYER_LOGIN")
      expect(ns.map.guideButton).toBeTruthy()
    end)
  end)
end)
