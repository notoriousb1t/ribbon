-- Quest bridge: puts the tracked quest on the compass.
-- Reads the engine's quest tracking; nothing is changed in the game. The quest is compass-only
-- because the game draws its own quest points on the maps. A quest whose point is on a different
-- map than the one you are standing in is not shown (the engine only lists points per map).
local ADDON, ns = ...

local B = {}
ns.questBridge = B

local translate = ns.questTranslate

local current   -- { key, uid }

local function clear()
  if current then
    ns:RemoveWaypoint(current.uid)
    current = nil
  end
end

function B.refresh()
  local questID = ns.client.superTrackedQuestID()
  -- The guide's current step already has this quest as an objective: its waypoint is on the compass, so the
  -- game's tracked quest is left out.
  if questID and ns.guidePlayer and ns.guidePlayer.coversQuest(questID) then
    clear()
    return
  end
  local mapID = ns.client.currentMap()
  local point = questID and mapID and translate.pickPoint(ns.client.questPoints(mapID), questID)
  if not point then
    clear()
    return
  end

  local objectives = ns.client.questObjectives(questID)
  local icon = translate.iconFor(point, objectives)
  local description = translate.description(objectives)
  local key = translate.key(questID, mapID, point.x, point.y, icon)

  local existing = current and current.key == key and ns:GetWaypoint(current.uid)
  if existing then
    -- Progress ("3/8") changes the text every kill; update it in place instead of replacing the marker.
    existing.description = ns.NormalizeDescription(description)
    return
  end

  clear()
  local uid = ns:AddWaypoint(mapID, point.x, point.y, {
    title = ns.client.questTitle(questID) or ("Quest " .. questID),
    description = description,
    icon = icon,
    minimap = false,
    worldmap = false,
    lines = { "Tracked quest" },
  })
  if uid then current = { key = key, uid = uid } end
end

-- Events make it react at once; the ticker is the fallback, so an event this client does not have
-- (registering an unknown event is an error) costs nothing.
local EVENTS = { "SUPER_TRACKING_CHANGED", "QUEST_POI_UPDATE", "QUEST_LOG_UPDATE", "ZONE_CHANGED_NEW_AREA" }

ns:On("INIT", function()
  local frame = CreateFrame("Frame")
  for _, event in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, event) end
  frame:SetScript("OnEvent", function()
    local ok, err = pcall(B.refresh)
    if not ok then geterrorhandler()(err) end
  end)
  ns:Every(0.25, B.refresh)
end)
