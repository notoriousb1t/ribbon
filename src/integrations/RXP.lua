-- RXP bridge: shows RestedXP's current arrow target on the compass.
-- RXPGuides draws its own arrow and map pins, so the waypoint is compass-only. Nothing in RXP is
-- changed: the arrow frame (the global RXPG_ARROW) is only read, about four times a second.
local ADDON, ns = ...

local B = {}
ns.rxpBridge = B

local translate = ns.rxpTranslate

local current   -- { key, uid }

local function arrowFrame()
  local af = _G.RXPG_ARROW
  if type(af) == "table" then return af end
  local rxp = _G.RXP
  if type(rxp) == "table" and type(rxp.arrowFrame) == "table" then return rxp.arrowFrame end
end

-- The arrow as plain values: whether it is shown and what it points at.
local function snapshot()
  local af = arrowFrame()
  if not af then return nil end
  local ok, shown = pcall(af.IsShown, af)
  return { shown = ok and shown and true or false, element = af.element }
end

-- Use RXP's own target icon, following its theme; fall back to the quest turn-in icon.
local function refreshIcon()
  local rxp = _G.RXP
  if type(rxp) ~= "table" or type(rxp.GetV1Texture) ~= "function" then return end
  local ok, texture = pcall(rxp.GetV1Texture, "map_active_step_target_icon")
  if ok and type(texture) == "string" and texture ~= "" then ns.ICONS.rxp = texture end
end

local function clear()
  if current then
    ns:RemoveWaypoint(current.uid)
    current = nil
  end
end

function B.refresh()
  local req = translate.fromArrow(snapshot(), { isValidMap = ns.client.isValidMap })
  if not req then
    clear()
    return
  end

  local key = translate.key(req)
  if current and current.key == key and ns:GetWaypoint(current.uid) then return end

  clear()
  refreshIcon()
  local uid = ns:AddWaypoint(req.mapID, req.x, req.y, {
    title = req.title,
    icon = "rxp",
    minimap = false,
    worldmap = false,
    lines = { "RestedXP waypoint" },
  })
  if uid then current = { key = key, uid = uid } end
end

-- Diagnostics: /ribbon rxp
ns.commands.rxp = function()
  local snap = snapshot()
  if not snap then
    ns:Print("RestedXP arrow not found (RXPG_ARROW); nothing to mirror.")
    return
  end
  local e = snap.element
  ns:Print(string.format("RXP arrow shown=%s element=%s zone=%s x=%s y=%s title=%s; mirrored=%s",
    tostring(snap.shown), tostring(e ~= nil), tostring(e and e.zone), tostring(e and e.x), tostring(e and e.y),
    tostring(e and translate.title(e)), tostring(current ~= nil)))
end

ns:On("INIT", function()
  if not arrowFrame() then return end
  ns:Every(0.25, B.refresh)
end)
