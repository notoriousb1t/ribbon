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
  local b = CreateFrame("Button", "RibbonGuideMapButton", WorldMapFrame)
  b:SetSize(32, 32)
  local toggle = WorldMapFrame.SidePanelToggle
  if type(toggle) == "table" and toggle.GetObjectType then
    b:SetPoint("BOTTOM", toggle, "TOP", 0, 6)
  else
    b:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -10, 40)
  end
  -- No strata of its own: a fixed one can put it behind the map frame. A high level keeps it over the map's art.
  b:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 100)
  b.bezel = b:CreateTexture(nil, "BACKGROUND")
  b.bezel:SetTexture(style.textures.bezelButton)
  b.bezel:SetAllPoints()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(20, 20)
  b.icon:SetPoint("CENTER")
  b.icon:SetTexture([[Interface\AddOns\Ribbon\icon]])
  -- While the panel is open the button wears the bright blue of a selection.
  b.active = b:CreateTexture(nil, "OVERLAY")
  b.active:SetTexture(style.textures.focusRing)
  b.active:SetVertexColor(unpack(style.focusRing.color))
  b.active:SetPoint("CENTER")
  b.active:SetSize(36, 36)
  b.active:Hide()
  b:SetHighlightTexture(style.textures.bezelButton, "ADD")
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
  b.active:SetShown(dock and dock:IsShown() and true or false)
end

ns:On("GUIDE_DOCK_CHANGED", function(shown)
  if M.guideButton then M.guideButton.active:SetShown(shown and true or false) end
end)

M.createGuideButton = createGuideButton

-- The map header buttons. The world map is load-on-demand on some clients, so wait for it.
local function createButtons()
  createClearButton()
  createGuideButton()
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
