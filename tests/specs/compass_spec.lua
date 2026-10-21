local H = require("tests.helpers.addon")

local YD_PER_X, YD_PER_Y = 17.375, 11.5834

describe("Compass view", function()
  local ctx = H.use({ boot = true })
  local parts

  -- Advance one ribbon frame: geometry first, then the compass update (both at 30 Hz).
  local function frameTick() ctx.world:update(0.04) end
  local function lastPoint(frame)
    local c = frame.SetPoint.calls[#frame.SetPoint.calls]
    return { unpack(c, 1, c.n) }
  end

  beforeEach(function()
    ctx.world:placePlayer(1453, 61.99, 70.58, 0)
    parts = ctx.ns.compass.parts
  end)

  describe("frame", function()
    it("is created, named and shown at the saved position and width", function()
      expect(parts.frame).toBe(RibbonCompass)
      expect(parts.frame:IsShown()).toBe(true)
      expect(parts.frame.SetSize).toHaveBeenCalledWith(600, 28)
      expect(lastPoint(parts.frame)).toEqual({ "BOTTOM", UIParent, "BOTTOM", 0, 138 })
    end)

    it("builds a tick for every 5 degrees and a label for each of the eight bearings", function()
      expect(#parts.ticks).toBe(72)
      local count = 0
      for _ in pairs(parts.labels) do count = count + 1 end
      expect(count).toBe(8)
    end)
  end)

  describe("heading scale", function()
    it("keeps the N label under the dial (hidden) when facing north, with NE and NW either side", function()
      frameTick()
      expect(parts.labels[0]:IsShown()).toBe(false)
      expect(parts.labels[45]:IsShown()).toBe(true)
      expect(parts.labels[315]:IsShown()).toBe(true)
      expect(math.abs(lastPoint(parts.labels[45])[4])).toBe(math.floor(45 / 70 * 300 + 0.5))   -- on a whole pixel
      expect(lastPoint(parts.labels[45])[4]).toBe(-lastPoint(parts.labels[315])[4])
    end)

    it("hides labels outside the field of view", function()
      frameTick()
      expect(parts.labels[180]:IsShown()).toBe(false)
    end)

    it("moves the labels as the player turns", function()
      ctx.world.player.facing = math.pi / 2   -- facing west
      frameTick()
      expect(parts.labels[270]:IsShown()).toBe(false)   -- W is now under the dial
      expect(parts.labels[225]:IsShown()).toBe(true)    -- SW and NW are 45 degrees either side
      expect(parts.labels[315]:IsShown()).toBe(true)
      expect(parts.labels[0]:IsShown()).toBe(false)     -- N is now 90 degrees away, outside +/-70
    end)

    it("hides the scale and markers when facing is unavailable", function()
      ctx.ns:AddWaypoint(1453, 61.99, 60)
      frameTick()
      expect(parts.markers[1]:IsShown()).toBe(true)
      spyOn(ctx.ns.client, "facing"):andReturn(nil)
      frameTick()
      expect(parts.labels[0]:IsShown()).toBe(false)
      expect(parts.markers[1]:IsShown()).toBe(false)
    end)
  end)

  describe("markers", function()
    it("centres a waypoint straight ahead and captions it", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 50 / YD_PER_Y, { title = "North" })
      frameTick()
      local m = parts.markers[1]
      expect(m:IsShown()).toBe(true)
      expect(lastPoint(m)[4]).toBeCloseTo(0, 1)
      expect(parts.targetText.SetText).toHaveBeenCalledWith("North - 50 yd")
    end)

    it("draws a western waypoint on the left of centre", function()
      ctx.ns:AddWaypoint(1453, 61.99 - 10 / YD_PER_X, 70.58 - 50 / YD_PER_Y)
      frameTick()
      local x = lastPoint(parts.markers[1])[4]
      expect(x).toBeLessThan(0)
      expect(x).toBeGreaterThan(-300)
    end)

    it("draws an eastern waypoint on the right of centre", function()
      ctx.ns:AddWaypoint(1453, 61.99 + 10 / YD_PER_X, 70.58 - 50 / YD_PER_Y)
      frameTick()
      expect(lastPoint(parts.markers[1])[4]).toBeGreaterThan(0)
    end)

    it("clamps an off-screen waypoint to the edge at half alpha", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 + 100 / YD_PER_Y)   -- behind the player
      frameTick()
      local m = parts.markers[1]
      -- held inside the bar's end by half the marker, the padding and the arrow
      local cfg = ctx.ns.compassStyle.marker
      local size = ctx.ns.compassLayout.markerSize(ctx.ns:GetWaypoint(1).dist, false, cfg)
      expect(math.abs(lastPoint(m)[4])).toBeCloseTo(300 - (size / 2 + cfg.pad + cfg.arrow + 1), 6)
      expect(m.SetAlpha).toHaveBeenCalledWith(cfg.edgeAlpha)
    end)

    it("shows the ring on the dial white when dead, even in combat", function()
      ctx.world.inCombat = true
      ctx.world.dead = true
      frameTick()
      expect(parts.combatBar:IsShown()).toBe(true)
      expect(parts.combatBar.SetVertexColor).toHaveBeenCalledWith(unpack(ctx.ns.compassStyle.colors.dead))
      ctx.world.dead = false
      ctx.world.inCombat = false
      frameTick()
      expect(parts.combatBar:IsShown()).toBe(false)
    end)

    it("shows the red ring on the dial only while in combat", function()
      frameTick()
      expect(parts.combatBar:IsShown()).toBe(false)
      ctx.world.inCombat = true
      frameTick()
      expect(parts.combatBar:IsShown()).toBe(true)
      ctx.world.inCombat = false
      frameTick()
      expect(parts.combatBar:IsShown()).toBe(false)
    end)

    it("rings only the focused marker", function()
      local a = ctx.ns:AddWaypoint(1453, 61.99, 60)
      ctx.ns:AddWaypoint(1453, 61.99, 59)
      ctx.ns:SetFocus(a)
      frameTick()
      local focused, other
      for _, m in ipairs(parts.markers) do
        if m.uid == a then focused = m else other = m end
      end
      expect(focused.ring:IsShown()).toBe(true)
      expect(other.ring:IsShown()).toBe(false)
      ctx.ns:SetFocus(nil)
      frameTick()
      expect(focused.ring:IsShown()).toBe(false)
    end)

    it("keeps a marker still while the player's position shivers by a fraction of a degree", function()
      local uid = ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 80 / YD_PER_Y, { title = "Ahead" })
      frameTick()
      local m = parts.markers[1]
      local x0 = lastPoint(m)[4]
      for _, wobble in ipairs({ 0.004, -0.003, 0.005, -0.004, 0.002, -0.005, 0.003 }) do
        ctx.world.player.facing = wobble                      -- about a quarter of a degree either way
        frameTick()
        expect(lastPoint(m)[4]).toBe(x0)
      end
    end)

    it("follows a real turn", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 80 / YD_PER_Y, { title = "Ahead" })
      frameTick()
      local m = parts.markers[1]
      local x0 = lastPoint(m)[4]
      ctx.world.player.facing = -0.35                          -- turned about 20 degrees
      for _ = 1, 12 do frameTick() end
      expect(math.abs(lastPoint(m)[4] - x0)).toBeGreaterThan(40)
    end)

    it("draws marker positions on whole pixels", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 80 / YD_PER_Y, { title = "Ahead" })
      ctx.world.player.facing = 0.123
      for _ = 1, 6 do frameTick() end
      local x = lastPoint(parts.markers[1])[4]
      expect(x).toBe(math.floor(x))
    end)

    it("sets the icon texture for the waypoint", function()
      ctx.ns:AddWaypoint(1453, 61.99, 60, { icon = "kill" })
      frameTick()
      expect(parts.markers[1].tex.SetTexture).toHaveBeenCalledWith(ctx.ns.ICONS.kill)
    end)

    it("hides markers for hidden waypoints and for waypoints with compass disabled", function()
      local a = ctx.ns:AddWaypoint(1453, 61.99, 60)
      ctx.ns:AddWaypoint(1453, 61.99, 59, { compass = false })
      frameTick()
      expect(parts.markers[1]:IsShown()).toBe(true)
      expect(parts.markers[2]).toBeNil()
      ctx.ns:SetWaypointVisible(a, false)
      frameTick()
      expect(parts.markers[1]:IsShown()).toBe(false)
    end)

    it("reuses marker frames instead of creating more", function()
      ctx.ns:AddWaypoint(1453, 61.99, 60)
      frameTick()
      frameTick()
      expect(#parts.markers).toBe(1)
    end)

    it("draws at most 20 markers", function()
      for i = 1, 25 do ctx.ns:AddWaypoint(1453, 61.99, 70.58 - i * 0.5) end
      frameTick()
      expect(#parts.markers).toBe(20)
    end)

    it("captions the focused waypoint instead of the nearest", function()
      ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 10 / YD_PER_Y, { title = "Near" })
      local far = ctx.ns:AddWaypoint(1453, 61.99, 70.58 - 80 / YD_PER_Y, { title = "Far" })
      ctx.ns:SetFocus(far)
      frameTick()
      expect(parts.targetText.SetText).toHaveBeenCalledWith("Far - 80 yd")
    end)

    it("shows the tooltip with the title and a hide hint on hover", function()
      ctx.ns:AddWaypoint(1453, 61.99, 60, { title = "Anvil", lines = { "Quest giver" } })
      frameTick()
      parts.markers[1]:Trigger("OnEnter")
      expect(GameTooltip.SetText).toHaveBeenCalledWith("Anvil")
      expect(GameTooltip.AddLine).toHaveBeenCalledWith("Quest giver", 1, 1, 1)
      expect(GameTooltip.Show).toHaveBeenCalled()
      parts.markers[1]:Trigger("OnLeave")
      expect(GameTooltip.Hide).toHaveBeenCalled()
    end)

    it("hides the waypoint on right-click", function()
      local uid = ctx.ns:AddWaypoint(1453, 61.99, 60)
      frameTick()
      parts.markers[1]:Trigger("OnClick", "RightButton")
      expect(ctx.ns:GetWaypoint(uid).visible).toBe(false)
    end)
  end)

  describe("dragging", function()
    it("moves while unlocked and saves the position when released", function()
      parts.frame:Trigger("OnDragStart")
      expect(parts.frame.StartMoving).toHaveBeenCalled()
      parts.frame:Trigger("OnDragStop")
      expect(parts.frame.StopMovingOrSizing).toHaveBeenCalled()
      expect(RibbonDB.compass.point).toBe("BOTTOM")
    end)

    it("does not move while locked", function()
      ctx.ns.commands.compass("lock")
      parts.frame:Trigger("OnDragStart")
      expect(parts.frame.StartMoving).never.toHaveBeenCalled()
      ctx.ns.commands.compass("unlock")
      parts.frame:Trigger("OnDragStart")
      expect(parts.frame.StartMoving).toHaveBeenCalledTimes(1)
    end)
  end)

  describe("/ribbon compass", function()
    it("hides, shows and toggles the ribbon", function()
      ctx.ns.commands.compass("hide")
      expect(parts.frame:IsShown()).toBe(false)
      ctx.ns.commands.compass("show")
      expect(parts.frame:IsShown()).toBe(true)
      ctx.ns.commands.compass("toggle")
      expect(parts.frame:IsShown()).toBe(false)
    end)

    it("sets the width within 500 to 800", function()
      ctx.ns.commands.compass("width 700")
      expect(parts.frame.SetSize).toHaveBeenCalledWith(700, 28)
      ctx.ns.commands.compass("width 9000")
      expect(RibbonDB.compass.width).toBe(800)
      ctx.ns.commands.compass("width 10")
      expect(RibbonDB.compass.width).toBe(500)
    end)

    it("sets the field of view within 90 to 180", function()
      ctx.ns.commands.compass("fov 100")
      expect(RibbonDB.compass.fov).toBe(100)
      ctx.ns.commands.compass("fov 400")
      expect(RibbonDB.compass.fov).toBe(180)
    end)

    it("resets to defaults", function()
      ctx.ns.commands.compass("width 700")
      ctx.ns.commands.compass("reset")
      expect(RibbonDB.compass.width).toBe(600)
    end)

    it("prints usage for unknown input", function()
      ctx.ns.commands.compass("frobnicate")
      expect(ctx.world:output()).toContain("usage")
    end)
  end)
end)
