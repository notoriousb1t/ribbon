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

local SIZES = { world = 24, mini = 18 }

-- Pin factory: a button drawn as the waypoint's badge (the same icons as the compass), Configure(uid, texture, icon) and
-- Hide().
local function createPin(kind)
  local f = CreateFrame("Button", nil, UIParent)
  f:SetSize(SIZES[kind], SIZES[kind])
  f:RegisterForClicks("RightButtonUp")
  ns.badge.build(f)
  f.Configure = function(self, uid, texture, icon)
    self.uid = uid
    ns.badge.draw(self, icon, SIZES[kind])
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
  -- No strata of its own: a fixed one can put it behind the map frame. A high level keeps it over the map's art.
  b:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 100)
  b.bezel = b:CreateTexture(nil, "BACKGROUND")
  b.bezel:SetTexture(style.textures.panelToggle)
  b.bezel:SetAllPoints()
  -- The caret points the way the panel will move: left to bring it out, right to put it away.
  b.caret = b:CreateTexture(nil, "ARTWORK")
  b.caret:SetTexture(style.textures.panelCaret)
  -- The middle of the compass: its needle.
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexture(style.textures.needle)
  b.setOpen = function(open)
    if open then b.caret:SetTexCoord(1, 0, 0, 1) else b.caret:SetTexCoord(0, 1, 0, 1) end
  end
  b.setOpen(false)
  b:SetHighlightTexture(style.textures.panelToggle, "ADD")
  b:SetScript("OnClick", function() ns.guideBrowser.toggleDock() end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(ns.guide and ns.guide.title or "Guide")
    GameTooltip:AddLine("Chapters and progress", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  M.guideButton = b
  M.alignGuideButton()
  -- The map lays itself out after it opens and when it is resized: line up again then.
  pcall(function()
    WorldMapFrame:HookScript("OnShow", M.alignGuideButton)
    WorldMapFrame:HookScript("OnSizeChanged", M.alignGuideButton)
  end)
  local dock = ns.guideBrowser and ns.guideBrowser.dock()
  b.setOpen(dock and dock:IsShown() and true or false)
end

-- Sizes the button to the map's own quest log toggle and puts it just above it, right edges level, so the two line up
-- exactly. Without that toggle (or before it has a size) the button keeps the style's size in the map's corner.
function M.alignGuideButton()
  local b = M.guideButton
  if not b then return end
  local look = ns.compassStyle.toggle
  local toggle = WorldMapFrame and WorldMapFrame.SidePanelToggle
  local w, h = look.width, look.height
  local found = type(toggle) == "table" and toggle.GetObjectType
  if found then
    local tw = toggle.GetWidth and toggle:GetWidth()
    local th = toggle.GetHeight and toggle:GetHeight()
    if type(tw) == "number" and tw > 0 and type(th) == "number" and th > 0 then w, h = tw, th end
  end
  b:SetSize(w, h)
  b:ClearAllPoints()
  if found then
    b:SetPoint("BOTTOMRIGHT", toggle, "TOPRIGHT", 0, look.gap)
  else
    b:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -10, 40)
  end
  -- The caret and the needle side by side, sized to the button.
  local side = math.min(w, h)
  local caret, icon = math.floor(side * look.caret + 0.5), math.floor(side * look.icon + 0.5)
  local inset = math.floor(side * look.inset + 0.5)
  b.caret:SetSize(caret, caret)
  b.caret:ClearAllPoints()
  b.caret:SetPoint("LEFT", b, "LEFT", inset, 0)
  b.icon:SetSize(icon, icon)
  b.icon:ClearAllPoints()
  b.icon:SetPoint("RIGHT", b, "RIGHT", -math.max(1, inset - 2), 0)
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

-- Preview ---------------------------------------------------------------------------------

local previewPin
local previewOwner = {}   -- the pin library keys icons by owner; the preview has its own

-- Takes the preview pin off the map.
function M.clearPreview()
  if previewPin and M.lib then
    M.lib:RemoveWorldMapIcon(previewOwner, previewPin)
    previewPin:Hide()
  end
end

-- Pans the map so a point (0-100) is in the middle, at the style's zoom between the smallest and the largest scale.
-- The map's scroll container is Blizzard's and its calls are not documented, so each is tried and none may fail.
local function centreOn(x, y)
  local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
  if type(sc) ~= "table" then return end
  local nx, ny = x / 100, y / 100
  local lo = sc.GetScaleForMinZoom and select(2, pcall(sc.GetScaleForMinZoom, sc))
  local hi = sc.GetScaleForMaxZoom and select(2, pcall(sc.GetScaleForMaxZoom, sc))
  local scale
  if type(lo) == "number" and type(hi) == "number" then scale = lo + (hi - lo) * ns.compassStyle.preview.zoom end
  if scale and sc.InstantPanAndZoom then
    pcall(sc.InstantPanAndZoom, sc, scale, nx, ny)
  else
    if scale and sc.SetZoomTarget then pcall(sc.SetZoomTarget, sc, scale) end
    if sc.SetPanTarget then pcall(sc.SetPanTarget, sc, nx, ny) end
  end
end

-- Shows a point of the guide on the map: switches the map to its zone, draws its icon there and centres on it. The map
-- needs a frame to lay itself out after a zone change, so the centring runs again a moment later.
function M.preview(map, x, y, icon)
  if not (WorldMapFrame and type(map) == "number" and type(x) == "number" and type(y) == "number") then return end
  M.clearPreview()
  pcall(WorldMapFrame.SetMapID, WorldMapFrame, map)
  if M.lib then
    local size = ns.compassStyle.preview.size
    if not previewPin then
      previewPin = CreateFrame("Frame", nil, UIParent)
      ns.badge.build(previewPin)
    end
    previewPin:SetSize(size, size)
    ns.badge.draw(previewPin, icon, size)
    M.lib:AddWorldMapIconMap(previewOwner, previewPin, map, x / 100, y / 100, _G.HBD_PINS_WORLDMAP_SHOW_CONTINENT)
  end
  centreOn(x, y)
  if C_Timer and C_Timer.After then C_Timer.After(0.05, function() centreOn(x, y) end) end
end

M.previewPin = function() return previewPin end

ns:On("INIT", function()
  local lib = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
  M.lib = lib
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
