local H = require("tests.helpers.addon")

-- A stand-in for RXPGuides: the named arrow frame RXPG_ARROW (with IsShown and the active element)
-- and the global RXP addon table with GetV1Texture.
local function newRXP()
  local af = { shown = true, element = { zone = 1453, x = 64.6, y = 37.2, title = "Furen" } }
  function af:IsShown() return self.shown end
  _G.RXPG_ARROW = af
  _G.RXP = {
    arrowFrame = af,
    GetV1Texture = function(name) return "Interface\\AddOns\\RXPGuides\\Textures\\" .. name end,
  }
  return af
end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

describe("RXP bridge", function()
  describe("when RXPGuides is loaded", function()
    local af
    local ctx = H.use({ boot = true, world = function() af = newRXP() end })

    local function tick() ctx.world:update(0.3) end

    it("mirrors the arrow target with its title, compass only", function()
      tick()
      local wp = ctx.ns:GetWaypoint(1)
      expect(wp.title).toBe("Furen")
      expect(wp.mapID).toBe(1453)
      expect(wp.x).toBe(64.6)
      expect(wp.y).toBe(37.2)
      expect(wp.compass).toBe(true)
      expect(wp.minimap).toBe(false)
      expect(wp.worldmap).toBe(false)
      expect(wp.icon).toBe("rxp")
    end)

    it("uses RXP's own target icon, following its theme", function()
      tick()
      expect(ctx.ns.ICONS.rxp).toBe("Interface\\AddOns\\RXPGuides\\Textures\\map_active_step_target_icon")
    end)

    it("does not duplicate the waypoint while the target is unchanged", function()
      tick()
      tick()
      tick()
      expect(count(ctx.ns.waypoints)).toBe(1)
    end)

    it("moves the waypoint when RXP points somewhere else", function()
      tick()
      af.element = { zone = 1453, x = 20, y = 30, title = "Next stop" }
      tick()
      expect(count(ctx.ns.waypoints)).toBe(1)
      expect(ctx.ns:GetWaypoint(2).title).toBe("Next stop")
      expect(ctx.ns:GetWaypoint(1)).toBeNil()
    end)

    it("removes the waypoint when RXP hides its arrow", function()
      tick()
      af.shown = false
      tick()
      expect(count(ctx.ns.waypoints)).toBe(0)
    end)

    it("restores the waypoint when the arrow comes back", function()
      tick()
      af.shown = false
      tick()
      af.shown = true
      tick()
      expect(count(ctx.ns.waypoints)).toBe(1)
    end)

    it("adds nothing for a corpse or Spirit Healer target (no zone coordinates)", function()
      af.element = { wx = 100, wy = 200, instance = 0, title = "Corpse" }
      tick()
      expect(count(ctx.ns.waypoints)).toBe(0)
    end)

    it("leaves other waypoints alone", function()
      local own = ctx.ns:AddWaypoint(1453, 10, 10)
      tick()
      af.shown = false
      tick()
      expect(ctx.ns:GetWaypoint(own)).toBeTruthy()
    end)

    it("/ribbon rxp reports what the arrow points at", function()
      tick()
      ctx.ns.commands.rxp()
      local out = ctx.world:output()
      expect(out).toContain("shown=true")
      expect(out).toContain("zone=1453")
      expect(out).toContain("title=Furen")
      expect(out).toContain("mirrored=true")
    end)
  end)

  describe("RXP without a readable theme", function()
    local ctx = H.use({
      boot = true,
      world = function()
        newRXP()
        _G.RXP.GetV1Texture = function() error("no theme") end
      end,
    })

    it("keeps the default icon and still mirrors the target", function()
      ctx.world:update(0.3)
      expect(ctx.ns:GetWaypoint(1).icon).toBe("rxp")
      expect(ctx.ns.ICONS.rxp).toBe(ctx.ns.ICONS.turnin)
    end)
  end)

  describe("RXP with only the arrow frame global", function()
    local ctx = H.use({
      boot = true,
      world = function()
        newRXP()
        _G.RXP = nil
      end,
    })

    it("still mirrors the target", function()
      ctx.world:update(0.3)
      expect(ctx.ns:GetWaypoint(1).title).toBe("Furen")
    end)
  end)

  describe("when RXPGuides is absent", function()
    local ctx = H.use({ boot = true })

    it("does nothing and says so on request", function()
      ctx.world:update(0.3)
      expect(next(ctx.ns.waypoints)).toBeNil()
      ctx.ns.commands.rxp()
      expect(ctx.world:output()).toContain("RestedXP arrow not found")
    end)
  end)
end)
