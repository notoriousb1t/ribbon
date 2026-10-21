local H = require("tests.helpers.addon")

describe("Marker badges", function()
  local ctx = H.use({ boot = true })
  local parts, S

  local function frameTick() ctx.world:update(0.04) end
  local function last(spy) return spy.calls[#spy.calls] end

  beforeEach(function()
    ctx.world:placePlayer(1453, 61.99, 70.58, 0)
    parts = ctx.ns.compass.parts
    S = ctx.ns.compassStyle
  end)

  it("draws accept and turn-in as a dark disc, a coloured rim and a crisp text symbol", function()
    ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "accept" })
    frameTick()
    local m = parts.markers[1]
    expect(m.fill:IsShown()).toBe(true)
    expect(m.rim:IsShown()).toBe(true)
    expect(m.glyph:IsShown()).toBe(true)
    expect(last(m.glyph.SetText)[1]).toBe("!")
    expect(m.tex:IsShown()).toBe(false)
    local c = S.badge.kinds.accept.color
    expect(m.rim.SetVertexColor).toHaveBeenCalledWith(c[1], c[2], c[3], 1)
    expect(m.fill.SetVertexColor).toHaveBeenCalledWith(unpack(S.badge.fillColor))
  end)

  it("uses a question mark for a turn-in", function()
    ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "turnin" })
    frameTick()
    expect(last(parts.markers[1].glyph.SetText)[1]).toBe("?")
  end)

  it("sizes the symbol to the marker", function()
    ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "accept" })
    frameTick()
    local m = parts.markers[1]
    local size = last(m.SetSize)[1]
    expect(m.glyphSize).toBe(math.floor(size * S.badge.glyphScale + 0.5))
  end)

  it("puts the icon of other kinds inside the disc at the icon scale", function()
    ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "kill" })
    frameTick()
    local m = parts.markers[1]
    local size = last(m.SetSize)[1]
    expect(m.fill:IsShown()).toBe(true)
    expect(m.glyph:IsShown()).toBe(false)
    expect(m.tex:IsShown()).toBe(true)
    expect(m.tex.SetTexture).toHaveBeenCalledWith(ctx.ns.ICONS.kill)
    local icon = math.floor(size * S.badge.iconScale + 0.5)
    expect(last(m.tex.SetSize)).toEqual({ icon, icon, n = 2 })
  end)

  it("draws other addons' icons plain, at the full marker size, with no disc", function()
    for _, name in ipairs({ "tomtom", "rxp", "raid8" }) do
      local ns, world = H.load({ boot = true })
      world:placePlayer(1453, 61.99, 70.58, 0)
      ns:AddWaypoint(1453, 61.99, 60, { icon = name })
      world:update(0.04)
      local m = ns.compass.parts.markers[1]
      expect(m.fill:IsShown()).toBe(false)
      expect(m.rim:IsShown()).toBe(false)
      expect(m.glyph:IsShown()).toBe(false)
      expect(m.tex:IsShown()).toBe(true)
      expect(m.tex.SetAllPoints).toHaveBeenCalledWith(m)
    end
  end)

  it("keeps the biggest marker with its ring inside the dial", function()
    expect(S.marker.max + S.marker.focusBoost + S.focusRing.pad).toBeLessThan(S.dial.size)
  end)
end)
