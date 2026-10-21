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

  -- The x (0-100) of each step pin (not a waypoint's) added to the map since call `from`.
  local function placed(from)
    local out = {}
    local calls = ctx.ns.map.lib.AddWorldMapIconMap.calls
    for i = from + 1, #calls do
      if calls[i][1] ~= ctx.ns then out[#out + 1] = math.floor(calls[i][4] * 100 + 0.5) end
    end
    return out
  end

  it("draws only the next two steps after the current one, smaller than its pin, and none before it", function()
    local lib = ctx.ns.map.lib
    ctx.ns.guidePlayer.state()                            -- the plan is built (it draws step 1's next two)
    local before = #lib.AddWorldMapIconMap.calls
    ctx.ns.guidePlayer.jump(1, 3)
    expect(placed(before)).toEqual({ 44, 45 })            -- steps 4 and 5; step 2 (just done) gets no pin
    local small = lib.AddWorldMapIconMap.calls[#lib.AddWorldMapIconMap.calls][2]
    local S = ctx.ns.compassStyle
    expect(small.SetSize.calls[#small.SetSize.calls][1]).toBe(math.floor(S.pins.world * S.context.next.scale + 0.5))
    expect(small.SetSize.calls[#small.SetSize.calls][1]).toBeLessThan(S.pins.world)
  end)

  it("on hover, draws the step the mouse is over opaque and the next two after it fainter, and nothing before it", function()
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    local lib = ctx.ns.map.lib
    local before = #lib.AddWorldMapIconMap.calls
    d.rightRows.items[3]:Trigger("OnEnter")
    local got = placed(before)
    table.sort(got)
    expect(got).toEqual({ 43, 44, 45 })
    local calls = lib.AddWorldMapIconMap.calls
    local alpha = {}
    for i = before + 1, #calls do local a = calls[i][2].SetAlpha.calls alpha[math.floor(calls[i][4] * 100 + 0.5)] = a[#a][1] end
    expect(alpha[43]).toBe(1)
    expect(alpha[44]).toBeLessThan(0.9)
    expect(alpha[45]).toBeLessThan(0.9)
  end)

  it("keeps the current step's next two on the map while a step is hovered, and takes the hovered ones away after", function()
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    local lib = ctx.ns.map.lib
    local function shownPins()
      local seen, out = {}, {}
      for _, c in ipairs(lib.AddWorldMapIconMap.calls) do
        local pin = c[2]
        if c[1] ~= ctx.ns and not seen[pin] and pin:IsShown() then
          seen[pin] = true
          out[#out + 1] = math.floor(c[4] * 100 + 0.5)
        end
      end
      table.sort(out)
      return out
    end
    expect(shownPins()).toEqual({ 42, 43 })               -- the current step is the first: steps 2 and 3
    d.rightRows.items[4]:Trigger("OnEnter")
    expect(shownPins()).toEqual({ 42, 43, 44, 45 })       -- and the hovered step 4 with step 5 after it
    d.rightRows.items[4]:Trigger("OnLeave")
    expect(shownPins()).toEqual({ 42, 43 })
  end)

  it("passes over a level-up step for the pins: a current step with no place draws the next one's pin", function()
    local c = Ribbon.Guide("g"):Chapter("Two", { levels = { 3, 4 } })
    c:Step():Ding(4)
    for i = 1, 3 do c:Step():Goto(1453, 60 + i, 60):Accept(20 + i) end
    c:Done()
    local lib = ctx.ns.map.lib
    ctx.ns.guidePlayer.state()
    local before = #lib.AddWorldMapIconMap.calls
    ctx.ns.guidePlayer.jump(2, 1)
    local got = placed(before)
    table.sort(got)
    expect(got).toEqual({ 61, 62, 63 })
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

  -- The x of the first dash's start and of the dot, the line's two ends.
  local function ends()
    local lines, _, dot = ctx.ns.map.dashParts()
    local shown
    for _, l in ipairs(lines) do if l:IsShown() then shown = l break end end
    local s = shown.SetStartPoint.calls[#shown.SetStartPoint.calls]
    local p = dot.SetPoint.calls[#dot.SetPoint.calls]
    return s[3], p[4]
  end

  it("runs from the hovered step through the next two, in the ribbon's blue", function()
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    d.rightRows.items[2]:Trigger("OnEnter")                -- steps 2 to 4 at x = 30, 50, 70
    local look = ctx.ns.compassStyle.context.line
    expect(look.color[3]).toBeGreaterThan(look.color[1])
    local lines = ctx.ns.map.dashParts()
    expect(#lines).toBeGreaterThan(10)
    local a, z = ends()
    expect(a).toBeCloseTo(300, 1)                          -- x = 30% of 1000
    expect(z).toBeCloseTo(700, 1)                          -- the dot on step 4
  end)

  it("runs from the current step through the next two when nothing is hovered", function()
    ctx.ns.guidePlayer.jump(1, 3)                          -- steps 3 to 5 at x = 50, 70, 90
    local a, z = ends()
    expect(a).toBeCloseTo(500, 1)
    expect(z).toBeCloseTo(900, 1)
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

  it("follows the steps onto the continent's map, and is not drawn on another continent", function()
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    WorldMapFrame.GetMapID = function() return 1453 end
    d.rightRows.items[2]:Trigger("OnEnter")
    local lines, _, dot = ctx.ns.map.dashParts()
    expect(lines[1]:IsShown()).toBe(true)
    WorldMapFrame.GetMapID = function() return 1415 end         -- Eastern Kingdoms, Stormwind's continent
    ctx.ns.map.redrawLine()                                     -- the map changed: drawn again
    expect(lines[1]:IsShown()).toBe(true)
    local x = ctx.ns.client.mapPosition(1453, 70, 50, 1415)
    local p = dot.SetPoint.calls[#dot.SetPoint.calls]
    expect(p[4]).toBeCloseTo(x / 100 * 1000, 1)                -- the dot on step 4, where the continent map has it
    WorldMapFrame.GetMapID = function() return 1414 end         -- Kalimdor
    ctx.ns.map.redrawLine()
    expect(lines[1]:IsShown()).toBe(false)
    WorldMapFrame.GetMapID = nil
  end)

  it("passes over a step with no place on the map, joining the icons either side of it", function()
    local c = Ribbon.Guide("g"):Chapter("Two", { levels = { 3, 4 } })
    c:Step():Goto(1453, 10, 50):Accept(11)
    c:Step():Fp("Nowhere")
    c:Step():Goto(1453, 50, 50):Accept(12)
    c:Step():Goto(1453, 90, 50):Accept(13)
    c:Done()
    ctx.ns.guidePlayer.jump(2, 1)
    local lines, _, dot = ctx.ns.map.dashParts()
    local first = lines[1].SetStartPoint.calls[#lines[1].SetStartPoint.calls]
    local p = dot.SetPoint.calls[#dot.SetPoint.calls]
    expect(first[3]).toBeCloseTo(100, 1)                        -- from step 1
    expect(p[4]).toBeCloseTo(900, 1)                            -- through step 3 to step 4: two placed steps after it
    expect(dot:IsShown()).toBe(true)
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
    -- the hovered line goes; the current step's stays: steps 1 to 3, the dot on step 3 at x = 50%
    expect(dot:IsShown()).toBe(false)
    local _, _, current = ctx.ns.map.dashParts("current")
    expect(current:IsShown()).toBe(true)
    local at = current.SetPoint.calls[#current.SetPoint.calls]
    expect(at[4]).toBeCloseTo(500, 1)
  end)

  it("draws the current step's line and the hovered step's line at once", function()
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    d.rightRows.items[3]:Trigger("OnEnter")
    local _, _, hoverDot = ctx.ns.map.dashParts("hover")
    local _, _, currentDot = ctx.ns.map.dashParts("current")
    expect(hoverDot:IsShown()).toBe(true)
    expect(currentDot:IsShown()).toBe(true)
    expect(hoverDot.SetPoint.calls[#hoverDot.SetPoint.calls][4]).toBeCloseTo(900, 1)       -- steps 3 to 5
    expect(currentDot.SetPoint.calls[#currentDot.SetPoint.calls][4]).toBeCloseTo(500, 1)   -- steps 1 to 3
  end)

  it("starts a line at the next step with a place when the step is a level-up", function()
    local c = Ribbon.Guide("g"):Chapter("Two", { levels = { 3, 4 } })
    c:Step():Ding(4)
    for i = 1, 3 do c:Step():Goto(1453, 10 + 20 * i, 50):Accept(20 + i) end
    c:Done()
    ctx.ns.guidePlayer.jump(2, 1)
    local lines, _, dot = ctx.ns.map.dashParts("current")
    local first
    for _, l in ipairs(lines) do if l:IsShown() then first = l break end end
    expect(first.SetStartPoint.calls[#first.SetStartPoint.calls][3]).toBeCloseTo(300, 1)
    expect(dot.SetPoint.calls[#dot.SetPoint.calls][4]).toBeCloseTo(700, 1)
  end)
end)
