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

  if WorldMapFrame then
    createClearButton()
  else
    -- World map is load-on-demand on some clients.
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("ADDON_LOADED")
    waiter:SetScript("OnEvent", function(self)
      if WorldMapFrame then
        createClearButton()
        self:UnregisterAllEvents()
      end
    end)
  end
end)
