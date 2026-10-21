local H = require("tests.helpers.addon")

-- Chapter one: 4 steps; chapter two: 2 steps; chapter three: 3 steps.
local function build(R)
  local function chapter(name, n)
    local c = R:Chapter(name, { levels = { 1, 2 } })
    for i = 1, n do c:Step():Goto(1453, 40 + i, 40 + i):Accept(i) end
    c:Done()
  end
  chapter("One", 4)
  chapter("Two", 2)
  chapter("Three", 3)
  return R
end

describe("The count beside the search box", function()
  local ctx = H.use({ boot = true })
  local function open()
    ctx.ns.guideBrowser.toggleDock()
    return ctx.ns.guideBrowser.dock()
  end
  local function shown(d) local c = d.counter.text.SetText.calls return c[#c][1] end
  beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

  it("has a box of its own at the right of the search row, with a gold label and white numbers", function()
    local d = open()
    expect(d.counter).toBeTruthy()
    expect(d.counter.SetPoint).toHaveBeenCalledWith("TOPRIGHT", d, "TOPRIGHT", -(ctx.ns.compassStyle.bezel.band + 8), -(ctx.ns.compassStyle.bezel.band + ctx.ns.compassStyle.bezel.title + 6))
    expect(shown(d)).toContain("|cffe9b949Steps:|r")
    expect(shown(d)).toContain("|cffffffff1/4|r")
  end)

  it("says which step of the chapter the player is on: 3/4 on the third step", function()
    ctx.ns.guidePlayer.jump(1, 3)
    local d = open()
    expect(shown(d)).toContain("3/4")
  end)

  it("follows the player as steps complete", function()
    local d = open()
    ctx.ns.guidePlayer.skip()
    expect(shown(d)).toContain("2/4")
  end)

  it("shows all of a finished chapter and none of one still to come", function()
    ctx.ns.guidePlayer.jump(3, 1)
    local d = open()                                     -- on chapter three; browse the others
    ctx.ns.guideBrowser.showSteps(1)
    expect(shown(d)).toContain("4/4")
    ctx.ns.guideBrowser.showChapters()
    ctx.ns.guideBrowser.showSteps(3)
    expect(shown(d)).toContain("1/3")
  end)

  it("counts chapters on the list: the player's chapter of all of them", function()
    ctx.ns.guidePlayer.jump(2, 1)
    local d = open()
    ctx.ns.guideBrowser.showChapters()
    expect(shown(d)).toContain("Chapters:")
    expect(shown(d)).toContain("2/3")
  end)

  it("is not changed by a search", function()
    local d = open()
    d.search:SetText("zzzz")
    d.search:Trigger("OnTextChanged", true)
    expect(shown(d)).toContain("1/4")
  end)

  it("leaves the search box room: the box is narrower by the count and the cog", function()
    local d = open()
    local width = 300 + 2 * ctx.ns.compassStyle.bezel.band + 12
    local expected = width - 2 * (ctx.ns.compassStyle.bezel.band + 8) - 30 - 84 - 6 - 24
    expect(d.search.SetSize).toHaveBeenCalledWith(expected, 20)
  end)
end)
