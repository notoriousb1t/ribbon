local H = require("tests.helpers.addon")

-- A two-chapter guide on Stormwind City (1453), which the fake world knows: 3 + 2 visible steps.
local function build(R)
  R:Names({ QUEST = { [1] = "One", [2] = "Two", [3] = "Three", [4] = "Four", [5] = "Five" } })
  R:Chapter("Camp Narache", { levels = { 1, 5 } })
    :Step():Goto(1453, 50, 50):Accept(1)
    :Step():Goto(1453, 51, 51):Accept(2)
    :Step():Goto(1453, 52, 52):Accept(3)
    :Done()
  R:Chapter("11-12 Sentinel Hill (Westfall) \226\134\146 Report to Gryan", { levels = { 11, 12 } })
    :Step():Goto(1453, 60, 60):Accept(4)
    :Step():Goto(1453, 61, 61):Accept(5)
    :Done()
  return R
end

describe("Guide progress", function()
  describe("planner", function()
    local ns = H.pure({ "guide/Planner.lua", "guide/Text.lua" })
    local P, T = ns.guidePlanner, ns.guideText
    local view = {
      { index = 1, name = "a", steps = { {}, {}, {} } },
      { index = 2, name = "b", steps = { {}, {} } },
    }
    local flat = { 1, 2, 3, 4, 5 }

    it("counts the steps before the cursor as done, per chapter and overall", function()
      local p = P.progress(view, flat, 4)       -- on the first step of chapter 2
      expect(p.done).toBe(3)
      expect(p.total).toBe(5)
      expect(p.fraction).toBeCloseTo(0.6, 6)
      expect(p.chapters[1]).toEqual({ done = 3, total = 3, fraction = 1 })
      expect(p.chapters[2]).toEqual({ done = 0, total = 2, fraction = 0 })
    end)

    it("splits a chapter part-way", function()
      local p = P.progress(view, flat, 2)
      expect(p.chapters[1].done).toBe(1)
      expect(p.chapters[1].fraction).toBeCloseTo(1 / 3, 6)
      expect(p.chapters[2].done).toBe(0)
    end)

    it("is complete when finished and empty when there is no guide", function()
      expect(P.progress(view, flat, 6).fraction).toBe(1)
      expect(P.progress(view, flat, nil).done).toBe(5)
      expect(P.progress({}, {}, 1).fraction).toBe(0)
    end)

    it("keeps a chapter's level range on the view", function()
      local guide = { chapters = { { name = "c", opts = { levels = { 1, 5 } }, steps = { { groups = {} } } } } }
      expect(P.view(guide, {})[1].levels).toEqual({ 1, 5 })
    end)

    it("gives travel points a wide arrival radius, NPC points a medium one and quest points the default", function()
      local g = function(...) local calls = {} for i, k in ipairs({ ... }) do calls[i] = { kind = k } end return { calls = calls } end
      expect(P.arrivalRadius(g("Travel"))).toBe(25)
      expect(P.arrivalRadius(g("Enter", "Subzone"))).toBe(25)
      expect(P.arrivalRadius(g("Fp"))).toBe(10)
      expect(P.arrivalRadius(g("Travel", "Fp"))).toBe(10)
      expect(P.arrivalRadius(g("Accept"))).toBeNil()
      expect(P.arrivalRadius(g("Travel", "Kill"))).toBeNil()
      expect(P.arrivalRadius({ loop = { map = 1, points = {} }, calls = {} })).toBe(25)
    end)

    it("splits a chapter name at its arrow", function()
      local place, goal = T.chapterParts("11-12 Sentinel Hill (Westfall) \226\134\146 Report to Gryan")
      expect(place).toBe("11-12 Sentinel Hill (Westfall)")
      expect(goal).toBe("Report to Gryan")
      local only, none = T.chapterParts("1-11 Teldrassil (NightElf)")
      expect(only).toBe("1-11 Teldrassil (NightElf)")
      expect(none).toBeNil()
    end)
  end)

  describe("panel", function()
    local ctx = H.use({ boot = true })
    beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

    it("gives each chapter card its levels and progress", function()
      ctx.ns.guidePlayer.jump(1, 3)
      local left = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1)
      expect(left[1].levels).toEqual({ 1, 5 })
      expect(left[1].done).toBe(2)
      expect(left[1].total).toBe(3)
      expect(left[2].done).toBe(0)
    end)

    it("writes 'Lv a-b - percent' on the second line", function()
      local B = ctx.ns.guideBrowser
      expect(B.subtitle({ levels = { 12, 14 }, fraction = 0.48 })).toContain("Lv 12-14 - 48%")
      expect(B.subtitle({ levels = { 5, 5 }, fraction = 1 })).toContain("Lv 5 - 100%")
      expect(B.subtitle({ fraction = 0 })).toContain("0%")
    end)

    it("shows the place on the card, the percent in the subtitle and a filled bar", function()
      ctx.ns.guidePlayer.jump(2, 1)               -- chapter 1 is done
      ctx.ns.guideBrowser.toggle()
      local frame = ctx.ns.guideBrowser.frame()
      local card = frame.leftRows.items[2]
      expect(card.label.SetText).toHaveBeenCalled()
      local text = card.label.SetText.calls[#card.label.SetText.calls][1]
      expect(text).toContain("11-12 Sentinel Hill (Westfall)")
      expect(text).never.toContain("Report to Gryan")
      expect(frame.leftRows.items[1].sub.SetText.calls[#frame.leftRows.items[1].sub.SetText.calls][1]).toContain("100%")
      expect(frame.leftRows.items[1].bar.fill:IsShown()).toBe(true)
      expect(frame.leftRows.items[2].bar.fill:IsShown()).toBe(false)
    end)

    it("shows the overall percent of the whole guide", function()
      ctx.ns.guidePlayer.jump(2, 1)               -- 3 of 5 steps done
      ctx.ns.guideBrowser.toggle()
      local frame = ctx.ns.guideBrowser.frame()
      expect(frame.overallText.SetText).toHaveBeenCalledWith("60%")
    end)

    it("drops the browsed chapter when the step changes and shows the active chapter again", function()
      ctx.ns.guideBrowser.toggle()
      local frame = ctx.ns.guideBrowser.frame()
      frame.leftRows.items[2]:Trigger("OnClick")            -- browse chapter 2 (two steps)
      expect(frame.rightRows.items[3]:IsShown()).toBe(false)
      ctx.ns.guidePlayer.skip()                              -- a step occurs, still in chapter 1 (three steps)
      expect(frame.rightRows.items[3]:IsShown()).toBe(true)
    end)

    it("opens with /ribbon guides", function()
      SlashCmdList.RIBBON("guides")
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(true)
      SlashCmdList.RIBBON("guides")
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(false)
    end)
  end)

  describe("arrival radius", function()
    local ctx = H.use({ boot = true })

    it("gives a travel step's waypoint the wide radius and a quest step's the default", function()
      Ribbon.Guide("g", { schema = 1 }):Chapter("c")
        :Step():Goto(1453, 50, 50):Travel()
        :Step():Goto(1453, 60, 60):Accept(1)
        :Done()
      local function only() local w for _, wp in pairs(ctx.ns.waypoints) do w = wp end return w end
      ctx.ns.guidePlayer.refresh()
      expect(only().radius).toBe(25)
      ctx.ns.guidePlayer.skip()
      ctx.ns.guidePlayer.refresh()
      expect(only().radius).toBe(5)
    end)
  end)

  describe("focus", function()
    local ctx = H.use({ boot = true })

    local function guide()
      Ribbon.Guide("g", { schema = 1 }):Chapter("c")
        :Step():Goto(1453, 50, 50):Accept(1)
        :Step():Goto(1453, 60, 60):Accept(2):Goto(1453, 70, 70):Accept(3)
        :Step():Goto(1453, 40, 40):Accept(4)
        :Done()
    end
    local function focusedStep() return ctx.ns.focus and ctx.ns:GetWaypoint(ctx.ns.focus) end

    it("focuses the current step's waypoint, and the next step's after completing one", function()
      guide()
      ctx.ns.guidePlayer.refresh()
      expect(focusedStep().x).toBe(50)
      ctx.world.quest.log[1] = { complete = false }          -- step 1 done
      ctx.ns.guidePlayer.refresh()
      expect(focusedStep().x).toBe(60)                        -- the first located group of step 2
    end)

    it("keeps a waypoint the player focused until the step changes", function()
      guide()
      ctx.ns.guidePlayer.skip()
      ctx.ns.guidePlayer.refresh()
      local other
      for uid, wp in pairs(ctx.ns.waypoints) do if wp.x == 70 then other = uid end end
      ctx.ns:SetFocus(other)
      ctx.ns.guidePlayer.refresh()
      ctx.ns.guidePlayer.refresh()
      expect(ctx.ns.focus).toBe(other)
      ctx.ns.guidePlayer.skip()
      ctx.ns.guidePlayer.refresh()
      expect(focusedStep().x).toBe(40)
    end)

    it("keeps the step focused when the plan is rebuilt around it", function()
      guide()
      ctx.ns.guidePlayer.refresh()
      local before = focusedStep().x
      ctx.ns:Fire("GUIDE_CHAPTER_ADDED")           -- chapters arriving mark the plan stale; the next use rebuilds it
      ctx.ns.guidePlayer.refresh()
      expect(focusedStep().x).toBe(before)
    end)

    it("focuses on a manual skip and a jump as well", function()
      guide()
      ctx.ns.guidePlayer.jump(1, 3)
      expect(focusedStep().x).toBe(40)
      ctx.ns.guidePlayer.prev()
      expect(focusedStep().x).toBe(60)
    end)
  end)

  describe("tracked quest that the guide already covers", function()
    local ctx = H.use({ boot = true })

    local function track(id)
      local q = ctx.world.quest
      q.tracked = id
      q.titles[id] = "Stormpike's Order"
      q.points[1453] = { { questID = id, x = 0.646, y = 0.372 } }
      q.objectives[id] = { { finished = true, type = "log" } }
    end
    local function titles()
      local out = {}
      for _, wp in pairs(ctx.ns.waypoints) do out[#out + 1] = wp.title end
      table.sort(out)
      return out
    end

    it("is left out while the guide's current step names the quest, and shows once the step moves on", function()
      Ribbon.Guide("g", { schema = 1 }):Chapter("c")
        :Step():Goto(1453, 60, 60):Turnin(1338)
        :Step():Goto(1453, 70, 70):Accept(2)
        :Done()
      track(1338)
      ctx.world:placePlayer(1453, 50, 50, 0)
      ctx.ns.guidePlayer.refresh()
      ctx.world:update(0.3)
      expect(#titles()).toBe(1)                                   -- just the guide's step
      expect(titles()[1]).toContain("Turn in")
      ctx.ns.guidePlayer.skip()
      ctx.world:update(0.3)
      local all = titles()
      expect(#all).toBe(2)                                        -- the game's tracked quest comes back
      expect(all[1]).toBe("Accept quest 2")
      expect(all[2]).toBe("Stormpike's Order")
    end)

    it("still shows a tracked quest the guide does not mention", function()
      Ribbon.Guide("g", { schema = 1 }):Chapter("c")
        :Step():Goto(1453, 60, 60):Accept(7)
        :Done()
      track(1338)
      ctx.world:placePlayer(1453, 50, 50, 0)
      ctx.ns.guidePlayer.refresh()
      ctx.world:update(0.3)
      expect(#titles()).toBe(2)
    end)
  end)

  describe("compass dial click", function()
    local ctx = H.use({ boot = true })

    it("does nothing without a guide", function()
      ctx.ns.compass.parts.dial:Trigger("OnClick", "LeftButton")
      expect(ctx.ns.guideBrowser.frame()).toBeNil()
    end)

    it("opens the panel on a click on the dial and closes it on the next", function()
      build(Ribbon.Guide("g", { schema = 1 }))
      local dial = ctx.ns.compass.parts.dial
      dial:Trigger("OnClick", "LeftButton")
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(true)
      dial:Trigger("OnClick", "LeftButton")
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(false)
    end)

    it("does not open for a click on the ribbon itself", function()
      build(Ribbon.Guide("g", { schema = 1 }))
      ctx.ns.compass.parts.frame:Trigger("OnMouseUp", "LeftButton")
      expect(ctx.ns.compass.parts.frame:GetScript("OnMouseUp")).toBeNil()
      expect(ctx.ns.guideBrowser.frame()).toBeNil()
    end)

    it("ignores the release that ends a drag of the dial", function()
      build(Ribbon.Guide("g", { schema = 1 }))
      local dial = ctx.ns.compass.parts.dial
      dial:Trigger("OnDragStart")
      dial:Trigger("OnDragStop")
      dial:Trigger("OnClick", "LeftButton")
      expect(ctx.ns.guideBrowser.frame()).toBeNil()
      dial:Trigger("OnClick", "LeftButton")          -- the next click is a click again
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(true)
    end)
  end)

  describe("map button", function()
    local ctx = H.use({ boot = true })

    it("does not exist without a guide", function()
      expect(ctx.ns.map.guideButton).toBeNil()
    end)

    it("appears once a guide registers and toggles the panel", function()
      build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 }))
      local button = ctx.ns.map.guideButton
      expect(button).toBeTruthy()
      expect(button.icon.SetTexture).toHaveBeenCalledWith("Interface\\AddOns\\Ribbon\\icon")
      button:Trigger("OnClick")
      expect(ctx.ns.guideBrowser.dock():IsShown()).toBe(true)
      button:Trigger("OnClick")
      expect(ctx.ns.guideBrowser.dock():IsShown()).toBe(false)
    end)
  end)

  describe("panel docked to the world map", function()
    local ctx = H.use({ boot = true })
    beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

    local function dockPanel() return ctx.ns.guideBrowser.dock() end

    it("is a child of the world map, anchored down its right side, and above the map's own frames", function()
      ctx.ns.map.guideButton:Trigger("OnClick")
      local d = dockPanel()
      expect(d:GetParent()).toBe(WorldMapFrame)
      expect(d.SetPoint).toHaveBeenCalledWith("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -6, -66)
      expect(d.SetPoint).toHaveBeenCalledWith("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -6, 6)
      expect(d.SetFrameLevel.calls[#d.SetFrameLevel.calls][1]).toBeGreaterThan(WorldMapFrame:GetFrameLevel())
    end)

    it("shows the same chapter cards and progress as the dialog", function()
      ctx.ns.guidePlayer.jump(2, 1)
      ctx.ns.map.guideButton:Trigger("OnClick")
      local d = dockPanel()
      expect(d.leftRows.items[1].sub.SetText.calls[#d.leftRows.items[1].sub.SetText.calls][1]).toContain("100%")
      expect(d.overallText.SetText).toHaveBeenCalledWith("60%")
      expect(d.progress.SetText).toHaveBeenCalledWith("Step 4 of 5")
    end)

    it("is narrower than the floating dialog and stays out of the escape-closes list", function()
      ctx.ns.map.guideButton:Trigger("OnClick")
      ctx.ns.guideBrowser.toggle()
      expect(dockPanel().SetWidth.calls[1][1]).toBeLessThan(ctx.ns.guideBrowser.frame().SetWidth.calls[1][1])
      for _, name in ipairs(UISpecialFrames or {}) do expect(name).never.toBe("RibbonGuideDock") end
    end)

    it("remembers whether it was open, and Close hides it", function()
      ctx.ns.map.guideButton:Trigger("OnClick")
      expect(RibbonDB.guideDock).toBe(true)
      dockPanel().close:Trigger("OnClick")
      expect(dockPanel():IsShown()).toBe(false)
      expect(RibbonDB.guideDock).toBe(false)
    end)

    it("follows the step: chapter cards and steps refresh while docked", function()
      ctx.ns.map.guideButton:Trigger("OnClick")
      local d = dockPanel()
      d.leftRows.items[2]:Trigger("OnClick")                   -- browse chapter 2 (two steps)
      expect(d.rightRows.items[3]:IsShown()).toBe(false)
      ctx.ns.guidePlayer.skip()                                 -- a step occurs: back to the active chapter
      expect(d.rightRows.items[3]:IsShown()).toBe(true)
    end)

    it("keeps the dialog and the dock independent", function()
      ctx.ns.map.guideButton:Trigger("OnClick")
      ctx.ns.guideBrowser.toggle()
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(true)
      expect(dockPanel():IsShown()).toBe(true)
      ctx.ns.guideBrowser.toggle()
      expect(ctx.ns.guideBrowser.frame():IsShown()).toBe(false)
      expect(dockPanel():IsShown()).toBe(true)
    end)
  end)

  describe("docked panel at login", function()
    it("reopens when it was open last session", function()
      local ns, world = H.load({ world = function() RibbonDB = { guideDock = true } end })
      build(Ribbon.Guide("g", { schema = 1 }))
      world:fireEvent("PLAYER_LOGIN")
      expect(ns.guideBrowser.dock()).toBeTruthy()
      expect(ns.guideBrowser.dock():IsShown()).toBe(true)
    end)

    it("stays closed otherwise", function()
      local ns, world = H.load({})
      build(Ribbon.Guide("g", { schema = 1 }))
      world:fireEvent("PLAYER_LOGIN")
      expect(ns.guideBrowser.dock()).toBeNil()
    end)
  end)

  describe("map button when the guide loads first", function()
    it("is there after login", function()
      local ns, world = H.load({})
      build(Ribbon.Guide("early", { schema = 1 }))
      world:fireEvent("PLAYER_LOGIN")
      expect(ns.map.guideButton).toBeTruthy()
    end)
  end)
end)
