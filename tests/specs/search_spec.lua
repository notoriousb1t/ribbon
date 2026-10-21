local H = require("tests.helpers.addon")

describe("Guide search", function()
  describe("matching", function()
    local S = H.pure({ "guide/Search.lua" }).guideSearch
    local function m(q, t) return S.matches(q, t) end

    it("matches an empty query against anything", function()
      expect(m("", "anything")).toBe(true)
      expect(m("   ", "")).toBe(true)
    end)

    it("ignores case and punctuation", function()
      expect(m("CROSSROADS", "11-13 Crossroads (The Barrens)")).toBe(true)
      expect(m("barrens", "11-13 Crossroads (The Barrens)")).toBe(true)
      expect(m("fp", "Ratchet FP")).toBe(true)
    end)

    it("finds a word typed with letters left out: crssrods finds Crossroads", function()
      expect(m("crssrods", "Crossroads")).toBe(true)
      expect(m("crsrds", "11-13 Crossroads (The Barrens)")).toBe(true)
      expect(m("brghtwsh", "Accept The Gift of Skysight from Ventaari Brightwish")).toBe(true)
    end)

    it("forgives one slip: a wrong, extra or missing letter, or two swapped", function()
      expect(m("crossraods", "Crossroads")).toBe(true)     -- swapped
      expect(m("crosroads", "Crossroads")).toBe(true)      -- missing
      expect(m("croossroads", "Crossroads")).toBe(true)    -- extra
      expect(m("crossrnads", "Crossroads")).toBe(true)     -- wrong
    end)

    it("needs every word of the query", function()
      expect(m("crossroads barrens", "11-13 Crossroads (The Barrens)")).toBe(true)
      expect(m("crossroads ashenvale", "11-13 Crossroads (The Barrens)")).toBe(false)
    end)

    it("does not match unrelated text", function()
      expect(m("crossroads", "Westfall Sentinel Hill")).toBe(false)
      expect(m("zzzz", "Crossroads")).toBe(false)
      expect(m("stormwind", "Crossroads (The Barrens)")).toBe(false)
    end)

    it("makes a single letter start a word instead of matching everything", function()
      expect(m("c", "Crossroads")).toBe(true)
      expect(m("c", "Westfall Hill")).toBe(false)
      expect(m("w", "Westfall Hill")).toBe(true)
    end)

    it("does not let a few letters match a long word they merely appear in", function()
      expect(m("xyz", "Crossroads")).toBe(false)
      expect(m("rdz", "Crossroads")).toBe(false)         -- must start with the word's own first letter
    end)

    it("filters a list in order and returns it whole for an empty query", function()
      local items = { { t = "Crossroads" }, { t = "Westfall" }, { t = "Crossing Point" } }
      local function text(i) return i.t end
      expect(#S.filter(items, "", text)).toBe(3)
      local got = S.filter(items, "cross", text)
      expect(#got).toBe(2)
      expect(got[1].t).toBe("Crossroads")
      expect(got[2].t).toBe("Crossing Point")
    end)
  end)

  describe("in the panel", function()
    local ctx = H.use({ boot = true })

    local function build(R)
      R:Names({ QUEST = { [1] = "Kodo Hunt", [2] = "Lost Harness", [3] = "Water Pouch" } })
      R:Chapter("11-13 Crossroads (The Barrens)", { levels = { 11, 13 } })
        :Step():Goto(1453, 50, 50):Accept(1)
        :Step():Goto(1453, 52, 52):Accept(2)
        :Done()
      R:Chapter("14-16 Silverpine Forest", { levels = { 14, 16 } })
        :Step():Goto(1453, 60, 60):Accept(3)
        :Done()
      return R
    end
    local function open()
      ctx.ns.guideBrowser.toggleDock()
      return ctx.ns.guideBrowser.dock()
    end
    local function shownCount(rows, n)
      local c = 0
      for i = 1, n do if rows.items[i] and rows.items[i]:IsShown() then c = c + 1 end end
      return c
    end
    local function type_(d, text)
      d.search:SetText(text)
      d.search:Trigger("OnTextChanged", true)
    end
    beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

    it("has a search box under the title bar", function()
      local d = open()
      expect(d.search).toBeTruthy()
      expect(d.search.hint.SetText).toHaveBeenCalledWith("Search chapters and steps")
      expect(d.search.hint:IsShown()).toBe(true)
      expect(d.search.clear:IsShown()).toBe(false)
    end)

    it("finds a chapter by a misspelt name: crssrods leaves only Crossroads on the chapter list", function()
      local d = open()
      d.back:Trigger("OnClick")
      type_(d, "crssrods")
      local left = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, nil, "crssrods")
      expect(#left).toBe(1)
      expect(left[1].label).toContain("Crossroads")
      expect(shownCount(d.leftRows, 2)).toBe(1)
    end)

    it("finds a chapter by something one of its steps says", function()
      local left = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, nil, "water pouch")
      expect(#left).toBe(1)
      expect(left[1].label).toContain("Silverpine")
    end)

    it("finds a chapter by its levels", function()
      local left = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, nil, "level 14")
      expect(#left).toBe(1)
      expect(left[1].label).toContain("Silverpine")
    end)

    it("narrows the step list to the steps that match, under a header naming their chapter", function()
      local d = open()                                           -- on the steps of chapter one
      type_(d, "harnss")                                         -- "Lost Harness", misspelt
      expect(shownCount(d.rightRows, 3)).toBe(2)                 -- the chapter's header and the step
      expect(d.rightRows.items[1].isHeader).toBe(true)
      expect(d.rightRows.items[2].isHeader).toBe(false)
      local texts = d.rightRows.items[2].label.SetText.calls
      expect(texts[#texts][1]).toContain("Lost Harness")
    end)

    it("searches any text a step says, not just its first line", function()
      local _, right = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1, "kodo")
      expect(#right).toBe(2)                                     -- a section header and the step
      expect(right[1].header).toBe(true)
      expect(right[2].step).toBe(1)
      local _, none = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1, "zzzzz")
      expect(#none).toBe(0)
    end)

    it("says so when nothing matches, and goes away when the search is cleared", function()
      local d = open()
      type_(d, "zzzzz")
      expect(d.empty:IsShown()).toBe(true)
      type_(d, "")
      expect(d.empty:IsShown()).toBe(false)
    end)

    it("shows the clear button and hides the hint while there is text", function()
      local d = open()
      type_(d, "kodo")
      expect(d.search.clear:IsShown()).toBe(true)
      expect(d.search.hint:IsShown()).toBe(false)
      d.search.clear:Trigger("OnClick")
      expect(d.search:GetText()).toBe("")
      expect(d.search.clear:IsShown()).toBe(false)
      expect(d.search.hint:IsShown()).toBe(true)
      expect(shownCount(d.rightRows, 3)).toBe(2)                 -- everything is back: chapter one's two steps, no headers
      expect(d.rightRows.items[1].isHeader).toBe(false)
    end)

    it("leaves what is typed alone while the player is typing (no rewriting a trailing space)", function()
      local d = open()
      d.search:SetText("kodo ")
      d.search:Trigger("OnTextChanged", true)
      expect(d.search:GetText()).toBe("kodo ")
    end)

    it("clears on Escape, and leaves the box when it is already empty", function()
      local d = open()
      type_(d, "kodo")
      d.search:Trigger("OnEscapePressed")
      expect(d.search:GetText()).toBe("")
      expect(d.search.ClearFocus).never.toHaveBeenCalled()
      d.search:Trigger("OnEscapePressed")
      expect(d.search.ClearFocus).toHaveBeenCalled()
    end)

    it("starts empty every time the panel opens", function()
      local d = open()
      type_(d, "kodo")
      d.close:Trigger("OnClick")
      d = open()
      expect(d.search:GetText()).toBe("")
      expect(shownCount(d.rightRows, 3)).toBe(2)
    end)

    it("still jumps by the real step when the list is narrowed", function()
      local d = open()
      type_(d, "harness")                                        -- the header, then step two
      local row = d.rightRows.items[2]
      expect(row.step).toBe(2)
      row.go:Trigger("OnClick")
      expect(ctx.ns.guidePlayer.current().index).toBe(2)
    end)

    it("scrolls to the top of the results while searching", function()
      local d = open()
      d.rightScroll.SetVerticalScroll.calls = {}
      type_(d, "kodo")
      local calls = d.rightScroll.SetVerticalScroll.calls
      expect(calls[#calls][1]).toBe(0)
    end)
  end)

  describe("the back button", function()
    local ctx = H.use({ boot = true })
    beforeEach(function()
      Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
        :Step():Goto(1453, 50, 50):Accept(1):Done()
    end)

    it("is drawn from Ribbon's own textures in the game's frame too, over the title bar's art", function()
      _G.ButtonFrameTemplate_HidePortrait = function() end
      ctx.ns.guideBrowser.toggleDock()
      local d = ctx.ns.guideBrowser.dock()
      expect(d.native).toBe(true)
      expect(d.back.bg.SetTexture).toHaveBeenCalledWith(ctx.ns.compassStyle.textures.bezelButton)
      expect(d.back.caret.SetTexture).toHaveBeenCalledWith(ctx.ns.compassStyle.textures.panelCaret)
      expect(d.back.SetFrameLevel.calls[#d.back.SetFrameLevel.calls][1]).toBeGreaterThan(d:GetFrameLevel() + 10)
      _G.ButtonFrameTemplate_HidePortrait = nil
    end)

    it("shows on the steps page and not on the chapter list", function()
      ctx.ns.guideBrowser.toggleDock()
      local d = ctx.ns.guideBrowser.dock()
      expect(d.back:IsShown()).toBe(true)
      ctx.ns.guideBrowser.showChapters()
      expect(d.back:IsShown()).toBe(false)
    end)
  end)
end)
