local H = require("tests.helpers.addon")

-- A small guide on Stormwind City (1453), which the fake world knows.
local function build(R)
  R:Names({
    QUEST = { [747] = "The Hunt Begins", [3091] = "Simple Note", [750] = "The Hunt Continues" },
    NPC = { [2980] = "Grull Hawkwind" },
    CREATURE = { [2955] = "Plainstrider" },
    ITEM = { [4739] = "Plainstrider Meat" },
    MAP = { [1453] = "Stormwind City" },
  })
  R:Chapter("Camp Narache", { faction = "HORDE", race = "TAUREN" })
    :Step()
      :Goto(1453, 50.00, 50.00)
      :Accept(747):At(2980)
    :Step()
      :Goto(1453, 52.00, 52.00)
      :Kill(2955, 7, { quest = 747, index = 1 })
      :Loot(4739, 7, { quest = 747, index = 2 })
    :Step()
      :Only{ class = "WARRIOR" }
      :Goto(1453, 53.00, 53.00)
      :Accept(3091)
    :Step()
      :Goto(1453, 50.00, 50.00)
      :Turnin(747):At(2980)
    :Done()
  R:Chapter("Crossroads", { faction = "HORDE" })
    :Step()
      :Goto(1453, 60.00, 60.00)
      :Fp("Crossroads")
    :Step()
      :Goto(1453, 61.00, 61.00)
      :Accept(750)
    :Done()
  return R
end

local function titles(ns)
  local out = {}
  for _, wp in pairs(ns.waypoints) do out[#out + 1] = wp.title end
  table.sort(out)
  return out
end

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

describe("Guide player", function()
  describe("without a guide", function()
    local ctx = H.use({ boot = true })

    it("never starts and creates no waypoints or browser", function()
      expect(ctx.ns.guidePlayer.state()).toBeNil()
      expect(ctx.ns.guideBrowser.dock()).toBeNil()
      expect(count(ctx.ns.waypoints)).toBe(0)
    end)

    it("the browser says there is no guide", function()
      ctx.ns.guideBrowser.toggle()
      expect(ctx.world:output()).toContain("no guide installed")
      expect(ctx.ns.guideBrowser.dock()).toBeNil()
    end)
  end)

  describe("a registered guide", function()
    local ctx = H.use({ boot = true })
    local function start()
      build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 }))
    end

    it("starts on the first step and shows it on the compass", function()
      start()
      local P = ctx.ns.guidePlayer
      expect(P.state()).toBeTruthy()
      local entry, cursor = P.current()
      expect(cursor).toBe(1)
      expect(entry.chapter).toBe(1)
      expect(titles(ctx.ns)).toEqual({ "Accept The Hunt Begins" })
    end)

    it("starts at login when the guide registered first (the usual order)", function()
      local ns, world = H.load({})          -- guide addon loads before login
      build(Ribbon.Guide("early", { schema = 1 }))
      expect(ns.guidePlayer.state()).toBeNil()
      world:fireEvent("PLAYER_LOGIN")
      expect(ns.guidePlayer.state()).toBeTruthy()
      expect(count(ns.waypoints)).toBe(1)
    end)

    it("advances when the quest is accepted", function()
      start()
      ctx.world.quest.log[747] = { complete = false }
      ctx.ns.guidePlayer.refresh()
      local _, cursor = ctx.ns.guidePlayer.current()
      expect(cursor).toBe(2)
      expect(titles(ctx.ns)).toEqual({ "Kill Plainstrider (0/7)" })
    end)

    it("shows quest log progress in place, keeping the same waypoint", function()
      start()
      ctx.world.quest.log[747] = { complete = false }
      ctx.world.quest.objectives[747] = {
        { numFulfilled = 3, numRequired = 7, finished = false },
        { numFulfilled = 0, numRequired = 7, finished = false },
      }
      ctx.ns.guidePlayer.refresh()
      local uid
      for id in pairs(ctx.ns.waypoints) do uid = id end
      expect(ctx.ns:GetWaypoint(uid).title).toBe("Kill Plainstrider (3/7)")
      expect(ctx.ns:GetWaypoint(uid).description).toEqual({ "Collect Plainstrider Meat (0/7)" })
      ctx.world.quest.objectives[747][1] = { numFulfilled = 5, numRequired = 7, finished = false }
      ctx.ns.guidePlayer.refresh()
      expect(ctx.ns:GetWaypoint(uid).title).toBe("Kill Plainstrider (5/7)")
      expect(count(ctx.ns.waypoints)).toBe(1)
    end)

    it("moves on when every objective is finished", function()
      start()
      ctx.world.quest.log[747] = { complete = false }
      ctx.world.quest.objectives[747] = {
        { numFulfilled = 7, numRequired = 7, finished = true },
        { numFulfilled = 7, numRequired = 7, finished = true },
      }
      ctx.ns.guidePlayer.refresh()
      local entry = ctx.ns.guidePlayer.current()
      expect(entry.index).toBe(3)   -- the warrior's step (the fake character is a warrior)
    end)

    it("skips ahead for a character who already did the quests", function()
      start()
      ctx.world.quest.done[747] = true
      ctx.world.quest.done[3091] = true
      ctx.ns.guidePlayer.refresh()
      local entry = ctx.ns.guidePlayer.current()
      expect(entry.chapter).toBe(2)
      expect(entry.index).toBe(1)
    end)

    it("does not show another class's step", function()
      ctx.world.character.class = "MAGE"
      start()
      local state = ctx.ns.guidePlayer.state()
      expect(#state.flat).toBe(5)   -- 3 + 2 visible steps
    end)

    it("completes a flight point step when the flight master's map opens there, not on arriving", function()
      start()
      ctx.world.quest.done[747] = true
      ctx.world.quest.done[3091] = true
      ctx.ns.guidePlayer.refresh()          -- now at the Crossroads flight point step
      ctx.world:placePlayer(1453, 60, 60, 0)
      ctx.ns:UpdateGeometry()               -- arrival fires WAYPOINT_ARRIVED
      ctx.ns.guidePlayer.refresh()
      expect(ctx.ns.guidePlayer.current().index).toBe(1)
      ctx.world:fireEvent("TAXIMAP_OPENED")
      expect(ctx.ns.guidePlayer.current().index).toBe(2)
    end)

    it("skip, prev, reset and jump move the cursor and the waypoint", function()
      start()
      local P = ctx.ns.guidePlayer
      P.skip()
      expect(select(2, P.current())).toBe(2)
      expect(titles(ctx.ns)[1]).toContain("Plainstrider")
      P.prev()
      expect(select(2, P.current())).toBe(1)
      P.jump(2, 2)
      expect(P.current().chapter).toBe(2)
      expect(titles(ctx.ns)).toEqual({ "Accept The Hunt Continues" })
      P.reset()
      expect(select(2, P.current())).toBe(1)
      expect(P.jump(9, 9)).toBe(false)
    end)

    it("stepping past the last step finishes the guide and removes the waypoints", function()
      start()
      local P = ctx.ns.guidePlayer
      local finished = createSpy()
      ctx.ns:On("GUIDE_FINISHED", finished)
      for _ = 1, 10 do P.skip() end
      expect(finished).toHaveBeenCalled()
      expect(count(ctx.ns.waypoints)).toBe(0)
    end)

    it("saves the position per character and resumes from it", function()
      start()
      ctx.ns.guidePlayer.skip()
      local saved = ctx.ns.db.guide["Tester-Realm"]
      expect(saved).toEqual({ guide = "g", chapter = 1, step = 2 })

      local ns, world = H.load({})
      RibbonDB = { guide = { ["Tester-Realm"] = { guide = "g", chapter = 2, step = 1 } } }
      build(Ribbon.Guide("g", { schema = 1 }))
      world:fireEvent("PLAYER_LOGIN")
      expect(ns.guidePlayer.current().chapter).toBe(2)
    end)

    it("ignores a saved position from a different guide", function()
      local ns, world = H.load({})
      RibbonDB = { guide = { ["Tester-Realm"] = { guide = "other", chapter = 2, step = 1 } } }
      build(Ribbon.Guide("g", { schema = 1 }))
      world:fireEvent("PLAYER_LOGIN")
      expect(select(2, ns.guidePlayer.current())).toBe(1)
    end)

    it("lands on the last step when the saved position is past the end, without resetting the save", function()
      local ns, world = H.load({})
      RibbonDB = { guide = { ["Tester-Realm"] = { guide = "g", chapter = 9, step = 1 } } }
      build(Ribbon.Guide("g", { schema = 1 }))
      world:fireEvent("PLAYER_LOGIN")
      local entry, cursor = ns.guidePlayer.current()
      expect(cursor).toBe(#ns.guidePlayer.state().flat)
      expect(entry.chapter).toBe(2)
      expect(ns.db.guide["Tester-Realm"].chapter).toBe(2)
    end)

    it("says once when a step cannot be placed, then stays quiet", function()
      local ns, world = H.load({})
      Ribbon.Guide("g", { schema = 1 }):Chapter("Nowhere")
        :Step():Goto(1453, 50, 50):Accept(747):Done()
      world.maps[1453] = nil           -- the client no longer knows the map
      world:fireEvent("PLAYER_LOGIN")
      ns.guidePlayer.refresh()
      ns.guidePlayer.refresh()
      expect(count(ns.waypoints)).toBe(0)
      local out = world:output()
      expect(out).toContain("cannot place")
      expect(select(2, out:gsub("cannot place", ""))).toBe(1)
    end)

    it("marks a skippable step in its title", function()
      local ns, world = H.load({})
      Ribbon.Guide("g", { schema = 1 }):Chapter("Elite")
        :Step():Skippable():Goto(1453, 50, 50):Accept(747):Done()
      world:fireEvent("PLAYER_LOGIN")
      expect(titles(ns)[1]).toContain("(skippable) Accept")
    end)

    it("announces a text change once, not on every poll", function()
      start()
      ctx.world.quest.log[747] = { complete = false }
      ctx.world.quest.objectives[747] = { { numFulfilled = 3, numRequired = 7, finished = false }, { numFulfilled = 0, numRequired = 7, finished = false } }
      ctx.ns.guidePlayer.refresh()
      local changed = 0
      ctx.ns:On("WAYPOINT_CHANGED", function() changed = changed + 1 end)
      ctx.ns.guidePlayer.refresh()
      expect(changed).toBe(0)
      ctx.world.quest.objectives[747][1] = { numFulfilled = 4, numRequired = 7, finished = false }
      ctx.ns.guidePlayer.refresh()
      expect(changed).toBe(1)
    end)

    it("polls on a ticker", function()
      start()
      ctx.world.quest.log[747] = { complete = false }
      ctx.world:update(0.6)
      expect(select(2, ctx.ns.guidePlayer.current())).toBe(2)
    end)
  end)

  describe("commands", function()
    local ctx = H.use({ boot = true })
    beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

    it("skip and prev report the step", function()
      SlashCmdList.RIBBON("guide skip")
      expect(ctx.world:output()).toContain("step 2 of 6")
      SlashCmdList.RIBBON("guide prev")
      expect(ctx.world:output()).toContain("step 1 of 6")
    end)

    it("reset returns to the first step", function()
      ctx.ns.guidePlayer.skip()
      SlashCmdList.RIBBON("guide reset")
      expect(select(2, ctx.ns.guidePlayer.current())).toBe(1)
    end)

    it("status still reports the chapters", function()
      SlashCmdList.RIBBON("guide status")
      expect(ctx.world:output()).toContain("Test Guide: 2 chapters")
    end)

    it("an unknown subcommand lists the commands", function()
      SlashCmdList.RIBBON("guide dance")
      expect(ctx.world:output()).toContain("guide commands:")
    end)
  end)

  describe("browser", function()
    local ctx = H.use({ boot = true })
    beforeEach(function() build(Ribbon.Guide("g", { title = "Test Guide", schema = 1 })) end)

    it("is not built until it is opened", function()
      expect(ctx.ns.guideBrowser.dock()).toBeNil()
      SlashCmdList.RIBBON("guide")
      expect(ctx.ns.guideBrowser.dock()).toBeTruthy()
    end)

    it("lists the chapters and the selected chapter's steps", function()
      ctx.ns.guideBrowser.toggle()
      local frame = ctx.ns.guideBrowser.dock()
      expect(frame.leftRows.items[1].label.SetText).toHaveBeenCalled()
      local left, right = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1)
      expect(#left).toBe(2)
      expect(left[1].label).toBe("Camp Narache")
      expect(left[1].state).toBe("current")
      expect(left[2].state).toBe("todo")
      expect(#right).toBe(4)
      expect(right[1].state).toBe("current")
      expect(right[2].state).toBe("todo")
      expect(right[1].label).toContain("Accept The Hunt Begins")
    end)

    it("marks passed steps done", function()
      ctx.ns.guidePlayer.jump(2, 1)
      local left, right = ctx.ns.guideBrowser.rows(ctx.ns.guidePlayer, 1)
      expect(left[1].state).toBe("done")
      expect(right[4].state).toBe("done")
    end)

    it("clicking a step previews it without moving the player; its icon moves the player", function()
      ctx.ns.guideBrowser.toggle()
      local frame = ctx.ns.guideBrowser.dock()
      frame.rightRows.items[3]:Trigger("OnClick")
      expect(ctx.ns.guidePlayer.current().index).toBe(1)
      frame.rightRows.items[3].icon:Trigger("OnClick")
      expect(ctx.ns.guidePlayer.current().index).toBe(3)
    end)

    it("clicking a chapter browses it", function()
      ctx.ns.guideBrowser.toggle()
      local frame = ctx.ns.guideBrowser.dock()
      frame.leftRows.items[2]:Trigger("OnClick")
      expect(#frame.rightRows.items).toBe(4)          -- pooled rows are reused, extras hidden
      expect(frame.rightRows.items[3].IsShown and frame.rightRows.items[3]:IsShown()).toBe(false)
    end)

    it("closes with Close and toggles", function()
      ctx.ns.guideBrowser.toggle()
      local frame = ctx.ns.guideBrowser.dock()
      frame.close:Trigger("OnClick")
      expect(frame:IsShown()).toBe(false)
      ctx.ns.guideBrowser.toggle()
      expect(frame:IsShown()).toBe(true)
      ctx.ns.guideBrowser.toggle()
      expect(frame:IsShown()).toBe(false)
    end)
  end)
end)
