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

    it("is gold on a bronze groove that shows even when the bar is empty", function()
      local b = ctx.ns.map.guideButton
      local c = b.fill.SetColorTexture.calls[1]
      expect(c[1]).toBeGreaterThan(c[3] + 0.4)
      local g = b.track.SetColorTexture.calls[1]
      expect(g[1] + g[2] + g[3]).toBeGreaterThan(0.6)            -- not black on the dark face
      expect(b.track:IsShown()).toBe(true)
    end)

    it("is at least a few pixels long once any progress is made, so the start of the guide shows", function()
      local b = ctx.ns.map.guideButton
      ctx.ns.guidePlayer.jump(1, 2)                              -- 1 of 5 steps
      expect(lastCall(b.fill.SetWidth)[1]).toBeGreaterThan(S.toggle.loader.min - 0.001)
      local ctx2 = ctx
      expect(S.toggle.loader.height).toBeGreaterThan(3)
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

  describe("no fixed header", function()
    it("has no Steps or Chapters header bar above the lists", function()
      local d = open()
      expect(d.header).toBeNil()
      expect(d.folded).toBeNil()
    end)
  end)

  describe("section headers in search results", function()
    local function type_(d, t)
      d.search:SetText(t)
      d.search:Trigger("OnTextChanged", true)
    end

    it("group the matching steps of every chapter under a header naming the chapter", function()
      local d = open()
      type_(d, "accept")                                           -- every step accepts something
      local _, right = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1, "accept")
      local shape = {}
      for _, r in ipairs(right) do shape[#shape + 1] = r.header and "H" or "s" end
      expect(table.concat(shape)).toBe("HsssHss")
      expect(right[1].label).toBe("Camp Narache")
      expect(right[1].count).toBe(3)
      expect(right[5].label).toBe("Second Place")
      expect(right[5].count).toBe(2)
    end)

    it("are laid out with their own height, one under the other", function()
      local d = open()
      type_(d, "accept")
      local rows = d.rightRows.items
      local function pt(row) local c = row.SetPoint.calls return c[#c][4], c[#c][5] end
      local _, y1 = pt(rows[1])
      local _, y2 = pt(rows[2])
      local _, y5 = pt(rows[5])
      expect(y1).toBe(0)
      expect(y2).toBe(-24)                                         -- under a 24 px header
      expect(y5).toBe(-(24 + 3 * 34))                              -- under the header and three 34 px steps
      expect(rows[1].SetHeight).toHaveBeenCalledWith(24)
      expect(rows[2].SetHeight).toHaveBeenCalledWith(34)
      expect(d.rightContent.SetHeight.calls[#d.rightContent.SetHeight.calls][1]).toBe(24 + 3 * 34 + 24 + 2 * 34)
    end)

    it("look like the quest log's headers: a dark bar and the name with a count, no step parts", function()
      local d = open()
      type_(d, "accept")
      local head = d.rightRows.items[1]
      expect(head.headBg:IsShown()).toBe(true)
      expect(head.icon:IsShown()).toBe(false)
      expect(head.label:IsShown()).toBe(false)
      local texts = head.headText.SetText.calls
      expect(texts[#texts][1]).toContain("Camp Narache")
      expect(texts[#texts][1]).toContain("(3)")
      local step = d.rightRows.items[2]
      expect(step.headBg:IsShown()).toBe(false)
      expect(step.icon:IsShown()).toBe(true)
    end)

    it("do nothing when clicked and take no hover look", function()
      local d = open()
      type_(d, "accept")
      local head = d.rightRows.items[1]
      head:Trigger("OnClick")
      expect(d.rightRows.items[1].sel:IsShown()).toBe(false)
      head:Trigger("OnEnter")
      expect(head.glow:IsShown()).toBe(false)
    end)

    it("are not there when nothing is searched for", function()
      local d = open()
      expect(d.rightRows.items[1].isHeader).toBe(false)
    end)
  end)

  describe("the back button", function()
    it("is at the start of the search row, inside the panel's own content", function()
      local d = open()
      expect(d.back.SetPoint).toHaveBeenCalledWith("TOPLEFT", d, "TOPLEFT", S.bezel.band + 8, -(S.bezel.band + S.bezel.title + 5))
      expect(d.search.SetPoint).toHaveBeenCalledWith("TOPLEFT", d, "TOPLEFT", S.bezel.band + 8 + 30, -(S.bezel.band + S.bezel.title + 6))
      expect(d.back:IsShown()).toBe(true)
    end)
  end)

  describe("the button's icons", function()
    it("are sized to the button, with a bold star that fills its box", function()
      local b = ctx.ns.map.guideButton
      local side = math.min(S.toggle.width, S.toggle.height)
      local icon = math.floor(side * S.toggle.icon + 0.5)
      expect(b.icon.SetSize).toHaveBeenCalledWith(icon, icon)
      expect(S.toggle.iconFill).toBeGreaterThan(0.9)
      expect(icon * S.toggle.iconFill).toBeGreaterThan(16)        -- what you see of the star is at least 16 px
    end)

    it("are centred as a pair by what you see of them, not by their boxes", function()
      local b = ctx.ns.map.guideButton
      local side = math.min(S.toggle.width, S.toggle.height)
      local caret, icon = math.floor(side * S.toggle.caret + 0.5), math.floor(side * S.toggle.icon + 0.5)
      local caretSeen, iconSeen = caret * S.toggle.caretFill, icon * S.toggle.iconFill
      local between = side * S.toggle.between
      local start = (S.toggle.width - (caretSeen + between + iconSeen)) / 2
      local c = b.caret.SetPoint.calls[#b.caret.SetPoint.calls]
      local n = b.icon.SetPoint.calls[#b.icon.SetPoint.calls]
      expect(c[1]).toBe("CENTER")
      expect(c[4]).toBeCloseTo(start + caretSeen / 2, 4)
      expect(n[4]).toBeCloseTo(start + caretSeen + between + iconSeen / 2, 4)
      -- the same space is left either side of what you see
      local leftMargin = c[4] - caretSeen / 2
      local rightMargin = S.toggle.width - (n[4] + iconSeen / 2)
      expect(leftMargin).toBeCloseTo(rightMargin, 4)
    end)

    it("keep the star and the caret inside the button", function()
      local side = math.min(S.toggle.width, S.toggle.height)
      local seen = side * S.toggle.caret * S.toggle.caretFill + side * S.toggle.between + side * S.toggle.icon * S.toggle.iconFill
      expect(seen).toBeLessThan(S.toggle.width)
    end)
  end)
end)
