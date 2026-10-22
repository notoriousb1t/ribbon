local H = require("tests.helpers.addon")

-- Two chapters on Stormwind City (1453): the first timed (3 steps), the second without timing.
local function build(R)
  R:Names({ QUEST = { [1] = "One", [2] = "Two", [3] = "Three", [4] = "Four" } })
  R:Chapter("Camp Narache", { levels = { 1, 5 } })
    :Step():Time(30, 10):Goto(1453, 50, 50):Accept(1)
    :Step():Time(0, 600):Goto(1453, 51, 51):Accept(2)
    :Step():Time(90, 20):Goto(1453, 52, 52):Accept(3)
    :Done()
  R:Chapter("Untimed", { levels = { 5, 6 } })
    :Step():Goto(1453, 60, 60):Accept(4)
    :Done()
  return R
end

describe("Guide timing", function()
  describe("builder", function()
    local ctx = H.use({ boot = true })
    local R

    beforeEach(function() R = Ribbon.Guide("g", { title = "Test Guide", schema = 1 }) end)

    it("keeps a step's travel and activity seconds and marks the chapter timed", function()
      build(R)
      local timed, untimed = R.chapters[1], R.chapters[2]
      expect(timed.steps[1].time).toEqual({ travel = 30, activity = 10 })
      expect(timed.timed).toBe(true)
      expect(untimed.timed).toBeNil()
      expect(untimed.steps[1].time).toBeNil()
    end)

    it("refuses negative or non-numeric seconds and skips the chapter", function()
      R:Chapter("Bad", {}):Step():Time(-1, 5):Goto(1453, 1, 1):Accept(1):Done()
      expect(#R.chapters).toBe(0)
      expect(#R.errors).toBe(1)
    end)
  end)

  describe("planner", function()
    local ns = H.pure({ "guide/Planner.lua", "guide/Text.lua" })
    local P, T = ns.guidePlanner, ns.guideText
    local function s(travel, activity) return { step = { time = travel and { travel = travel, activity = activity } or nil } } end
    local view = {
      { index = 1, steps = { s(30, 10), s(0, 600), s(90, 20) } },
      { index = 2, steps = { s() } },
    }

    it("sums the chapter and what is left, counting the current step", function()
      local t = P.times(view, {}, 2)
      expect(t.total).toBe(750)
      expect(t.left).toBe(710)
      expect(t.chapters[1]).toEqual({ total = 750, left = 710, timed = true })
      expect(t.chapters[2]).toEqual({ total = 0, left = 0, timed = false })
      expect(t.timed).toBe(true)
    end)

    it("has nothing left once finished and nothing timed without data", function()
      expect(P.times(view, {}, nil).left).toBe(0)
      expect(P.times({ { index = 1, steps = { s() } } }, {}, 1).timed).toBe(false)
    end)

    it("carries a step's time through filtering", function()
      local f = P.filterStep({ groups = {}, time = { travel = 1, activity = 2 } }, {})
      expect(f.time).toEqual({ travel = 1, activity = 2 })
    end)

    it("writes durations to the minute", function()
      expect(T.duration(20)).toBe("<1m")
      expect(T.duration(750)).toBe("13m")
      expect(T.duration(3900)).toBe("1h 05m")
    end)
  end)

  describe("panel", function()
    local ctx = H.use({ boot = true })
    beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

    it("shows the chapter's time and what is left, and nothing for an untimed chapter", function()
      ctx.ns.guidePlayer.jump(1, 2)
      local B, P = ctx.ns.guideBrowser, ctx.ns.guidePlayer
      local line = B.timeLine(P, 1, "steps")
      expect(line).toContain("Chapter")
      expect(line).toContain("13m")      -- 750 s in all
      expect(line).toContain("12m")      -- 710 s left (the current step counts)
      expect(B.timeLine(P, 2, "steps")).toBeNil()
    end)

    it("shows the guide's time on the chapter list", function()
      ctx.ns.guidePlayer.jump(1, 1)
      expect(ctx.ns.guideBrowser.timeLine(ctx.ns.guidePlayer, 1, "chapters")).toContain("Guide")
    end)
  end)
end)
