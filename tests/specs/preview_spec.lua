local H = require("tests.helpers.addon")

-- Chapter one: accept (Stormwind 50,50), kill (52,52), loot-only step with no place, turn in (50,50).
local function build(R)
  R:Names({ QUEST = { [1] = "One", [2] = "Two" }, CREATURE = { [9] = "Boar" } })
  R:Chapter("Camp Narache", { levels = { 1, 5 } })
    :Step():Goto(1453, 50, 50):Accept(1)
    :Step():Goto(1453, 52, 52):Kill(9, 3, { quest = 1, index = 1 })
    :Step():Train(nil, { "Heal" })
    :Step():Goto(1453, 50, 50):Turnin(1)
    :Done()
  R:Chapter("Chapter Two", { levels = { 6, 8 } })
    :Step():Loop(1453, { { 10, 10 }, { 12, 12 } }):Kill(9, 3)
    :Done()
  return R
end

describe("Step icons, preview and the hover arrow", function()
  describe("pure helpers", function()
    local ns = H.pure({ "guide/Planner.lua", "guide/Text.lua" })
    local P, T = ns.guidePlanner, ns.guideText
    local function step(...) return { groups = { ... } } end
    local function group(kinds, at, loop)
      local calls = {}
      for i, k in ipairs(kinds) do calls[i] = { kind = k } end
      return { calls = calls, at = at, loop = loop }
    end

    it("draws a step with the first icon its groups have of their own", function()
      expect(T.stepIcon(step(group({ "Accept" })))).toBe("accept")
      expect(T.stepIcon(step(group({ "Travel" }), group({ "Kill" })))).toBe("kill")
      expect(T.stepIcon(step(group({ "Travel" })))).toBe("poi")
      expect(T.stepIcon(step())).toBe("poi")
    end)

    it("finds where a step is: its first located group, or a search area's first point", function()
      expect({ P.stepLocation(step(group({ "Accept" }, { map = 1, x = 2, y = 3 }))) }).toEqual({ 1, 2, 3 })
      expect({ P.stepLocation(step(group({ "Kill" }), group({ "Kill" }, { map = 4, x = 5, y = 6 }))) }).toEqual({ 4, 5, 6 })
      expect({ P.stepLocation(step(group({ "Kill" }, nil, { map = 7, points = { { 8, 9 }, { 1, 1 } } }))) }).toEqual({ 7, 8, 9 })
      expect(P.stepLocation(step(group({ "Train" })))).toBeNil()
    end)
  end)

  describe("step rows", function()
    local ctx = H.use({ boot = true })
    local function dock() return ctx.ns.guideBrowser.dock() end
    local function rows() return select(2, ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1)) end
    local function open()
      ctx.ns.guideBrowser.toggleDock()
      return dock()
    end
    beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

    it("has the step's icon and place, and no number in its text", function()
      local r = rows()
      expect(r[1].icon).toBe("accept")
      expect(r[2].icon).toBe("kill")
      expect(r[3].icon).toBe("train")
      expect(r[1].map).toBe(1453)
      expect(r[1].x).toBe(50)
      expect(r[3].map).toBeNil()
      expect(r[1].label).toBe("Accept One")
      expect(r[2].label).never.toContain("2. ")
    end)

    it("draws each row with its badge: the quest symbol for an accept, an inked symbol in the disc for a kill", function()
      local d = open()
      local accept, kill = d.rightRows.items[1], d.rightRows.items[2]
      expect(accept.icon.glyphTex.SetTexture).toHaveBeenCalledWith(ctx.ns.compassStyle.textures.questExclaim)
      expect(accept.icon.glyphTex:IsShown()).toBe(true)
      expect(kill.icon.glyphTex.SetTexture).toHaveBeenCalledWith(ctx.ns.compassStyle.textures.glyphKill)
      expect(kill.icon.glyphTex:IsShown()).toBe(true)
    end)

    it("keeps the text clear of the icon", function()
      local d = open()
      local row = d.rightRows.items[1]
      local left = 6 + 24 + 8
      expect(row.label.SetPoint).toHaveBeenCalledWith("TOPLEFT", row, "TOPLEFT", left, -5)
      local width = 300 - 22
      expect(row.label.SetWidth).toHaveBeenCalledWith(width - left - 10)
    end)
  end)

  describe("the icon as the make-current button", function()
    local ctx = H.use({ boot = true })
    local function open()
      ctx.ns.guideBrowser.toggleDock()
      return ctx.ns.guideBrowser.dock()
    end
    beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

    it("takes the current step's glow while the mouse is over the row, and loses it after", function()
      local d = open()
      local row = d.rightRows.items[2]
      expect(row.glow:IsShown()).toBe(false)
      row:Trigger("OnEnter")
      expect(row.glow:IsShown()).toBe(true)
      row:Trigger("OnLeave")
      expect(row.glow:IsShown()).toBe(false)
    end)

    it("keeps the look while the mouse moves from the row onto the icon", function()
      local d = open()
      local row = d.rightRows.items[2]
      row:Trigger("OnEnter")
      row.IsMouseOver = function() return true end            -- the mouse is still over the row's area
      row:Trigger("OnLeave")
      expect(row.glow:IsShown()).toBe(true)
    end)

    it("makes the step the player's current one when the icon is clicked, and its tooltip says so", function()
      local d = open()
      local row = d.rightRows.items[4]
      row.icon:Trigger("OnEnter")
      expect(GameTooltip.SetText).toHaveBeenCalledWith("Make this your current step")
      row.icon:Trigger("OnClick")
      expect(ctx.ns.guidePlayer.current().index).toBe(4)
    end)

    it("is not a separate arrow any more: nothing is drawn at the row's right", function()
      local d = open()
      expect(d.rightRows.items[1].go).toBeNil()
      expect(d.rightRows.items[1].check).toBeNil()
    end)
  end)

  describe("preview", function()
    local ctx = H.use({ boot = true })
    local calls
    local function open()
      ctx.ns.guideBrowser.toggleDock()
      return ctx.ns.guideBrowser.dock()
    end
    beforeEach(function()
      build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 }))
      calls = { preview = {}, clear = 0 }
      ctx.ns.map.preview = function(...) calls.preview[#calls.preview + 1] = { ... } end
      ctx.ns.map.clearPreview = function() calls.clear = calls.clear + 1 end
    end)

    it("shows a step on the map: its zone, place and icon", function()
      local d = open()
      d.rightRows.items[2]:Trigger("OnClick")
      expect(calls.preview[1]).toEqual({ 1453, 52, 52, "kill", { chapter = 1, step = 2 } })
    end)

    it("washes the previewed row blue and no other", function()
      local d = open()
      d.rightRows.items[2]:Trigger("OnClick")
      expect(d.rightRows.items[2].sel:IsShown()).toBe(true)
      expect(d.rightRows.items[1].sel:IsShown()).toBe(false)
      d.rightRows.items[1]:Trigger("OnClick")
      expect(d.rightRows.items[1].sel:IsShown()).toBe(true)
      expect(d.rightRows.items[2].sel:IsShown()).toBe(false)
    end)

    it("does not move the player", function()
      local d = open()
      d.rightRows.items[4]:Trigger("OnClick")
      expect(ctx.ns.guidePlayer.current().index).toBe(1)
    end)

    it("takes the pin off the map for a step that has no place", function()
      local d = open()
      d.rightRows.items[3]:Trigger("OnClick")
      expect(#calls.preview).toBe(0)
      expect(calls.clear).toBeGreaterThan(0)
    end)

    it("ends when the player's step changes, when the page changes and when the panel closes", function()
      local d = open()
      d.rightRows.items[2]:Trigger("OnClick")
      ctx.ns.guidePlayer.skip()
      expect(d.rightRows.items[2].sel:IsShown()).toBe(false)
      d.rightRows.items[2]:Trigger("OnClick")
      d.back:Trigger("OnClick")
      expect(d.rightRows.items[2].sel:IsShown()).toBe(false)
      ctx.ns.guideBrowser.showSteps()
      d.rightRows.items[2]:Trigger("OnClick")
      d.close:Trigger("OnClick")
      expect(d.rightRows.items[2].sel:IsShown()).toBe(false)
    end)

    it("clears the map pin each time it ends", function()
      local d = open()
      d.rightRows.items[2]:Trigger("OnClick")
      local before = calls.clear
      ctx.ns.guidePlayer.skip()
      expect(calls.clear).toBeGreaterThan(before)
    end)
  end)

  describe("on the map", function()
    local ctx = H.use({ boot = true })
    local sc

    beforeEach(function()
      sc = {
        GetScaleForMinZoom = function() return 0.5 end,
        GetScaleForMaxZoom = function() return 2.5 end,
      }
      sc.calls = {}
      sc.InstantPanAndZoom = function(self, ...) sc.calls[#sc.calls + 1] = { ... } end
      WorldMapFrame.ScrollContainer = sc
    end)
    afterEach(function() WorldMapFrame.ScrollContainer = nil end)

    it("switches the map to the zone, puts the badge there and centres on it half way into the zoom range", function()
      ctx.ns.map.preview(1453, 40, 60, "accept")
      expect(WorldMapFrame.SetMapID).toHaveBeenCalledWith(1453)
      local pins = ctx.world.pins
      expect(pins.AddWorldMapIconMap).toHaveBeenCalled()
      local call = pins.AddWorldMapIconMap.calls[#pins.AddWorldMapIconMap.calls]
      expect(call[3]).toBe(1453)
      expect(call[4]).toBeCloseTo(0.4, 6)
      expect(call[5]).toBeCloseTo(0.6, 6)
      local pin = ctx.ns.map.previewPin()
      expect(call[2]).toBe(pin)
      expect(pin.glyphTex.SetTexture).toHaveBeenCalledWith(ctx.ns.compassStyle.textures.questExclaim)
      expect(sc.calls[1][1]).toBeCloseTo(0.5 + (2.5 - 0.5) * ctx.ns.compassStyle.preview.zoom, 6)
      expect(sc.calls[1][2]).toBeCloseTo(0.4, 6)
      expect(sc.calls[1][3]).toBeCloseTo(0.6, 6)
    end)

    it("replaces the earlier preview and removes the pin on clear", function()
      ctx.ns.map.preview(1453, 40, 60, "accept")
      ctx.ns.map.preview(1453, 10, 20, "kill")
      local pins = ctx.world.pins
      expect(pins.RemoveWorldMapIcon).toHaveBeenCalledTimes(1)
      ctx.ns.map.clearPreview()
      expect(pins.RemoveWorldMapIcon).toHaveBeenCalledTimes(2)
      expect(ctx.ns.map.previewPin():IsShown()).toBe(false)
    end)

    it("falls back to pan and zoom targets when the container has no instant call", function()
      sc.InstantPanAndZoom = nil
      local zoom, pan
      sc.SetZoomTarget = function(self, z) zoom = z end
      sc.SetPanTarget = function(self, x, y) pan = { x, y } end
      ctx.ns.map.preview(1453, 40, 60, "kill")
      expect(zoom).toBeCloseTo(1.5, 6)
      expect(pan[1]).toBeCloseTo(0.4, 6)
    end)

    it("copes with a map container it does not know, and with bad arguments", function()
      WorldMapFrame.ScrollContainer = {}
      ctx.ns.map.preview(1453, 40, 60, "kill")       -- nothing to centre with: no error
      ctx.ns.map.preview("x", 1, 2, "kill")
      ctx.ns.map.preview(1453, nil, 2, "kill")
      expect(WorldMapFrame.SetMapID.calls[#WorldMapFrame.SetMapID.calls][1]).toBe(1453)
    end)
  end)
end)

describe("Clicking an icon on the map", function()
  local ctx = H.use({ boot = true })
  beforeEach(function()
    Ribbon.Guide("g", { title = "Test Guide", schema = 1 })
      :Chapter("One", { levels = { 1, 2 } }):Step():Goto(1453, 50, 50):Accept(1):Done()
    Ribbon.Guide("g"):Chapter("Two", { levels = { 3, 4 } }):Step():Goto(1453, 60, 60):Accept(2):Done()
  end)

  it("jumps to the previewed step, changing the chapter if need be", function()
    ctx.ns.guideBrowser.toggleDock()
    ctx.ns.guideBrowser.showSteps(2)
    ctx.ns.guideBrowser.preview(2, 1)
    local pin = ctx.ns.map.previewPin()
    expect(pin.target.chapter).toBe(2)
    pin:Trigger("OnClick", "LeftButton")
    expect(ctx.ns.guidePlayer.current().chapter).toBe(2)
  end)

  it("focuses the step's waypoint when a guide pin is left-clicked", function()
    local uid = ctx.ns.guidePlayer.state().waypoints[1].uid
    local pin = ctx.ns.map.createPin("world")
    pin:Configure(uid, nil, "quest")
    pin:Trigger("OnClick", "LeftButton")
    expect(ctx.ns.focus).toBe(uid)
  end)
end)

describe("Pins around the current step on the map", function()
  local ctx = H.use({ boot = true })
  beforeEach(function()
    local c = Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
    for i = 1, 5 do c:Step():Goto(1453, 40 + i, 40 + i):Accept(i) end
    c:Done()
  end)

  it("draws the last step white and the next two smaller", function()
    ctx.ns.guidePlayer.jump(1, 3)
    local ok, ctxPins = pcall(function() return ctx.ns.map end)
    local shown = {}
    local lib = ctx.ns.map.lib
    expect(lib.AddWorldMapIconMap.calls).toBeTruthy()
    local n = #lib.AddWorldMapIconMap.calls
    expect(n).toBeGreaterThan(2)
    local last = lib.AddWorldMapIconMap.calls[n - 2]
    local pin = last[2]
    local w = ctx.ns.compassStyle.context.last.color
    expect(pin.glyphTex.SetVertexColor).toHaveBeenCalledWith(w[1], w[2], w[3], 1)
    local small = lib.AddWorldMapIconMap.calls[n][2]
    local S = ctx.ns.compassStyle
    expect(small.SetSize.calls[#small.SetSize.calls][1]).toBe(math.floor(S.pins.world * S.context.next.scale + 0.5))
    expect(small.SetSize.calls[#small.SetSize.calls][1]).toBeLessThan(S.pins.world)
  end)

  it("draws the step the mouse is over opaque, with the steps either side of it fainter", function()
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    local lib = ctx.ns.map.lib
    local before = #lib.AddWorldMapIconMap.calls
    d.rightRows.items[3]:Trigger("OnEnter")
    local calls = lib.AddWorldMapIconMap.calls
    expect(#calls).toBe(before + 3)
    local alphas = {}
    for i = before + 1, before + 3 do local a = calls[i][2].SetAlpha.calls alphas[#alphas + 1] = a[#a][1] end
    expect(alphas[2]).toBe(1)
    expect(alphas[1]).toBeLessThan(0.9)
    expect(alphas[3]).toBeLessThan(0.9)
  end)

  it("draws the step the mouse is over in the panel the same small way", function()
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    local lib = ctx.ns.map.lib
    local before = #lib.AddWorldMapIconMap.calls
    d.rightRows.items[5]:Trigger("OnEnter")
    expect(#lib.AddWorldMapIconMap.calls).toBe(before + 2)        -- the step before it and the step itself (it is the last)
    d.rightRows.items[5]:Trigger("OnLeave")
    expect(lib.RemoveWorldMapIcon).toHaveBeenCalled()
  end)
end)

describe("The dashed line through a hovered step", function()
  local ctx = H.use({ boot = true })
  beforeEach(function()
    local c = Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
    for i = 1, 5 do c:Step():Goto(1453, 10 + 20 * (i - 1), 50):Accept(i) end
    c:Done()
    WorldMapFrame.ScrollContainer = { Child = WorldMapFrame }
    WorldMapFrame.GetWidth = function() return 1000 end
    WorldMapFrame.GetHeight = function() return 500 end
  end)

  it("runs from the step before to the second step after, in the ribbon's blue", function()
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    d.rightRows.items[2]:Trigger("OnEnter")                -- steps 1 to 4 at x = 10, 30, 50, 70
    local look = ctx.ns.compassStyle.context.line
    expect(look.color[3]).toBeGreaterThan(look.color[1])
    local lines = ctx.ns.map.dashParts()
    expect(#lines).toBeGreaterThan(10)
    local first, last = lines[1].SetStartPoint.calls[1], lines[#lines].SetEndPoint.calls[1]
    expect(first[3]).toBeCloseTo(100, 1)                    -- x = 10% of 1000
    expect(last[3]).toBeLessThan(701)                        -- not past x = 70%
    d.rightRows.items[2]:Trigger("OnLeave")
    expect(lines[1].Hide).toHaveBeenCalled()
  end)
end)

describe("The dashed line and the map being shown", function()
  local ctx = H.use({ boot = true })
  beforeEach(function()
    local c = Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
    for i = 1, 4 do c:Step():Goto(1453, 10 + 20 * (i - 1), 50):Accept(i) end
    c:Done()
    WorldMapFrame.ScrollContainer = { Child = WorldMapFrame }
    WorldMapFrame.GetWidth = function() return 1000 end
    WorldMapFrame.GetHeight = function() return 500 end
  end)

  it("is drawn only when the map shown is the one the steps are on", function()
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    WorldMapFrame.GetMapID = function() return 1453 end
    d.rightRows.items[2]:Trigger("OnEnter")
    local lines = ctx.ns.map.dashParts()
    expect(#lines).toBeGreaterThan(0)
    expect(lines[1]:IsShown()).toBe(true)
    d.rightRows.items[2]:Trigger("OnLeave")
    WorldMapFrame.GetMapID = function() return 1411 end         -- another zone's map
    d.rightRows.items[2]:Trigger("OnEnter")
    expect(lines[1]:IsShown()).toBe(false)
    WorldMapFrame.GetMapID = nil
  end)
end)

describe("The dashed line's look", function()
  local ctx = H.use({ boot = true })
  beforeEach(function()
    local c = Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
    for i = 1, 5 do c:Step():Goto(1453, 10 + 20 * (i - 1), 50):Accept(i) end
    c:Done()
    WorldMapFrame.ScrollContainer = { Child = WorldMapFrame }
    WorldMapFrame.GetWidth = function() return 1000 end
    WorldMapFrame.GetHeight = function() return 500 end
  end)

  it("is mostly opaque, thins along its length and ends in a dot", function()
    local look = ctx.ns.compassStyle.context.line
    expect(look.alpha).toBe(1)
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    d.rightRows.items[2]:Trigger("OnEnter")
    local lines, halos, dot, halo = ctx.ns.map.dashParts()
    local a = lines[1].SetThickness.calls[1][1]
    local z = lines[#lines].SetThickness.calls[1][1]
    expect(a).toBeGreaterThan(z)
    expect(a).toBeLessThan(look.thickness + 0.001)
    expect(z).toBeGreaterThan(look.thin - 0.001)
    expect(dot.SetSize).toHaveBeenCalledWith(look.dot, look.dot)
    expect(dot:IsShown()).toBe(true)
    -- a dark halo under every dash and under the dot, wider than they are, so it reads on any map colour
    local h1 = halos[1].SetThickness.calls[1][1]
    expect(h1).toBeCloseTo(a + look.haloWidth, 4)
    expect(halos[1].SetColorTexture.calls[1][1]).toBeLessThan(look.color[1])
    expect(halo.SetSize).toHaveBeenCalledWith(look.dot + look.haloWidth, look.dot + look.haloWidth)
    d.rightRows.items[2]:Trigger("OnLeave")
    expect(dot:IsShown()).toBe(false)
    expect(halo:IsShown()).toBe(false)
    expect(halos[1]:IsShown()).toBe(false)
  end)
end)
