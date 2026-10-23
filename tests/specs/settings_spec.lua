local H = require("tests.helpers.addon")

describe("Guide settings", function()
  local ctx = H.use({ boot = true })
  local calls

  beforeEach(function()
    Ribbon.Guide("g", { title = "Test Guide", schema = 1 }):Chapter("One", { levels = { 1, 2 } })
      :Step():Goto(1453, 50, 50):Accept(1):Done()
    calls = {}
    for _, name in ipairs({ "AcceptQuest", "CompleteQuest", "GetQuestReward" }) do
      _G[name] = function(...) calls[#calls + 1] = { name, ... } end
    end
    _G.IsQuestCompletable = function() return true end
    _G.GetNumQuestChoices = function() return 0 end
    _G.IsShiftKeyDown = function() return false end
  end)
  afterEach(function()
    for _, name in ipairs({ "AcceptQuest", "CompleteQuest", "GetQuestReward", "IsQuestCompletable", "GetNumQuestChoices", "IsShiftKeyDown" }) do
      _G[name] = nil
    end
  end)

  it("has both options on by default", function()
    expect(ctx.ns.guideSettings.get("autoAdvance")).toBe(true)
    expect(ctx.ns.guideSettings.get("autoQuest")).toBe(true)
  end)

  it("accepts an offered quest, continues a finished one and hands it in when there is no reward to choose", function()
    local S = ctx.ns.guideSettings
    S.handle("QUEST_DETAIL")
    S.handle("QUEST_PROGRESS")
    S.handle("QUEST_COMPLETE")
    expect(calls[1][1]).toBe("AcceptQuest")
    expect(calls[2][1]).toBe("CompleteQuest")
    expect(calls[3][1]).toBe("GetQuestReward")
  end)

  it("leaves a quest with a reward to choose from alone", function()
    _G.GetNumQuestChoices = function() return 3 end
    ctx.ns.guideSettings.handle("QUEST_COMPLETE")
    expect(#calls).toBe(0)
  end)

  it("picks quests in a gossip window that has other options, finished ones first", function()
    _G.GetNumGossipActiveQuests = function() return 2 end
    _G.GetGossipActiveQuests = function() return "A", 5, false, false, "B", 5, false, true end
    _G.GetNumGossipAvailableQuests = function() return 1 end
    _G.SelectGossipActiveQuest = function(i) calls[#calls + 1] = { "SelectGossipActiveQuest", i } end
    _G.SelectGossipAvailableQuest = function(i) calls[#calls + 1] = { "SelectGossipAvailableQuest", i } end
    ctx.ns.guideSettings.handle("GOSSIP_SHOW")
    expect(calls[1][1]).toBe("SelectGossipActiveQuest")
    expect(calls[1][2]).toBe(2)
    _G.GetGossipActiveQuests = function() return "A", 5, false, false, "B", 5, false, false end
    ctx.ns.guideSettings.handle("GOSSIP_SHOW")
    expect(calls[2][1]).toBe("SelectGossipAvailableQuest")
    for _, n in ipairs({ "GetNumGossipActiveQuests", "GetGossipActiveQuests", "GetNumGossipAvailableQuests", "SelectGossipActiveQuest", "SelectGossipAvailableQuest" }) do _G[n] = nil end
  end)

  it("picks an available quest in a quest greeting", function()
    _G.GetNumActiveQuests = function() return 0 end
    _G.GetNumAvailableQuests = function() return 2 end
    _G.SelectAvailableQuest = function(i) calls[#calls + 1] = { "SelectAvailableQuest", i } end
    ctx.ns.guideSettings.handle("QUEST_GREETING")
    expect(calls[1][1]).toBe("SelectAvailableQuest")
    for _, n in ipairs({ "GetNumActiveQuests", "GetNumAvailableQuests", "SelectAvailableQuest" }) do _G[n] = nil end
  end)

  it("hands in a finished quest in a quest greeting by reading C_QuestLog (the old log calls answer 0 on Forever)", function()
    local saved = { _G.C_QuestLog, _G.GetNumQuestLogEntries }
    _G.C_QuestLog = {
      GetNumQuestLogEntries = function() return 3 end,
      GetInfo = function(i) return ({ { title = "Zone", isHeader = true }, { title = "A", questID = 1 }, { title = "B", questID = 2 } })[i] end,
      IsComplete = function(id) return id == 2 end,
    }
    _G.GetNumQuestLogEntries = function() return 0 end
    _G.GetNumActiveQuests = function() return 2 end
    _G.GetActiveTitle = function(i) return ({ "A", "B" })[i] end
    _G.SelectActiveQuest = function(i) calls[#calls + 1] = { "SelectActiveQuest", i } end
    ctx.ns.guideSettings.handle("QUEST_GREETING")
    expect(calls[1][1]).toBe("SelectActiveQuest")
    expect(calls[1][2]).toBe(2)
    _G.C_QuestLog, _G.GetNumQuestLogEntries = saved[1], saved[2]
    for _, n in ipairs({ "GetNumActiveQuests", "GetActiveTitle", "SelectActiveQuest" }) do _G[n] = nil end
  end)

  it("does nothing when the option is off or Shift is held", function()
    ctx.ns.guideSettings.set("autoQuest", false)
    ctx.ns.guideSettings.handle("QUEST_DETAIL")
    expect(#calls).toBe(0)
    ctx.ns.guideSettings.set("autoQuest", true)
    _G.IsShiftKeyDown = function() return true end
    ctx.ns.guideSettings.handle("QUEST_DETAIL")
    expect(#calls).toBe(0)
  end)

  it("has a cog beside the count whose menu toggles the options", function()
    ctx.ns.guideBrowser.toggleDock()
    local d = ctx.ns.guideBrowser.dock()
    expect(d.gear.SetPoint).toHaveBeenCalledWith("RIGHT", d.counter, "LEFT", -4, 0)
    expect(d.menu:IsShown()).toBe(false)
    d.gear:Trigger("OnClick")
    expect(d.menu:IsShown()).toBe(true)
    d.menu.rows[1]:Trigger("OnClick")
    expect(ctx.ns.guideSettings.get("autoAdvance")).toBe(false)
    d.menu.rows[2]:Trigger("OnClick")
    expect(ctx.ns.guideSettings.get("autoQuest")).toBe(false)
  end)
end)
