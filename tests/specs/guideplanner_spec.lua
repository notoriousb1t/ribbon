local H = require("tests.helpers.addon")

describe("Guide planner and text", function()
  local ns = H.pure({ "guide/Planner.lua", "guide/Text.lua" })
  local P, T = ns.guidePlanner, ns.guideText

  local function call(kind, fields)
    fields = fields or {}
    fields.kind = kind
    return fields
  end

  local function step(groups, extra)
    local s = { groups = groups }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
  end

  local function guide()
    return {
      chapters = {
        { name = "One", opts = { faction = "HORDE", race = "TAUREN" }, steps = {
          step({ { at = { map = 1, x = 1, y = 1 }, calls = { call("Accept", { quest = 747, npc = 2980 }) } } }),
          step({ { calls = { call("Accept", { quest = 3091 }) } } }, { only = { class = "WARRIOR" } }),
          step({
            { at = { map = 1, x = 2, y = 2 }, calls = { call("Accept", { quest = 1 }) }, only = { class = "HUNTER" } },
            { at = { map = 1, x = 3, y = 3 }, calls = { call("Accept", { quest = 2 }) } },
          }),
        } },
        { name = "Undead", opts = { race = "UNDEAD" }, steps = {
          step({ { calls = { call("Ding", { level = 5 }) } } }),
        } },
      },
    }
  end

  describe("tokens", function()
    it("compares class, race and faction without case, spaces or underscores", function()
      expect(P.matches({ race = "NIGHT_ELF" }, { race = "NightElf" })).toBe(true)
      expect(P.matches({ class = "warrior" }, { class = "WARRIOR" })).toBe(true)
    end)

    it("treats the client's Scourge as Undead", function()
      expect(P.matches({ race = "UNDEAD" }, { race = "Scourge" })).toBe(true)
    end)

    it("accepts any of a list", function()
      expect(P.matches({ race = { "DWARF", "GNOME" } }, { race = "Gnome" })).toBe(true)
      expect(P.matches({ race = { "DWARF", "GNOME" } }, { race = "Human" })).toBe(false)
    end)

    it("does not match a lock on something the client did not report", function()
      expect(P.matches({ class = "WARRIOR" }, {})).toBe(false)
      expect(P.matches(nil, {})).toBe(true)
    end)
  end)

  describe("view", function()
    it("hides chapters of another race or faction", function()
      local v = P.view(guide(), { race = "Tauren", faction = "Horde", class = "MAGE" })
      expect(#v).toBe(1)
      expect(v[1].name).toBe("One")
      local undead = P.view(guide(), { race = "Scourge", faction = "Horde", class = "MAGE" })
      expect(#undead).toBe(1)
      expect(undead[1].name).toBe("Undead")
    end)

    it("hides locked steps and locked groups, keeping guide positions", function()
      local mage = P.view(guide(), { race = "Tauren", faction = "Horde", class = "MAGE" })
      expect(#mage[1].steps).toBe(2)
      expect(mage[1].steps[2].index).toBe(3)
      expect(#mage[1].steps[2].step.groups).toBe(1)
      local warrior = P.view(guide(), { race = "Tauren", faction = "Horde", class = "WARRIOR" })
      expect(#warrior[1].steps).toBe(3)
      local hunter = P.view(guide(), { race = "Tauren", faction = "Horde", class = "HUNTER" })
      expect(#hunter[1].steps[2].step.groups).toBe(2)
    end)

    it("finds a saved position, or the next visible step after it", function()
      local flat = P.flatten(P.view(guide(), { race = "Tauren", faction = "Horde", class = "MAGE" }))
      expect(P.locate(flat, { chapter = 1, step = 3 })).toBe(2)
      expect(P.locate(flat, { chapter = 1, step = 2 })).toBe(2)   -- step 2 is the warrior's: next visible
      expect(P.locate(flat, { chapter = 1, step = 9 })).toBeNil()
      expect(P.locate(flat, nil)).toBe(1)
    end)

    it("outlines passed, current and coming steps and chapters", function()
      local view = P.view(guide(), { race = "Tauren", faction = "Horde", class = "WARRIOR" })
      local flat = P.flatten(view)
      local o = P.outline(view, flat, 2)
      expect(o.steps).toEqual({ "done", "current", "todo" })
      expect(o.chapters[1]).toBe("current")
      local later = P.outline(P.view(guide(), { race = "Scourge", faction = "Horde", class = "MAGE" }), { {} }, 1)
      expect(later.chapters[2]).toBe("current")
    end)

    it("finds the first step of a chapter", function()
      local flat = P.flatten(P.view(guide(), { race = "Scourge", faction = "Horde", class = "MAGE" }))
      expect(P.firstOfChapter(flat, 2)).toBe(1)
      expect(P.firstOfChapter(flat, 1)).toBeNil()
    end)
  end)

  describe("completion", function()
    local function env(t)
      t = t or {}
      return {
        quest = function(id) return (t.quests or {})[id] or "none" end,
        objective = function(q, i) return (t.objectives or {})[q .. ":" .. i] end,
        level = t.level or 1,
      }
    end
    local function one(c) return step({ { calls = { c } } }) end

    it("an accept is done once the quest is in the log or turned in", function()
      local s = one(call("Accept", { quest = 5 }))
      expect(P.stepDone(s, env())).toBe(false)
      expect(P.stepDone(s, env({ quests = { [5] = "active" } }))).toBe(true)
      expect(P.stepDone(s, env({ quests = { [5] = "done" } }))).toBe(true)
    end)

    it("a turn-in is done only when turned in", function()
      local s = one(call("Turnin", { quest = 5 }))
      expect(P.stepDone(s, env({ quests = { [5] = "complete" } }))).toBe(false)
      expect(P.stepDone(s, env({ quests = { [5] = "done" } }))).toBe(true)
    end)

    it("an objective is done when the client says so, or its quest is complete", function()
      local s = one(call("Kill", { quest = 5, index = 1, creature = 9, count = 3 }))
      expect(P.stepDone(s, env({ quests = { [5] = "active" }, objectives = { ["5:1"] = { finished = false } } }))).toBe(false)
      expect(P.stepDone(s, env({ quests = { [5] = "active" }, objectives = { ["5:1"] = { finished = true } } }))).toBe(true)
      expect(P.stepDone(s, env({ quests = { [5] = "complete" } }))).toBe(true)
      expect(P.stepDone(s, env())).toBe(false)   -- not accepted yet
    end)

    it("needs every judged call done", function()
      local s = step({ { calls = { call("Kill", { quest = 5, index = 1 }), call("Loot", { quest = 5, index = 2 }) } } })
      local e = env({ quests = { [5] = "active" }, objectives = { ["5:1"] = { finished = true }, ["5:2"] = { finished = false } } })
      expect(P.stepDone(s, e)).toBe(false)
    end)

    it("a level goal follows the player's level", function()
      expect(P.stepDone(one(call("Ding", { level = 5 })), env({ level = 4 }))).toBe(false)
      expect(P.stepDone(one(call("Ding", { level = 5 })), env({ level = 5 }))).toBe(true)
      expect(P.stepDone(one(call("Grind", { level = 5, npc = { 1 } })), env({ level = 6 }))).toBe(true)
    end)

    it("says nothing for steps the client cannot judge", function()
      expect(P.stepDone(one(call("Fp", { node = "Camp Taurajo" })), env())).toBeNil()
      expect(P.stepDone(one(call("Grind", { count = 9, npc = { 1 } })), env())).toBeNil()
      expect(P.stepDone(one(call("Travel")), env())).toBeNil()
    end)
  end)

  describe("text", function()
    local names = {
      QUEST = { [747] = "The Hunt Begins" }, NPC = { [2980] = "Grull Hawkwind" },
      CREATURE = { [2955] = "Plainstrider" }, ITEM = { [4739] = "Plainstrider Meat" },
      OBJECT = { [337] = "Water Pitcher" }, MAP = { [1412] = "Mulgore" },
    }
    local env = {
      quest = function() return "active" end,
      objective = function(_, i) return i == 1 and { have = 3, need = 7, finished = false } or nil end,
    }

    it("writes accept and turn-in lines with the NPC", function()
      expect(T.line(call("Accept", { quest = 747, npc = 2980 }), names)).toBe("Accept The Hunt Begins from Grull Hawkwind")
      expect(T.line(call("Turnin", { quest = 747 }), names)).toBe("Turn in The Hunt Begins")
    end)

    it("shows quest log progress on objectives", function()
      expect(T.line(call("Kill", { creature = 2955, count = 7, quest = 747, index = 1 }), names, env)).toBe("Kill Plainstrider (3/7)")
      expect(T.line(call("Loot", { item = 4739, count = 7, quest = 747, index = 2 }), names, env)).toBe("Collect Plainstrider Meat (7)")
    end)

    it("shows the required count before the quest is accepted", function()
      local none = { quest = function() return "none" end, objective = function() end }
      expect(T.line(call("Kill", { creature = 2955, count = 7, quest = 747, index = 1 }), names, none)).toBe("Kill Plainstrider (7)")
    end)

    it("falls back to the id when a name is missing", function()
      expect(T.line(call("Accept", { quest = 5 }), {})).toBe("Accept quest 5")
    end)

    it("writes grind, level, flight and travel lines", function()
      expect(T.line(call("Grind", { npc = { 2955 }, count = 9 }), names)).toBe("Kill 9 Plainstrider")
      expect(T.line(call("Grind", { npc = { 2955 }, level = 8 }), names)).toBe("Grind Plainstrider to level 8")
      expect(T.line(call("Ding", { level = 10 }), names)).toBe("Reach level 10")
      expect(T.line(call("Fp", { node = "Camp Taurajo" }), names)).toBe("Get the Camp Taurajo flight path")
      expect(T.line(call("Enter", { map = 1412 }), names)).toBe("Travel to Mulgore")
    end)

    it("leaves finished calls out of a group's lines and hides the Travel marker", function()
      local group = { calls = { call("Travel"), call("Enter", { map = 1412 }), call("Accept", { quest = 747 }) } }
      local lines = T.lines(group, names, env, function(c) return c.kind == "Accept" and "done" or "open" end)
      expect(lines).toEqual({ "Travel to Mulgore" })
      expect(T.lines({ calls = { call("Travel") } }, names)).toEqual({ "Travel" })
      expect(T.lines({ at = { map = 1412, x = 1, y = 1 }, calls = { call("Travel") } }, names)).toEqual({ "Travel to Mulgore" })
    end)

    it("picks an icon from the first call that has one", function()
      expect(T.icon({ calls = { call("Travel"), call("Kill", {}) } })).toBe("kill")
      expect(T.icon({ calls = { call("Fp", { node = "x" }) } })).toBe("poi")
    end)

    it("summarises a step in two lines", function()
      local s = step({ { calls = { call("Accept", { quest = 747 }), call("Accept", { quest = 1 }), call("Accept", { quest = 2 }) } } })
      expect(T.summary(s, names)).toBe("Accept The Hunt Begins, Accept quest 1")
    end)
  end)
end)
