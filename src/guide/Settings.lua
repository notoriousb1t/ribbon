-- Guide settings and the quest windows' automation. Two options, both on by default, saved in RibbonDB.guideSettings:
--   autoAdvance: the guide moves on by itself when the quest log says a step is finished (guide/Player.lua reads this).
--   autoQuest:   while a guide is running, quest windows are answered for the player: a quest offered is accepted, a quest
--                whose objectives are done is handed in when it offers no reward to choose from. Holding Shift leaves a
--                window alone.
local ADDON, ns = ...

local Set = {}
ns.guideSettings = Set

-- The options in the order the menu lists them.
Set.OPTIONS = {
  { key = "autoAdvance", label = "Auto-advance", tip = "Move to the next step when the quest log shows the step is done." },
  { key = "autoQuest", label = "Auto accept and turn in", tip = "Accept quests and hand in finished ones that have no reward to choose from. Hold Shift to skip." },
}

function Set.get(key)
  local saved = ns.db and ns.db.guideSettings
  local v = saved and saved[key]
  if v == nil then return true end
  return v and true or false
end

function Set.set(key, value)
  if not ns.db then return end
  ns.db.guideSettings = ns.db.guideSettings or {}
  ns.db.guideSettings[key] = value and true or false
  ns:Fire("GUIDE_SETTINGS_CHANGED", key, value and true or false)
end

-- Quest windows ---------------------------------------------------------------------------

local function active()
  if not Set.get("autoQuest") then return false end
  if not (ns.guidePlayer and ns.guidePlayer.state()) then return false end
  if _G.IsShiftKeyDown and _G.IsShiftKeyDown() then return false end
  return true
end

local function call(name, ...)
  local fn = _G[name]
  if type(fn) == "function" then return pcall(fn, ...) end
end

local handlers = {
  -- A quest is offered.
  QUEST_DETAIL = function() call("AcceptQuest") end,
  -- The quest's window asks for the objectives: continue when they are done.
  QUEST_PROGRESS = function()
    if type(_G.IsQuestCompletable) == "function" and _G.IsQuestCompletable() then call("CompleteQuest") end
  end,
  -- The reward page: hand in when there is nothing to choose between.
  QUEST_COMPLETE = function()
    local choices = type(_G.GetNumQuestChoices) == "function" and _G.GetNumQuestChoices() or nil
    if choices == 0 then call("GetQuestReward", 0) end
  end,
}

-- (Set.handle is what the watcher calls; the specs call it directly.)
function Set.handle(event)
  if handlers[event] and active() then handlers[event]() end
end

local watcher
function Set.watch()
  if watcher or type(_G.CreateFrame) ~= "function" then return end
  watcher = CreateFrame("Frame")
  for event in pairs(handlers) do pcall(watcher.RegisterEvent, watcher, event) end
  watcher:SetScript("OnEvent", function(_, event) Set.handle(event) end)
end

ns:On("INIT", Set.watch)
