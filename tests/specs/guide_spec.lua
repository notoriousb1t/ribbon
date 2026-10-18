local H = require("tests.helpers.addon")

describe("Guide tracking frame", function()
  local ctx = H.use({ boot = true })
  local parts

  local function tick() ctx.world:update(0.25) end
  local function lastText(fs) return fs.SetText.calls[#fs.SetText.calls][1] end

  beforeEach(function()
    ctx.world:placePlayer(1453, 50, 50, 0)
    parts = ctx.ns.Guide.parts
  end)

  it("builds the frame with six rows", function()
    expect(parts.frame).toBe(RibbonGuide)
    expect(#parts.rows).toBe(6)
  end)

  it("hides itself when there is nothing to track", function()
    tick()
    expect(parts.frame:IsShown()).toBe(false)
  end)

  it("lists the nearest waypoints with distances", function()
    ctx.ns:AddWaypoint(1453, 50, 40, { title = "Far" })
    ctx.ns:AddWaypoint(1453, 50, 48, { title = "Near" })
    tick()
    expect(parts.frame:IsShown()).toBe(true)
    expect(lastText(parts.rows[1].name)).toBe("Near")
    expect(lastText(parts.rows[2].name)).toBe("Far")
    expect(lastText(parts.rows[1].dist)).toMatch("^%d+ yd$")
    expect(parts.rows[3]:IsShown()).toBe(false)
  end)

  it("uses the default header, or the one a provider sets", function()
    ctx.ns:AddWaypoint(1453, 50, 40)
    tick()
    expect(lastText(parts.header)).toBe("Waypoints")
    ctx.ns.Guide:SetHeader("Chapter 1")
    tick()
    expect(lastText(parts.header)).toBe("Chapter 1")
  end)

  it("stays visible for a provider header even with no waypoints", function()
    ctx.ns.Guide:SetHeader("Chapter 1")
    tick()
    expect(parts.frame:IsShown()).toBe(true)
  end)

  it("hides again when the user turns it off", function()
    ctx.ns:AddWaypoint(1453, 50, 40)
    ctx.ns.commands.guide("hide")
    expect(parts.frame:IsShown()).toBe(false)
    ctx.ns.commands.guide("show")
    expect(parts.frame:IsShown()).toBe(true)
  end)

  it("shows 'here' for an arrived waypoint", function()
    ctx.ns:AddWaypoint(1453, 50, 50, { title = "Here" })
    tick()
    expect(lastText(parts.rows[1].dist)).toBe("here")
  end)

  it("focuses a waypoint on left-click and unfocuses on a second click", function()
    local uid = ctx.ns:AddWaypoint(1453, 50, 40)
    tick()
    parts.rows[1]:Trigger("OnClick", "LeftButton")
    expect(ctx.ns.focus).toBe(uid)
    tick()
    expect(parts.rows[1].hl.SetShown).toHaveBeenCalledWith(true)
    parts.rows[1]:Trigger("OnClick", "LeftButton")
    expect(ctx.ns.focus).toBeNil()
  end)

  it("hides a waypoint on right-click", function()
    local uid = ctx.ns:AddWaypoint(1453, 50, 40)
    tick()
    parts.rows[1]:Trigger("OnClick", "RightButton")
    expect(ctx.ns:GetWaypoint(uid).visible).toBe(false)
  end)

  it("saves its position after a drag", function()
    parts.frame:Trigger("OnDragStart")
    expect(parts.frame.StartMoving).toHaveBeenCalled()
    parts.frame:Trigger("OnDragStop")
    expect(RibbonDB.guide.point).toBe("TOPLEFT")
  end)
end)
