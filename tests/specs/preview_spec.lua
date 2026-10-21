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

    it("draws each row with its badge: the quest symbol for an accept, the icon inside the disc for a kill", function()
      local d = open()
      local accept, kill = d.rightRows.items[1], d.rightRows.items[2]
      expect(accept.icon.glyphTex.SetTexture).toHaveBeenCalledWith(ctx.ns.compassStyle.textures.questExclaim)
      expect(accept.icon.glyphTex:IsShown()).toBe(true)
      expect(kill.icon.tex.SetTexture).toHaveBeenCalledWith(ctx.ns.ICONS.kill)
      expect(kill.icon.tex:IsShown()).toBe(true)
    end)

    it("keeps the text clear of the icon and of the hover arrow", function()
      local d = open()
      local row = d.rightRows.items[1]
      local left = 6 + 24 + 8
      expect(row.label.SetPoint).toHaveBeenCalledWith("TOPLEFT", row, "TOPLEFT", left, -5)
      local width = 300 - 22
      expect(row.label.SetWidth).toHaveBeenCalledWith(width - left - 22 - 10)
    end)
  end)

  describe("hover arrow", function()
    local ctx = H.use({ boot = true })
    local function open()
      ctx.ns.guideBrowser.toggleDock()
      return ctx.ns.guideBrowser.dock()
    end
    beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

    it("is hidden until the mouse is over the row, and hidden again when it leaves", function()
      local d = open()
      local row = d.rightRows.items[2]
      expect(row.go:IsShown()).toBe(false)
      row:Trigger("OnEnter")
      expect(row.go:IsShown()).toBe(true)
      row:Trigger("OnLeave")
      expect(row.go:IsShown()).toBe(false)
    end)

    it("stays while the mouse moves from the row onto the arrow", function()
      local d = open()
      local row = d.rightRows.items[2]
      row:Trigger("OnEnter")
      row.IsMouseOver = function() return true end            -- the mouse is still over the row's area
      row:Trigger("OnLeave")
      expect(row.go:IsShown()).toBe(true)
    end)

    it("makes the step the player's current one, and its tooltip says so", function()
      local d = open()
      local row = d.rightRows.items[4]
      row.go:Trigger("OnEnter")
      expect(GameTooltip.SetText).toHaveBeenCalledWith("Make this your current step")
      row.go:Trigger("OnClick")
      expect(ctx.ns.guidePlayer.current().index).toBe(4)
    end)

    it("points right, like go", function()
      local d = open()
      expect(d.rightRows.items[1].go.caret.SetTexCoord).toHaveBeenCalledWith(1, 0, 0, 1)
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
      expect(calls.preview[1]).toEqual({ 1453, 52, 52, "kill" })
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
