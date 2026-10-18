local H = require("tests.helpers.addon")

-- A TomTom with the theme data the real one has: db.profile.worldmap.theme and a theme registry.
local function themedTomTom(theme)
  local tt = {
    waypoints = {},
    db = { profile = { worldmap = { theme = theme } } },
    waypointThemeRegistry = {
      GetThemeDotTexture = function(_, key)
        return "Interface\\AddOns\\TomTom\\Images\\Modern\\Waypoints\\WaypointDot" .. key
      end,
    },
  }
  function tt:AddWaypoint(m, x, y, opts)
    local uid = { m, x, y, title = opts and opts.title }
    tt.waypoints[m] = tt.waypoints[m] or {}
    tt.waypoints[m][m .. ":" .. x .. ":" .. y] = uid
    return uid
  end
  return tt
end

describe("TomTom waypoint icon", function()
  describe("the default", function()
    local ctx = H.use({ boot = true })

    it("is TomTom's own modern green dot", function()
      expect(ctx.ns.ICONS.tomtom).toBe("Interface\\AddOns\\TomTom\\Images\\Modern\\Waypoints\\WaypointDotGreen")
    end)
  end)

  describe("with TomTom's theme data", function()
    local tt
    local ctx = H.use({
      boot = true,
      world = function() tt = themedTomTom("Purple") _G.TomTom = tt end,
    })

    it("marks mirrored waypoints with the tomtom icon", function()
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "Anvil" })
      expect(ctx.ns:GetWaypoint(1).icon).toBe("tomtom")
    end)

    it("uses the dot of the theme the player chose in TomTom", function()
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "Anvil" })
      expect(ctx.ns.ICONS.tomtom).toBe("Interface\\AddOns\\TomTom\\Images\\Modern\\Waypoints\\WaypointDotPurple")
    end)

    it("follows a theme change on the next waypoint", function()
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "A" })
      tt.db.profile.worldmap.theme = "Red"
      tt:AddWaypoint(1453, 0.6, 0.25, { title = "B" })
      expect(ctx.ns.ICONS.tomtom).toBe("Interface\\AddOns\\TomTom\\Images\\Modern\\Waypoints\\WaypointDotRed")
    end)
  end)

  describe("without readable theme data", function()
    local tt
    local ctx = H.use({
      boot = true,
      world = function()
        tt = { AddWaypoint = function(self, m, x, y, opts) return { m, x, y, title = opts and opts.title } end }
        _G.TomTom = tt
      end,
    })

    it("keeps the default dot and still mirrors the waypoint", function()
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "Anvil" })
      expect(ctx.ns:GetWaypoint(1).icon).toBe("tomtom")
      expect(ctx.ns.ICONS.tomtom).toBe("Interface\\AddOns\\TomTom\\Images\\Modern\\Waypoints\\WaypointDotGreen")
    end)
  end)

  describe("with a theme registry that fails", function()
    local tt
    local ctx = H.use({
      boot = true,
      world = function()
        tt = themedTomTom("Blue")
        tt.waypointThemeRegistry.GetThemeDotTexture = function() error("unknown theme") end
        _G.TomTom = tt
      end,
    })

    it("falls back to the default dot", function()
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "Anvil" })
      expect(ctx.ns:GetWaypoint(1).icon).toBe("tomtom")
      expect(ctx.ns.ICONS.tomtom).toContain("WaypointDotGreen")
    end)
  end)
end)
