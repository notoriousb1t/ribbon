-- RXP translation: pure functions that turn RXPGuides' arrow target into a waypoint request.
-- No client calls and no RXP access; the bridge passes a plain snapshot:
--   { shown = boolean, element = { zone, x, y, title, step = { title, arrowtext, index } } }
-- Written against RXPGuides v4.11.26 (read from its source): the arrow frame is the global
-- RXPG_ARROW; its element is the active waypoint, with zone (uiMapID) and x, y (0-100) for
-- zone-based waypoints. The corpse and Spirit Healer waypoints carry world coordinates only
-- (no zone), so they are not translated.
local ADDON, ns = ...

local T = {}
ns.rxpTranslate = T

local function clean(text)
  text = text:gsub("RXP_[A-Z]+_", "")      -- RXP's colour tokens
  text = text:gsub("|c%x%x%x%x%x%x%x%x", "") -- colour start
  text = text:gsub("|r", "")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  return text
end

-- A short label for the waypoint: its own title, else the step's arrow text, title or number.
function T.title(element)
  local step = element.step
  local raw
  if type(element.title) == "string" and element.title ~= "" then
    raw = element.title
  elseif type(step) == "table" then
    raw = step.arrowtext or step.title or (step.index and ("Step " .. step.index))
  end
  local text = type(raw) == "string" and clean(raw) or ""
  if text == "" then return "RestedXP" end
  return text
end

-- A request { mapID, x, y, title } or nil when there is no zone-based arrow target.
function T.fromArrow(snapshot, ctx)
  if type(snapshot) ~= "table" or not snapshot.shown then return nil end
  local e = snapshot.element
  if type(e) ~= "table" then return nil end
  if type(e.zone) ~= "number" or type(e.x) ~= "number" or type(e.y) ~= "number" then return nil end
  if e.x < 0 or e.x > 100 or e.y < 0 or e.y > 100 then return nil end
  if not ctx.isValidMap(e.zone) then return nil end
  return { mapID = e.zone, x = e.x, y = e.y, title = T.title(e) }
end

-- Identity of the arrow target; a change replaces the Ribbon waypoint.
function T.key(req)
  return string.format("%d:%.2f:%.2f:%s", req.mapID, req.x, req.y, req.title)
end
