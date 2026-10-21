-- Guide browser: chapter cards with progress bars on the left and the selected chapter's steps on the right, in a
-- panel with a blue bezel docked beside the world map. Click a step to jump to it, or "Start chapter" to begin at the
-- chapter's first step. The map button, the compass dial and /ribbon guides all open this one panel (opening the map if
-- need be). It is built on first use, so a player without a guide never has the frames. Rows are built from
-- guide/Planner's outline; this file is the view.
local ADDON, ns = ...

local Br = {}
ns.guideBrowser = Br

local planner = ns.guidePlanner
local text = ns.guideText

local ROW = 20
local CARD = 40                          -- height of a chapter card
local LEFT_W, RIGHT_W = 190, 230        -- the two columns of the panel
local TOP = 66                           -- room for the bezel, the title bar and the overall bar
local BOTTOM = 50                        -- room for the bezel and the buttons

local COLORS = {
  done = "|cff808080", current = "|cffe9b949", todo = "|cfff3ead2",
}

local dock, selected   -- the docked panel; selected: guide chapter index being browsed

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
    b.label:SetWordWrap(false)   -- one line per step: a long summary is cut, it does not run into the next row
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
  return content
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
  local entry, cursor = player.current()
  f.progress:SetText(entry and string.format("Step %d of %d", cursor, #S.flat) or "Guide finished")
  local overall = planner.progress(S.view, S.flat, S.cursor)
  f.overall.set(overall.fraction, BAR_COLORS.current)
  f.overallText:SetText(string.format("%d%%", math.floor(overall.fraction * 100 + 0.5)))
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

-- A flat blue button: a lit top edge, a dark bottom edge, centred text and a hover glow.
local function blueButton(parent, label, width)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, 22)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.122, 0.478, 0.600, 1)
  b.light = b:CreateTexture(nil, "BORDER")
  b.light:SetColorTexture(0.45, 0.80, 0.92, 1)
  b.light:SetHeight(1)
  b.light:SetPoint("TOPLEFT")
  b.light:SetPoint("TOPRIGHT")
  b.dark = b:CreateTexture(nil, "BORDER")
  b.dark:SetColorTexture(0.03, 0.14, 0.19, 1)
  b.dark:SetHeight(1)
  b.dark:SetPoint("BOTTOMLEFT")
  b.dark:SetPoint("BOTTOMRIGHT")
  b.glow = b:CreateTexture(nil, "ARTWORK")
  b.glow:SetAllPoints()
  b.glow:SetColorTexture(1, 1, 1, 0.18)
  b.glow:Hide()
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.text:SetPoint("CENTER")
  b.text:SetText(label)
  b.text:SetTextColor(0.953, 0.918, 0.824)
  b:SetScript("OnEnter", function(self) self.glow:Show() end)
  b:SetScript("OnLeave", function(self) self.glow:Hide() end)
  return b
end

-- Builds the panel as a child of the world map, so it shows and hides with the map.
local function build()
  local style = ns.compassStyle
  local B = style.bezel.band
  local f = CreateFrame("Frame", "RibbonGuideDock", WorldMapFrame)
  local width = LEFT_W + RIGHT_W + 2 * B + 18
  f:SetWidth(width)
  f:EnableMouse(true)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.051, 0.212, 0.275, 0.96)   -- the logo's dark teal
  addBezel(f)

  -- The title bar, like the map's: the title in the middle, the step on the left and a close button on the right.
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
  f.title:SetText(ns.guide and ns.guide.title or "Guide")
  f.title:SetTextColor(0.85, 0.95, 1)
  f.progress = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.progress:SetPoint("LEFT", strip, "LEFT", 8, 0)
  f.progress:SetTextColor(0.72, 0.84, 0.88)

  f.close = CreateFrame("Button", nil, f)
  f.close:SetSize(22, 22)
  f.close:SetPoint("RIGHT", strip, "RIGHT", -2, 0)
  f.close.bg = f.close:CreateTexture(nil, "ARTWORK")
  f.close.bg:SetTexture(style.textures.bezelButton)
  f.close.bg:SetAllPoints()
  f.close.x = f.close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.close.x:SetPoint("CENTER", 0, 1)
  f.close.x:SetText("x")
  f.close.x:SetTextColor(0.953, 0.918, 0.824)
  f.close:SetHighlightTexture(style.textures.bezelButton, "ADD")
  f.close:SetScript("OnClick", function() Br.setDock(false) end)

  -- Overall progress along the whole guide, under the title bar.
  f.overall = bar(f, width - 2 * (B + 8) - 40, 8)
  f.overall.track:SetPoint("TOPLEFT", f, "TOPLEFT", B + 8, -(B + style.bezel.title + 10))
  f.overallText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.overallText:SetPoint("LEFT", f.overall.track, "RIGHT", 6, 0)

  f.leftRows, f.rightRows = {}, {}
  local left = scroller(f, "RibbonGuideDockChapters", B + 6, LEFT_W)
  local right = scroller(f, "RibbonGuideDockSteps", B + 6 + LEFT_W + 6, RIGHT_W)
  local makeLeft, makeRight = makeCard(LEFT_W - 22), makeRow(RIGHT_W - 22)
  f.setLeft = pool(left, f.leftRows, function(parent, i)
    local b = makeLeft(parent, i)
    b:SetScript("OnClick", function(self)
      selected = self.chapter
      Br.refresh()
    end)
    return b
  end, CARD)
  f.setRight = pool(right, f.rightRows, function(parent, i)
    local b = makeRight(parent, i)
    b:SetScript("OnClick", function(self)
      ns.guidePlayer.jump(self.chapter, self.step)
    end)
    return b
  end)

  f.start = blueButton(f, "Start chapter", 110)
  f.start:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", B + 6, B + 8)
  f.start:SetScript("OnClick", function()
    if selected then ns.guidePlayer.jumpToChapter(selected) end
  end)
  f.skip = blueButton(f, "Skip step", 92)
  f.skip:SetPoint("LEFT", f.start, "RIGHT", 6, 0)
  f.skip:SetScript("OnClick", function() ns.guidePlayer.skip() end)
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
end)

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
  dock:SetShown(shown)
  if ns.db then ns.db.guideDock = shown and true or false end
  if shown then
    selected = nil
    Br.refresh()
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
