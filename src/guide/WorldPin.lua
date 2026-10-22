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

-- Screen-space icon: the focused waypoint's own badge (the icon the compass and map draw), anchored to the client's
-- navigation frame (the on-screen position of the super-tracked waypoint) and scaled by distance. It is a flat overlay
-- without depth and exists only while the waypoint does. Fail-open: with no C_Navigation.GetFrame, or no frame, nothing
-- is drawn.
local ALPHA = 0.50   -- the icon is see-through, so the world shows behind it
-- Pixels above the waypoint: high enough to clear a quest giver's own marker when near, higher still from far away.
local LIFT_NEAR, LIFT_FAR = 84, 170
local NEAR, FAR = 10, 150   -- yards at which it is lowest and highest
local FOV_TAN = 0.577         -- tan of half the camera's vertical field of view (about 60 degrees)
local DZ_LIMIT = 220         -- pixels: the most a height difference moves the icon
local CURVE = 0.35          -- below 1: the lift falls faster the closer the player gets, steepest in the last 30 yd
local pinIcon
local drawn   -- "icon:size" the badge was last drawn with

local function navFrame()
  local nav = _G.C_Navigation
  if type(nav) ~= "table" or type(nav.GetFrame) ~= "function" then return nil end
  local ok, f = pcall(nav.GetFrame)
  if ok and type(f) == "table" and type(f.IsVisible) == "function" then return f end
end

-- Runs every frame, so it only touches the frame when something changed (the anchor, size and look are re-set on a change
-- of a whole pixel, not on every fractional step of the distance).
local lastAnchor, lastLift, lastSize, lastAlpha

local function iconUpdate(self)
  local f = navFrame()
  if not f or not f:IsVisible() then
    if lastAlpha ~= 0 then lastAlpha = 0 self:SetAlpha(0) end
    return
  end
  local size, lift = 28.8, LIFT_NEAR
  local nav = _G.C_Navigation
  if type(nav.GetDistance) == "function" then
    local ok, d = pcall(nav.GetDistance)
    if ok and type(d) == "number" then
      size = math.max(16, math.min(28.8, 2160 / math.max(d, 40)))
      -- starts high and settles onto the point as the player closes in
      local t = math.max(0, math.min(1, (d - NEAR) / (FAR - NEAR)))
      lift = LIFT_NEAR + (LIFT_FAR - LIFT_NEAR) * t ^ CURVE
      -- The client puts its waypoint at the height of the ground under the character. When the step carries its own height,
      -- the icon moves by the difference, in pixels at this distance; without one nothing changes.
      local playerZ = self.z and ns.client.playerZ()
      if playerZ and _G.UIParent then
        local pxPerYard = (_G.UIParent:GetHeight() / 2) / (math.max(d, 5) * FOV_TAN)
        lift = lift + math.max(-DZ_LIMIT, math.min(DZ_LIMIT, (self.z - playerZ) * pxPerYard))
      end
    end
  end
  lift = math.max(0, math.floor(lift + 0.5))
  if f ~= lastAnchor or lift ~= lastLift then
    lastAnchor, lastLift = f, lift
    self:ClearAllPoints()
    self:SetPoint("BOTTOM", f, "CENTER", 0, lift)
  end
  size = 2 * math.floor(size / 2)   -- even, so it centres on whole pixels
  if size ~= lastSize or self.icon ~= drawn then
    lastSize, drawn = size, self.icon
    self:SetSize(size, size)
    ns.badge.draw(self, self.icon, size, true)
  end
  if lastAlpha ~= ALPHA then lastAlpha = ALPHA self:SetAlpha(ALPHA) end
end

local function showIcon(wp)
  -- The navigation frame may not exist yet when the waypoint is set; the icon is made anyway and stays invisible until
  -- iconUpdate finds the frame.
  local nav = _G.C_Navigation
  if type(_G.CreateFrame) ~= "function" or not ns.badge or type(nav) ~= "table" or type(nav.GetFrame) ~= "function" then return end
  if not pinIcon then
    pinIcon = _G.CreateFrame("Frame", nil, _G.UIParent)
    pinIcon:SetFrameStrata("BACKGROUND")
    pinIcon:SetSize(32, 32)
    ns.badge.build(pinIcon)
    pinIcon:SetScript("OnUpdate", iconUpdate)
  end
  pinIcon.icon = wp.icon or ns.DEFAULT_ICON
  pinIcon.z = wp.z
  pinIcon:Show()
end

local function hideIcon()
  if pinIcon then pinIcon:Hide() end
end

-- State of the screen-space icon, for /ribbon probe.
function W.status()
  local f = navFrame()
  return {
    nav = f ~= nil,
    navVisible = f ~= nil and f:IsVisible() or false,
    icon = pinIcon ~= nil,
    iconShown = pinIcon ~= nil and pinIcon:IsShown() or false,
    iconName = pinIcon and pinIcon.icon or nil,
    iconAlpha = pinIcon and pinIcon:GetAlpha() or nil,
    iconSize = pinIcon and pinIcon:GetWidth() or nil,
    ours = ours,
  }
end

local function clear()
  hideIcon()
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
  if key == ours then return showIcon(wp) end
  if type(map.CanSetUserWaypointOnMap) == "function" and not map.CanSetUserWaypointOnMap(wp.mapID) then return clear() end
  local p = point(wp.mapID, wp.x / 100, wp.y / 100)
  if not p then return end
  if pcall(map.SetUserWaypoint, p) then
    ours = key
    if track and type(track.SetSuperTrackedUserWaypoint) == "function" then pcall(track.SetSuperTrackedUserWaypoint, true) end
    showIcon(wp)
  end
end

for _, event in ipairs({ "FOCUS_CHANGED", "WAYPOINT_REMOVED", "GUIDE_STEP_CHANGED", "GUIDE_SETTINGS_CHANGED" }) do
  ns:On(event, W.sync)
end
