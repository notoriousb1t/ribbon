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

-- Marker size in pixels for a distance in yards. cfg = { min, max, nearYd, farYd, default, focusBoost }
-- (compass/Style.lua). Closer is bigger: `max` up to nearYd, `min` from farYd, logarithmic between.
function L.markerSize(dist, focused, cfg)
  local size
  if type(dist) ~= "number" then
    size = cfg.default
  else
    local near, far = math.log(cfg.nearYd), math.log(cfg.farYd)
    local t = (math.log(math.max(dist, cfg.nearYd)) - near) / (far - near)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    size = cfg.max - (cfg.max - cfg.min) * t
  end
  if focused then size = size + cfg.focusBoost end
  return floor(size + 0.5)
end

-- Marker placements for waypoints (nearest first, as returned by ns:Sorted()).
-- Returns an array of { wp, x, edge, side, focused, size } (at most max, plus the focused waypoint when
-- it is beyond the limit) and the waypoint to caption (the focused one, else the nearest). `side` is
-- "left" or "right" for a waypoint outside the field of view, which gets an arrow pointing that way.
-- `cfg` is the marker configuration (compass/Style.lua): sizes, and `pad` and `arrow`, which keep a
-- marker and its arrow inside the bar. Without it every marker is 20 px (26 when focused) and may sit
-- on the very end of the bar.
function L.markers(list, fovDeg, width, max, focusUID, cfg)
  local fovRad = rad(fovDeg)
  local limit = max or L.MAX_MARKERS
  local sizing = cfg or { min = 20, max = 20, nearYd = 1, farYd = 2, default = 20, focusBoost = 6 }
  local placements, label = {}, nil
  for _, wp in ipairs(list) do
    local focused = focusUID ~= nil and wp.uid == focusUID
    if wp.compass and wp.delta and (#placements < limit or focused) then
      local size = L.markerSize(wp.dist, focused, sizing)
      local inset = (cfg and cfg.arrow) and (size / 2 + cfg.pad + cfg.arrow + 1) or 0
      local x, edge, side = ns.geometry.markerOffset(wp.delta, fovRad, width, inset)
      placements[#placements + 1] = {
        wp = wp, x = x, edge = edge, side = side, focused = focused, size = size,
      }
      if not label or focused then label = wp end
    end
  end
  return placements, label
end

function L.targetText(wp)
  if not wp or not wp.dist then return "" end
  return string.format("%s - %d yd%s", wp.title, wp.dist, wp.arrived and " (arrived)" or "")
end

-- Text cut to at most max bytes, ending in "..." when something was removed. A cut never leaves half
-- of a multi-byte (UTF-8) character behind.
function L.shorten(text, max)
  if #text <= max then return text end
  local cut = text:sub(1, max - 3)
  -- Drop an incomplete trailing UTF-8 sequence (a lead byte without all its continuation bytes).
  for back = 1, math.min(3, #cut) do
    local byte = cut:byte(#cut - back + 1)
    if byte >= 0xC0 then
      local need = byte >= 0xF0 and 4 or (byte >= 0xE0 and 3 or 2)
      if back < need then cut = cut:sub(1, #cut - back) end
      break
    elseif byte < 0x80 then
      break
    end
  end
  return cut:gsub("%s+$", "") .. "..."
end

L.DETAIL_LINES = 2
L.DETAIL_WIDTH = 70

-- The short description shown under the bar: up to DETAIL_LINES lines, each cut to DETAIL_WIDTH.
function L.details(wp)
  local out = {}
  if not wp or type(wp.description) ~= "table" then return out end
  for i = 1, math.min(#wp.description, L.DETAIL_LINES) do
    out[i] = L.shorten(wp.description[i], L.DETAIL_WIDTH)
  end
  return out
end

local POINTS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

-- Compass heading in degrees clockwise from north (0-360, from geometry.heading's -180..180) and its
-- eight-point name ("NE").
function L.headingDegrees(heading)
  local d = heading % 360
  return d
end

function L.compassPoint(degrees)
  local d = degrees % 360
  return POINTS[math.floor((d + 22.5) / 45) % 8 + 1]
end

-- The dial's tooltip: coordinates as the title, then the zone and the heading. Position missing
-- (indoors, loading) gives "Position unavailable".
function L.coordinateTooltip(zoneName, x, y, heading)
  local lines = {}
  if zoneName and zoneName ~= "" then lines[#lines + 1] = zoneName end
  if heading then
    local d = L.headingDegrees(heading)
    lines[#lines + 1] = string.format("Facing %s (%d degrees)", L.compassPoint(d), math.floor(d + 0.5) % 360)
  end
  return { title = x and L.coordsText(x, y) or "Position unavailable", lines = lines }
end

function L.coordsText(x, y)
  if not x then return "" end
  return string.format("%.2f, %.2f", x, y)
end
