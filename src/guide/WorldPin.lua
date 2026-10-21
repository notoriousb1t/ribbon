-- The in-world marker: while a guide runs, the focused waypoint (the step's place) is also set as the game's own user
-- waypoint and super-tracked, so the client draws its beacon and distance at that spot in the 3D world. Only a waypoint
-- Ribbon set is ever cleared; a waypoint the player placed on the map is left alone until a step replaces it.
local ADDON, ns = ...

local W = {}
ns.worldPin = W

local ours   -- "map:x:y" of the user waypoint this module set, nil when it has none

local function api()
  local map, track = _G.C_Map, _G.C_SuperTrack
  if type(map) ~= "table" or type(map.SetUserWaypoint) ~= "function" or type(map.ClearUserWaypoint) ~= "function" then return nil end
  return map, track
end

-- Whether this client can set a user waypoint at all (Classic Era cannot).
function W.supported()
  return api() ~= nil
end

local function point(mapID, x, y)
  if type(_G.UiMapPoint) == "table" and type(_G.UiMapPoint.CreateFromCoordinates) == "function" then
    return _G.UiMapPoint.CreateFromCoordinates(mapID, x, y)
  end
  if type(_G.CreateVector2D) == "function" then
    return { uiMapID = mapID, position = _G.CreateVector2D(x, y), z = 0 }
  end
end

local function clear()
  if not ours then return end
  ours = nil
  local map = api()
  if map then pcall(map.ClearUserWaypoint) end
end

local function wanted()
  if ns.guideSettings and not ns.guideSettings.get("worldPin") then return nil end
  if not (ns.guidePlayer and ns.guidePlayer.state()) then return nil end
  return ns.focus and ns:GetWaypoint(ns.focus) or nil
end

-- Puts the marker on the focused waypoint, or takes it away when there is none.
function W.sync()
  local wp = wanted()
  if not wp then return clear() end
  local map, track = api()
  if not map then return end
  local key = string.format("%s:%.4f:%.4f", wp.mapID, wp.x, wp.y)
  if key == ours then return end
  if type(map.CanSetUserWaypointOnMap) == "function" and not map.CanSetUserWaypointOnMap(wp.mapID) then return clear() end
  local p = point(wp.mapID, wp.x / 100, wp.y / 100)
  if not p then return end
  if pcall(map.SetUserWaypoint, p) then
    ours = key
    if track and type(track.SetSuperTrackedUserWaypoint) == "function" then pcall(track.SetSuperTrackedUserWaypoint, true) end
  end
end

for _, event in ipairs({ "FOCUS_CHANGED", "WAYPOINT_REMOVED", "GUIDE_STEP_CHANGED", "GUIDE_SETTINGS_CHANGED" }) do
  ns:On(event, W.sync)
end
