-- Compass ribbon view: creates frames and applies the placements computed by compass/Layout.lua.
local ADDON, ns = ...

local C = {}
ns.compass = C

local deg = math.deg
local TRACK_HEIGHT = 28

local db, frame, dial, needle, targetText, detailText, captionPlate, captionTrim
local lastRotation
local chrome = {}
local ticks, labels, markers = {}, {}, {}
local layout

-- Outlined, shadowed text stays readable over any background. The font file comes from the
-- game's own font object so it follows the player's UI font and language.
local function styleText(fs, size)
  local base = _G.GameFontHighlight
  if base and base.GetFont then
    local ok, path = pcall(base.GetFont, base)
    if ok and path then fs:SetFont(path, size, "OUTLINE") end
  end
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
end

-- Show the caption for a waypoint (or clear it): headline, up to two description lines, and a plate
-- sized to fit the text.
local function setCaption(wp)
  local head = layout.targetText(wp)
  local details = table.concat(layout.details(wp), "\n")
  targetText:SetText(head)
  detailText:SetText(details)
  if head == "" then
    captionPlate:Hide()
    captionTrim:Hide()
    return
  end
  local cap = ns.compassStyle.caption
  local width = math.max(targetText:GetStringWidth() or 0, details ~= "" and (detailText:GetStringWidth() or 0) or 0)
  local height = (targetText:GetStringHeight() or cap.headSize) + cap.padY * 2
  if details ~= "" then height = height + cap.lineGap + (detailText:GetStringHeight() or cap.detailSize) end
  captionPlate:SetSize(math.max(width + cap.padX * 2, cap.minWidth), height)
  captionPlate:Show()
  captionTrim:Show()
end

local function savePosition()
  local point, _, relPoint, x, y = frame:GetPoint()
  db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
end

function C.Apply()
  local opacity = ns.compassStyle.opacity
  db.width = ns.geometry.clamp(tonumber(db.width) or 600, 500, 800)
  db.fov = ns.geometry.clamp(tonumber(db.fov) or 140, 90, 180)
  db.opacity = ns.geometry.clamp(tonumber(db.opacity) or opacity.default, opacity.min, opacity.max)
  for _, texture in ipairs(chrome) do texture:SetAlpha(db.opacity) end
  frame:SetSize(db.width, TRACK_HEIGHT)
  frame:ClearAllPoints()
  frame:SetPoint(db.point or "TOP", UIParent, db.relPoint or db.point or "TOP", db.x or 0, db.y or -72)
  frame:SetShown(db.shown and true or false)
end

local function showTooltip(self)
  local wp = ns:GetWaypoint(self.uid)
  if not wp then return end
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:SetText(wp.title)
  for _, line in ipairs(wp.description or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
  if wp.lines then
    for _, line in ipairs(wp.lines) do GameTooltip:AddLine(tostring(line), 1, 1, 1) end
  end
  if wp.dist then GameTooltip:AddLine(string.format("%d yd", wp.dist), 0.7, 0.7, 0.7) end
  GameTooltip:AddLine("Click to focus, right-click to hide", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

-- The dial's tooltip: coordinates, zone and which way you are facing.
local function showCoordinates(owner)
  local mapID, x, y = ns.client.playerMapPosition()
  local info = mapID and ns.client.mapInfo(mapID)
  local facing = ns.client.facing()
  local tip = layout.coordinateTooltip(info and info.name, x, y, facing and ns.geometry.heading(facing) or nil)
  local gold = ns.compassStyle.colors.gold
  GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
  GameTooltip:SetText(tip.title, gold[1], gold[2], gold[3])
  for _, line in ipairs(tip.lines) do GameTooltip:AddLine(line, 1, 1, 1) end
  GameTooltip:Show()
end

local function marker(i)
  local m = markers[i]
  if m then return m end
  m = CreateFrame("Button", nil, frame)
  m:SetSize(20, 20)
  m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  m.tex = m:CreateTexture(nil, "ARTWORK")
  m.tex:SetAllPoints()
  -- For a waypoint outside the view: an arrow beside the marker, pointing the way to turn.
  local arrowSize = ns.compassStyle.marker.arrow
  m.arrow = m:CreateTexture(nil, "OVERLAY")
  m.arrow:SetTexture(ns.compassStyle.textures.edgeArrow)
  m.arrow:SetSize(arrowSize, arrowSize)
  m.arrow:Hide()
  m:SetScript("OnEnter", showTooltip)
  m:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Left-click focuses the waypoint (its name shows under the bar); clicking the focused one again
  -- goes back to the nearest. Right-click hides it.
  m:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      GameTooltip:Hide()
      ns:SetWaypointVisible(self.uid, false)
    else
      ns:SetFocus(ns.focus ~= self.uid and self.uid or nil)
    end
  end)
  markers[i] = m
  return m
end

local function build()
  frame = CreateFrame("Frame", "RibbonCompass", UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() savePosition() end)

  local style = ns.compassStyle
  local c = style.colors

  -- The band, with a light top edge and a dark bottom edge.
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(c.band))
  local highlight = frame:CreateTexture(nil, "BACKGROUND")
  highlight:SetColorTexture(unpack(c.highlight))
  highlight:SetHeight(style.band.highlight)
  highlight:SetPoint("TOPLEFT")
  highlight:SetPoint("TOPRIGHT")
  local shadow = frame:CreateTexture(nil, "BACKGROUND")
  shadow:SetColorTexture(unpack(c.shadow))
  shadow:SetHeight(style.band.shadow)
  shadow:SetPoint("BOTTOMLEFT")
  shadow:SetPoint("BOTTOMRIGHT")

  -- Swallowtail ends, drawn behind the band.
  local capLeft = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
  capLeft:SetTexture(style.textures.capLeft)
  capLeft:SetSize(style.cap.width, style.cap.height)
  capLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", -style.cap.leftEdge, 0)
  local capRight = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
  capRight:SetTexture(style.textures.capRight)
  capRight:SetSize(style.cap.width, style.cap.height)
  capRight:SetPoint("TOPLEFT", frame, "TOPRIGHT", -style.cap.rightEdge, 0)

  -- The ribbon itself can be made see-through; text, ticks, markers, the dial and the caption plate
  -- stay opaque so they remain easy to read.
  chrome = { bg, highlight, shadow, capLeft, capRight }

  -- Heading reference: a thin notch through the band.
  local notch = frame:CreateTexture(nil, "OVERLAY")
  notch:SetColorTexture(unpack(c.notch))
  notch:SetSize(2, TRACK_HEIGHT)
  notch:SetPoint("CENTER")

  -- The compass: a dial under the bar with a needle that always points to due north.
  -- Hovering it shows the coordinates; dragging it moves the bar.
  dial = CreateFrame("Button", nil, frame)
  dial:SetSize(style.dial.size, style.dial.size)
  dial:SetPoint("TOP", frame, "BOTTOM", 0, -style.dial.gap)
  dial:RegisterForDrag("LeftButton")
  dial.face = dial:CreateTexture(nil, "ARTWORK")
  dial.face:SetAllPoints()
  dial.face:SetTexture(style.textures.dial)
  needle = dial:CreateTexture(nil, "OVERLAY")
  needle:SetAllPoints()
  needle:SetTexture(style.textures.needle)
  dial:SetScript("OnEnter", showCoordinates)
  dial:SetScript("OnLeave", function() GameTooltip:Hide() end)
  dial:SetScript("OnDragStart", function() if not db.locked then frame:StartMoving() end end)
  dial:SetScript("OnDragStop", function() frame:StopMovingOrSizing() savePosition() end)

  -- Caption above the bar: a dark plate with a gold trim, the headline (name and distance) and the description.
  local cap = style.caption
  captionPlate = frame:CreateTexture(nil, "BACKGROUND")
  captionPlate:SetColorTexture(unpack(c.captionPlate))
  captionPlate:SetPoint("BOTTOM", frame, "TOP", 0, cap.gap)
  captionPlate:SetSize(cap.minWidth, 20)
  captionPlate:Hide()
  captionTrim = frame:CreateTexture(nil, "BORDER")
  captionTrim:SetColorTexture(unpack(c.gold))
  captionTrim:SetHeight(1)
  captionTrim:SetPoint("TOPLEFT", captionPlate, "TOPLEFT")
  captionTrim:SetPoint("TOPRIGHT", captionPlate, "TOPRIGHT")
  captionTrim:Hide()

  targetText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  styleText(targetText, cap.headSize)
  targetText:SetPoint("TOP", captionPlate, "TOP", 0, -cap.padY)
  targetText:SetTextColor(unpack(c.cream))

  detailText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  styleText(detailText, cap.detailSize)
  detailText:SetPoint("TOP", targetText, "BOTTOM", 0, -cap.lineGap)
  detailText:SetTextColor(unpack(c.detail))

  C.parts = { frame = frame, dial = dial, needle = needle, targetText = targetText, detailText = detailText,
    captionPlate = captionPlate, ticks = ticks, labels = labels, markers = markers,
    capLeft = capLeft, capRight = capRight }

  for i = 1, layout.TICK_COUNT do
    local t = frame:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(unpack(c.cream))
    ticks[i] = t
  end
  for h, name in pairs(layout.NAMES) do
    -- Outline and shadow make the directions stand out against the band and the scenery behind it.
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    styleText(fs, style.labelSize)
    fs:SetText(name)
    fs:SetTextColor(unpack(h == 0 and c.north or c.cream))
    labels[h] = fs
  end
end

local function hideScale()
  for _, t in pairs(ticks) do t:Hide() end
  for _, fs in pairs(labels) do fs:Hide() end
end

local function hideMarkers(from)
  for i = from, #markers do markers[i]:Hide() end
end

local function applyScale(heading)
  local tickDefs, labelDefs = layout.scale(heading, db.fov, db.width)
  for i, t in pairs(ticks) do
    local def = tickDefs[i]
    if def then
      t:SetSize(1, def.height)
      t:SetAlpha(def.alpha)
      t:ClearAllPoints()
      t:SetPoint("BOTTOM", frame, "BOTTOM", def.x, ns.compassStyle.band.shadow + 1)
      t:Show()
    else
      t:Hide()
    end
  end
  for h, fs in pairs(labels) do
    local def = labelDefs[h]
    if def then
      fs:ClearAllPoints()
      fs:SetPoint("CENTER", frame, "CENTER", def.x, 0)
      fs:Show()
    else
      fs:Hide()
    end
  end
end

-- The needle points to due north. Facing grows counter-clockwise and a texture rotates
-- counter-clockwise, so turning left (facing up) must turn the needle right: rotation = -facing.
local function pointNeedle(facing)
  local rotation = facing and -facing or 0
  if lastRotation and math.abs(rotation - lastRotation) < 0.002 then return end
  lastRotation = rotation
  needle:SetRotation(rotation)
end

function C.Update()
  if not frame:IsShown() then return end
  local facing = ns.client.facing()
  pointNeedle(facing)
  if not facing then
    hideScale()
    hideMarkers(1)
    setCaption(nil)
    return
  end

  applyScale(ns.geometry.heading(facing))

  local placements, label = layout.markers(ns:Sorted(), db.fov, db.width, layout.MAX_MARKERS, ns.focus, ns.compassStyle.marker)
  for i, p in ipairs(placements) do
    local m = marker(i)
    m.uid = p.wp.uid
    m.tex:SetTexture(ns.ICONS[p.wp.icon] or ns.ICONS[ns.DEFAULT_ICON])
    m:ClearAllPoints()
    m:SetPoint("CENTER", frame, "CENTER", p.x, 0)
    m:SetAlpha(p.edge and ns.compassStyle.marker.edgeAlpha or 1)
    -- Outside the view: hold the marker near the end of the bar with an arrow pointing that way.
    -- The arrow image points right; the left end flips it.
    m.arrow:ClearAllPoints()
    if p.side == "left" then
      m.arrow:SetPoint("RIGHT", m, "LEFT", -1, 0)
      m.arrow:SetTexCoord(1, 0, 0, 1)
      m.arrow:Show()
    elseif p.side == "right" then
      m.arrow:SetPoint("LEFT", m, "RIGHT", 1, 0)
      m.arrow:SetTexCoord(0, 1, 0, 1)
      m.arrow:Show()
    else
      m.arrow:Hide()
    end
    -- Closer waypoints are drawn larger (up to taller than the ribbon), far ones small.
    m:SetSize(p.size, p.size)
    m:SetFrameLevel(frame:GetFrameLevel() + 2 + (layout.MAX_MARKERS - i) + (p.focused and layout.MAX_MARKERS + 1 or 0))
    m:Show()
  end
  hideMarkers(#placements + 1)
  setCaption(label)
end

-- Keep the dial's tooltip live while it is hovered.
function C.UpdateTooltip()
  if frame:IsShown() and GameTooltip:IsOwned(dial) then showCoordinates(dial) end
end

-- Slash command: /ribbon compass ...
ns.commands.compass = function(args)
  local sub, value = string.match(args or "", "^(%S*)%s*(.-)$")
  sub = string.lower(sub or "")
  if sub == "show" then db.shown = true
  elseif sub == "hide" then db.shown = false
  elseif sub == "toggle" or sub == "" then db.shown = not db.shown
  elseif sub == "lock" then db.locked = true
  elseif sub == "unlock" then db.locked = false
  elseif sub == "width" and tonumber(value) then db.width = tonumber(value)
  elseif sub == "fov" and tonumber(value) then db.fov = tonumber(value)
  elseif sub == "opacity" and tonumber(value) then db.opacity = tonumber(value) / 100   -- given as a percentage
  elseif sub == "reset" then
    for k, v in pairs(ns.defaults.compass) do db[k] = v end
  else
    ns:Print("usage: /ribbon compass [show|hide|toggle|lock|unlock|reset|width <500-800>|fov <90-180>|opacity <20-100>]")
    return
  end
  C.Apply()
end

ns:On("INIT", function()
  layout = ns.compassLayout
  db = ns.db.compass
  build()
  C.Apply()
  ns:Every(0.033, C.Update)
  ns:Every(0.1, C.UpdateTooltip)
end)
