local H = require("tests.helpers.addon")

describe("Compass layout", function()
  local ns = H.pure({ "core/Geometry.lua", "compass/Layout.lua" })
  local L = ns.compassLayout

  describe("scale", function()
    it("labels north at the centre when heading north", function()
      local _, labels = L.scale(0, 140, 600)
      expect(labels[0].name).toBe("N")
      expect(labels[0].x).toBe(0)
    end)

    it("shows only labels inside the field of view", function()
      local _, labels = L.scale(0, 140, 600)
      expect(labels[45]).toBeTruthy()   -- NE at +45 degrees
      expect(labels[315]).toBeTruthy()  -- NW at -45 degrees
      expect(labels[90]).toBeNil()      -- E at +90 is outside +/-70
      expect(labels[180]).toBeNil()
    end)

    it("moves labels left as heading turns clockwise", function()
      local _, labels = L.scale(45, 140, 600)
      expect(labels[45].x).toBe(0)
      expect(labels[0].x).toBeLessThan(0)
      expect(labels[90].x).toBeGreaterThan(0)
    end)

    it("draws major ticks every 15 degrees and minor ticks every 5", function()
      local ticks = L.scale(0, 140, 600)
      -- index 4 = heading 15 (major), index 3 = heading 10 (minor)
      expect(ticks[4].height).toBe(12)
      expect(ticks[3].height).toBe(6)
      expect(ticks[4].alpha).toBeGreaterThan(ticks[3].alpha)
    end)

    it("leaves tick slots empty where a label is drawn or the view ends", function()
      local ticks = L.scale(0, 140, 600)
      expect(ticks[1]).toBe(false)    -- heading 0 is the N label
      expect(ticks[37]).toBe(false)   -- heading 180, far outside the view
    end)

    it("scales offsets with the bar width", function()
      local _, narrow = L.scale(0, 140, 500)
      local _, wide = L.scale(0, 140, 800)
      expect(math.abs(wide[45].x)).toBeGreaterThan(math.abs(narrow[45].x))
    end)

    it("wraps across north", function()
      local _, labels = L.scale(350, 140, 600)
      expect(labels[0].x).toBeGreaterThan(0)
    end)
  end)

  describe("settle", function()
    local cfg = { tau = 0.06, step = 0.033, hold = 0.9, jump = 80 }
    local function run(state, targets)
      local px
      for _, t in ipairs(targets) do px, state = L.settle(state, t, cfg) end
      return px, state
    end

    it("takes a marker seen for the first time at its target, on a whole pixel", function()
      local px, state = L.settle(nil, 123.4, cfg)
      expect(px).toBe(123)
      expect(state.raw).toBe(123.4)
    end)

    it("holds the pixel while the target shivers within a pixel", function()
      local px, state = L.settle(nil, 100, cfg)
      for _, t in ipairs({ 100.4, 99.7, 100.5, 99.6, 100.3, 100.6, 99.5 }) do
        px, state = L.settle(state, t, cfg)
        expect(px).toBe(100)
      end
    end)

    it("moves once the target has really moved, easing toward it rather than jumping", function()
      local px, state = L.settle(nil, 100, cfg)
      px, state = L.settle(state, 130, cfg)
      expect(px).toBeGreaterThan(100)
      expect(px).toBeLessThan(130)
      px = run(state, { 130, 130, 130, 130, 130, 130, 130, 130, 130, 130, 130, 130 })
      expect(math.abs(px - 130)).toBeLessThan(1)       -- within the hold of its target
    end)

    it("takes a swing of more than the jump limit at once", function()
      local _, state = L.settle(nil, -250, cfg)
      local px = L.settle(state, 250, cfg)
      expect(px).toBe(250)
    end)

    it("always draws whole pixels", function()
      local px, state = L.settle(nil, 10.5, cfg)
      for t = 10.5, 40, 1.37 do
        px, state = L.settle(state, t, cfg)
        expect(px).toBe(math.floor(px))
      end
    end)
  end)

  describe("markers", function()
    local function wp(uid, delta, extra)
      local t = { uid = uid, delta = delta, compass = true, dist = 10 * uid, title = "wp" .. uid }
      for k, v in pairs(extra or {}) do t[k] = v end
      return t
    end

    it("eases the bearing toward the centre inside the settle radius", function()
      local cfg = { min = 20, max = 20, nearYd = 1, farYd = 2, default = 20, focusBoost = 0, settleYd = 8 }
      local far = L.markers({ wp(1, math.rad(35), { dist = 20 }) }, 140, 600, nil, nil, cfg)[1].x
      local near = L.markers({ wp(1, math.rad(35), { dist = 2 }) }, 140, 600, nil, nil, cfg)[1].x
      local onTop = L.markers({ wp(1, math.rad(35), { dist = 0 }) }, 140, 600, nil, nil, cfg)[1].x
      expect(math.abs(near)).toBeLessThan(math.abs(far))
      expect(onTop).toBeCloseTo(0, 6)
    end)

    it("does not shake: a point 2 yd away barely moves for a large bearing swing", function()
      local cfg = { min = 20, max = 20, nearYd = 1, farYd = 2, default = 20, focusBoost = 0, settleYd = 8 }
      local a = L.markers({ wp(1, math.rad(10), { dist = 2 }) }, 140, 600, nil, nil, cfg)[1].x
      local b = L.markers({ wp(1, math.rad(-10), { dist = 2 }) }, 140, 600, nil, nil, cfg)[1].x
      expect(math.abs(a - b)).toBeLessThan(30)
    end)

    it("stacks by kind and age, never by distance, with RXP and TomTom lowest and the focus highest", function()
      local list = {
        wp(1, 0, { dist = 500, icon = "kill" }),
        wp(2, 0, { dist = 5, icon = "rxp" }),
        wp(3, 0, { dist = 100, icon = "tomtom" }),
        wp(4, 0, { dist = 1, icon = "kill" }),
      }
      local byUid = {}
      for _, p in ipairs(L.markers(list, 140, 600, nil, 1)) do byUid[p.wp.uid] = p.level end
      expect(byUid[2]).toBeLessThan(byUid[3])     -- bridged ones are lowest, oldest first
      expect(byUid[3]).toBeLessThan(byUid[4])     -- ours above theirs
      expect(byUid[4]).toBeLessThan(byUid[1])     -- the focused one is on top
      local again = {}
      list[1].dist, list[4].dist = 1, 500          -- moving does not reshuffle
      for _, p in ipairs(L.markers(list, 140, 600, nil, 1)) do again[p.wp.uid] = p.level end
      expect(again).toEqual(byUid)
    end)

    it("places markers left for positive delta and right for negative", function()
      local placements = L.markers({ wp(1, math.rad(35)), wp(2, math.rad(-35)) }, 140, 600)
      expect(placements[1].x).toBeCloseTo(-150, 6)
      expect(placements[2].x).toBeCloseTo(150, 6)
      expect(placements[1].edge).toBe(false)
    end)

    it("clamps and flags markers outside the field of view", function()
      local placements = L.markers({ wp(1, math.rad(120)) }, 140, 600)
      expect(placements[1].x).toBe(-300)
      expect(placements[1].edge).toBe(true)
    end)

    it("skips waypoints without a delta or with compass disabled", function()
      local placements = L.markers({ wp(1, nil), wp(2, 0, { compass = false }), wp(3, 0) }, 140, 600)
      expect(#placements).toBe(1)
      expect(placements[1].wp.uid).toBe(3)
    end)

    it("draws at most max markers", function()
      local list = {}
      for i = 1, 30 do list[i] = wp(i, 0) end
      expect(#(L.markers(list, 140, 600))).toBe(L.MAX_MARKERS)
      expect(#(L.markers(list, 140, 600, 5))).toBe(5)
    end)

    it("captions the nearest waypoint, or the focused one", function()
      local list = { wp(1, 0), wp(2, 0), wp(3, 0) }
      local _, nearest = L.markers(list, 140, 600)
      expect(nearest.uid).toBe(1)
      local _, focused = L.markers(list, 140, 600, 20, 3)
      expect(focused.uid).toBe(3)
    end)
  end)

  describe("text", function()
    it("formats the target caption", function()
      expect(L.targetText({ title = "Anvil", dist = 123.7 })).toBe("Anvil - 123 yd")
      expect(L.targetText({ title = "Anvil", dist = 2, arrived = true })).toBe("Anvil - 2 yd (arrived)")
    end)

    it("is empty without a waypoint or distance", function()
      expect(L.targetText(nil)).toBe("")
      expect(L.targetText({ title = "x" })).toBe("")
    end)

    it("formats coordinates to one decimal", function()
      expect(L.coordsText(61.99, 70.58)).toBe("61.99, 70.58")
      expect(L.coordsText(nil, nil)).toBe("")
    end)
  end)
end)
