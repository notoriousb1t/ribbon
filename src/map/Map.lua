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

-- Pin sizes and the tracked ring's pad: about the player's arrow (Style.pins).
local function sizes() return ns.compassStyle.pins end

-- Every pin made, so the tracked ring follows the focus.
local allPins = {}

ns:On("FOCUS_CHANGED", function(uid)
  for _, pin in ipairs(allPins) do
    if pin.uid and pin.icon and pin:IsShown() then
      ns.badge.draw(pin, pin.icon, pin:GetWidth() or sizes().world, pin.uid == uid, pin.ringPad)
    end
  end
end)

-- Pin factory: a button drawn as the waypoint's symbol, without the badge's circle (the same icons as the compass), Configure(uid, texture, icon) and
-- Hide().
local function createPin(kind)
  local f = CreateFrame("Button", nil, UIParent)
  f:SetSize(sizes()[kind], sizes()[kind])
  f.ringPad = kind == "world" and sizes().worldRingPad or sizes().ringPad
  f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  ns.badge.build(f)
  f.Configure = function(self, uid, texture, icon)
    self.uid = uid
    self.icon = icon
    ns.badge.draw(self, icon, sizes()[kind], ns.focus == uid, self.ringPad)
  end
  allPins[#allPins + 1] = f
  f:SetScript("OnEnter", showTooltip)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Left click focuses the step's point on the compass; right click hides the pin.
  f:SetScript("OnClick", function(self, button)
    GameTooltip:Hide()
    if button == "RightButton" then
      ns:SetWaypointVisible(self.uid, false)
    else
      ns:SetFocus(self.uid)
    end
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
  b.icon:SetTexture(style.textures.panelNeedle)
  -- Like the map's own toggle: the caret points left while the panel is out and right while it is put away.
  b.setOpen = function(open)
    if open then b.caret:SetTexCoord(0, 1, 0, 1) else b.caret:SetTexCoord(1, 0, 0, 1) end
  end
  b.setOpen(false)
  b:SetHighlightTexture(style.textures.panelToggle, "ADD")
  b:SetScript("OnClick", function() ns.guideBrowser.toggleDock() end)
  -- The percentages are on hover.
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(ns.guide and ns.guide.title or "Guide")
    local overall, chapter, name = ns.guideBrowser.progress()
    GameTooltip:AddLine(string.format("Guide: %d%%", math.floor(overall * 100 + 0.5)), 1, 1, 1)
    if name then GameTooltip:AddLine(string.format("%s: %d%%", name, math.floor(chapter * 100 + 0.5)), 0.72, 0.84, 0.88) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  M.guideButton = b
  M.alignGuideButton()
  -- The map lays itself out after it opens and when it is resized: line up again then.
  pcall(function()
    WorldMapFrame:HookScript("OnShow", M.alignGuideButton)
    WorldMapFrame:HookScript("OnSizeChanged", M.alignGuideButton)
    -- The map settles its layout a moment after it is maximized or restored: line up again then.
    local function later() if C_Timer and C_Timer.After then C_Timer.After(0.1, M.alignGuideButton) end end
    WorldMapFrame:HookScript("OnShow", later)
    WorldMapFrame:HookScript("OnSizeChanged", later)
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
  -- Maximized, the map's toggle sits at the top right under the title bar with no room above it, so the button goes
  -- below it instead of above.
  local maximized = WorldMapFrame and WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized() and true or false
  if found and maximized then
    b:SetPoint("TOPRIGHT", toggle, "BOTTOMRIGHT", 0, -look.gap)
  elseif found then
    b:SetPoint("BOTTOMRIGHT", toggle, "TOPRIGHT", 0, look.gap)
  elseif maximized then
    b:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -10, -70)
  else
    b:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -10, 40)
  end
  -- The caret and the needle side by side, sized to the button and centred as a pair by what you see of each (the
  -- shapes do not fill their boxes the same way), not by the boxes.
  local side = math.min(w, h)
  local caret, icon = math.floor(side * look.caret + 0.5), math.floor(side * look.icon + 0.5)
  local between = side * look.between
  local caretSeen, iconSeen = caret * look.caretFill, icon * look.iconFill
  local start = (w - (caretSeen + between + iconSeen)) / 2
  b.caret:SetSize(caret, caret)
  b.caret:ClearAllPoints()
  b.caret:SetPoint("CENTER", b, "LEFT", start + caretSeen / 2, 0)
  b.icon:SetSize(icon, icon)
  b.icon:ClearAllPoints()
  b.icon:SetPoint("CENTER", b, "LEFT", start + caretSeen + between + iconSeen / 2, 0)
end

-- The guide's progress is a loader bar along the bottom of the guide panel; keep it up to date.
function M.updateProgress()
  if ns.guideBrowser then ns.guideBrowser.updateProgress() end
end

ns:On("GUIDE_STEP_CHANGED", function() M.updateProgress() end)
ns:On("GUIDE_STARTED", function() M.updateProgress() end)
ns:On("GUIDE_CHAPTER_ADDED", function() M.updateProgress() end)

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
-- `target` ({ chapter =, step = }) is the step the pin belongs to: clicking the pin makes it the player's current step,
-- in whichever chapter it is.
function M.preview(map, x, y, icon, target)
  if not (WorldMapFrame and type(map) == "number" and type(x) == "number" and type(y) == "number") then return end
  M.clearPreview()
  pcall(WorldMapFrame.SetMapID, WorldMapFrame, map)
  if M.lib then
    local size = ns.compassStyle.preview.size
    if not previewPin then
      previewPin = CreateFrame("Button", nil, UIParent)
      ns.badge.build(previewPin)
      previewPin:RegisterForClicks("LeftButtonUp")
      previewPin:SetScript("OnClick", function(self)
        local t = self.target
        if t and ns.guidePlayer then ns.guidePlayer.jump(t.chapter, t.step) end
      end)
    end
    previewPin.target = target
    previewPin:SetSize(size, size)
    ns.badge.draw(previewPin, icon, size, true, sizes().worldRingPad)   -- the step being looked at is the tracked one
    M.lib:AddWorldMapIconMap(previewOwner, previewPin, map, x / 100, y / 100, _G.HBD_PINS_WORLDMAP_SHOW_CONTINENT)
  end
  centreOn(x, y)
  if C_Timer and C_Timer.After then C_Timer.After(0.05, function() centreOn(x, y) end) end
end

M.previewPin = function() return previewPin end

-- Context pins ----------------------------------------------------------------------------

local contextPins = {}
local contextOwner = {}

local function contextPin(slot, item)
  local style = ns.compassStyle.context
  local look = style[item.mode]
  local size = math.floor(sizes().world * look.scale + 0.5)
  local pin = contextPins[slot]
  if not pin then
    pin = CreateFrame("Frame", nil, UIParent)
    ns.badge.build(pin)
    contextPins[slot] = pin
  end
  if M.lib then M.lib:RemoveWorldMapIcon(contextOwner, pin) end
  pin:SetSize(size, size)
  pin:Show()
  ns.badge.draw(pin, item.icon, size, false)
  -- The step just done is tinted (the colour in the style); the others keep their own.
  if look.color then
    local c = look.color
    pin.glyphTex:SetVertexColor(c[1], c[2], c[3], 1)
    pin.tex:SetVertexColor(c[1], c[2], c[3], 1)
  end
  pin:SetAlpha(item.alpha or look.alpha * (item.fade or 1))
  if M.lib then M.lib:AddWorldMapIconMap(contextOwner, pin, item.map, item.x / 100, item.y / 100, _G.HBD_PINS_WORLDMAP_SHOW_CONTINENT) end
  return pin
end

local function clearSlot(slot)
  local pin = contextPins[slot]
  if pin then
    if M.lib then M.lib:RemoveWorldMapIcon(contextOwner, pin) end
    pin:Hide()
  end
end

-- The step just done and the next two, around the player's current step.
function M.refreshContext()
  local player = ns.guidePlayer
  local S = player and player.state()
  local slots = { "last" }
  for n = 1, ns.compassStyle.context.count do slots[#slots + 1] = "next" .. n end
  for _, slot in ipairs(slots) do clearSlot(slot) end
  if not S or S.finished then return end
  local function show(slot, mode, offset)
    local entry = S.flat[S.cursor + offset]
    if not entry then return end
    local map, x, y = ns.guidePlanner.stepLocation(entry.step)
    if type(map) ~= "number" or type(x) ~= "number" then return end
    contextPin(slot, { mode = mode, map = map, x = x, y = y, icon = ns.guideText.stepIcon(entry.step) })
  end
  show("last", "last", -1)
  for n = 1, ns.compassStyle.context.count do show("next" .. n, "next", n) end
end

-- A step the mouse is over in the panel: its pin fully opaque, and the one before it and the one after it, a little more
-- transparent. Called with nothing to take them away.
local HOVER = { { "hoverLast", "last", -1 }, { "hover0", "next", 0 }, { "hover1", "next", 1 } }
local lines, halos = {}, {}   -- the dashes' cores and the dark halos under them
local lineDot, lineDotHalo

function M.dashParts() return lines, halos, lineDot, lineDotHalo end

-- Draws a dashed line through points ({ x, y } in 0-100 on the map being shown) on the map canvas.
local function dashedLine(points)
  for _, l in ipairs(lines) do l:Hide() end
  for _, l in ipairs(halos) do l:Hide() end
  if lineDot then lineDot:Hide() end
  if lineDotHalo then lineDotHalo:Hide() end
  local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
  local canvas = type(sc) == "table" and sc.Child or WorldMapFrame
  if not (canvas and canvas.CreateLine) or #points < 2 then return end
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  if not (type(w) == "number" and w > 0 and type(h) == "number" and h > 0) then return end
  local look = ns.compassStyle.context.line
  local used = 0
  local total = 0
  for i = 1, #points - 1 do
    total = total + math.sqrt(((points[i + 1][1] - points[i][1]) / 100 * w) ^ 2 + ((points[i + 1][2] - points[i][2]) / 100 * h) ^ 2)
  end
  if total <= 0 then return end
  local done = 0
  local function dash(x1, y1, x2, y2)
    used = used + 1
    local l, halo = lines[used], halos[used]
    if not l then
      halo = canvas:CreateLine(nil, "ARTWORK")
      l = canvas:CreateLine(nil, "OVERLAY")
      lines[used], halos[used] = l, halo
    end
    -- thinner along the way: the thickness at the dash's middle
    local mid = done + (math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)) / 2
    local thick = look.thickness + (look.thin - look.thickness) * math.min(1, mid / total)
    for _, part in ipairs({ { halo, thick + look.haloWidth, look.halo }, { l, thick, look.color } }) do
      local line, width, c = part[1], part[2], part[3]
      line:SetThickness(width)
      line:SetColorTexture(c[1], c[2], c[3], look.alpha)
      line:SetStartPoint("TOPLEFT", canvas, x1, -y1)
      line:SetEndPoint("TOPLEFT", canvas, x2, -y2)
      line:Show()
    end
  end
  for i = 1, #points - 1 do
    local x1, y1 = points[i][1] / 100 * w, points[i][2] / 100 * h
    local x2, y2 = points[i + 1][1] / 100 * w, points[i + 1][2] / 100 * h
    local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    if len > 0 then
      local ux, uy = (x2 - x1) / len, (y2 - y1) / len
      local t = 0
      while t < len do
        local e = math.min(t + look.dash, len)
        dash(x1 + ux * t, y1 + uy * t, x1 + ux * e, y1 + uy * e)
        t = t + look.dash + look.gap
      end
    end
    done = done + len
  end
  -- A dot where the line ends.
  local last = points[#points]
  if not lineDot then
    lineDotHalo = canvas:CreateTexture(nil, "ARTWORK")
    lineDotHalo:SetTexture(ns.compassStyle.textures.markerFill)
    lineDot = canvas:CreateTexture(nil, "OVERLAY")
    lineDot:SetTexture(ns.compassStyle.textures.markerFill)
  end
  for _, part in ipairs({ { lineDotHalo, look.dot + look.haloWidth, look.halo }, { lineDot, look.dot, look.color } }) do
    local dot, size, c = part[1], part[2], part[3]
    dot:SetVertexColor(c[1], c[2], c[3], look.alpha)
    dot:SetSize(size, size)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", canvas, "TOPLEFT", last[1] / 100 * w, -(last[2] / 100 * h))
    dot:Show()
  end
end

function M.hoverStep(chapter, step)
  for _, h in ipairs(HOVER) do clearSlot(h[1]) end
  dashedLine({})
  local player = ns.guidePlayer
  local S = player and player.state()
  if not (S and chapter and step) then return end
  local at = ns.guidePlanner.locate(S.flat, { chapter = chapter, step = step })
  if not at then return end
  for _, h in ipairs(HOVER) do
    local entry = S.flat[at + h[3]]
    if entry then
      local map, x, y = ns.guidePlanner.stepLocation(entry.step)
      if type(map) == "number" and type(x) == "number" then
        contextPin(h[1], { mode = h[2], map = map, x = x, y = y, icon = ns.guideText.stepIcon(entry.step), fade = ns.compassStyle.context.hoverFade, alpha = h[3] == 0 and 1 or nil })
      end
    end
  end
  -- The dashed route from the step before to the second step after, over the stretch that is on one map: the one the
  -- hovered step is on.
  local shown = {}
  local home
  for offset = -1, 2 do
    local entry = S.flat[at + offset]
    local map, x, y
    if entry then map, x, y = ns.guidePlanner.stepLocation(entry.step) end
    if offset == 0 then home = map end
    if type(map) == "number" and type(x) == "number" then shown[#shown + 1] = { x, y, map = map } else shown[#shown + 1] = false end
  end
  local run = {}
  for _, p in ipairs(shown) do
    if p and p.map == home then run[#run + 1] = p else if #run > 0 and p == false then break end end
  end
  -- Only on the map being shown: a step on another map has no place on this canvas.
  local shownMap = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  if type(shownMap) == "number" and home ~= shownMap then run = {} end
  dashedLine(run)
end

ns:On("GUIDE_STEP_CHANGED", function() M.refreshContext() end)
ns:On("GUIDE_DOCK_CHANGED", function() M.refreshContext() end)

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
