local H = require("tests.helpers.addon")

describe("Compass view style", function()
  local ctx = H.use({ boot = true })
  local parts, S

  beforeEach(function()
    parts = ctx.ns.compass.parts
    S = ctx.ns.compassStyle
  end)

  it("draws the swallowtail caps with the cap textures, at the bar's ends", function()
    expect(parts.capLeft.SetTexture).toHaveBeenCalledWith(S.textures.capLeft)
    expect(parts.capRight.SetTexture).toHaveBeenCalledWith(S.textures.capRight)
    expect(parts.capLeft.SetPoint).toHaveBeenCalledWith("TOPLEFT", parts.frame, "TOPLEFT", -S.cap.leftEdge, 0)
    expect(parts.capRight.SetPoint).toHaveBeenCalledWith("TOPLEFT", parts.frame, "TOPRIGHT", -S.cap.rightEdge, 0)
    expect(parts.capLeft.SetSize).toHaveBeenCalledWith(S.cap.width, S.cap.height)
  end)

  it("hangs the compass dial under the bar at the centre", function()
    expect(parts.dial.SetSize).toHaveBeenCalledWith(S.dial.size, S.dial.size)
    expect(parts.dial.SetPoint).toHaveBeenCalledWith("TOP", parts.frame, "BOTTOM", 0, -S.dial.gap)
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

  it("captions in cream", function()
    expect(parts.targetText.SetTextColor).toHaveBeenCalledWith(unpack(S.colors.cream))
  end)
end)
