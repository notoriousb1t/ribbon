-- RXP translation: pure functions that turn RXPGuides' arrow target into a waypoint request.
-- No client calls and no RXP access; the bridge passes a plain snapshot:
--   { shown = boolean, element = { zone, x, y, title, text, step = { title, arrowtext, index, elements } } }
-- Written against RXPGuides v4.11.26 (read from its source): the arrow frame is the global
-- RXPG_ARROW; its element is the active waypoint, with zone (uiMapID) and x, y (0-100) for
-- zone-based waypoints. The corpse and Spirit Healer waypoints carry world coordinates only
-- (no zone), so they are not translated. The step the waypoint belongs to lists its elements, each
-- with its own text ("Accept X", "Kill Y (0/8)", ...); those lines are the description.
local ADDON, ns = ...

local T = {}
ns.rxpTranslate = T

local function clean(text)
  text = text:gsub("RXP_[A-Z]+_", "")      -- RXP's colour tokens
  text = text:gsub("|c%x%x%x%x%x%x%x%x", "") -- colour start
  text = text:gsub("|r", "")
  text = text:gsub("|T.-|t", "")            -- inline textures (icons)
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  return text
end

-- RXP's generated "Go to 45.5,77.4 (Zone)" text says where, which the bar already shows.
local function isGenericGoto(text)
  return text:find("^Go to [%d%.]+, ?[%d%.]+") ~= nil
end

-- The text lines of the step the waypoint belongs to, in step order: what to do there. A step text can
-- itself span several lines ("Loot X ...\nX: 0/1"); each becomes its own line. Finished and skipped
-- lines are left out, as are duplicates and the generated "Go to ..." line.
function T.stepLines(element)
  local step = element.step
  local list = (type(step) == "table" and type(step.elements) == "table") and step.elements or { element }
  local lines, seen = {}, {}
  for _, e in ipairs(list) do
    if type(e) == "table" and not e.completed and not e.skip and not e.hidden and type(e.text) == "string" then
      for raw in e.text:gmatch("[^\r\n]+") do
        local text = clean(raw)
        if text ~= "" and not isGenericGoto(text) and not seen[text] then
          seen[text] = true
          lines[#lines + 1] = text
        end
      end
    end
  end
  return lines
end

-- A short headline: the element's own title (a quest name), else the first line of the step's text,
-- else the step's arrow text, title or number. Always a single line.
function T.title(element)
  if type(element.title) == "string" then
    for raw in element.title:gmatch("[^\r\n]+") do
      local own = clean(raw)
      if own ~= "" then return own end
    end
  end
  local lines = T.stepLines(element)
  if lines[1] then return lines[1] end
  local step = element.step
  local raw = type(step) == "table" and (step.arrowtext or step.title or (step.index and ("Step " .. step.index))) or nil
  local text = type(raw) == "string" and clean(raw) or ""
  if text == "" then return "RestedXP" end
  return text
end

-- The step's text lines other than the one already used as the headline.
function T.description(element)
  local title = T.title(element)
  local out = {}
  for _, line in ipairs(T.stepLines(element)) do
    if line ~= title then out[#out + 1] = line end
  end
  return out
end

-- A request { mapID, x, y, title, description } or nil when there is no zone-based arrow target.
function T.fromArrow(snapshot, ctx)
  if type(snapshot) ~= "table" or not snapshot.shown then return nil end
  local e = snapshot.element
  if type(e) ~= "table" then return nil end
  if type(e.zone) ~= "number" or type(e.x) ~= "number" or type(e.y) ~= "number" then return nil end
  if e.x < 0 or e.x > 100 or e.y < 0 or e.y > 100 then return nil end
  if not ctx.isValidMap(e.zone) then return nil end
  return { mapID = e.zone, x = e.x, y = e.y, title = T.title(e), description = T.description(e) }
end

-- Identity of the arrow target: where it is. The text changes in place as the step progresses
-- ("Kill Y (3/8)"), so it is not part of the identity.
function T.key(req)
  return string.format("%d:%.2f:%.2f", req.mapID, req.x, req.y)
end
