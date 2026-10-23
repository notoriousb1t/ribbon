local H = require("tests.helpers.addon")

-- A one-chapter guide on Stormwind City (1453, which the fake world knows) whose first step accepts quest `quest`.
local function guide(id, opts, quest)
  opts = opts or {}
  opts.schema = 1
  opts.title = opts.title or id
  local R = Ribbon.Guide(id, opts)
  R:Names({ QUEST = { [quest] = "Quest " .. quest, [quest + 1] = "Quest " .. (quest + 1) } })
  R:Chapter("Start " .. id, {})
    :Step():Goto(1453, 50, 50):Accept(quest)
    :Step():Goto(1453, 51, 51):Accept(quest + 1)
    :Done()
  return R
end

local function titles(ns)
  local out = {}
  for _, wp in pairs(ns.waypoints) do out[#out + 1] = wp.title end
  table.sort(out)
  return out
end

describe("Choosing among guides", function()
  describe("scoring (pure)", function()
    local ns = H.pure({ "guide/Planner.lua" })
    local P = ns.guidePlanner
    local warrior = { class = "WARRIOR", race = "Tauren", faction = "Horde", flavor = "FOREVER" }

    it("scores a guide for everyone 0, a class match above a race match, and a mismatch nil", function()
      expect(P.guideScore({}, warrior)).toBe(0)
      expect(P.guideScore({ only = { race = "TAUREN" } }, warrior)).toBeGreaterThan(0)
      expect(P.guideScore({ only = { class = "WARRIOR" } }, warrior)).toBeGreaterThan(P.guideScore({ only = { race = "TAUREN" } }, warrior))
      expect(P.guideScore({ only = { class = "HUNTER" } }, warrior)).toBeNil()
      expect(P.guideScore({ only = { race = "HUMAN" } }, warrior)).toBeNil()
    end)

    it("uses the race to break a tie between guides for the same class", function()
      local plain = { id = "plain", only = { class = "WARRIOR" } }
      local tauren = { id = "tauren", only = { class = "WARRIOR", race = "TAUREN" } }
      expect(P.chooseGuide({ plain, tauren }, warrior)).toBe(tauren)
    end)

    it("ranks a class guide above a race-only guide however many races it names", function()
      local classOnly = { id = "class", only = { class = "WARRIOR" } }
      local raceOnly = { id = "race", only = { race = "TAUREN" } }
      expect(P.chooseGuide({ raceOnly, classOnly }, warrior)).toBe(classOnly)
    end)

    it("prefers the narrower class list", function()
      local two = { id = "two", only = { class = { "WARRIOR", "HUNTER" } } }
      local one = { id = "one", only = { class = "WARRIOR" } }
      expect(P.chooseGuide({ two, one }, warrior)).toBe(one)
    end)

    it("keeps registration order for equal scores", function()
      local a, b = { id = "a" }, { id = "b" }
      expect(P.chooseGuide({ a, b }, warrior)).toBe(a)
    end)

    it("honours the player's pick, even a guide for someone else", function()
      local hunter = { id = "hunter", only = { class = "HUNTER" } }
      local any = { id = "any" }
      expect(P.chooseGuide({ hunter, any }, warrior)).toBe(any)
      expect(P.chooseGuide({ hunter, any }, warrior, "hunter")).toBe(hunter)
    end)

    it("falls back to the first guide when none fits, so a lone guide always plays", function()
      local hunter = { id = "hunter", only = { class = "HUNTER" } }
      expect(P.chooseGuide({ hunter }, warrior)).toBe(hunter)
      expect(P.chooseGuide({}, warrior)).toBeNil()
    end)

    it("describes a lock", function()
      expect(P.lockText({ class = { "HUNTER", "WARLOCK" }, race = "NIGHT_ELF" })).toBe("Hunter, Warlock - Night Elf")
      expect(P.lockText(nil)).toBe("")
    end)
  end)

  describe("registration", function()
    local ctx = H.use({ boot = true })

    it("registers several guides, each once, and fires GUIDE_REGISTERED for each", function()
      local registered = createSpy()
      ctx.ns:On("GUIDE_REGISTERED", registered)
      local a = Ribbon.Guide("a", { schema = 1, class = "HUNTER" })
      local b = Ribbon.Guide("b", { schema = 1, class = { "WARLOCK", "MAGE" } })
      expect(Ribbon.Guide("a", { schema = 1 })).toBe(a)
      expect(#ctx.ns.guides).toBe(2)
      expect(registered).toHaveBeenCalledTimes(2)
      expect(a.only).toEqual({ class = "HUNTER" })
      expect(b.only.class).toEqual({ "WARLOCK", "MAGE" })
    end)

    it("keeps a guide without a lock open to everyone", function()
      expect(Ribbon.Guide("open", { schema = 1 }).only).toBeNil()
    end)
  end)

  describe("at login", function()
    it("starts the guide that fits the character best, whatever the load order", function()
      local ns, world = H.load({})   -- the fake character is a Tauren warrior
      guide("hunter", { class = "HUNTER" }, 100)
      guide("any", {}, 200)
      guide("warrior", { class = "WARRIOR" }, 300)
      guide("tauren-warrior", { class = "WARRIOR", race = "TAUREN" }, 400)
      world:fireEvent("PLAYER_LOGIN")
      expect(ns.guidePlayer.state().guide.id).toBe("tauren-warrior")
      expect(ns.guide.id).toBe("tauren-warrior")
      expect(titles(ns)).toEqual({ "Accept Quest 400" })
    end)

    it("plays a lone guide that names another class rather than showing nothing", function()
      local ns, world = H.load({})
      guide("hunter", { class = "HUNTER" }, 100)
      world:fireEvent("PLAYER_LOGIN")
      expect(ns.guidePlayer.state().guide.id).toBe("hunter")
    end)
  end)

  describe("switching", function()
    local ctx = H.use({ boot = true })

    local function two()
      guide("hunter", { class = "HUNTER", title = "Hunter" }, 100)
      guide("warrior", { class = "WARRIOR", title = "Warrior" }, 200)
    end

    it("starts on the best fit and moves to a guide the player picks", function()
      two()
      local P = ctx.ns.guidePlayer
      expect(P.state().guide.id).toBe("warrior")
      local switched = createSpy()
      ctx.ns:On("GUIDE_SWITCHED", switched)
      expect(P.choose("hunter")).toBe(true)
      expect(P.state().guide.id).toBe("hunter")
      expect(ctx.ns.guide.id).toBe("hunter")
      expect(switched).toHaveBeenCalledTimes(1)
      expect(titles(ctx.ns)).toEqual({ "Accept Quest 100" })
      expect(P.choice()).toBe("hunter")
    end)

    it("returns to the best fit on auto and rejects an unknown guide", function()
      two()
      local P = ctx.ns.guidePlayer
      P.choose("hunter")
      expect(P.choose("nope")).toBe(false)
      expect(P.state().guide.id).toBe("hunter")
      P.choose("auto")
      expect(P.state().guide.id).toBe("warrior")
      expect(P.choice()).toBeNil()
    end)

    it("keeps each guide's position", function()
      two()
      local P = ctx.ns.guidePlayer
      P.skip()                                  -- warrior: step 2
      P.choose("hunter")
      expect(select(2, P.current())).toBe(1)    -- the hunter guide starts at its first step
      P.choose("warrior")
      expect(select(2, P.current())).toBe(2)    -- ... and the warrior guide is where it was left
    end)

    it("saves the pick for the character", function()
      two()
      ctx.ns.guidePlayer.choose("hunter")
      expect(ctx.ns.db.guideChoice[ctx.ns.client.character().key]).toBe("hunter")
    end)

    it("follows a guide registered later when the pick is automatic, not over a pick", function()
      guide("any", {}, 100)
      local P = ctx.ns.guidePlayer
      expect(P.state().guide.id).toBe("any")
      guide("warrior", { class = "WARRIOR" }, 200)
      expect(P.state().guide.id).toBe("warrior")
      P.choose("any")
      guide("tauren", { class = "WARRIOR", race = "TAUREN" }, 300)
      expect(P.state().guide.id).toBe("any")
    end)

    it("lists the guides and switches with /ribbon guide use", function()
      two()
      SlashCmdList.RIBBON("guide use hunter")
      expect(ctx.ns.guidePlayer.state().guide.id).toBe("hunter")
      local out = ctx.world:output()
      expect(out).toContain("Hunter")
      expect(out).toContain("recommended")
      SlashCmdList.RIBBON("guide use auto")
      expect(ctx.ns.guidePlayer.state().guide.id).toBe("warrior")
    end)
  end)

  describe("the guide panel", function()
    local ctx = H.use({ boot = true })

    it("has no picker, and starts again on the new guide's current step after /ribbon guide use", function()
      guide("hunter", { class = "HUNTER", title = "Hunter Guide" }, 100)
      guide("warrior", { class = "WARRIOR", title = "Warrior Guide" }, 200)
      ctx.ns.guideBrowser.toggle()
      local frame = ctx.ns.guideBrowser.dock()
      expect(frame.picker).toBeNil()
      SlashCmdList.RIBBON("guide use hunter")
      ctx.ns.guideBrowser.showChapters()
      expect(frame.title.SetText.calls[#frame.title.SetText.calls][1]).toBe("Hunter Guide")
    end)
  end)
end)
