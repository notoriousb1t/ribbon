-- Map wiring: real pin frames, HereBeDragons-Pins lookup and the world-map Clear button.
-- Pin bookkeeping lives in map/PinManager.lua.
local ADDON, ns = ...

local M = {}
ns.map = M

local function showTooltip(self)
  local wp = ns:GetWaypoint(self.uid)
  if not wp then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(wp.title)
  for _, line in ipairs(wp.description or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
  if wp.lines then
    for _, line in ipairs(wp.lines) do GameTooltip:AddLine(tostring(line), 1, 1, 1) end
  end
  if wp.dist then GameTooltip:AddLine(string.format("%d yd", wp.dist), 0.7, 0.7, 0.7) end
  GameTooltip:AddLine("Right-click to hide", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local SIZES = { world = 18, mini = 14 }

-- Pin factory: a button with an icon texture, Configure(uid, texture) and Hide().
local function createPin(kind)
  local f = CreateFrame("Button", nil, UIParent)
  f:SetSize(SIZES[kind], SIZES[kind])
  f:RegisterForClicks("RightButtonUp")
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetAllPoints()
  f.Configure = function(self, uid, texture)
    self.uid = uid
    self.tex:SetTexture(texture)
  end
  f:SetScript("OnEnter", showTooltip)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f:SetScript("OnClick", function(self)
    GameTooltip:Hide()
    ns:SetWaypointVisible(self.uid, false)
  end)
  return f
end

M.createPin = createPin

local function createClearButton()
  if M.clearButton or not WorldMapFrame then return end
  local b = CreateFrame("Button", "RibbonClearPinsButton", WorldMapFrame, "UIPanelButtonTemplate")
  b:SetSize(90, 20)
  b:SetText("Clear Pins")
  b:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -130, -4)
  b:SetFrameStrata("HIGH")
  b:SetScript("OnClick", function() ns:HideAll() end)
  M.clearButton = b
end

-- The guide button: a blue version of the map's own quest log toggle, stacked just above it (or in the map's bottom
-- right corner when that toggle cannot be found), shown once a guide is installed. It opens and closes the guide panel.
local function createGuideButton()
  if M.guideButton or not WorldMapFrame or not ns.guide then return end
  local style = ns.compassStyle
  local look = style.toggle
  local b = CreateFrame("Button", "RibbonGuideMapButton", WorldMapFrame)
  b:SetSize(look.width, look.height)
  local toggle = WorldMapFrame.SidePanelToggle
  if type(toggle) == "table" and toggle.GetObjectType then
    b:SetPoint("BOTTOM", toggle, "TOP", 0, 6)
  else
    b:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -10, 40)
  end
  -- No strata of its own: a fixed one can put it behind the map frame. A high level keeps it over the map's art.
  b:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 100)
  b.bezel = b:CreateTexture(nil, "BACKGROUND")
  b.bezel:SetTexture(style.textures.panelToggle)
  b.bezel:SetTexCoord(0, 1, look.rows[1], look.rows[2])
  b.bezel:SetAllPoints()
  -- The caret points the way the panel will move: left to bring it out, right to put it away.
  b.caret = b:CreateTexture(nil, "ARTWORK")
  b.caret:SetTexture(style.textures.panelCaret)
  b.caret:SetSize(look.caret, look.caret)
  b.caret:SetPoint("LEFT", b, "LEFT", 6, 0)
  -- The middle of the compass: its needle.
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexture(style.textures.needle)
  b.icon:SetSize(look.icon, look.icon)
  b.icon:SetPoint("RIGHT", b, "RIGHT", -4, 0)
  b.setOpen = function(open)
    if open then b.caret:SetTexCoord(1, 0, 0, 1) else b.caret:SetTexCoord(0, 1, 0, 1) end
  end
  b.setOpen(false)
  b:SetHighlightTexture(style.textures.panelToggle, "ADD")
  local hl = b:GetHighlightTexture()
  if hl then hl:SetTexCoord(0, 1, look.rows[1], look.rows[2]) end
  b:SetScript("OnClick", function() ns.guideBrowser.toggleDock() end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(ns.guide and ns.guide.title or "Guide")
    GameTooltip:AddLine("Chapters and progress", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  M.guideButton = b
  local dock = ns.guideBrowser and ns.guideBrowser.dock()
  b.setOpen(dock and dock:IsShown() and true or false)
end

ns:On("GUIDE_DOCK_CHANGED", function(shown)
  if M.guideButton then M.guideButton.setOpen(shown and true or false) end
end)

-- The map's own quest log panel and the guide panel take turns: opening one closes the other. The names are the
-- retail map's (the toggle's CloseButton, QuestMapFrame); anything missing is skipped, never an error.
local function blizzardToggle()
  local t = WorldMapFrame and WorldMapFrame.SidePanelToggle
  if type(t) == "table" and t.GetObjectType then return t end
end

-- Close the map's quest log panel if it is open; true when it was.
function M.collapseQuestLog()
  local toggle = blizzardToggle()
  local close = toggle and toggle.CloseButton
  local open = _G.QuestMapFrame and _G.QuestMapFrame.IsShown and _G.QuestMapFrame:IsShown()
  if not open then return false end
  M.collapsing = true
  local ok = false
  if close and close.Click then ok = pcall(close.Click, close) end
  if not ok and WorldMapFrame.HandleUserActionToggleSidePanel then
    ok = pcall(WorldMapFrame.HandleUserActionToggleSidePanel, WorldMapFrame)
  end
  M.collapsing = false
  return ok
end

-- When the map's quest log panel opens, put the guide panel away.
local function questLogOpened()
  if M.collapsing then return end
  local dock = ns.guideBrowser and ns.guideBrowser.dock()
  if dock and dock:IsShown() then ns.guideBrowser.setDock(false) end
end

function M.linkQuestLog()
  local qmf = _G.QuestMapFrame
  if type(qmf) == "table" and qmf.HookScript and not qmf.ribbonLinked then
    qmf.ribbonLinked = true
    pcall(qmf.HookScript, qmf, "OnShow", questLogOpened)
  end
  local toggle = blizzardToggle()
  local open = toggle and toggle.OpenButton
  if type(open) == "table" and open.HookScript and not open.ribbonLinked then
    open.ribbonLinked = true
    pcall(open.HookScript, open, "OnClick", questLogOpened)
  end
end

M.createGuideButton = createGuideButton

-- The map header buttons. The world map is load-on-demand on some clients, so wait for it.
local function createButtons()
  createClearButton()
  createGuideButton()
  M.linkQuestLog()
end

ns:On("INIT", function()
  if WorldMapFrame then
    createButtons()
  else
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("ADDON_LOADED")
    waiter:SetScript("OnEvent", function(self)
      if WorldMapFrame then
        createButtons()
        self:UnregisterAllEvents()
      end
    end)
  end
end)
ns:On("GUIDE_REGISTERED", createGuideButton)

ns:On("INIT", function()
  local lib = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
  if not lib then
    ns:Print("map pins disabled: the bundled HereBeDragons-Pins-2.0 did not load.")
    return
  end

  local manager = ns.PinManager.new({
    pins = lib, ref = ns, factory = { create = createPin },
    icons = ns.ICONS, defaultIcon = ns.DEFAULT_ICON, worldFlag = _G.HBD_PINS_WORLDMAP_SHOW_CONTINENT,
  })
  M.manager = manager

  ns:On("WAYPOINT_ADDED", function(wp) manager:refresh(wp) end)
  ns:On("WAYPOINT_CHANGED", function(wp) manager:refresh(wp) end)
  ns:On("WAYPOINT_REMOVED", function(wp) manager:remove(wp) end)
  manager:resync(ns.waypoints)
end)
