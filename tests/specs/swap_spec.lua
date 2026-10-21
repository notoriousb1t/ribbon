local H = require("tests.helpers.addon")

describe("Caption above the bar, dial centred on it", function()
  local ctx = H.use({ boot = true })
  local parts, S

  beforeEach(function()
    parts = ctx.ns.compass.parts
    S = ctx.ns.compassStyle
  end)

  it("anchors the caption plate's bottom to the bar's top, with a gap that clears the dial", function()
    local overhang = (S.dial.size - 28) / 2
    expect(parts.captionPlate.SetPoint).toHaveBeenCalledWith("BOTTOM", parts.frame, "TOP", 0, S.caption.gap + overhang + S.distance.height)
  end)

  it("keeps the headline at the top of the plate and the description under it", function()
    expect(parts.targetText.SetPoint).toHaveBeenCalledWith("TOP", parts.captionPlate, "TOP", 0, -S.caption.padY)
    expect(parts.detailText.SetPoint).toHaveBeenCalledWith("TOP", parts.targetText, "BOTTOM", 0, -S.caption.lineGap)
  end)

  it("centres the dial on the bar", function()
    expect(parts.dial.SetPoint).toHaveBeenCalledWith("CENTER", parts.frame, "CENTER", 0, S.dial.offsetY)
  end)

  it("hangs nothing under the bar", function()
    local below = 0
    for _, o in ipairs(ctx.world.objects) do
      for _, call in ipairs(o.SetPoint and o.SetPoint.calls or {}) do
        if call[1] == "TOP" and call[2] == parts.frame and call[3] == "BOTTOM" then below = below + 1 end
      end
    end
    expect(below).toBe(0)
  end)

  it("opens the dial's tooltip below it", function()
    parts.dial:Trigger("OnEnter")
    expect(GameTooltip.SetOwner).toHaveBeenCalledWith(parts.dial, "ANCHOR_BOTTOM")
  end)

  it("starts at the top of the screen, low enough that the dial is not cut off", function()
    local d = ctx.ns.defaults.compass
    expect(d.point).toBe("TOP")
    expect(d.relPoint).toBe("TOP")
    expect(d.y).toBe(-(ctx.ns.compassStyle.dial.size - 28) / 2)
  end)

  it("uses that position by default and again after a reset", function()
    expect(RibbonDB.compass.y).toBe(ctx.ns.defaults.compass.y)
    ctx.ns.commands.compass("reset")
    expect(RibbonDB.compass.y).toBe(ctx.ns.defaults.compass.y)
  end)

  it("keeps a position the player already chose", function()
    local ns, world = H.load({
      world = function() RibbonDB = { compass = { point = "BOTTOM", relPoint = "BOTTOM", x = -6, y = 228 } } end,
      boot = true,
    })
    expect(RibbonDB.compass.y).toBe(228)
    require("tests.fakes.wow").uninstall()
  end)
end)
