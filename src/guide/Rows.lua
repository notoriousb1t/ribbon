-- Guide rows: pure model for the tracking frame. No frames, no client calls.
local ADDON, ns = ...

local R = {}
ns.guideRows = R

function R.distanceText(wp)
  if wp.arrived then return "here" end
  if wp.dist then return string.format("%d yd", wp.dist) end
  return "--"
end

-- Row descriptors for the nearest waypoints (list is nearest first), at most maxRows.
function R.build(list, maxRows, focusUID)
  local rows = {}
  for i = 1, math.min(#list, maxRows) do
    local wp = list[i]
    rows[i] = {
      uid = wp.uid, icon = wp.icon, title = wp.title,
      distance = R.distanceText(wp), focused = focusUID == wp.uid,
    }
  end
  return rows
end

-- The frame shows when enabled and there is something to show (a waypoint or a provider header).
function R.shouldShow(enabled, count, header)
  return (enabled and (count > 0 or header ~= nil)) and true or false
end
