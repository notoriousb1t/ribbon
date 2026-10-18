local H = require("tests.helpers.addon")
local Spy = require("tests.framework.spy")

describe("PinManager", function()
  local PM = H.pure({ "map/PinManager.lua" }).PinManager
  local ICONS = { poi = "tex-poi", kill = "tex-kill" }
  local pins, factory, created, manager, owner

  local function newPin()
    local pin = { Configure = Spy.new(nil, true), Hide = Spy.new(nil, true) }
    created[#created + 1] = pin
    return pin
  end

  local function wp(extra)
    local t = { uid = 1, mapID = 1453, x = 50, y = 25, icon = "kill", visible = true, worldmap = true, minimap = true }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
  end

  beforeEach(function()
    created, owner = {}, {}
    pins = {
      AddWorldMapIconMap = Spy.new(nil, true), RemoveWorldMapIcon = Spy.new(nil, true),
      AddMinimapIconMap = Spy.new(nil, true), RemoveMinimapIcon = Spy.new(nil, true),
    }
    factory = { create = Spy.new(newPin) }
    manager = PM.new({ pins = pins, ref = owner, factory = factory, icons = ICONS, defaultIcon = "poi", worldFlag = 2 })
  end)

  it("adds a world map icon with normalized coordinates and the show flag", function()
    manager:refresh(wp())
    expect(pins.AddWorldMapIconMap).toHaveBeenCalledTimes(1)
    local call = pins.AddWorldMapIconMap.calls[1]
    expect(call[1]).toBe(owner)
    expect(call[3]).toBe(1453)
    expect(call[4]).toBe(0.5)
    expect(call[5]).toBe(0.25)
    expect(call[6]).toBe(2)
  end)

  it("adds a minimap icon that floats on the edge", function()
    manager:refresh(wp())
    local call = pins.AddMinimapIconMap.calls[1]
    expect(call[1]).toBe(owner)
    expect(call[3]).toBe(1453)
    expect(call[6]).toBe(true)
    expect(call[7]).toBe(true)
  end)

  it("configures each pin with the waypoint uid and its icon texture", function()
    manager:refresh(wp({ uid = 7, icon = "kill" }))
    expect(created[1].Configure).toHaveBeenCalledWith(7, "tex-kill")
    expect(created[2].Configure).toHaveBeenCalledWith(7, "tex-kill")
  end)

  it("falls back to the default icon for an unknown icon name", function()
    manager:refresh(wp({ icon = "nonsense" }))
    expect(created[1].Configure).toHaveBeenCalledWith(1, "tex-poi")
  end)

  it("skips a surface the waypoint opts out of", function()
    manager:refresh(wp({ minimap = false }))
    expect(pins.AddWorldMapIconMap).toHaveBeenCalledTimes(1)
    expect(pins.AddMinimapIconMap).never.toHaveBeenCalled()
    manager:refresh(wp({ uid = 2, worldmap = false }))
    expect(pins.AddWorldMapIconMap).toHaveBeenCalledTimes(1)
    expect(pins.AddMinimapIconMap).toHaveBeenCalledTimes(1)
  end)

  it("adds nothing for a hidden waypoint", function()
    manager:refresh(wp({ visible = false }))
    expect(pins.AddWorldMapIconMap).never.toHaveBeenCalled()
    expect(pins.AddMinimapIconMap).never.toHaveBeenCalled()
  end)

  it("removes the old icons before re-adding on refresh", function()
    local w = wp()
    manager:refresh(w)
    manager:refresh(w)
    expect(pins.RemoveWorldMapIcon).toHaveBeenCalledTimes(1)
    expect(pins.RemoveMinimapIcon).toHaveBeenCalledTimes(1)
    expect(pins.AddWorldMapIconMap).toHaveBeenCalledTimes(2)
  end)

  it("removes icons and hides the pins when a waypoint goes away", function()
    local w = wp()
    manager:refresh(w)
    manager:remove(w)
    expect(pins.RemoveWorldMapIcon).toHaveBeenCalledTimes(1)
    expect(pins.RemoveMinimapIcon).toHaveBeenCalledTimes(1)
    expect(created[1].Hide).toHaveBeenCalled()
    expect(created[2].Hide).toHaveBeenCalled()
  end)

  it("recycles pins through a pool instead of creating new ones", function()
    local w = wp()
    manager:refresh(w)
    expect(factory.create).toHaveBeenCalledTimes(2)
    manager:remove(w)
    manager:refresh(w)
    expect(factory.create).toHaveBeenCalledTimes(2)
  end)

  it("asks the factory for the right kind of pin", function()
    manager:refresh(wp())
    expect(factory.create).toHaveBeenCalledWith("world")
    expect(factory.create).toHaveBeenCalledWith("mini")
  end)

  it("removing an unknown waypoint does nothing", function()
    manager:remove(wp({ uid = 99 }))
    expect(pins.RemoveWorldMapIcon).never.toHaveBeenCalled()
  end)

  it("resyncs every waypoint", function()
    manager:resync({ [1] = wp({ uid = 1 }), [2] = wp({ uid = 2 }) })
    expect(pins.AddWorldMapIconMap).toHaveBeenCalledTimes(2)
  end)
end)
