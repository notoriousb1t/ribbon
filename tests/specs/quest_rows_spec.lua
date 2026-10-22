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
    it("split a step into a title (its first line, or its quest when it has several objectives) and objectives", function()
      local _, right = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1)
      expect(right[1].title).toBe("Accept Coming of Age")
      expect(right[1].objectives).toEqual({ "Rorian the Dayseeker" })   -- the NPC has a line of its own
      expect(right[2].title).toBe("The Hunt")
      expect(right[2].objectives).toEqual({ "Defeat 8 Pesky Cirrusfly", "Defeat 8 Juvenile Vuldren" })
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
      expect(lastText(d.rightRows.items[3].label)).toContain("|cff8a6d2c")    -- steps to come are a dimmer gold
    end)

    it("lists the objectives under the title with a dash, in plain text", function()
      local d = open()
      ctx.ns.guidePlayer.jump(1, 2)
      ctx.ns.guideBrowser.refresh()
      local objectives = lastText(d.rightRows.items[2].objectives)           -- the current step
      expect(objectives).toContain("- Defeat 8 Juvenile Vuldren")
      expect(objectives).toContain("|cffe6e0cf")
      expect(lastText(d.rightRows.items[1].objectives)).toContain("- Rorian the Dayseeker")
    end)

    it("puts a gold glow behind the icon of the player's step only", function()
      local d = open()
      expect(d.rightRows.items[1].glow:IsShown()).toBe(true)
      expect(d.rightRows.items[2].glow:IsShown()).toBe(false)
    end)

    it("shows a check mark in place of the icon of a step that is done, in the colour of its text", function()
      ctx.ns.guidePlayer.jump(1, 3)
      local d = open()
      local done, todo = d.rightRows.items[1], d.rightRows.items[3]
      expect(done.tick:IsShown()).toBe(true)
      expect(done.icon:IsShown()).toBe(false)
      expect(todo.tick:IsShown()).toBe(false)
      expect(todo.icon:IsShown()).toBe(true)
      expect(lastText(done.label)).toContain("|cff808080")
      local c = done.tick.SetVertexColor.calls[1]
      expect(c[1]).toBeCloseTo(0x80 / 255, 2)                          -- the grey of the text
      expect(done.tick.SetDesaturated).toHaveBeenCalledWith(true)
    end)

    it("shows the step's own icon with the glow again while the mouse is over a done step", function()
      ctx.ns.guidePlayer.jump(1, 3)
      local d = open()
      local row = d.rightRows.items[1]
      row:Trigger("OnEnter")
      expect(row.tick:IsShown()).toBe(false)
      expect(row.icon:IsShown()).toBe(true)
      expect(row.glow:IsShown()).toBe(true)
      row:Trigger("OnLeave")
      expect(row.tick:IsShown()).toBe(true)
      expect(row.icon:IsShown()).toBe(false)
      expect(row.glow:IsShown()).toBe(false)
    end)

    it("dims a step still to come until the mouse is over it", function()
      local d = open()
      local row = d.rightRows.items[3]                                 -- to come
      expect(lastText(row.label)).toContain("|cff8a6d2c")
      expect(lastText(row.objectives)).never.toContain("|cffe6e0cf")
      row:Trigger("OnEnter")
      expect(lastText(row.label)).toContain("|cffe9b949")              -- full colour
      expect(lastText(row.objectives)).toContain("- Rorian the Dayseeker")
      row:Trigger("OnLeave")
      expect(lastText(row.label)).toContain("|cff8a6d2c")
    end)

    it("does not dim the current step or a done one", function()
      ctx.ns.guidePlayer.jump(1, 2)
      local d = open()
      expect(lastText(d.rightRows.items[2].label)).toContain("|cffffd24a")
      expect(lastText(d.rightRows.items[1].label)).toContain("|cff808080")
    end)

    it("brightens the objectives of a step to come on hover", function()
      Ribbon.Guide("g")                                                -- (already registered: ignored)
      local d = open()
      ctx.ns.guideBrowser.showSteps(2)
      local row = d.rightRows.items[1]
      expect(lastText(row.objectives)).toBe("")
      ctx.ns.guideBrowser.showSteps(1)
      local kill = d.rightRows.items[2]
      expect(lastText(kill.objectives)).toContain("|cff7a766b")        -- dim
      kill:Trigger("OnEnter")
      expect(lastText(kill.objectives)).toContain("|cffe6e0cf")        -- bright
    end)

    it("makes a row as tall as its text, never less than its icon needs", function()
      local d = open()
      local plain, withObjectives = d.rightRows.items[3], d.rightRows.items[2]
      plain.label.GetStringHeight = function() return 14 end
      withObjectives.label.GetStringHeight = function() return 28 end            -- a title on two lines
      withObjectives.objectives.GetStringHeight = function() return 24 end       -- two objective lines
      ctx.ns.guideBrowser.refresh()
      expect(plain.SetHeight.calls[#plain.SetHeight.calls][1]).toBe(10 + 14 + 12 + 2)   -- a one-line title and the NPC line
      expect(withObjectives.SetHeight.calls[#withObjectives.SetHeight.calls][1]).toBe(10 + 28 + 24 + 2)
    end)

    it("stacks rows by their own heights", function()
      local d = open()
      d.rightRows.items[1].label.GetStringHeight = function() return 14 end
      d.rightRows.items[2].label.GetStringHeight = function() return 28 end
      d.rightRows.items[2].objectives.GetStringHeight = function() return 12 end
      ctx.ns.guideBrowser.refresh()
      local function y(row) local c = row.SetPoint.calls return c[#c][5] end
      expect(y(d.rightRows.items[1])).toBe(0)                                    -- no header above the steps
      expect(y(d.rightRows.items[2])).toBe(-38)                                  -- title 14 + the NPC line 12 + padding
      expect(y(d.rightRows.items[3])).toBe(-(38 + 10 + 28 + 12 + 2))
    end)
  end)

  describe("section headers", function()
    it("are not there while nothing is searched for: the title bar names the chapter", function()
      local d = open()
      expect(d.section).toBeNil()
      expect(d.rightRows.items[1].isHeader).toBe(false)
      expect(d.rightRows.items[1].headBg:IsShown()).toBe(false)
    end)

    it("is a row of its own for each chapter while searching, and folds that chapter", function()
      local d = open()
      d.search:SetText("accept")
      d.search:Trigger("OnTextChanged", true)
      local head = d.rightRows.items[1]
      expect(head.isHeader).toBe(true)
      expect(head.minus:IsShown()).toBe(true)
      head:Trigger("OnClick")                                                    -- fold chapter one's results
      expect(d.rightRows.items[1].plus:IsShown()).toBe(true)
      expect(d.rightRows.items[2].isHeader).toBe(true)                           -- the next row is chapter two's header
    end)

    it("start open again when the panel is opened again", function()
      local d = open()
      d.search:SetText("accept")
      d.search:Trigger("OnTextChanged", true)
      d.rightRows.items[1]:Trigger("OnClick")                                    -- fold chapter one
      d.close:Trigger("OnClick")
      d = open()
      d.search:SetText("accept")
      d.search:Trigger("OnTextChanged", true)
      expect(d.rightRows.items[1].plus:IsShown()).toBe(false)
      expect(d.rightRows.items[2].isHeader).toBe(false)                          -- chapter one's steps are back
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

describe("A step with several objectives of one quest", function()
  local ctx = H.use({ boot = true })
  beforeEach(function()
    local R = Ribbon.Guide("g", { title = "Test Guide", schema = 1 })
    R:Names({ QUEST = { [7] = "Stolen Supplies" }, CREATURE = { [20] = "Stormcaller", [21] = "Living Lightning" }, ITEM = { [30] = "Cyclas's Head" } })
    R:Chapter("One", { levels = { 1, 2 } })
      :Step():Goto(1453, 50, 50):Kill(20, 6, { quest = 7, index = 1 }):Kill(21, 4, { quest = 7, index = 2 }):Loot(30, 1, { quest = 7, index = 3 })
      :Step():Goto(1453, 51, 51):Kill(20, 6, { quest = 7, index = 1 })
      :Done()
  end)

  it("is titled with the quest and lists every objective under it", function()
    local _, right = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1)
    expect(right[1].title).toBe("Stolen Supplies")
    expect(#right[1].objectives).toBe(3)
    expect(right[1].objectives[1]).toBe("Defeat 6 Stormcaller")
  end)

  it("keeps a lone objective as its own title", function()
    local _, right = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1)
    expect(right[2].title).toBe("Defeat 6 Stormcaller")
    expect(#right[2].objectives).toBe(0)
  end)
end)

describe("Step rows are centred vertically", function()
  local ctx = H.use({ boot = true })
  beforeEach(function()
    Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
      :Step():Goto(1453, 50, 50):Accept(1):Done()
  end)

  it("puts the icon at the row's middle and the text block centred in the row", function()
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    local row = d.rightRows.items[1]
    expect(row.icon.SetPoint).toHaveBeenCalledWith("LEFT", row, "LEFT", 6, 0)
    row.label.GetStringHeight = function() return 14 end          -- a one-line title in a 34 px row
    ctx.ns.guideBrowser.refresh()
    local c = row.label.SetPoint.calls[#row.label.SetPoint.calls]
    expect(c[1]).toBe("TOPLEFT")
    expect(c[5]).toBe(-math.max(5, (34 - 14) / 2))
  end)
end)
