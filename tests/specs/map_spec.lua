local H = require("tests.helpers.addon")

describe("Map wiring", function()
  describe("with HereBeDragons-Pins loaded", function()
    local ctx = H.use({ boot = true })

    it("adds a world map and a minimap icon when a waypoint is added", function()
      local uid = ctx.ns:AddWaypoint(1453, 50, 25, { icon = "kill" })
      local pins = ctx.world.pins
      expect(pins.AddWorldMapIconMap).toHaveBeenCalledTimes(1)
      expect(pins.AddMinimapIconMap).toHaveBeenCalledTimes(1)
      local call = pins.AddWorldMapIconMap.calls[1]
      expect(call[1]).toBe(ctx.ns)
      expect(call[3]).toBe(1453)
      expect(call[4]).toBe(0.5)
      expect(call[5]).toBe(0.25)
      expect(call[6]).toBe(2)
      expect(call[2].uid).toBe(uid)
    end)

    it("gives the pins the waypoint's icon", function()
      ctx.ns:AddWaypoint(1453, 50, 25, { icon = "kill" })
      local pin = ctx.world.pins.AddWorldMapIconMap.calls[1][2]
      expect(pin.glyphTex.SetTexture).toHaveBeenCalledWith(ctx.ns.compassStyle.textures.glyphKill)
    end)

    it("removes the icons when the waypoint is hidden and restores them when shown", function()
      local uid = ctx.ns:AddWaypoint(1453, 50, 25)
      local pins = ctx.world.pins
      ctx.ns:SetWaypointVisible(uid, false)
      expect(pins.RemoveWorldMapIcon).toHaveBeenCalledTimes(1)
      expect(pins.RemoveMinimapIcon).toHaveBeenCalledTimes(1)
      ctx.ns:SetWaypointVisible(uid, true)
      expect(pins.AddWorldMapIconMap).toHaveBeenCalledTimes(2)
    end)

    it("removes the icons when the waypoint is removed", function()
      local uid = ctx.ns:AddWaypoint(1453, 50, 25)
      ctx.ns:RemoveWaypoint(uid)
      expect(ctx.world.pins.RemoveWorldMapIcon).toHaveBeenCalledTimes(1)
      expect(ctx.world.pins.RemoveMinimapIcon).toHaveBeenCalledTimes(1)
    end)

    it("hides the waypoint on right-click of a pin", function()
      local uid = ctx.ns:AddWaypoint(1453, 50, 25)
      local pin = ctx.world.pins.AddWorldMapIconMap.calls[1][2]
      pin:Trigger("OnClick", "RightButton")
      expect(ctx.ns:GetWaypoint(uid).visible).toBe(false)
    end)

    it("shows a tooltip on hover", function()
      ctx.ns:AddWaypoint(1453, 50, 25, { title = "Anvil" })
      local pin = ctx.world.pins.AddWorldMapIconMap.calls[1][2]
      pin:Trigger("OnEnter")
      expect(GameTooltip.SetText).toHaveBeenCalledWith("Anvil")
    end)

    it("adds a Clear Pins button to the world map that hides every waypoint", function()
      local uid = ctx.ns:AddWaypoint(1453, 50, 25)
      local button = RibbonClearPinsButton
      expect(button).toBeTruthy()
      expect(button.SetText).toHaveBeenCalledWith("Clear Pins")
      button:Trigger("OnClick")
      expect(ctx.ns:GetWaypoint(uid).visible).toBe(false)
    end)
  end)

  describe("without the pin library", function()
    local ctx = H.use({
      boot = true,
      world = function(w) w.libs["HereBeDragons-Pins-2.0"] = nil end,
    })

    it("prints one message and adds waypoints without pins", function()
      expect(ctx.world:output()).toContain("map pins disabled")
      expect(ctx.ns:AddWaypoint(1453, 50, 25)).toBe(1)
    end)
  end)
end)

describe("Map pin size", function()
  local ctx = H.use({ boot = true })

  it("draws world map and minimap pins at the player arrow's size, with the thin map ring while tracked", function()
    local S = ctx.ns.compassStyle
    local uid = ctx.ns:AddWaypoint(1453, 50, 50, { title = "A" })
    ctx.ns:SetFocus(uid)
    local world = ctx.world.pins.AddWorldMapIconMap.calls[#ctx.world.pins.AddWorldMapIconMap.calls][2]
    local mini = ctx.world.pins.AddMinimapIconMap.calls[#ctx.world.pins.AddMinimapIconMap.calls][2]
    expect(world.SetSize).toHaveBeenCalledWith(S.pins.world, S.pins.world)
    expect(mini.SetSize).toHaveBeenCalledWith(S.pins.mini, S.pins.mini)
    local ring = world.fill.SetSize.calls[#world.fill.SetSize.calls]
    local D = ctx.ns.badge.DIAMOND   -- the tracked ring is a diamond, drawn larger than a disc
    expect(ring[1]).toBe(math.floor((S.pins.world + S.pins.worldRingPad) * D + 0.5))
    local miniRing = mini.fill.SetSize.calls[#mini.fill.SetSize.calls]
    expect(miniRing[1]).toBe(math.floor((S.pins.mini + S.pins.ringPad) * D + 0.5))
  end)
end)
