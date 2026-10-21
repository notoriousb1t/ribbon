-- Guide browser: a panel with a blue bezel docked beside the world map. The chapters are the parent list (cards with
-- progress bars) and a chapter's steps are its child page, shown one at a time: click a chapter to go into it, the back
-- arrow in the title bar to return to the list, a step to jump to it. The panel always opens on the child page, at the
-- step the player is on. The map button, the compass dial and /ribbon guides all open this one panel (opening the map
-- if need be). It is built on first use, so a player without a guide never has the frames. Rows are built from
-- guide/Planner's outline; this file is the view.
local ADDON, ns = ...

local Br = {}
ns.guideBrowser = Br

local planner = ns.guidePlanner
local text = ns.guideText

local ROW = 34                           -- height of a step row (two lines of text)
local CARD = 40                          -- height of a chapter card
local COLUMN_W = 300                     -- the width of the list
local TOP = 66                           -- room for the bezel, the title bar and the overall bar
local BOTTOM = 22                        -- room for the bezel

local COLORS = {
  done = "|cff808080", current = "|cffe9b949", todo = "|cfff3ead2",
}

local dock, selected   -- the docked panel; selected: guide chapter index being browsed (nil: the active chapter)

-- Rows --------------------------------------------------------------------------------

-- Left rows: { chapter =, label =, state =, levels =, done =, total =, fraction = }. Right rows:
-- { chapter =, step =, label =, state = }. Progress is by position: steps before the current one count as done.
function Br.rows(player, chapter)
  local S = player.state()
  local env = player.env()
  local outline = planner.outline(S.view, S.flat, S.cursor)
  local progress = planner.progress(S.view, S.flat, S.cursor)
  local left, right = {}, {}
  for _, ch in ipairs(S.view) do
    local p = progress.chapters[ch.index]
    left[#left + 1] = {
      chapter = ch.index, label = ch.name, state = outline.chapters[ch.index], levels = ch.levels,
      done = p.done, total = p.total, fraction = p.fraction,
    }
  end
  local base = 0
  for _, ch in ipairs(S.view) do
    if ch.index == chapter then
      for i, s in ipairs(ch.steps) do
        right[#right + 1] = {
          chapter = s.chapter, step = s.index, state = outline.steps[base + i],
          label = string.format("%d. %s", i, text.summary(s.step, S.guide.names, env)),
        }
      end
    end
    base = base + #ch.steps
  end
  return left, right
end

local function colored(state, label)
  return (COLORS[state] or COLORS.todo) .. (state == "current" and "> " or "") .. label .. "|r"
end

-- Frame ---------------------------------------------------------------------------------

local function pool(parent, rows, make, height)
  rows.items = rows.items or {}
  height = height or ROW
  return function(n)
    for i = #rows.items + 1, n do rows.items[i] = make(parent, i) end
    for i = 1, #rows.items do rows.items[i]:SetShown(i <= n) end
    parent:SetHeight(math.max(1, n * height))
  end
end

local BAR_H = 5

-- A flat progress bar: a dark track and a fill whose width follows the fraction.
local function bar(parent, width, height)
  local track = parent:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0, 0, 0, 0.45)
  track:SetSize(width, height)
  local fill = parent:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", track, "TOPLEFT")
  fill:SetHeight(height)
  local b = { track = track, fill = fill, width = width }
  function b.set(fraction, color)
    fraction = math.max(0, math.min(1, fraction or 0))
    fill:SetColorTexture(color[1], color[2], color[3], 1)
    fill:SetWidth(math.max(0.001, fraction * width))
    fill:SetShown(fraction > 0)
  end
  return b
end

local BAR_COLORS = {
  done = { 0.42, 0.62, 0.66 }, current = { 0.914, 0.725, 0.286 }, todo = { 0.953, 0.918, 0.824 },
}

-- A chapter card: place on the first line, levels and percent on the second, a progress bar under both.
local function makeCard(width)
  return function(parent, i)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, CARD)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * CARD)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
    b.label:SetWidth(width - 8)
    b.label:SetJustifyH("LEFT")
    b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.sub:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -2)
    b.sub:SetWidth(width - 8)
    b.sub:SetJustifyH("LEFT")
    b.bar = bar(b, width - 8, BAR_H)
    b.bar.track:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 4, 4)
    b:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
    return b
  end
end

local function makeRow(width)
  return function(parent, i)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, ROW)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * ROW)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("LEFT", b, "LEFT", 4, 0)
    b.label:SetWidth(width - 8)
    b.label:SetJustifyH("LEFT")
    b.label:SetMaxLines(2)       -- two lines per step: a longer summary is cut, it does not run into the next row
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    return b
  end
end

-- A scrolling column: it runs from under the header to above the buttons, whatever the frame's height.
local function scroller(parent, name, x, width)
  local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -TOP)
  scroll:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, BOTTOM)
  scroll:SetWidth(width - 22)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(width - 22, 1)
  scroll:SetScrollChild(content)
  return content, scroll
end

-- Scrolls a column so row i (rows of the given height) is in the middle of its view, or as near as the column allows.
local function scrollTo(scroll, i, height)
  if not (scroll and scroll.SetVerticalScroll and i) then return end
  local view = scroll:GetHeight()
  view = type(view) == "number" and view or 0
  local y = math.max(0, (i - 1) * height - (view - height) / 2)
  local range = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange()
  if type(range) == "number" then y = math.min(y, range) end
  scroll:SetVerticalScroll(y)
end

-- Brings the visible page to the player's place: the chapter list to the browsed chapter's card, the step list to the
-- current step (when the chapter shown is the active one). The columns have only just been filled, so their length is
-- not known until the next frame: scroll again shortly after.
function Br.scrollToCurrent()
  if not dock then return end
  local player = ns.guidePlayer
  if not player.state() then return end
  local left, right = Br.rows(player, selected)
  local chapter, step
  for i, row in ipairs(left) do
    if row.chapter == selected then chapter = i end
  end
  for i, row in ipairs(right) do
    if row.state == "current" then step = i end
  end
  local function go()
    if dock.page == "chapters" then
      scrollTo(dock.leftScroll, chapter, CARD)
    else
      scrollTo(dock.rightScroll, step or 1, ROW)
    end
  end
  go()
  if C_Timer and C_Timer.After then C_Timer.After(0.05, go) end
end

-- Fills the panel from the player's state.
local function fill(f, player)
  local S = player.state()
  local left, right = Br.rows(player, selected)

  f.setLeft(#left)
  for i, row in ipairs(left) do
    local b = f.leftRows.items[i]
    local place = text.chapterParts(row.label)
    local state = row.chapter == selected and "current" or row.state
    b.label:SetText(colored(state, place))
    b.sub:SetText(Br.subtitle(row))
    b.bar.set(row.fraction, BAR_COLORS[row.state] or BAR_COLORS.todo)
    b.chapter = row.chapter
  end
  f.setRight(#right)
  for i, row in ipairs(right) do
    local b = f.rightRows.items[i]
    b.label:SetText(colored(row.state, row.label))
    b.chapter, b.step = row.chapter, row.step
  end
  -- The page: the chapter list shows the whole guide's progress and the guide's title; a chapter's steps show that
  -- chapter's progress and its name, with the back arrow.
  local onSteps = f.page == "steps"
  f.leftScroll:SetShown(not onSteps)
  f.rightScroll:SetShown(onSteps)
  f.back:SetShown(onSteps)
  local fraction = planner.progress(S.view, S.flat, S.cursor).fraction
  local title = ns.guide and ns.guide.title or "Guide"
  if onSteps then
    for _, row in ipairs(left) do
      if row.chapter == selected then
        fraction = row.fraction
        title = text.chapterParts(row.label)
      end
    end
  end
  f.title:SetText(title)
  f.overall.set(fraction, BAR_COLORS.current)
  f.overallText:SetText(string.format("%d%%", math.floor(fraction * 100 + 0.5)))
end

-- Refreshes the panel if it has been built.
function Br.refresh()
  local player = ns.guidePlayer
  if not (dock and player.state()) then return end
  local S = player.state()
  if not selected then
    local entry = player.current()
    selected = entry and entry.chapter or (S.view[1] and S.view[1].index)
  end
  fill(dock, player)
end

-- The second line of a chapter card: "Lv 12-14 - 48%".
function Br.subtitle(row)
  local parts = {}
  local lv = row.levels
  if type(lv) == "table" and lv[1] then
    parts[#parts + 1] = lv[2] and lv[2] ~= lv[1] and string.format("Lv %d-%d", lv[1], lv[2]) or string.format("Lv %d", lv[1])
  end
  parts[#parts + 1] = string.format("%d%%", math.floor((row.fraction or 0) * 100 + 0.5))
  return "|cffb8c7cc" .. table.concat(parts, " - ") .. "|r"
end

-- The blue bezel: four corners (one texture flipped), four edges that tile, drawn in the style of the map's own frame.
local function addBezel(f)
  local style = ns.compassStyle
  local B, K = style.bezel.band, style.bezel.corner
  local t = style.textures
  local function piece(file)
    local tex = f:CreateTexture(nil, "BORDER")
    tex:SetTexture(file, "REPEAT", "REPEAT")
    return tex
  end
  local function corner(point, l, r, top, bottom)
    local tex = piece(t.bezelCorner)
    tex:SetSize(K, K)
    tex:SetPoint(point, f, point, 0, 0)
    tex:SetTexCoord(l, r, top, bottom)
    return tex
  end
  local bezel = {
    corner("TOPLEFT", 0, 1, 0, 1), corner("TOPRIGHT", 1, 0, 0, 1),
    corner("BOTTOMLEFT", 0, 1, 1, 0), corner("BOTTOMRIGHT", 1, 0, 1, 0),
  }
  local top, bottom, left, right = piece(t.bezelEdgeH), piece(t.bezelEdgeH), piece(t.bezelEdgeV), piece(t.bezelEdgeV)
  top:SetPoint("TOPLEFT", f, "TOPLEFT", K, 0)
  top:SetPoint("TOPRIGHT", f, "TOPRIGHT", -K, 0)
  top:SetHeight(B)
  bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", K, 0)
  bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -K, 0)
  bottom:SetHeight(B)
  left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -K)
  left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, K)
  left:SetWidth(B)
  right:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -K)
  right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, K)
  right:SetWidth(B)
  bezel.top, bezel.bottom, bezel.left, bezel.right = top, bottom, left, right
  f.bezel = bezel

  -- The edges repeat once per corner-width of length; only the band part of each texture is shown.
  function f.layoutBezel()
    local w, h = f:GetWidth(), f:GetHeight()
    if not (type(w) == "number" and type(h) == "number" and w > 0 and h > 0) then return end
    local nx, ny, band = math.max(0, (w - 2 * K) / K), math.max(0, (h - 2 * K) / K), style.bezel.bandFraction
    top:SetTexCoord(0, nx, 0, band)
    bottom:SetTexCoord(0, nx, band, 0)
    left:SetTexCoord(0, band, 0, ny)
    right:SetTexCoord(band, 0, 0, ny)
  end
  f:SetScript("OnSizeChanged", f.layoutBezel)
  f.layoutBezel()
end

-- Builds the panel as a child of the world map, so it shows and hides with the map.
local function build()
  local style = ns.compassStyle
  local B = style.bezel.band
  local f = CreateFrame("Frame", "RibbonGuideDock", WorldMapFrame)
  local width = COLUMN_W + 2 * B + 12
  f:SetWidth(width)
  f:EnableMouse(true)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.051, 0.212, 0.275, 0.96)   -- the logo's dark teal
  addBezel(f)

  -- The title bar, like the map's: the title in the middle and a close button on the right.
  local strip = f:CreateTexture(nil, "ARTWORK")
  strip:SetColorTexture(0.06, 0.25, 0.33, 1)
  strip:SetPoint("TOPLEFT", f, "TOPLEFT", B, -B)
  strip:SetPoint("TOPRIGHT", f, "TOPRIGHT", -B, -B)
  strip:SetHeight(style.bezel.title)
  f.strip = strip
  local rule = f:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(0.16, 0.58, 0.71, 1)
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", strip, "BOTTOMLEFT")
  rule:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT")

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("CENTER", strip, "CENTER", 0, 0)
  f.title:SetWidth(width - 2 * B - 64)     -- clear of the back arrow and the close button
  f.title:SetWordWrap(false)
  f.title:SetText(ns.guide and ns.guide.title or "Guide")
  f.title:SetTextColor(0.85, 0.95, 1)

  -- The back arrow, on the child page: a bezel button with the caret pointing left.
  f.back = CreateFrame("Button", nil, f)
  f.back:SetSize(22, 22)
  f.back:SetPoint("LEFT", strip, "LEFT", 2, 0)
  f.back.bg = f.back:CreateTexture(nil, "ARTWORK")
  f.back.bg:SetTexture(style.textures.bezelButton)
  f.back.bg:SetAllPoints()
  f.back.caret = f.back:CreateTexture(nil, "OVERLAY")
  f.back.caret:SetTexture(style.textures.panelCaret)
  f.back.caret:SetSize(14, 14)
  f.back.caret:SetPoint("CENTER", f.back, "CENTER", -1, 0)
  f.back:SetHighlightTexture(style.textures.bezelButton, "ADD")
  f.back:SetScript("OnClick", function() Br.showChapters() end)
  f.back:Hide()

  f.close = CreateFrame("Button", nil, f)
  f.close:SetSize(22, 22)
  f.close:SetPoint("RIGHT", strip, "RIGHT", -2, 0)
  f.close.bg = f.close:CreateTexture(nil, "ARTWORK")
  f.close.bg:SetTexture(style.textures.bezelButton)
  f.close.bg:SetAllPoints()
  -- The X is two thin bars crossed at the button's exact centre (a letter in a font sits off-centre).
  f.close.bars = {}
  for i, angle in ipairs({ 45, -45 }) do
    local bar = f.close:CreateTexture(nil, "OVERLAY")
    bar:SetColorTexture(0.953, 0.918, 0.824, 1)
    bar:SetSize(2, 12)
    bar:SetPoint("CENTER", f.close, "CENTER", 0, 0)
    bar:SetRotation(math.rad(angle))
    f.close.bars[i] = bar
  end
  f.close:SetHighlightTexture(style.textures.bezelButton, "ADD")
  f.close:SetScript("OnClick", function() Br.setDock(false) end)

  -- Overall progress along the whole guide, under the title bar.
  f.overall = bar(f, width - 2 * (B + 8) - 40, 8)
  f.overall.track:SetPoint("TOPLEFT", f, "TOPLEFT", B + 8, -(B + style.bezel.title + 10))
  f.overallText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.overallText:SetPoint("LEFT", f.overall.track, "RIGHT", 6, 0)

  -- Two lists in the same place, one per page: the chapters (left rows) and a chapter's steps (right rows).
  f.leftRows, f.rightRows = {}, {}
  f.page = "steps"
  local left, right
  left, f.leftScroll = scroller(f, "RibbonGuideDockChapters", B + 6, COLUMN_W)
  right, f.rightScroll = scroller(f, "RibbonGuideDockSteps", B + 6, COLUMN_W)
  local makeLeft, makeRight = makeCard(COLUMN_W - 22), makeRow(COLUMN_W - 22)
  f.setLeft = pool(left, f.leftRows, function(parent, i)
    local b = makeLeft(parent, i)
    b:SetScript("OnClick", function(self)
      Br.showSteps(self.chapter)
    end)
    return b
  end, CARD)
  f.setRight = pool(right, f.rightRows, function(parent, i)
    local b = makeRight(parent, i)
    b:SetScript("OnClick", function(self)
      ns.guidePlayer.jump(self.chapter, self.step)
    end)
    return b
  end, ROW)

  return f
end

-- Where the panel goes. The map and its quest log are one frame, and the quest log panel draws over anything put
-- inside the frame's right side, so the panel sits just outside the frame's right edge when the screen has room for
-- it, and only falls back to overlapping the frame (above the quest log) when the map fills the screen.
function Br.placeDock()
  if not (dock and WorldMapFrame) then return end
  local right, screen = WorldMapFrame:GetRight(), UIParent:GetRight()
  local width = dock:GetWidth() or 0
  dock:ClearAllPoints()
  if type(right) == "number" and type(screen) == "number" and screen - right >= width + 8 then
    dock:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", 4, 0)
    dock:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMRIGHT", 4, 0)
  else
    dock:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -6, -66)
    dock:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -6, 6)
  end
  dock:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 200)
  if dock.layoutBezel then dock.layoutBezel() end
end

local function buildDock()
  dock = build()
  Br.placeDock()
  -- The map moves and resizes (maximize, drag): follow it.
  pcall(function()
    WorldMapFrame:HookScript("OnShow", Br.placeDock)
    WorldMapFrame:HookScript("OnSizeChanged", Br.placeDock)
  end)
  dock:SetScript("OnShow", Br.placeDock)
end

-- A step change drops the chapter being browsed, so the panel goes back to the active chapter (the one just clicked,
-- after a jump).
ns:On("GUIDE_STEP_CHANGED", function()
  selected = nil
  Br.refresh()
  Br.scrollToCurrent()
end)

-- The child page: a chapter's steps (the browsed chapter when none is given).
function Br.showSteps(chapter)
  if not dock then return end
  if chapter then selected = chapter end
  dock.page = "steps"
  Br.refresh()
  Br.scrollToCurrent()
end

-- The parent page: the chapters.
function Br.showChapters()
  if not dock then return end
  dock.page = "chapters"
  Br.refresh()
  Br.scrollToCurrent()
end

-- Show or hide the panel, and remember the choice for the next session.
function Br.setDock(shown)
  if not ns.guidePlayer.state() then
    ns:Print("no guide installed.")
    return
  end
  -- The world map is load-on-demand on some clients: load it, and if that is not possible say what to do.
  if not WorldMapFrame then
    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if load then pcall(load, "Blizzard_WorldMap") end
  end
  if not WorldMapFrame then
    ns:Print("the world map is not loaded yet: open it once (M), then try again.")
    return
  end
  if ns.map and ns.map.createGuideButton then ns.map.createGuideButton() end   -- make sure the map button exists too
  if not dock then buildDock() end
  -- The map's quest log panel and this one take turns.
  if shown and ns.map and ns.map.collapseQuestLog then ns.map.collapseQuestLog() end
  dock:SetShown(shown)
  if ns.db then ns.db.guideDock = shown and true or false end
  if shown then
    selected = nil
    Br.showSteps()   -- always open on the child page, at the step the player is on
  end
  ns:Fire("GUIDE_DOCK_CHANGED", shown and true or false)
end

function Br.toggleDock()
  Br.setDock(not (dock and dock:IsShown()))
end

-- The compass dial, /ribbon guides and /ribbon guide: close the panel if it is showing, otherwise open the map (if it
-- is not open) and the panel.
function Br.toggle()
  if dock and dock:IsShown() and WorldMapFrame and WorldMapFrame:IsShown() then
    Br.setDock(false)
    return
  end
  Br.setDock(true)
  if WorldMapFrame and not WorldMapFrame:IsShown() and ToggleWorldMap then ToggleWorldMap() end
end

-- Reopen the panel at login if it was open when the player last left.
ns:On("GUIDE_STARTED", function()
  if ns.db and ns.db.guideDock and WorldMapFrame then Br.setDock(true) end
end)

function Br.dock() return dock end

-- /ribbon guides and /ribbon dock open the panel.
ns.commands.guides = function() Br.toggle() end
ns.commands.dock = function() Br.toggle() end
