local H = require("tests.helpers.addon")

-- A fake game environment for probes: just the tables the probe under test reads.
local function questEnv(overrides)
  local env = {
    C_SuperTrack = {
      GetSuperTrackedQuestID = function() return 1234 end,
      SetSuperTrackedQuestID = function() end,
    },
    C_QuestLog = {
      GetTitleForQuestID = function(id) return "Wolves of Elwynn" end,
      GetNextWaypoint = function(id) return 1429, 0.42, 0.67 end,
      GetQuestObjectives = function(id) return { { text = "Wolf slain: 3/8", numFulfilled = 3, numRequired = 8 } } end,
      GetLogIndexForQuestID = function(id) return 2 end,
      GetQuestsOnMap = function(map) return { { questID = 1234, x = 0.5, y = 0.4 } } end,
      GetNumQuestWatches = function() return 1 end,
      GetNumQuestLogEntries = function() return 5, 3 end,
    },
    C_Map = { GetBestMapForUnit = function() return 1429 end },
  }
  for k, v in pairs(overrides or {}) do env[k] = v end
  return env
end

describe("Probe", function()
  local ctx = H.use({ boot = true })
  local P

  beforeEach(function() P = ctx.ns.probe end)

  describe("helpers", function()
    it("resolves dotted paths and returns nil for missing ones", function()
      local env = { A = { B = { C = 5 } } }
      expect(P.resolve(env, "A.B.C")).toBe(5)
      expect(P.resolve(env, "A.X.C")).toBeNil()
      expect(P.resolve(env, "Z")).toBeNil()
    end)

    it("calls a function once and packs its results", function()
      local calls = 0
      local env = { f = function(a, b) calls = calls + 1 return a + b, "x" end }
      local ok, result = P.call(env, "f", 1, 2)
      expect(ok).toBe(true)
      expect(result).toEqual({ n = 2, 3, "x" })
      expect(calls).toBe(1)
    end)

    it("reports a missing function as nil and an error as false", function()
      local env = { boom = function() error("bad") end }
      expect(P.call(env, "nope")).toBeNil()
      local ok, err = P.call(env, "boom")
      expect(ok).toBe(false)
      expect(err).toMatch("bad")
    end)

    it("describes calls on one line", function()
      local env = { add = function(a, b) return a + b end, boom = function() error("bad") end }
      expect(P.line(env, "add", 1, 2)).toBe("add(1, 2) -> 3")
      expect(P.line(env, "nope")).toBe("nope: missing")
      expect(P.line(env, "boom")).toContain("errored")
    end)

    it("reports which paths exist", function()
      expect(P.exists({ a = { b = 1 } }, { "a.b", "a.c" })).toBe("a.b=true, a.c=false")
    end)
  end)

  describe("quest probe", function()
    it("reports the super-tracked quest, its waypoint and objectives", function()
      local lines = P.run("quest", "", questEnv())
      local text = table.concat(lines, "\n")
      expect(text).toContain("GetSuperTrackedQuestID() -> 1234")
      expect(text).toContain('GetTitleForQuestID(1234) -> "Wolves of Elwynn"')
      expect(text).toContain("GetNextWaypoint(1234) -> 1429, 0.42, 0.67")
      expect(text).toContain("Wolf slain: 3/8")
      expect(text).toContain("GetQuestsOnMap(1429)")
      expect(text).toContain("APIs: C_QuestLog.GetNextWaypoint=true")
    end)

    it("takes an explicit quest id", function()
      local lines = P.run("quest", "99", questEnv())
      expect(table.concat(lines, "\n")).toContain("GetTitleForQuestID(99)")
    end)

    it("says what to do when no quest is tracked", function()
      local env = questEnv({ C_SuperTrack = { GetSuperTrackedQuestID = function() return 0 end } })
      expect(table.concat(P.run("quest", "", env), "\n")).toContain("no quest")
    end)

    it("copes with APIs that do not exist", function()
      local lines = P.run("quest", "", {})
      local text = table.concat(lines, "\n")
      expect(text).toContain("C_SuperTrack.GetSuperTrackedQuestID: missing")
      expect(text).toContain("C_QuestLog.GetNextWaypoint=false")
    end)
  end)

  describe("navigation probe", function()
    local function navEnv(overrides)
      local env = {
        C_Navigation = {
          GetTargetState = function() return 2 end,
          GetDistance = function() return 7.5 end,
          HasValidScreenPosition = function() return true end,
          WasClampedToScreen = function() return false end,
          GetNextWaypointForMap = function(map) return nil end,
          GetFrame = function()
            return {
              GetPoint = function() return "CENTER", nil, "CENTER", 10, 20 end,
              IsShown = function() return true end,
            }
          end,
        },
        C_SuperTrack = { GetSuperTrackedQuestID = function() return 1234 end },
        C_QuestLog = { GetQuestsOnMap = function(map) return { { questID = 1234, x = 0.5, y = 0.25 } } end },
        C_Map = {
          GetBestMapForUnit = function() return 1453 end,
          -- The quest point sits 3 yd north and 4 yd west of the player at (100, 200).
          GetWorldPosFromMapPos = function(map, vec) return 0, { x = 103, y = 204 } end,
        },
        UnitPosition = function() return 100, 200, 0, 0 end,
        CreateVector2D = function(x, y) return { x = x, y = y } end,
      }
      for k, v in pairs(overrides or {}) do env[k] = v end
      return env
    end

    it("reports the engine's target state, distance and screen position", function()
      local text = table.concat(P.run("navigation", "", navEnv()), "\n")
      expect(text).toContain("C_Navigation.GetTargetState() -> 2")
      expect(text).toContain("C_Navigation.GetDistance() -> 7.5")
      expect(text).toContain("HasValidScreenPosition() -> true")
      expect(text).toContain("frame shown=true point=CENTER relPoint=CENTER x=10 y=20")
    end)

    it("compares with the 2D world distance to the tracked quest's map point", function()
      local text = table.concat(P.run("navigation", "", navEnv()), "\n")
      expect(text).toContain("tracked quest 1234 map point 0.5, 0.25; 2D distance 5.0 yd")
    end)

    it("derives the height difference the engine distance implies (7.5 engine vs 5 flat is 5.6 yd)", function()
      local text = table.concat(P.run("navigation", "", navEnv()), "\n")
      expect(text).toContain("engine 7.5 yd vs flat 5.0 yd: implied height difference 5.6 yd")
      expect(text).toContain('UnitPosition("player") -> 100, 200, 0, 0')
    end)

    it("reports zero implied height when the engine distance is not longer than the flat one", function()
      local env = navEnv()
      env.C_Navigation.GetDistance = function() return 4.9 end
      expect(table.concat(P.run("navigation", "", env), "\n")).toContain("implied height difference 0.0 yd")
    end)

    it("says so when there is no tracked quest point to compare with", function()
      local env = navEnv({ C_SuperTrack = { GetSuperTrackedQuestID = function() return 0 end } })
      expect(table.concat(P.run("navigation", "", env), "\n")).toContain("no tracked quest point")
    end)

    it("copes with a client that has no C_Navigation", function()
      local lines = P.run("navigation", "", {})
      expect(table.concat(lines, "\n")).toContain("C_Navigation.GetDistance: missing")
    end)

    it("reports a missing frame", function()
      local env = navEnv()
      env.C_Navigation.GetFrame = function() return nil end
      expect(table.concat(P.run("navigation", "", env), "\n")).toContain("no frame")
    end)
  end)

  describe("player probe", function()
    it("reports position, facing and map through the fake client", function()
      local text = table.concat(P.run("player", ""), "\n")
      expect(text).toContain("GetPlayerFacing() -> 0")
      expect(text).toContain("C_Map.GetBestMapForUnit(\"player\") -> 1453")
      expect(text).toContain("UnitPosition(\"player\")")
    end)
  end)

  describe("apis probe", function()
    it("checks the paths given", function()
      expect(P.run("apis", "C_Map C_Nothing", { C_Map = {} })[1]).toBe("C_Map=true, C_Nothing=false")
    end)

    it("checks a default set when none is given", function()
      expect(P.run("apis", "", {})[1]).toContain("C_QuestLog=false")
    end)
  end)

  describe("dump probe", function()
    it("serializes an expression in the given environment", function()
      local lines = P.run("dump", "C_Map", { C_Map = { b = 1, a = print } })
      expect(lines[1]).toBe("C_Map = {a=<function>, b=1}")
    end)

    it("reports a parse error and a runtime error without raising", function()
      expect(P.run("dump", "1 +", {})[1]).toContain("cannot parse")
      expect(P.run("dump", "error('x')", {})[1]).toContain("errored")
    end)

    it("shows usage without an argument", function()
      expect(P.run("dump", "", {})[1]).toContain("usage")
    end)
  end)

  describe("addons probe", function()
    it("lists loaded addons", function()
      local env = {
        GetNumAddOns = function() return 2 end,
        GetAddOnInfo = function(i) return ({ "A", "B" })[i] end,
        IsAddOnLoaded = function(name) return name == "B" end,
      }
      expect(P.run("addons", "", env)[1]).toBe("B")
    end)

    it("says when the API is missing", function()
      expect(P.run("addons", "", {})[1]).toContain("missing")
    end)
  end)

  describe("running and saving", function()
    it("saves each run under RibbonDB.probes with its arguments", function()
      P.run("apis", "A", { A = {} })
      local runs = RibbonDB.probes.apis
      expect(#runs).toBe(1)
      expect(runs[1].args).toBe("A")
      expect(runs[1].lines[1]).toBe("A=true")
      expect(runs[1].time).toBeTruthy()
    end)

    it("keeps only the last ten runs of a probe", function()
      for i = 1, 12 do P.run("apis", tostring(i), {}) end
      local runs = RibbonDB.probes.apis
      expect(#runs).toBe(10)
      expect(runs[1].args).toBe("3")
      expect(runs[10].args).toBe("12")
    end)

    it("reports an unknown probe", function()
      local lines, err = P.run("nonsense", "")
      expect(lines).toBeNil()
      expect(err).toContain("unknown probe")
    end)

    it("turns a probe that errors into a result line", function()
      P.register("broken", "always fails", function() error("kaboom") end)
      expect(P.run("broken", "")[1]).toContain("kaboom")
    end)

    it("accepts a probe that returns a single string", function()
      P.register("single", "one line", function() return "hello" end)
      expect(P.run("single", "")).toEqual({ "hello" })
    end)
  end)

  describe("commands", function()
    it("/ribbonprobe with no name lists the probes", function()
      SlashCmdList.RIBBON_PROBE("")
      local out = ctx.world:output()
      expect(out).toContain("quest")
      expect(out).toContain("player")
      expect(out).toContain("dump")
    end)

    it("/ribbonprobe <name> prints the result", function()
      SlashCmdList.RIBBON_PROBE("apis C_Map")
      expect(ctx.world:output()).toContain("C_Map=true")
    end)

    it("is case-insensitive about the probe name", function()
      SlashCmdList.RIBBON_PROBE("APIS C_Map")
      expect(ctx.world:output()).toContain("C_Map=true")
    end)

    it("reports an unknown probe", function()
      SlashCmdList.RIBBON_PROBE("nonsense")
      expect(ctx.world:output()).toContain("unknown probe")
    end)

it("registers under its own key so another addon's RIBBONPROBE slash command cannot replace it", function()      expect(SLASH_RIBBON_PROBE1).toBe("/ribbonprobe")      expect(SlashCmdList.RIBBON_PROBE).toBeTruthy()      expect(SlashCmdList.RIBBONPROBE).toBeNil()    end)
    it("is also reachable as /ribbon probe", function()
      SlashCmdList.RIBBON("probe apis C_Map")
      expect(ctx.world:output()).toContain("C_Map=true")
    end)
  end)

  describe("on a dormant addon", function()
    local dormant = H.use({ world = function(w) w:removeApi("UnitPosition") end })

    it("still works, since probing is most useful when something is missing", function()
      dormant.world:fireEvent("PLAYER_LOGIN")
      SlashCmdList.RIBBON_PROBE("apis UnitPosition")
      expect(dormant.world:output()).toContain("UnitPosition=false")
    end)
  end)
end)
