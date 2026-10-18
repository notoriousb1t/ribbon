-- TomTom translation: pure functions that turn TomTom data into waypoint requests.
-- No client calls and no TomTom access; the bridge supplies what it needs through ctx:
--   ctx.tomtom            the TomTom table (so a leading self argument can be dropped)
--   ctx.isValidMap(mapID) -> boolean
-- A request is { mapID, x, y, title } with x and y in 0-100, or nil plus a reason.
--
-- Written against TomTom v4.3.12 (read from its source):
--   TomTom:AddWaypoint(m, x, y, opts)   m = uiMapID, x and y fractions 0-1, opts.title
--   a waypoint handle ("uid") is { m, x, y, title = ..., from = ... }
-- Every way of setting a waypoint (/way, AddWaypointToCurrentZone, SetCustomWaypoint, restoring
-- saved waypoints) ends in AddWaypoint, so that is the only call that needs translating.
local ADDON, ns = ...

local T = {}
ns.tomtomTranslate = T

local function isNumber(v) return type(v) == "number" end

local function titleOf(v)
  if type(v) == "string" and v ~= "" then return v end
end

local function finish(mapID, x, y, title, ctx)
  if not (isNumber(mapID) and isNumber(x) and isNumber(y)) then return nil, "not numbers" end
  -- TomTom uses fractions; convert to the 0-100 Ribbon uses.
  x, y = x * 100, y * 100
  if x < 0 or x > 100 or y < 0 or y > 100 then return nil, "coordinates out of range" end
  if not ctx.isValidMap(mapID) then return nil, "unknown map" end
  return { mapID = mapID, x = x, y = y, title = title }
end

-- Stable identity for a waypoint: map, coordinates rounded to two decimals, and title
-- (TomTom treats waypoints with different titles at the same spot as different waypoints).
function T.key(mapID, x, y, title)
  return string.format("%d:%.2f:%.2f:%s", mapID, x, y, tostring(title or ""))
end

function T.keyOf(req)
  return T.key(req.mapID, req.x, req.y, req.title)
end

-- Arguments of TomTom:AddWaypoint(m, x, y, opts), with or without the leading self.
function T.fromAddWaypoint(args, ctx)
  local a = { n = args.n }
  for i = 1, args.n do a[i] = args[i] end
  if ctx.tomtom ~= nil and a[1] == ctx.tomtom then table.remove(a, 1) end
  local opts = a[4]
  return finish(a[1], a[2], a[3], type(opts) == "table" and titleOf(opts.title) or nil, ctx)
end

-- A TomTom waypoint handle as a request.
function T.fromUID(uid, ctx)
  if type(uid) ~= "table" then return nil, "not a waypoint" end
  return finish(uid[1], uid[2], uid[3], titleOf(uid.title), ctx)
end
