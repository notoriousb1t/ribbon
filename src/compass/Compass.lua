-- Compass ribbon view: creates frames and applies the placements computed by compass/Layout.lua.
local ADDON, ns = ...

local C = {}
ns.compass = C

local deg = math.deg
local TRACK_HEIGHT = 28

local db, frame, badge, targetText
local ticks, labels, markers = {}, {}, {}
local layout

local function savePosition()
  local point, _, relPoint, x, y = frame:GetPoint()
  db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
end

function C.Apply()
  db.width = ns.geometry.clamp(tonumber(db.width) or 600, 500, 800)
  db.fov = ns.geometry.clamp(tonumber(db.fov) or 140, 90, 180)
  frame:SetSize(db.width, TRACK_HEIGHT)
  frame:ClearAllPoints()
  frame:SetPoint(db.point or "TOP", UIParent, db.relPoint or db.point or "TOP", db.x or 0, db.y or -40)
  frame:SetShown(db.shown and true or false)
end

local function showTooltip(self)
  local wp = ns:GetWaypoint(self.uid)
  if not wp then return end
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:SetText(wp.title)
  if wp.lines then
    for _, line in ipairs(wp.lines) do GameTooltip:AddLine(tostring(line), 1, 1, 1) end
  end
  if wp.dist then GameTooltip:AddLine(string.format("%d yd", wp.dist), 0.7, 0.7, 0.7) end
  GameTooltip:AddLine("Right-click to hide", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function marker(i)
  local m = markers[i]
  if m then return m end
  m = CreateFrame("Button", nil, frame)
  m:SetSize(20, 20)
  m:RegisterForClicks("RightButtonUp")
  m.tex = m:CreateTexture(nil, "ARTWORK")
  m.tex:SetAllPoints()
  m:SetScript("OnEnter", showTooltip)
  m:SetScript("OnLeave", function() GameTooltip:Hide() end)
  m:SetScript("OnClick", function(self)
    GameTooltip:Hide()
    ns:SetWaypointVisible(self.uid, false)
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

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.55)

  local notch = frame:CreateTexture(nil, "OVERLAY")
  notch:SetColorTexture(1, 1, 1, 0.9)
  notch:SetSize(2, TRACK_HEIGHT + 8)
  notch:SetPoint("CENTER")

  badge = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  badge:SetPoint("BOTTOM", frame, "TOP", 0, 6)

  targetText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  targetText:SetPoint("TOP", frame, "BOTTOM", 0, -4)

  C.parts = { frame = frame, badge = badge, targetText = targetText, ticks = ticks, labels = labels, markers = markers }

  for i = 1, layout.TICK_COUNT do
    local t = frame:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 1)
    ticks[i] = t
  end
  for h, name in pairs(layout.NAMES) do
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetText(name)
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
      t:SetPoint("BOTTOM", frame, "BOTTOM", def.x, 1)
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

function C.Update()
  if not frame:IsShown() then return end
  local facing = ns.client.facing()
  if not facing then
    hideScale()
    hideMarkers(1)
    targetText:SetText("")
    return
  end

  applyScale(ns.geometry.heading(facing))

  local placements, label = layout.markers(ns:Sorted(), db.fov, db.width, layout.MAX_MARKERS, ns.focus)
  for i, p in ipairs(placements) do
    local m = marker(i)
    m.uid = p.wp.uid
    m.tex:SetTexture(ns.ICONS[p.wp.icon] or ns.ICONS[ns.DEFAULT_ICON])
    m:ClearAllPoints()
    m:SetPoint("CENTER", frame, "CENTER", p.x, 0)
    m:SetAlpha(p.edge and 0.5 or 1)
    m:SetFrameLevel(frame:GetFrameLevel() + 2 + (layout.MAX_MARKERS - i))
    m:Show()
  end
  hideMarkers(#placements + 1)
  targetText:SetText(layout.targetText(label))
end

function C.UpdateBadge()
  if not frame:IsShown() then return end
  local _, x, y = ns.client.playerMapPosition()
  badge:SetText(layout.coordsText(x, y))
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
  elseif sub == "reset" then
    for k, v in pairs(ns.defaults.compass) do db[k] = v end
  else
    ns:Print("usage: /ribbon compass [show|hide|toggle|lock|unlock|reset|width <500-800>|fov <90-180>]")
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
  ns:Every(0.1, C.UpdateBadge)
end)
