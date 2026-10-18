local H = require("tests.helpers.addon")

-- A TomTom stand-in that follows the real v4.3.12 behavior:
--   AddWaypoint(m, x, y, opts) takes fractions and returns the existing handle for a duplicate;
--   a handle is { m, x, y, title = ..., from = ... };
--   RemoveWaypoint calls ClearWaypoint and drops the handle from `waypoints`;
--   ClearAllWaypoints only calls ClearWaypoint for each handle (the table keeps them);
--   AddWaypointToCurrentZone(x, y, desc) takes 0-100 and ends in AddWaypoint.
local function newTomTom()
  local waypoints = {}
  local tt = { waypoints = waypoints }
  local function keyOf(m, x, y, title) return string.format("%d:%s:%s:%s", m, x, y, tostring(title)) end

  function tt:AddWaypoint(m, x, y, opts)
    opts = opts or {}
    local key = keyOf(m, x, y, opts.title)
    if waypoints[m] and waypoints[m][key] then return waypoints[m][key] end
    local uid = { m, x, y, title = opts.title, from = opts.from or "?" }
    waypoints[m] = waypoints[m] or {}
    waypoints[m][key] = uid
    return uid
  end

  function tt:AddWaypointToCurrentZone(x, y, desc)
    return self:AddWaypoint(1453, x / 100, y / 100, { title = desc, from = "TomTom/AWTCZ" })
  end

  function tt:ClearWaypoint(uid) end

  function tt:RemoveWaypoint(uid)
    self:ClearWaypoint(uid)
    waypoints[uid[1]][keyOf(uid[1], uid[2], uid[3], uid.title)] = nil
  end

  function tt:ClearAllWaypoints()
    for _, entries in pairs(waypoints) do
      for _, uid in pairs(entries) do self:ClearWaypoint(uid) end
    end
  end
  return tt
end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

describe("TomTom bridge", function()
  describe("when TomTom is loaded", function()
    local tt
    local ctx = H.use({
      boot = true,
      world = function() tt = newTomTom() _G.TomTom = tt end,
    })

    it("mirrors a waypoint added through TomTom, with its title", function()
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "Anvil" })
      local wp = ctx.ns:GetWaypoint(1)
      expect(wp.mapID).toBe(1453)
      expect(wp.x).toBe(50)
      expect(wp.y).toBe(25)
      expect(wp.title).toBe("Anvil")
      expect(wp.icon).toBe("tomtom")
    end)

    it("mirrors what /way sets (an AddWaypoint call from TomTom itself)", function()
      tt:AddWaypoint(1453, 0.482, 0.429, { title = "TomTom waypoint", from = "TomTom/way" })
      expect(ctx.ns:GetWaypoint(1).x).toBeCloseTo(48.2, 6)
      expect(ctx.ns:GetWaypoint(1).title).toBe("TomTom waypoint")
    end)

    it("mirrors AddWaypointToCurrentZone through the AddWaypoint it calls", function()
      tt:AddWaypointToCurrentZone(50, 25, "Bank")
      expect(ctx.ns:GetWaypoint(1).title).toBe("Bank")
      expect(ctx.ns:GetWaypoint(1).y).toBe(25)
      expect(count(ctx.ns.waypoints)).toBe(1)
    end)

    it("draws mirrored waypoints on the compass only, since TomTom draws its own map icons", function()
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "Anvil" })
      local wp = ctx.ns:GetWaypoint(1)
      expect(wp.compass).toBe(true)
      expect(wp.worldmap).toBe(false)
      expect(wp.minimap).toBe(false)
      expect(ctx.world.pins.AddWorldMapIconMap).never.toHaveBeenCalled()
      expect(ctx.world.pins.AddMinimapIconMap).never.toHaveBeenCalled()
    end)

    it("does not change what TomTom does or returns", function()
      local uid = tt:AddWaypoint(1453, 0.5, 0.25, { title = "Anvil" })
      expect(uid.title).toBe("Anvil")
      expect(tt.waypoints[1453]["1453:0.5:0.25:Anvil"]).toBe(uid)
      expect(TomTom).toBe(tt)
    end)

    it("uses a default title when none is given", function()
      tt:AddWaypoint(1453, 0.5, 0.25)
      expect(ctx.ns:GetWaypoint(1).title).toBe("TomTom waypoint")
    end)

    it("mirrors a repeated waypoint once", function()
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "A" })
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "A" })
      expect(count(ctx.ns.waypoints)).toBe(1)
    end)

    it("keeps waypoints with different titles at one spot apart", function()
      local a = tt:AddWaypoint(1453, 0.5, 0.25, { title = "A" })
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "B" })
      expect(count(ctx.ns.waypoints)).toBe(2)
      tt:RemoveWaypoint(a)
      expect(count(ctx.ns.waypoints)).toBe(1)
      expect(ctx.ns:GetWaypoint(2).title).toBe("B")
    end)

    it("removes the mirrored waypoint when TomTom removes it, leaving Ribbon's own", function()
      local own = ctx.ns:AddWaypoint(1453, 10, 10, { title = "Mine" })
      local uid = tt:AddWaypoint(1453, 0.5, 0.25)
      tt:RemoveWaypoint(uid)
      expect(count(ctx.ns.waypoints)).toBe(1)
      expect(ctx.ns:GetWaypoint(own)).toBeTruthy()
    end)

    it("removes mirrored waypoints when TomTom clears everything, leaving Ribbon's own", function()
      local own = ctx.ns:AddWaypoint(1453, 10, 10)
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "A" })
      tt:AddWaypoint(1453, 0.6, 0.35, { title = "B" })
      tt:ClearAllWaypoints()
      expect(count(ctx.ns.waypoints)).toBe(1)
      expect(ctx.ns:GetWaypoint(own)).toBeTruthy()
    end)

    it("removes the mirrored waypoint when TomTom clears one directly (arrival, profile reload)", function()
      local uid = tt:AddWaypoint(1453, 0.5, 0.25)
      tt:ClearWaypoint(uid)
      expect(next(ctx.ns.waypoints)).toBeNil()
    end)

    it("mirrors again when the same waypoint is re-added after removal", function()
      local uid = tt:AddWaypoint(1453, 0.5, 0.25, { title = "A" })
      tt:RemoveWaypoint(uid)
      tt:AddWaypoint(1453, 0.5, 0.25, { title = "A" })
      expect(count(ctx.ns.waypoints)).toBe(1)
    end)

    it("ignores calls it cannot translate", function()
      tt:AddWaypoint(99999, 0.5, 0.5)
      tt:AddWaypoint(1453, 50, 50)
      expect(next(ctx.ns.waypoints)).toBeNil()
    end)

    it("never lets its own errors reach TomTom's caller", function()
      spyOn(ctx.ns, "AddWaypoint"):andCall(function() error("registry failed") end)
      expect(function() tt:AddWaypoint(1453, 0.5, 0.25) end).never.toThrow()
      expect(ctx.world.errors[1]).toMatch("registry failed")
    end)

    it("/ribbon tomtom reports what was hooked and mirrored", function()
      tt:AddWaypoint(1453, 0.5, 0.25)
      ctx.ns.commands.tomtom()
      local out = ctx.world:output()
      expect(out).toContain("AddWaypoint")
      expect(out).toContain("RemoveWaypoint")
      expect(out).toContain("ClearWaypoint")
      expect(out).toContain("Mirrored waypoints: 1")
    end)
  end)

  describe("waypoints TomTom already held at login", function()
    local ctx = H.use({
      boot = true,
      world = function()
        local tt = newTomTom()
        tt:AddWaypoint(1453, 0.5, 0.25, { title = "Saved" })
        _G.TomTom = tt
      end,
    })

    it("are mirrored once Ribbon starts", function()
      expect(ctx.ns:GetWaypoint(1).title).toBe("Saved")
    end)
  end)

  describe("a TomTom that lacks some functions", function()
    local ctx = H.use({
      boot = true,
      world = function() _G.TomTom = { AddWaypoint = function() end } end,
    })

    it("hooks only what exists", function()
      ctx.ns.commands.tomtom()
      expect(ctx.world:output()).toContain("Hooked: AddWaypoint.")
    end)
  end)

  describe("when TomTom is absent", function()
    local ctx = H.use({ boot = true })

    it("does nothing and says so on request", function()
      expect(TomTom).toBeNil()
      ctx.ns.commands.tomtom()
      expect(ctx.world:output()).toContain("TomTom is not loaded")
    end)
  end)
end)
