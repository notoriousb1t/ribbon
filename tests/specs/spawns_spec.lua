local H = require("tests.helpers.addon")

describe("Objective dots", function()
  local ctx = H.use({ boot = true })

  local function dots(lib)
    local out = {}
    for _, c in ipairs(lib.AddWorldMapIconMap.calls) do
      if c[1] ~= ctx.ns then out[#out + 1] = c end
    end
    return out
  end

  beforeEach(function()
    local R = Ribbon.Guide("g", { title = "Test Guide", schema = 1 })
    R:Names({ QUEST = { [1] = "One" }, CREATURE = { [9] = "Boar" } })
    R:Chapter("Camp", { levels = { 1, 5 } })
      :Step():Goto(1453, 50, 50):Kill(9, 3, { quest = 1, index = 1 }):Spawns(1453, { { 10, 10 }, { 20, 20 }, { 30, 30 } })
      :Done()
    ctx.ns.guidePlayer.state()
  end)

  it("is on by default", function()
    expect(ctx.ns.guideSettings.get("spawnDots")).toBe(true)
  end)

  it("puts a red dot on the world map for each spawn point of the current step's objective", function()
    ctx.ns.map.refreshContext()
    local placed = dots(ctx.ns.map.lib)
    expect(#placed).toBe(3)
    expect(placed[1][3]).toBe(1453)
    expect(placed[1][4]).toBeCloseTo(0.10, 3)
    expect(placed[1][2].tex.SetVertexColor).toHaveBeenCalled()
  end)

  it("takes the dots away when the setting is turned off", function()
    ctx.ns.map.refreshContext()
    local lib = ctx.ns.map.lib
    ctx.ns.guideSettings.set("spawnDots", false)
    expect(#lib.RemoveWorldMapIcon.calls).toBeGreaterThan(2)
    local before = #dots(lib)
    ctx.ns.map.refreshContext()
    expect(#dots(lib)).toBe(before)
  end)
end)
