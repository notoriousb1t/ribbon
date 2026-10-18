local H = require("tests.helpers.addon")

-- RXPGuides with a real-looking step: the arrow element plus the step's other text lines.
local function newRXP()
  local step = { index = 19, elements = {} }
  local arrow = { zone = 1453, x = 45.5, y = 77.4, step = step }
  local kill = { text = "Kill Sharptusk Thornmantle (0/1)" }
  local loot = { text = "Collect the Hunting Horn" }
  step.elements = { arrow, kill, loot }
  local af = { shown = true, element = arrow }
  function af:IsShown() return self.shown end
  _G.RXPG_ARROW = af
  _G.RXP = { arrowFrame = af }
  return af, step, kill, loot
end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

describe("RXP step text on the compass", function()
  local af, step, kill, loot
  local ctx = H.use({ boot = true, world = function() af, step, kill, loot = newRXP() end })

  local function tick() ctx.world:update(0.3) end

  it("shows the step's own text instead of the step number", function()
    tick()
    local wp = ctx.ns:GetWaypoint(1)
    expect(wp.title).toBe("Kill Sharptusk Thornmantle (0/1)")
    expect(wp.title).never.toContain("Step")
    expect(wp.description).toEqual({ "Collect the Hunting Horn" })
  end)

  it("puts the headline and description on the compass caption", function()
    ctx.world:placePlayer(1453, 61.99, 70.58, 0)
    tick()
    tick()   -- the next frame measures the new waypoint's distance
    local parts = ctx.ns.compass.parts
    local texts = parts.targetText.SetText.calls
    local details = parts.detailText.SetText.calls
    expect(texts[#texts][1]).toContain("Kill Sharptusk Thornmantle (0/1)")
    expect(details[#details][1]).toBe("Collect the Hunting Horn")
  end)

  it("updates the text in place as the step progresses, keeping the same waypoint", function()
    tick()
    kill.text = "Kill Sharptusk Thornmantle (1/1)"
    tick()
    expect(count(ctx.ns.waypoints)).toBe(1)
    expect(ctx.ns:GetWaypoint(1).title).toBe("Kill Sharptusk Thornmantle (1/1)")
  end)

  it("drops finished lines from the description", function()
    tick()
    loot.completed = true
    tick()
    expect(ctx.ns:GetWaypoint(1).description).toEqual({})
  end)

  it("keeps focus on the waypoint while its text changes", function()
    tick()
    ctx.ns:SetFocus(1)
    kill.text = "Kill Sharptusk Thornmantle (1/1)"
    tick()
    expect(ctx.ns.focus).toBe(1)
  end)

  it("moves to a new waypoint when the arrow points somewhere else", function()
    tick()
    local other = { zone = 1453, x = 20, y = 30, step = step }
    af.element = other
    tick()
    expect(count(ctx.ns.waypoints)).toBe(1)
    expect(ctx.ns:GetWaypoint(2)).toBeTruthy()
  end)

  it("falls back to the step number when the step has no text", function()
    step.elements = { af.element }
    tick()
    expect(ctx.ns:GetWaypoint(1).title).toBe("Step 19")
  end)
end)
