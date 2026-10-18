local H = require("tests.helpers.addon")

describe("Compass dial", function()
  describe("layout", function()
    local L = H.pure({ "core/Geometry.lua", "compass/Layout.lua" }).compassLayout

    it("names the eight compass points", function()
      expect(L.compassPoint(0)).toBe("N")
      expect(L.compassPoint(45)).toBe("NE")
      expect(L.compassPoint(90)).toBe("E")
      expect(L.compassPoint(135)).toBe("SE")
      expect(L.compassPoint(180)).toBe("S")
      expect(L.compassPoint(225)).toBe("SW")
      expect(L.compassPoint(270)).toBe("W")
      expect(L.compassPoint(315)).toBe("NW")
    end)

    it("rounds to the nearest point and wraps at north", function()
      expect(L.compassPoint(22)).toBe("N")
      expect(L.compassPoint(23)).toBe("NE")
      expect(L.compassPoint(359)).toBe("N")
      expect(L.compassPoint(337)).toBe("NW")
      expect(L.compassPoint(-90)).toBe("W")
    end)

    it("turns a -180..180 heading into 0..360 degrees", function()
      expect(L.headingDegrees(-90)).toBe(270)
      expect(L.headingDegrees(45)).toBe(45)
      expect(L.headingDegrees(0)).toBe(0)
    end)

    it("builds the tooltip: coordinates, zone and facing", function()
      local tip = L.coordinateTooltip("Stormwind City", 45.4512, 77.3712, 45)
      expect(tip.title).toBe("45.45, 77.37")
      expect(tip.lines).toEqual({ "Stormwind City", "Facing NE (45 degrees)" })
    end)

    it("says when the position is unavailable and skips what is unknown", function()
      local tip = L.coordinateTooltip(nil, nil, nil, nil)
      expect(tip.title).toBe("Position unavailable")
      expect(tip.lines).toEqual({})
    end)
  end)

  describe("view", function()
    local ctx = H.use({ boot = true })
    local parts

    local function frameTick() ctx.world:update(0.04) end
    local function lastRotation()
      local calls = parts.needle.SetRotation.calls
      return calls[#calls] and calls[#calls][1]
    end
    local function tooltipTexts()
      local out = {}
      for _, call in ipairs(GameTooltip.SetText.calls) do out[#out + 1] = call[1] end
      for _, call in ipairs(GameTooltip.AddLine.calls) do out[#out + 1] = call[1] end
      return table.concat(out, "\n")
    end

    beforeEach(function()
      ctx.world:placePlayer(1453, 61.99, 70.58, 0)
      parts = ctx.ns.compass.parts
    end)

    describe("needle", function()
      it("points up (no rotation) when facing north", function()
        ctx.world.player.facing = 0
        frameTick()
        expect(lastRotation()).toBe(0)
      end)

      it("turns right when the player turns left (facing grows counter-clockwise)", function()
        ctx.world.player.facing = math.pi / 2   -- facing west: north is now to the right
        frameTick()
        expect(lastRotation()).toBeCloseTo(-math.pi / 2, 6)
      end)

      it("keeps pointing to north as the player turns around", function()
        ctx.world.player.facing = math.pi   -- facing south: north is behind
        frameTick()
        expect(lastRotation()).toBeCloseTo(-math.pi, 6)
      end)

      it("matches the measured turn: facing 4.8129 then 6.2266 (a quarter turn left)", function()
        ctx.world.player.facing = 4.8129005432129
        frameTick()
        local before = lastRotation()
        ctx.world.player.facing = 6.2266173362732
        frameTick()
        expect(lastRotation() - before).toBeCloseTo(-1.4137, 3)   -- rotates clockwise by the turn
      end)

      it("does not rewrite the rotation while the facing is unchanged", function()
        ctx.world.player.facing = 1
        frameTick()
        local count = parts.needle.SetRotation.callCount
        frameTick()
        frameTick()
        expect(parts.needle.SetRotation.callCount).toBe(count)
      end)

      it("resets to north when the facing is unavailable", function()
        ctx.world.player.facing = 1
        frameTick()
        spyOn(ctx.ns.client, "facing"):andReturn(nil)
        frameTick()
        expect(lastRotation()).toBe(0)
      end)
    end)

    describe("coordinates on hover", function()
      it("shows the coordinates, zone and facing", function()
        ctx.world.player.facing = math.pi / 2
        parts.dial:Trigger("OnEnter")
        local text = tooltipTexts()
        expect(text).toContain("61.99, 70.58")
        expect(text).toContain("Stormwind City")
        expect(text).toContain("Facing W (270 degrees)")
        expect(GameTooltip.Show).toHaveBeenCalled()
      end)

      it("anchors the tooltip to the dial", function()
        parts.dial:Trigger("OnEnter")
        expect(GameTooltip.SetOwner).toHaveBeenCalledWith(parts.dial, "ANCHOR_BOTTOM")
      end)

      it("colours the coordinates gold", function()
        parts.dial:Trigger("OnEnter")
        local gold = ctx.ns.compassStyle.colors.gold
        expect(GameTooltip.SetText).toHaveBeenCalledWith("61.99, 70.58", gold[1], gold[2], gold[3])
      end)

      it("says the position is unavailable when it is", function()
        ctx.world.player.noPosition = true
        parts.dial:Trigger("OnEnter")
        expect(tooltipTexts()).toContain("Position unavailable")
      end)

      it("hides the tooltip when the pointer leaves", function()
        parts.dial:Trigger("OnEnter")
        parts.dial:Trigger("OnLeave")
        expect(GameTooltip.Hide).toHaveBeenCalled()
      end)

      it("keeps the tooltip live while it is hovered", function()
        GameTooltip.IsOwned = function() return true end
        parts.dial:Trigger("OnEnter")
        local shows = GameTooltip.Show.callCount
        ctx.world:update(0.11)
        expect(GameTooltip.Show.callCount).toBeGreaterThan(shows)
      end)

      it("does not touch the tooltip when the dial is not hovered", function()
        GameTooltip.IsOwned = function() return false end
        ctx.world:update(0.11)
        expect(GameTooltip.Show).never.toHaveBeenCalled()
      end)
    end)

    describe("dragging", function()
      it("moves the bar when the dial is dragged", function()
        parts.dial:Trigger("OnDragStart")
        expect(parts.frame.StartMoving).toHaveBeenCalled()
        parts.dial:Trigger("OnDragStop")
        expect(parts.frame.StopMovingOrSizing).toHaveBeenCalled()
      end)

      it("does not move the bar while it is locked", function()
        ctx.ns.commands.compass("lock")
        parts.dial:Trigger("OnDragStart")
        expect(parts.frame.StartMoving).never.toHaveBeenCalled()
      end)
    end)
  end)
end)
