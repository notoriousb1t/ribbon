local H = require("tests.helpers.addon")

describe("Compass view style", function()
  local ctx = H.use({ boot = true })
  local parts, S

  beforeEach(function()
    parts = ctx.ns.compass.parts
    S = ctx.ns.compassStyle
  end)

  it("ends the bar square, with no flourishes", function()
    expect(parts.capLeft).toBeNil()
    expect(parts.capRight).toBeNil()
    expect(S.cap).toBeNil()
    expect(S.textures.capLeft).toBeNil()
  end)

  it("centres the compass dial on the bar", function()
    expect(parts.dial.SetSize).toHaveBeenCalledWith(S.dial.size, S.dial.size)
    expect(parts.dial.SetPoint).toHaveBeenCalledWith("CENTER", parts.frame, "CENTER", 0, S.dial.offsetY)
    expect(parts.dial.face.SetTexture).toHaveBeenCalledWith(S.textures.dial)
  end)

  it("draws the needle over the dial with the needle texture", function()
    expect(parts.needle.SetTexture).toHaveBeenCalledWith(S.textures.needle)
    expect(parts.needle.SetAllPoints).toHaveBeenCalled()
  end)

  it("has no separate coordinates plaque any more", function()
    expect(parts.badge).toBeNil()
    expect(parts.plaque).toBeNil()
    expect(parts.star).toBeNil()
  end)

  it("colours the band teal", function()
    local colored = false
    for _, o in ipairs(ctx.world.objects) do
      local calls = o.SetColorTexture and o.SetColorTexture.calls or {}
      for _, call in ipairs(calls) do
        if call[1] == S.colors.band[1] and call[2] == S.colors.band[2] then colored = true end
      end
    end
    expect(colored).toBe(true)
  end)

  it("colours the cardinal labels cream and north red", function()
    expect(parts.labels[0].SetTextColor).toHaveBeenCalledWith(unpack(S.colors.north))
    expect(parts.labels[90].SetTextColor).toHaveBeenCalledWith(unpack(S.colors.cream))
    expect(parts.labels[225].SetTextColor).toHaveBeenCalledWith(unpack(S.colors.cream))
  end)

  it("draws ticks in cream above the band's bottom edge", function()
    ctx.world:update(0.04)
    local shown
    for _, t in ipairs(parts.ticks) do
      local calls = t.SetPoint.calls
      if #calls > 0 then shown = calls[#calls] end
    end
    expect(shown[5]).toBe(S.band.shadow + 1)
    expect(parts.ticks[2].SetColorTexture).toHaveBeenCalledWith(unpack(S.colors.cream))
  end)

  it("captions the headline in the log's gold", function()
    expect(parts.targetText.SetTextColor).toHaveBeenCalledWith(unpack(S.colors.heading))
  end)
end)
