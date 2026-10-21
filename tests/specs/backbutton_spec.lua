local H = require("tests.helpers.addon")

describe("The back button", function()
  local ctx = H.use({ boot = true })
  local S
  beforeEach(function()
    S = ctx.ns.compassStyle
    Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
      :Step():Goto(1453, 50, 50):Accept(1):Done()
    ctx.ns.guideBrowser.toggleDock()
  end)

  it("is round like the map's own filter button: a dark disc in a gold bevelled ring, with a gold caret", function()
    local b = ctx.ns.guideBrowser.dock().back
    expect(b.fill.SetTexture).toHaveBeenCalledWith(S.textures.markerFill)
    expect(b.fill.SetVertexColor).toHaveBeenCalledWith(unpack(S.badge.questFill))
    expect(b.ring.SetTexture).toHaveBeenCalledWith(S.textures.questRing)
    expect(b.caret.SetTexture).toHaveBeenCalledWith(S.textures.panelCaret)
    expect(b.SetSize).toHaveBeenCalledWith(24, 24)
  end)

  it("lights up round on hover, not as a square", function()
    local b = ctx.ns.guideBrowser.dock().back
    expect(b.SetHighlightTexture).toHaveBeenCalledWith(S.textures.markerFill, "ADD")
  end)

  it("still goes back to the chapter list", function()
    local d = ctx.ns.guideBrowser.dock()
    d.back:Trigger("OnClick")
    expect(d.page).toBe("chapters")
  end)
end)
