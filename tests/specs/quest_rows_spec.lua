local H = require("tests.helpers.addon")

-- Chapter one: accept, a two-line kill step (two kills), a step with nothing to say; chapter two: one step.
local function build(R)
  R:Names({
    QUEST = { [1] = "Coming of Age", [2] = "The Hunt" },
    NPC = { [10] = "Rorian the Dayseeker" },
    CREATURE = { [20] = "Pesky Cirrusfly", [21] = "Juvenile Vuldren" },
  })
  R:Chapter("1-13 Zephras Isle (Skyborne)", { levels = { 1, 13 } })
    :Step():Goto(1453, 50, 50):Accept(1):At(10)
    :Step():Goto(1453, 52, 52):Kill(20, 8, { quest = 2, index = 1 }):Kill(21, 8, { quest = 2, index = 2 })
    :Step():Goto(1453, 54, 54):Turnin(1):At(10)
    :Done()
  R:Chapter("11-13 Crossroads (The Barrens)", { levels = { 11, 13 } })
    :Step():Goto(1453, 60, 60):Accept(2)
    :Done()
  return R
end

describe("Steps laid out like quests in the quest log", function()
  local ctx = H.use({ boot = true })
  local function dock() return ctx.ns.guideBrowser.dock() end
  local function open()
    ctx.ns.guideBrowser.toggleDock()
    return dock()
  end
  local function lastText(fs) local c = fs.SetText.calls return c[#c][1] end
  beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

  describe("rows", function()
    it("split a step into a title (its first line) and objectives (the rest)", function()
      local _, right = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1)
      expect(right[1].title).toBe("Accept Coming of Age from Rorian the Dayseeker")
      expect(#right[1].objectives).toBe(0)
      expect(right[2].title).toBe("Kill Pesky Cirrusfly (0/8)")
      expect(right[2].objectives).toEqual({ "Kill Juvenile Vuldren (0/8)" })
    end)

    it("carry no step number: the count is shown beside the search box instead", function()
      local _, right = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1)
      expect(right[2].position).toBeNil()
      expect(right[2].of).toBeNil()
    end)
  end)

  describe("the panel", function()
    it("titles each step in gold, like a quest's name, with no number in it", function()
      local d = open()
      local text = lastText(d.rightRows.items[1].label)
      expect(text).toContain("Accept Coming of Age")
      expect(text).never.toContain("[1/3]")
      expect(text).never.toContain("[")
      expect(text).toContain("|cffffd24a")                 -- the current step is the brightest gold
      expect(lastText(d.rightRows.items[3].label)).toContain("|cffe9b949")    -- the others are gold
    end)

    it("lists the objectives under the title with a dash, in plain text", function()
      local d = open()
      local objectives = lastText(d.rightRows.items[2].objectives)
      expect(objectives).toContain("- Kill Juvenile Vuldren (0/8)")
      expect(objectives).toContain("|cffe6e0cf")
      expect(lastText(d.rightRows.items[1].objectives)).toBe("")
    end)

    it("puts a gold glow behind the icon of the player's step only", function()
      local d = open()
      expect(d.rightRows.items[1].glow:IsShown()).toBe(true)
      expect(d.rightRows.items[2].glow:IsShown()).toBe(false)
    end)

    it("greys a step that is done and puts a check mark at its right", function()
      ctx.ns.guidePlayer.jump(1, 3)
      local d = open()
      expect(d.rightRows.items[1].check:IsShown()).toBe(true)
      expect(d.rightRows.items[3].check:IsShown()).toBe(false)
      expect(lastText(d.rightRows.items[1].label)).toContain("|cff808080")
    end)

    it("swaps the check for the hover arrow while the mouse is over a done step, and back", function()
      ctx.ns.guidePlayer.jump(1, 3)
      local d = open()
      local row = d.rightRows.items[1]
      row:Trigger("OnEnter")
      expect(row.go:IsShown()).toBe(true)
      expect(row.check:IsShown()).toBe(false)
      row:Trigger("OnLeave")
      expect(row.go:IsShown()).toBe(false)
      expect(row.check:IsShown()).toBe(true)
    end)

    it("makes a row as tall as its text, never less than its icon needs", function()
      local d = open()
      local plain, withObjectives = d.rightRows.items[1], d.rightRows.items[2]
      plain.label.GetStringHeight = function() return 14 end
      withObjectives.label.GetStringHeight = function() return 28 end            -- a title on two lines
      withObjectives.objectives.GetStringHeight = function() return 24 end       -- two objective lines
      ctx.ns.guideBrowser.refresh()
      expect(plain.SetHeight.calls[#plain.SetHeight.calls][1]).toBe(34)
      expect(withObjectives.SetHeight.calls[#withObjectives.SetHeight.calls][1]).toBe(10 + 28 + 24 + 2)
    end)

    it("stacks rows by their own heights", function()
      local d = open()
      d.rightRows.items[1].label.GetStringHeight = function() return 14 end
      d.rightRows.items[2].label.GetStringHeight = function() return 28 end
      d.rightRows.items[2].objectives.GetStringHeight = function() return 12 end
      ctx.ns.guideBrowser.refresh()
      local function y(row) local c = row.SetPoint.calls return c[#c][5] end
      expect(y(d.rightRows.items[1])).toBe(-24)                                  -- under the section header
      expect(y(d.rightRows.items[2])).toBe(-(24 + 34))
      expect(y(d.rightRows.items[3])).toBe(-(24 + 34 + 10 + 28 + 12 + 2))
    end)
  end)

  describe("the chapter's section header", function()
    it("tops the step list with the chapter's name, like the quest log's zone header", function()
      local d = open()
      expect(d.section:IsShown()).toBe(true)
      expect(d.section.headText.SetText).toHaveBeenCalledWith("1-13 Zephras Isle (Skyborne)")
      expect(d.section.headBg:IsShown()).toBe(true)
      expect(d.section.minus:IsShown()).toBe(true)
      expect(d.section.plus:IsShown()).toBe(false)
    end)

    it("folds the steps away, and a click opens them again", function()
      local d = open()
      d.section:Trigger("OnClick")
      expect(d.section.plus:IsShown()).toBe(true)                                -- a plus while folded
      expect(d.rightRows.items[1]:IsShown()).toBe(false)
      expect(d.rightContent.SetHeight.calls[#d.rightContent.SetHeight.calls][1]).toBe(24)
      d.section:Trigger("OnClick")
      expect(d.section.plus:IsShown()).toBe(false)
      expect(d.rightRows.items[1]:IsShown()).toBe(true)
    end)

    it("starts every section open when the panel is opened again", function()
      local d = open()
      d.section:Trigger("OnClick")
      d.close:Trigger("OnClick")
      d = open()
      expect(d.rightRows.items[1]:IsShown()).toBe(true)
    end)

    it("is a row of its own for each chapter while searching, and folds that chapter", function()
      local d = open()
      d.search:SetText("accept")
      d.search:Trigger("OnTextChanged", true)
      expect(d.section:IsShown()).toBe(false)
      local head = d.rightRows.items[1]
      expect(head.isHeader).toBe(true)
      expect(head.minus:IsShown()).toBe(true)
      head:Trigger("OnClick")                                                    -- fold chapter one's results
      expect(d.rightRows.items[1].plus:IsShown()).toBe(true)
      expect(d.rightRows.items[2].isHeader).toBe(true)                           -- the next row is chapter two's header
    end)
  end)

  describe("scrolling", function()
    it("brings the player's step to the middle using the rows' own positions", function()
      ctx.ns.guidePlayer.jump(1, 3)
      local d = open()
      d.rightScroll.GetHeight = function() return 100 end
      d.rightScroll.GetVerticalScrollRange = function() return 1000 end
      d.rowTop = { 0, 24, 58 }
      d.rowHeight = { 24, 34, 60 }
      d.rightScroll.SetVerticalScroll.calls = {}
      ctx.ns.guideBrowser.scrollToCurrent()
      local calls = d.rightScroll.SetVerticalScroll.calls
      expect(calls[#calls][1]).toBe(58 - (100 - 60) / 2)
    end)
  end)
end)
