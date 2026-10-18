local H = require("tests.helpers.addon")

describe("Caption above the bar, dial below", function()
  local ctx = H.use({ boot = true })
  local parts, S

  beforeEach(function()
    parts = ctx.ns.compass.parts
    S = ctx.ns.compassStyle
  end)

  it("anchors the caption plate's bottom to the bar's top, with a gap", function()
    expect(parts.captionPlate.SetPoint).toHaveBeenCalledWith("BOTTOM", parts.frame, "TOP", 0, S.caption.gap)
  end)

  it("keeps the headline at the top of the plate and the description under it", function()
    expect(parts.targetText.SetPoint).toHaveBeenCalledWith("TOP", parts.captionPlate, "TOP", 0, -S.caption.padY)
    expect(parts.detailText.SetPoint).toHaveBeenCalledWith("TOP", parts.targetText, "BOTTOM", 0, -S.caption.lineGap)
  end)

  it("hangs the dial from the bar's bottom edge", function()
    expect(parts.dial.SetPoint).toHaveBeenCalledWith("TOP", parts.frame, "BOTTOM", 0, -S.dial.gap)
  end)

  it("does not put anything under the bar except the dial", function()
    local below = 0
    for _, o in ipairs(ctx.world.objects) do
      for _, call in ipairs(o.SetPoint and o.SetPoint.calls or {}) do
        if call[1] == "TOP" and call[2] == parts.frame and call[3] == "BOTTOM" then below = below + 1 end
      end
    end
    expect(below).toBe(1)
  end)

  it("opens the dial's tooltip below it", function()
    parts.dial:Trigger("OnEnter")
    expect(GameTooltip.SetOwner).toHaveBeenCalledWith(parts.dial, "ANCHOR_BOTTOM")
  end)

  it("starts low enough on the screen for the two-line caption to fit above the bar", function()
    local cap = S.caption
    local tallest = cap.gap + cap.padY * 2 + cap.headSize * 1.4 + cap.lineGap + 2 * cap.detailSize * 1.4
    expect(-ctx.ns.defaults.compass.y).toBeGreaterThan(tallest)
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
