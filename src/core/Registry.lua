-- Registry: waypoint model, public API, geometry and arrival. No direct client calls.
local ADDON, ns = ...

local waypoints = {}
ns.waypoints = waypoints
local nextUID = 1
local sorted = {}

local function opt(v) return v ~= false end

-- Text on a single line: line breaks become spaces, so a title with an embedded newline cannot push the
-- distance onto a second line of the caption.
function ns.OneLine(text)
  local out = tostring(text):gsub("%s*[\r\n]+%s*", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return out
end

-- A description as a list of non-empty lines: a string (split on newlines) or a list of strings.
function ns.NormalizeDescription(value)
  local out = {}
  local function add(text)
    for line in tostring(text):gmatch("[^\r\n]+") do
      line = line:gsub("^%s+", ""):gsub("%s+$", "")
      if line ~= "" then out[#out + 1] = line end
    end
  end
  if type(value) == "string" then
    add(value)
  elseif type(value) == "table" then
    for _, v in ipairs(value) do
      if type(v) == "string" then add(v) end
    end
  end
  return out
end

-- Public API ---------------------------------------------------------------

-- Returns a unique integer uid, or nil for any bad argument.
function ns:AddWaypoint(mapID, x, y, options)
  if not ns.ready then return nil end
  if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return nil end
  if x < 0 or x > 100 or y < 0 or y > 100 then return nil end
  if not ns.client.isValidMap(mapID) then return nil end
  local first, second, instance = ns.client.toWorld(mapID, x, y)
  if not first then return nil end
  options = type(options) == "table" and options or {}

  local wp = {
    uid = nextUID,
    mapID = mapID, x = x, y = y,
    first = first, second = second, instance = instance,
    title = ns.OneLine(options.title or "Waypoint"),
    icon = ns.ICONS[options.icon] and options.icon or ns.DEFAULT_ICON,
    description = ns.NormalizeDescription(options.description),   -- short text shown under the bar
    lines = type(options.lines) == "table" and options.lines or nil,
    minimap = opt(options.minimap), worldmap = opt(options.worldmap), compass = opt(options.compass),
    radius = tonumber(options.arrival_distance) or 5,
    on_arrive = type(options.on_arrive) == "function" and options.on_arrive or nil,
    visible = true, arrived = false,
  }
  waypoints[wp.uid] = wp
  nextUID = nextUID + 1
  ns:Fire("WAYPOINT_ADDED", wp)
  return wp.uid
end

function ns:RemoveWaypoint(uid)
  local wp = waypoints[uid]
  if not wp then return end
  waypoints[uid] = nil
  if ns.focus == uid then ns.focus = nil end
  ns:Fire("WAYPOINT_REMOVED", wp)
end

function ns:ClearAllWaypoints()
  for uid in pairs(waypoints) do ns:RemoveWaypoint(uid) end
end

function ns:SetWaypointVisible(uid, isVisible)
  local wp = waypoints[uid]
  if not wp then return end
  isVisible = isVisible and true or false
  if wp.visible == isVisible then return end
  wp.visible = isVisible
  if not isVisible and ns.focus == uid then ns:SetFocus(nil) end   -- a hidden waypoint cannot stay focused
  ns:Fire("WAYPOINT_CHANGED", wp)
end

function ns:GetWaypoint(uid)
  return waypoints[uid]
end

-- Hide or restore every waypoint without removing it (Clear All / /ribbon show).
function ns:HideAll()
  for uid in pairs(waypoints) do ns:SetWaypointVisible(uid, false) end
end

function ns:ShowAll()
  for uid in pairs(waypoints) do ns:SetWaypointVisible(uid, true) end
end

function ns:SetFocus(uid)
  ns.focus = (uid and waypoints[uid]) and uid or nil
  ns:Fire("FOCUS_CHANGED", ns.focus)
end

-- Visible waypoints, nearest first; waypoints without a distance last.
-- The returned table is reused between calls.
function ns:Sorted()
  for i = #sorted, 1, -1 do sorted[i] = nil end
  for _, wp in pairs(waypoints) do
    if wp.visible then sorted[#sorted + 1] = wp end
  end
  table.sort(sorted, function(a, b)
    if a.dist and b.dist then
      if a.dist ~= b.dist then return a.dist < b.dist end
    elseif a.dist or b.dist then
      return a.dist ~= nil
    end
    return a.uid < b.uid
  end)
  return sorted
end

-- Geometry and arrival (30 Hz) ----------------------------------------------

function ns:UpdateGeometry()
  if next(waypoints) == nil then return end
  local pf, ps, pinst = ns.client.playerWorld()
  local facing = ns.client.facing()
  for _, wp in pairs(waypoints) do
    if pf and wp.instance == pinst then
      wp.dist, wp.delta = ns.geometry.bearing(pf, ps, wp.first, wp.second, facing)
      if not wp.arrived and wp.dist <= wp.radius then
        wp.arrived = true
        if wp.on_arrive then
          local ok, err = pcall(wp.on_arrive, wp.uid, wp)
          if not ok then geterrorhandler()(err) end
        end
        ns:Fire("WAYPOINT_ARRIVED", wp)
      elseif wp.arrived and wp.dist > wp.radius * 1.5 then
        wp.arrived = false
      end
    else
      wp.dist, wp.delta = nil, nil
    end
  end
end

ns:On("INIT", function() ns:Every(0.033, function() ns:UpdateGeometry() end) end)
