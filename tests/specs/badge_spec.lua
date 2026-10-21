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

  local function marker(icon, track)
    local uid = ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = icon })
    if track then ctx.ns:SetFocus(uid) end
    frameTick()
    return parts.markers[1], uid
  end

  describe("the quest kinds, drawn like Blizzard's quest icons", function()
    it("draws an accept as its gold exclamation mark alone: no disc, no ring", function()
      local m = marker("accept")
      expect(m.glyphTex:IsShown()).toBe(true)
      expect(m.glyphTex.SetTexture).toHaveBeenCalledWith(S.textures.questExclaim)
      expect(m.tex:IsShown()).toBe(false)
      expect(m.questRing:IsShown()).toBe(false)
      expect(m.rim:IsShown()).toBe(false)
      expect(m.fill:IsShown()).toBe(false)
    end)

    it("draws a turn-in the same way with the question mark", function()
      local m = marker("turnin")
      expect(m.glyphTex.SetTexture).toHaveBeenCalledWith(S.textures.questQuestion)
      expect(m.questRing:IsShown()).toBe(false)
    end)

    it("sets the tracked quest marker on a dark disc in the gold bevelled ring", function()
      local m = marker("accept", true)
      expect(m.fill:IsShown()).toBe(true)
      expect(m.fill.SetVertexColor).toHaveBeenCalledWith(unpack(S.badge.questFill))
      expect(m.questRing:IsShown()).toBe(true)
      expect(m.rim:IsShown()).toBe(false)
    end)

    it("sizes the symbol to the marker, and the ring a little larger", function()
      local m = marker("accept", true)
      local size = last(m.SetSize)[1]
      expect(last(m.glyphTex.SetSize)).toEqual({ size, size, n = 2 })
      expect(last(m.questRing.SetSize)).toEqual({ size + S.focusRing.pad, size + S.focusRing.pad, n = 2 })
    end)

    it("is drawn from textures, so it is as crisp as the game's own: no text, no font", function()
      expect(marker("turnin").glyph).toBeNil()
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
    ctx.ns:SetFocus(uid)
    frameTick()
    ctx.ns:RemoveWaypoint(uid)
    local m2 = marker("kill")
    expect(m2.questRing:IsShown()).toBe(false)
    expect(m2.glyphTex.SetTexture).toHaveBeenCalledWith(S.textures.glyphKill)
    expect(m2.rim:IsShown()).toBe(false)   -- not tracked
  end)

  it("draws the other kinds as an inked symbol in their colour, with a ring in the same colour while tracked", function()
    local m = marker("kill", true)
    local size = last(m.SetSize)[1]
    expect(m.glyphTex:IsShown()).toBe(true)
    expect(m.tex:IsShown()).toBe(false)
    expect(m.glyphTex.SetTexture).toHaveBeenCalledWith(S.textures.glyphKill)
    expect(last(m.glyphTex.SetSize)).toEqual({ size, size, n = 2 })
    local c = S.badge.kinds.kill.color
    expect(m.rim:IsShown()).toBe(true)
    expect(m.fill:IsShown()).toBe(true)
    expect(m.fill.SetVertexColor).toHaveBeenCalledWith(unpack(S.badge.fillColor))
    expect(m.rim.SetVertexColor).toHaveBeenCalledWith(c[1], c[2], c[3], 1)
    expect(m.glyphTex.SetVertexColor).toHaveBeenCalledWith(c[1], c[2], c[3], 1)
  end)

  it("has a symbol texture, shipped in the textures folder, for every kind that has one", function()
    local listed = {}
    for _, name in ipairs(S.textureFiles) do listed[name] = true end
    for kind, look in pairs(S.badge.kinds) do
      if look.glyph then
        local file = S.textures[look.glyph]
        expect(file).toBeTruthy()
        expect(listed[file:sub(select(2, file:find("textures", 1, true)) + 2)]).toBe(true)
      end
    end
  end)

  it("draws other addons' icons plain, at the full marker size", function()
    for _, name in ipairs({ "tomtom", "rxp", "raid8" }) do
      local ns, world = H.load({ boot = true })
      world:placePlayer(1453, 61.99, 70.58, 0)
      ns:AddWaypoint(1453, 61.99, 60, { icon = name })
      world:update(0.04)
      local m = ns.compass.parts.markers[1]
      expect(m.rim:IsShown()).toBe(false)
      expect(m.questRing:IsShown()).toBe(false)
      expect(m.glyphTex:IsShown()).toBe(false)
      expect(m.tex:IsShown()).toBe(true)
      expect(m.tex.SetAllPoints).toHaveBeenCalledWith(m)
    end
  end)

  it("rings flight points in flight master green while tracked", function()
    local c = S.badge.kinds.fp.color
    expect(c[2]).toBeGreaterThan(c[1] + 0.3)
    expect(c[2]).toBeGreaterThan(c[3] + 0.3)
    expect(marker("fp", true).rim.SetVertexColor).toHaveBeenCalledWith(c[1], c[2], c[3], 1)
  end)

  it("keeps the biggest marker with its ring inside the dial", function()
    expect(S.marker.max + S.marker.focusBoost + S.focusRing.pad).toBeLessThan(S.dial.size)
  end)

  describe("on the map", function()
    it("draws a world map or minimap pin as the bare symbol, with no circle", function()
      local uid = ctx.ns:AddWaypoint(1453, 50, 25, { icon = "turnin" })
      local pin = ctx.world.pins.AddWorldMapIconMap.calls[1][2]
      expect(pin.glyphTex.SetTexture).toHaveBeenCalledWith(S.textures.questQuestion)
      expect(pin.questRing:IsShown()).toBe(false)
      local mini = ctx.world.pins.AddMinimapIconMap.calls[1][2]
      expect(mini.glyphTex.SetTexture).toHaveBeenCalledWith(S.textures.questQuestion)
    end)

    it("rings the pin of the tracked waypoint and moves the ring when the focus changes", function()
      local a = ctx.ns:AddWaypoint(1453, 50, 25, { icon = "accept" })
      local pin = ctx.world.pins.AddWorldMapIconMap.calls[1][2]
      expect(pin.questRing:IsShown()).toBe(false)
      ctx.ns:SetFocus(a)
      expect(pin.questRing:IsShown()).toBe(true)
      ctx.ns:SetFocus(nil)
      expect(pin.questRing:IsShown()).toBe(false)
    end)

    it("draws a kill pin as its inked symbol, without the disc or rim", function()
      ctx.ns:AddWaypoint(1453, 50, 25, { icon = "kill" })
      local pin = ctx.world.pins.AddWorldMapIconMap.calls[1][2]
      expect(pin.glyphTex.SetTexture).toHaveBeenCalledWith(S.textures.glyphKill)
      expect(pin.rim:IsShown()).toBe(false)
    end)
  end)
end)

describe("Icons by kind of objective", function()
  local H2 = require("tests.helpers.addon")
  local ctx = H2.use({ boot = true })
  local T
  beforeEach(function() T = ctx.ns.guideText end)

  it("uses the gear for interacting with or using an object and the sack for looting", function()
    local function icon(kind) return T.icon({ calls = { { kind = kind } } }) end
    expect(icon("Interact")).toBe("interact")
    expect(icon("Use")).toBe("interact")
    expect(icon("Loot")).toBe("loot")
    expect(icon("Collect")).toBe("loot")
    expect(ctx.ns.compassStyle.badge.kinds.interact.glyph).toBe("glyphInteract")
  end)
end)
