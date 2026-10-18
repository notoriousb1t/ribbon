-- Geometry: pure math, no client calls.
-- World axes (measured): first increases north, second increases west.
-- Facing is radians, 0 = north, counter-clockwise positive, so a bearing computed as
-- atan2(dSecond, dFirst) is already in the facing convention and a positive delta is a target on the left.
local ADDON, ns = ...

local geo = {}
ns.geometry = geo

local pi, sqrt, abs, deg = math.pi, math.sqrt, math.abs, math.deg
local TWO_PI = 2 * pi
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

function geo.wrap(a)
  while a > pi do a = a - TWO_PI end
  while a < -pi do a = a + TWO_PI end
  return a
end

function geo.wrapDeg(a)
  while a > 180 do a = a - 360 end
  while a < -180 do a = a + 360 end
  return a
end

-- Compass heading in degrees clockwise from north, wrapped to [-180, 180].
function geo.heading(facing)
  return geo.wrapDeg(-deg(facing))
end

-- Distance in yards and signed delta (radians, positive = left of facing; nil without facing).
function geo.bearing(playerFirst, playerSecond, targetFirst, targetSecond, facing)
  local d1, d2 = targetFirst - playerFirst, targetSecond - playerSecond
  local dist = sqrt(d1 * d1 + d2 * d2)
  if not facing then return dist, nil end
  return dist, geo.wrap(atan2(d2, d1) - facing)
end

-- Horizontal offset in pixels from the bar centre for a delta (positive = right), whether the marker
-- is outside the field of view (then it is held at the end of the bar), and on which side that is
-- ("left" or "right"; nil when inside the field of view). `inset` keeps markers that many pixels
-- away from the bar's ends so a marker and its off-screen arrow fit inside the bar (default 0).
function geo.markerOffset(delta, fovRad, width, inset)
  local half = fovRad / 2
  local limit = width / 2 - (inset or 0)
  local x = -delta / half * (width / 2)
  if x > limit then x = limit elseif x < -limit then x = -limit end
  local edge = abs(delta) > half
  local side = edge and (delta > 0 and "left" or "right") or nil
  return x, edge, side
end

function geo.clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end
