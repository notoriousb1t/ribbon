local H = require("tests.helpers.addon")

local CORE = { "core/Core.lua", "core/Client.lua" }

describe("Core", function()
  describe("module events", function()
    local ctx = H.use({ files = CORE })

    it("delivers fired events with their arguments, in registration order", function()
      local order = {}
      ctx.ns:On("X", function(a, b) order[#order + 1] = "first:" .. a .. b end)
      ctx.ns:On("X", function() order[#order + 1] = "second" end)
      ctx.ns:Fire("X", 1, 2)
      expect(order).toEqual({ "first:12", "second" })
    end)

    it("ignores events nobody listens to", function()
      expect(function() ctx.ns:Fire("NOBODY") end).never.toThrow()
    end)

    it("isolates a failing handler and reports it to the error handler", function()
      local ran = createSpy()
      ctx.ns:On("X", function() error("bad handler") end)
      ctx.ns:On("X", ran)
      ctx.ns:Fire("X")
      expect(ran).toHaveBeenCalled()
      expect(#ctx.world.errors).toBe(1)
      expect(ctx.world.errors[1]).toMatch("bad handler")
    end)
  end)

  describe("start-up on a complete client", function()
    local ctx = H.use({ files = CORE })

    it("loads defaults, becomes ready and fires INIT", function()
      local init = createSpy()
      ctx.ns:On("INIT", init)
      ctx.world:fireEvent("PLAYER_LOGIN")
      expect(ctx.ns.ready).toBe(true)
      expect(init).toHaveBeenCalledTimes(1)
      expect(RibbonDB.compass.width).toBe(600)
      expect(ctx.ns.db).toBe(RibbonDB)
    end)
  end)

  describe("start-up with saved variables", function()
    local ctx = H.use({
      files = CORE, boot = true,
      world = function() RibbonDB = { compass = { width = 700 } } end,
    })

    it("keeps saved values and fills in missing defaults", function()
      expect(RibbonDB.compass.width).toBe(700)
      expect(RibbonDB.compass.fov).toBe(140)
      expect(RibbonDB.compass.locked).toBe(false)
    end)
  end)

  describe("start-up on a client missing an API", function()
    local ctx = H.use({
      files = CORE,
      world = function(w) w:removeApi("GetPlayerFacing") end,
    })

    it("stays dormant and names the missing APIs", function()
      local init = createSpy()
      ctx.ns:On("INIT", init)
      ctx.world:fireEvent("PLAYER_LOGIN")
      expect(ctx.ns.ready).toBeNil()
      expect(init).never.toHaveBeenCalled()
      expect(ctx.world:output()).toContain("GetPlayerFacing")
    end)
  end)

  describe("tickers", function()
    local ctx = H.use({ files = CORE, boot = true })

    it("fires a ticker once its interval has elapsed", function()
      local fn = createSpy()
      ctx.ns:Every(0.1, fn)
      ctx.world:update(0.05)
      expect(fn).never.toHaveBeenCalled()
      ctx.world:update(0.06)
      expect(fn).toHaveBeenCalledTimes(1)
    end)

    it("disables a ticker that errors and tells the user once", function()
      local fn = createSpy():andCall(function() error("boom") end)
      ctx.ns:Every(0.01, fn)
      ctx.world:update(0.02)
      ctx.world:update(0.02)
      expect(fn).toHaveBeenCalledTimes(1)
      expect(#ctx.world.errors).toBe(1)
      expect(ctx.world:output()).toContain("update loop was disabled")
    end)
  end)

  describe("tickers before the addon is ready", function()
    local ctx = H.use({ files = CORE })

    it("do not run", function()
      local fn = createSpy()
      ctx.ns:Every(0.01, fn)
      ctx.world:update(1)
      expect(fn).never.toHaveBeenCalled()
    end)
  end)
  describe("icons", function()
    local ctx = H.use({ files = CORE })

    it("keep the raid target markers (raid1 to raid8) for marked units, and no other icon uses one", function()
      for name, path in pairs(ctx.ns.ICONS) do
        local isRaid = name:match("^raid[1-8]$") ~= nil
        expect(path:find("RaidTargeting", 1, true) ~= nil).toBe(isRaid)
      end
      for i = 1, 8 do expect(ctx.ns.ICONS["raid" .. i]).toContain("UI-RaidTargetingIcon_" .. i) end
    end)

    it("have an icon for every kind of marker badge", function()
      local badge = H.pure({ "compass/Style.lua" }).compassStyle.badge
      for name in pairs(badge.kinds) do expect(ctx.ns.ICONS[name]).toBeTruthy() end
    end)

    it("include one for every guide icon name", function()
      for _, name in ipairs({ "accept", "turnin", "kill", "loot", "interact", "grind", "poi", "fp", "hearth", "train", "ding" }) do
        expect(ctx.ns.ICONS[name]).toBeTruthy()
      end
    end)
  end)
end)
