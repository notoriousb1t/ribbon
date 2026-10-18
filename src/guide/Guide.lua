-- Guide tracking frame view: applies the rows computed by guide/Rows.lua.
-- Providers set a header through ns.Guide:SetHeader.
local ADDON, ns = ...

local G = {}
ns.Guide = G

local ROWS = 6
local ROW_HEIGHT = 18
local WIDTH = 240

local db, frame, header
local rows = {}

function G:SetHeader(text)
  self.header = text
end

local function savePosition()
  local point, _, relPoint, x, y = frame:GetPoint()
  db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
end

local function buildRow(i)
  local r = CreateFrame("Button", nil, frame)
  r:SetHeight(ROW_HEIGHT)
  r:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -22 - (i - 1) * ROW_HEIGHT)
  r:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -22 - (i - 1) * ROW_HEIGHT)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(14, 14)
  r.icon:SetPoint("LEFT")
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
  r.name:SetPoint("RIGHT", r, "RIGHT", -52, 0)
  r.name:SetJustifyH("LEFT")
  r.dist = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.dist:SetPoint("RIGHT")
  r.hl = r:CreateTexture(nil, "BACKGROUND")
  r.hl:SetAllPoints()
  r.hl:SetColorTexture(1, 1, 1, 0.12)
  r.hl:Hide()
  r:SetScript("OnClick", function(self, button)
    if not self.uid then return end
    if button == "RightButton" then
      ns:SetWaypointVisible(self.uid, false)
    else
      ns:SetFocus(ns.focus ~= self.uid and self.uid or nil)
    end
  end)
  return r
end

local function build()
  frame = CreateFrame("Frame", "RibbonGuide", UIParent)
  frame:SetSize(WIDTH, 24 + ROWS * ROW_HEIGHT)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() savePosition() end)

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.5)

  header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", 8, -5)
  header:SetPoint("TOPRIGHT", -8, -5)
  header:SetJustifyH("LEFT")

  for i = 1, ROWS do rows[i] = buildRow(i) end
  G.parts = { frame = frame, header = header, rows = rows }

  frame:ClearAllPoints()
  frame:SetPoint(db.point or "TOPLEFT", UIParent, db.relPoint or db.point or "TOPLEFT", db.x or 20, db.y or -200)
end

function G.Update()
  local list = ns:Sorted()
  local show = ns.guideRows.shouldShow(db.shown, #list, G.header)
  frame:SetShown(show)
  if not show then return end

  header:SetText(G.header or "Waypoints")
  local descriptors = ns.guideRows.build(list, ROWS, ns.focus)
  for i = 1, ROWS do
    local r, d = rows[i], descriptors[i]
    if d then
      r.uid = d.uid
      r.icon:SetTexture(ns.ICONS[d.icon] or ns.ICONS[ns.DEFAULT_ICON])
      r.name:SetText(d.title)
      r.dist:SetText(d.distance)
      r.hl:SetShown(d.focused)
      r:Show()
    else
      r.uid = nil
      r:Hide()
    end
  end
end

ns.commands.guide = function(args)
  local sub = string.lower(strtrim(args or ""))
  if sub == "show" then db.shown = true
  elseif sub == "hide" then db.shown = false
  elseif sub == "toggle" or sub == "" then db.shown = not db.shown
  else ns:Print("usage: /ribbon guide [show|hide|toggle]") return end
  G.Update()
end

ns:On("INIT", function()
  db = ns.db.guide
  build()
  ns:Every(0.2, G.Update)
end)
