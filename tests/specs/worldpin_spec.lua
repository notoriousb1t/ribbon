local H = require("tests.helpers.addon")

describe("In-world marker", function()
  local ctx = H.use({ boot = true })
  local set, cleared, tracked

  beforeEach(function()
    Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
      :Step():Goto(1453, 50, 50):Accept(1):Done()
    set, cleared, tracked = {}, 0, {}
    _G.UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
    _G.C_Map = _G.C_Map or {}
    _G.C_Map.SetUserWaypoint = function(p) set[#set + 1] = p end
    _G.C_Map.ClearUserWaypoint = function() cleared = cleared + 1 end
    _G.C_Map.CanSetUserWaypointOnMap = nil
    _G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) tracked[#tracked + 1] = v end }
  end)
  afterEach(function()
    _G.UiMapPoint, _G.C_SuperTrack = nil, nil
    _G.C_Map.SetUserWaypoint, _G.C_Map.ClearUserWaypoint = nil, nil
  end)

  it("sets the game's waypoint to the focused waypoint while a guide runs, and clears it with the focus", function()
    ctx.ns.guidePlayer.state = function() return {} end
    local uid = ctx.ns:AddWaypoint(1453, 30, 40, { title = "Tome" })
    ctx.ns:SetFocus(uid)
    expect(#set).toBe(1)
    expect(set[1].uiMapID).toBe(1453)
    expect(set[1].x).toBeCloseTo(0.30, 3)
    expect(set[1].y).toBeCloseTo(0.40, 3)
    expect(tracked[1]).toBe(true)
    ctx.ns:SetFocus(nil)
    expect(cleared).toBe(1)
  end)

  it("leaves the game's waypoint alone with no guide running or the option off", function()
    ctx.ns.guidePlayer.state = function() return nil end
    local uid = ctx.ns:AddWaypoint(1453, 30, 40, { title = "Tome" })
    ctx.ns:SetFocus(uid)
    expect(#set).toBe(0)
    expect(cleared).toBe(0)
    ctx.ns.guidePlayer.state = function() return {} end
    ctx.ns.guideSettings.set("worldPin", false)
    ctx.ns:SetFocus(uid)
    expect(#set).toBe(0)
  end)
end)
