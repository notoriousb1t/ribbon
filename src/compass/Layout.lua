-- Compass layout: pure functions that turn headings and waypoints into pixel placements.
-- No frames and no client calls; the view in Compass.lua applies the result.
local ADDON, ns = ...

local L = {}
ns.compassLayout = L

local abs, floor, rad = math.abs, math.floor, math.rad

L.MAX_MARKERS = 20
L.TICK_STEP = 5
L.TICK_COUNT = 360 / L.TICK_STEP
L.NAMES = { [0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW" }

-- Heading scale for a heading (degrees clockwise from north), field of view (degrees) and bar width.
-- Returns ticks[i] (i = 1..72, heading (i-1)*5; false when outside the view or replaced by a label)
-- and labels[heading] (cardinals/ordinals inside the view).
function L.scale(heading, fov, width)
  local half, halfWidth = fov / 2, width / 2
  local ticks, labels = {}, {}
  for i = 1, L.TICK_COUNT do
    local h = (i - 1) * L.TICK_STEP
    local d = ns.geometry.wrapDeg(h - heading)
    if abs(d) <= half then
      local x = d / half * halfWidth
      if L.NAMES[h] then
        labels[h] = { name = L.NAMES[h], x = x }
        ticks[i] = false
      else
        local major = (h - 15 * floor(h / 15)) == 0
        ticks[i] = { x = x, height = major and 12 or 6, alpha = major and 0.85 or 0.45 }
      end
    else
      ticks[i] = false
    end
  end
  return ticks, labels
end

-- Marker placements for waypoints (nearest first, as returned by ns:Sorted()).
-- Returns an array of { wp, x, edge } (at most max) and the waypoint to caption (focus, else nearest).
function L.markers(list, fovDeg, width, max, focusUID)
  local fovRad = rad(fovDeg)
  local placements, label = {}, nil
  for _, wp in ipairs(list) do
    if #placements >= (max or L.MAX_MARKERS) then break end
    if wp.compass and wp.delta then
      local x, edge = ns.geometry.markerOffset(wp.delta, fovRad, width)
      placements[#placements + 1] = { wp = wp, x = x, edge = edge }
      if not label or wp.uid == focusUID then label = wp end
    end
  end
  return placements, label
end

function L.targetText(wp)
  if not wp or not wp.dist then return "" end
  return string.format("%s - %d yd%s", wp.title, wp.dist, wp.arrived and " (arrived)" or "")
end

function L.coordsText(x, y)
  if not x then return "" end
  return string.format("%.2f, %.2f", x, y)
end
