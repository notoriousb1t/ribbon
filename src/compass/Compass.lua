-- Compass ribbon view: creates frames and applies the placements computed by compass/Layout.lua.
local ADDON, ns = ...

local C = {}
ns.compass = C

local deg = math.deg
local TRACK_HEIGHT = 28

local db, frame, dial, needle, targetText, detailText, captionPlate, captionTrim, captionIcon, combatBar
local lastRotation, lastCombat
local chrome = {}
local ticks, labels, markers = {}, {}, {}
local settled = {}   -- uid -> the calmed x the marker was last drawn at (Layout.settle)
local layout

local styleText = ns.badge.styleText   -- outlined, shadowed text that stays readable over any background

-- Show the caption for a waypoint (or clear it): headline, up to two description lines, and a plate
-- sized to fit the text.
local function setCaption(wp)
  local head = layout.targetText(wp)
  local details = table.concat(layout.details(wp), "\n")
  targetText:SetText(head)
  detailText:SetText(details)
  if head == "" then
    captionPlate:Hide()
    captionTrim.Hide()
    captionIcon:Hide()
    return
  end
  local cap = ns.compassStyle.caption
  -- Lines are kept to about the length of the guide panel's (cap.maxWidth): a longer one wraps, and the plate is as wide
  -- as the widest line that results.
  local headWidth = math.min(targetText:GetStringWidth() or 0, cap.maxWidth)
  local detailWidth = details ~= "" and math.min(detailText:GetStringWidth() or 0, cap.maxWidth) or 0
  targetText:SetWidth(headWidth + 2)
  detailText:SetWidth(math.max(detailWidth, 1) + 2)
  local width = math.max(headWidth, detailWidth)
  local height = (targetText:GetStringHeight() or cap.headSize) + cap.padY * 2
  if details ~= "" then height = height + cap.lineGap + (detailText:GetStringHeight() or cap.detailSize) end
  -- The step's badge at the left, the text shifted over to make room for it.
  local lead = 0
  if wp and wp.icon then
    lead = cap.iconSize + cap.iconGap
    if wp.uid ~= nil and wp.uid == ns.focus then
      ns.badge.drawFitted(captionIcon, wp.icon, cap.iconSize)
    else
      ns.badge.draw(captionIcon, wp.icon, cap.iconSize, false)
    end
    captionIcon:Show()
  else
    captionIcon:Hide()
  end
  targetText:ClearAllPoints()
  targetText:SetPoint("TOP", captionPlate, "TOP", lead / 2, -cap.padY)
  captionPlate:SetSize(math.max(width + lead + cap.padX * 2, cap.minWidth), height)
  captionPlate:Show()
  captionTrim.Show()
end

-- The caption and the yards go below the ribbon while it sits in the upper half of the screen and above it in the
-- lower half, so they never run off the screen edge. Unknown positions keep them above.
local below = false

local function overhang()
  return math.max(0, (ns.compassStyle.dial.size - TRACK_HEIGHT) / 2)
end

local function sideIsBelow()
  if not (frame and frame.GetCenter and UIParent and UIParent.GetHeight) then return false end
  local _, cy = frame:GetCenter()
  local screenH = UIParent:GetHeight()
  if type(cy) ~= "number" or type(screenH) ~= "number" or screenH <= 0 then return false end
  local fs, ps = frame.GetEffectiveScale and frame:GetEffectiveScale(), UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
  local ratio = (type(fs) == "number" and type(ps) == "number" and ps > 0) and fs / ps or 1
  return cy * ratio > screenH / 2
end

-- Anchors the caption plate on the chosen side, clear of the row of yards.
local function placeCaption()
  local style = ns.compassStyle
  local off = style.caption.gap + overhang() + style.distance.height
  captionPlate:ClearAllPoints()
  if below then
    captionPlate:SetPoint("TOP", frame, "BOTTOM", 0, -off)
  else
    captionPlate:SetPoint("BOTTOM", frame, "TOP", 0, off)
  end
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
  local dialOpacity = ns.compassStyle.dialOpacity
  db.dialOpacity = ns.geometry.clamp(tonumber(db.dialOpacity) or dialOpacity.default, dialOpacity.min, dialOpacity.max)
  for _, texture in ipairs(chrome) do texture:SetAlpha(db.opacity) end
  dial.face:SetAlpha(db.dialOpacity)
  frame:SetSize(db.width, TRACK_HEIGHT)
  frame:ClearAllPoints()
  frame:SetPoint(db.point or "TOP", UIParent, db.relPoint or db.point or "TOP", db.x or 0, db.y or -16)
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
  ns.badge.build(m)   -- the icon: its symbol, with a ring while it is the tracked waypoint
  -- For a waypoint outside the view: an arrow beside the marker, pointing the way to turn.
  local arrowSize = ns.compassStyle.marker.arrow
  m.arrow = m:CreateTexture(nil, "OVERLAY")
  m.arrow:SetTexture(ns.compassStyle.textures.edgeArrow)
  m.arrow:SetSize(arrowSize, arrowSize)
  m.arrow:Hide()
  -- The distance, in a row above the bar (placed with the marker in Update).
  m.dist = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  styleText(m.dist, ns.compassStyle.distance.size)
  m.dist:SetTextColor(unpack(ns.compassStyle.colors.cream))
  m.dist:Hide()
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

-- The caption's edge, like the guide panel's section headers in the quest log: a fine gold line along the top and the
-- bottom of the plate. Returns an object with Show and Hide.
local function trim(owner, region)
  local gold = ns.compassStyle.caption.edge
  local lines = {}
  for _, side in ipairs({ "TOP", "BOTTOM" }) do
    local t = owner:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(gold))
    t:SetHeight(1)
    t:SetPoint(side .. "LEFT", region, side .. "LEFT")
    t:SetPoint(side .. "RIGHT", region, side .. "RIGHT")
    lines[#lines + 1] = t
  end
  local edge = {}
  function edge.Show() for _, t in ipairs(lines) do t:Show() end end
  function edge.Hide() for _, t in ipairs(lines) do t:Hide() end end
  return edge
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

  -- The ribbon itself can be made see-through; text, ticks, markers and the caption plate stay opaque so they
  -- remain easy to read.
  chrome = { bg, highlight, shadow }


  -- The compass: a dial under the bar with a needle that always points to due north.
  -- Hovering it shows the coordinates; dragging it moves the bar.
  dial = CreateFrame("Button", nil, frame)
  dial:SetSize(style.dial.size, style.dial.size)
  dial:SetPoint("CENTER", frame, "CENTER", 0, style.dial.offsetY)
  dial:SetFrameLevel(frame:GetFrameLevel() + 1)   -- over the ticks and direction names; the markers (+3 and up) pass over it
  dial:RegisterForDrag("LeftButton")
  dial.face = dial:CreateTexture(nil, "ARTWORK")
  dial.face:SetAllPoints()
  dial.face:SetTexture(style.textures.dial)
  -- Combat cue: a red ring laid over the dial's gold one while the player is in combat.
  combatBar = dial:CreateTexture(nil, "ARTWORK", nil, 1)
  combatBar:SetAllPoints()
  combatBar:SetTexture(style.textures.markerRim)
  combatBar:SetVertexColor(unpack(c.combat))
  combatBar:Hide()
  needle = dial:CreateTexture(nil, "OVERLAY")
  needle:SetAllPoints()
  needle:SetTexture(style.textures.needle)
  dial:SetScript("OnEnter", showCoordinates)
  dial:SetScript("OnLeave", function() GameTooltip:Hide() end)
  dial:SetScript("OnDragStart", function()
    if not db.locked then frame:StartMoving() end
  end)
  dial:SetScript("OnDragStop", function() frame:StopMovingOrSizing() savePosition() end)

  -- Caption above the bar: a dark warm plate like the quest log's, fine gold lines top and bottom, the headline (name and distance) and the description.
  local cap = style.caption
  captionPlate = frame:CreateTexture(nil, "BACKGROUND")
  captionPlate:SetColorTexture(unpack(c.captionPlate))
  placeCaption()
  captionPlate:SetSize(cap.minWidth, 20)
  captionPlate:Hide()
  captionIcon = CreateFrame("Frame", nil, frame)
  captionIcon:SetSize(cap.iconSize, cap.iconSize)
  ns.badge.build(captionIcon)
  captionIcon:SetPoint("LEFT", captionPlate, "LEFT", cap.padX, 0)
  captionIcon:Hide()
  captionTrim = trim(frame, captionPlate)
  captionTrim.Hide()

  -- The caption uses the game's quest fonts (shadowed, no outline), like the quest log's titles and objectives.
  targetText = frame:CreateFontString(nil, "OVERLAY", ns.badge.fontObject("QuestFont", "GameFontNormal"))
  targetText:SetPoint("TOP", captionPlate, "TOP", 0, -cap.padY)
  targetText:SetTextColor(unpack(c.heading))

  detailText = frame:CreateFontString(nil, "OVERLAY", ns.badge.fontObject("QuestFontNormalSmall", "GameFontHighlightSmall"))
  detailText:SetPoint("TOP", targetText, "BOTTOM", 0, -cap.lineGap)
  detailText:SetTextColor(unpack(c.detail))

  C.parts = { frame = frame, dial = dial, needle = needle, targetText = targetText, detailText = detailText,
    captionPlate = captionPlate, captionIcon = captionIcon, ticks = ticks, labels = labels, markers = markers, combatBar = combatBar,
  }

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
  local clear = ns.compassStyle.dial.size / 2   -- ticks under the dial stay hidden, whatever its opacity
  for i, t in pairs(ticks) do
    local def = tickDefs[i]
    if def and math.abs(def.x) >= clear then
      t:SetSize(1, def.height)
      t:SetAlpha(def.alpha)
      t:ClearAllPoints()
      t:SetPoint("BOTTOM", frame, "BOTTOM", math.floor(def.x + 0.5), ns.compassStyle.band.shadow + 1)
      t:Show()
    else
      t:Hide()
    end
  end
  for h, fs in pairs(labels) do
    local def = labelDefs[h]
    -- Direction names go under the dial like the ticks: one under it is hidden, not shown through it.
    if def and math.abs(def.x) >= clear then
      fs:ClearAllPoints()
      fs:SetPoint("CENTER", frame, "CENTER", math.floor(def.x + 0.5), 0)
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
  -- The ring on the dial: white when dead, soft red in combat, off otherwise.
  local alert = ns.client.isDead() and "dead" or (ns.client.inCombat() and "combat" or false)
  if alert ~= lastCombat then
    lastCombat = alert
    local c = ns.compassStyle.colors
    combatBar:SetVertexColor(unpack(alert == "dead" and c.dead or c.combat))
    combatBar:SetShown(alert ~= false)
  end
  local facing = ns.client.facing()
  pointNeedle(facing)
  if not facing then
    hideScale()
    hideMarkers(1)
    setCaption(nil)
    return
  end

  applyScale(ns.geometry.heading(facing))

  local side = sideIsBelow()
  if side ~= below then
    below = side
    placeCaption()
  end

  local placements, label = layout.markers(ns:Sorted(), db.fov, db.width, layout.MAX_MARKERS, ns.focus, ns.compassStyle.marker)
  local seen = {}
  for i, p in ipairs(placements) do
    local m = marker(i)
    m.uid = p.wp.uid
    -- A marker at the end of the bar is already still; the rest are calmed.
    local uid = p.wp.uid
    seen[uid] = true
    if p.edge then
      settled[uid] = nil
    else
      p.x, settled[uid] = layout.settle(settled[uid], p.x, ns.compassStyle.marker.smooth)
    end
    if p.focused then
      ns.badge.drawFitted(m, p.wp.icon, p.size)   -- the diamond is p.size across, so it stays inside the band
    else
      ns.badge.draw(m, p.wp.icon, p.size, false)
    end
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
    local dist = p.wp.dist
    if type(dist) == "number" then
      local d = ns.compassStyle.distance
      m.dist:ClearAllPoints()
      if below then
        m.dist:SetPoint("TOP", frame, "BOTTOM", p.x, -(d.gap + overhang()))
      else
        m.dist:SetPoint("BOTTOM", frame, "TOP", p.x, d.gap + overhang())
      end
      m.dist:SetText(string.format("%d yd", dist))
      m.dist:Show()
    else
      m.dist:Hide()
    end
    m:SetFrameLevel(frame:GetFrameLevel() + 2 + p.level)
    m:Show()
  end
  for uid in pairs(settled) do
    if not seen[uid] then settled[uid] = nil end
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
  elseif sub == "dial" and tonumber(value) then db.dialOpacity = tonumber(value) / 100
  elseif sub == "reset" then
    for k, v in pairs(ns.defaults.compass) do db[k] = v end
  else
    ns:Print("usage: /ribbon compass [show|hide|toggle|lock|unlock|reset|width <500-800>|fov <90-180>|opacity <20-100>|dial <20-100>]")
    return
  end
  C.Apply()
end

ns:On("INIT", function()
  layout = ns.compassLayout
  db = ns.db.compass
  -- One-time move from the old ribbon default to the new one, for players who never changed it.
  if db.opacity == ns.compassStyle.oldOpacityDefault and not db.opacityMigrated then db.opacity = ns.compassStyle.opacity.default end
  db.opacityMigrated = true
  build()
  C.Apply()
  ns:Every(0.033, C.Update)
  ns:Every(0.1, C.UpdateTooltip)
end)
