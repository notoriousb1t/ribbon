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

  describe("the quest kinds, drawn like Blizzard's quest icons", function()
    it("draws an accept as a warm dark disc, a gold bevelled ring and a gold exclamation mark", function()
      ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "accept" })
      frameTick()
      local m = parts.markers[1]
      expect(m.fill:IsShown()).toBe(true)
      expect(m.fill.SetVertexColor).toHaveBeenCalledWith(unpack(S.badge.questFill))
      expect(m.questRing:IsShown()).toBe(true)
      expect(m.rim:IsShown()).toBe(false)
      expect(m.glyphTex:IsShown()).toBe(true)
      expect(m.glyphTex.SetTexture).toHaveBeenCalledWith(S.textures.questExclaim)
      expect(m.tex:IsShown()).toBe(false)
    end)

    it("draws a turn-in the same way with the question mark, not flipped", function()
      ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "turnin" })
      frameTick()
      local m = parts.markers[1]
      expect(m.glyphTex.SetTexture).toHaveBeenCalledWith(S.textures.questQuestion)
      expect(m.questRing:IsShown()).toBe(true)
      expect(m.fill.SetVertexColor).toHaveBeenCalledWith(unpack(S.badge.questFill))
    end)

    it("sizes the symbol to the marker", function()
      ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "accept" })
      frameTick()
      local m = parts.markers[1]
      local size = last(m.SetSize)[1]
      local g = math.floor(size * S.badge.questGlyphScale + 0.5)
      expect(last(m.glyphTex.SetSize)).toEqual({ g, g, n = 2 })
    end)

    it("is drawn from textures, so it is as crisp as the game's own: no text, no font", function()
      ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "turnin" })
      frameTick()
      expect(parts.markers[1].glyph).toBeNil()
    end)

    it("uses the ring and symbols that exist as 128 px files", function()
      for _, name in ipairs({ "quest-ring", "quest-exclaim", "quest-question" }) do
        local found = false
        for _, f in ipairs(S.textureFiles) do if f == name then found = true end end
        expect(found).toBe(true)
      end
    end)
  end)

  it("redraws a reused marker with the right look when its waypoint changes kind", function()
    local uid = ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "turnin" })
    frameTick()
    ctx.ns:RemoveWaypoint(uid)
    ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "kill" })
    frameTick()
    local m = parts.markers[1]
    expect(m.questRing:IsShown()).toBe(false)
    expect(m.glyphTex:IsShown()).toBe(false)
    expect(m.rim:IsShown()).toBe(true)
    expect(m.fill.SetVertexColor).toHaveBeenCalledWith(unpack(S.badge.fillColor))
  end)

  it("puts the icon of other kinds inside the disc at the icon scale", function()
    ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "kill" })
    frameTick()
    local m = parts.markers[1]
    local size = last(m.SetSize)[1]
    expect(m.fill:IsShown()).toBe(true)
    expect(m.glyphTex:IsShown()).toBe(false)
    expect(m.tex:IsShown()).toBe(true)
    expect(m.tex.SetTexture).toHaveBeenCalledWith(ctx.ns.ICONS.kill)
    local icon = math.floor(size * S.badge.iconScale + 0.5)
    expect(last(m.tex.SetSize)).toEqual({ icon, icon, n = 2 })
    local c = S.badge.kinds.kill.color
    expect(m.rim.SetVertexColor).toHaveBeenCalledWith(c[1], c[2], c[3], 1)
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
      expect(m.questRing:IsShown()).toBe(false)
      expect(m.glyphTex:IsShown()).toBe(false)
      expect(m.tex:IsShown()).toBe(true)
      expect(m.tex.SetAllPoints).toHaveBeenCalledWith(m)
    end
  end)

  it("keeps the biggest marker with its ring inside the dial", function()
    expect(S.marker.max + S.marker.focusBoost + S.focusRing.pad).toBeLessThan(S.dial.size)
  end)

  describe("on the map", function()
    it("draws a world map or minimap pin as the same badge", function()
      local uid = ctx.ns:AddWaypoint(1453, 50, 25, { icon = "turnin" })
      local pin = ctx.world.pins.AddWorldMapIconMap.calls[1][2]
      expect(pin.glyphTex.SetTexture).toHaveBeenCalledWith(S.textures.questQuestion)
      expect(pin.questRing:IsShown()).toBe(true)
      local mini = ctx.world.pins.AddMinimapIconMap.calls[1][2]
      expect(mini.glyphTex.SetTexture).toHaveBeenCalledWith(S.textures.questQuestion)
    end)

    it("draws a kill pin with the sword inside the disc", function()
      ctx.ns:AddWaypoint(1453, 50, 25, { icon = "kill" })
      local pin = ctx.world.pins.AddWorldMapIconMap.calls[1][2]
      expect(pin.tex.SetTexture).toHaveBeenCalledWith(ctx.ns.ICONS.kill)
    end)
  end)
end)
