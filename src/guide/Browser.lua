-- Guide browser: chapter cards with progress bars on the left and the selected chapter's steps on the right.
-- Click a step to jump to it, or "Start chapter" to begin at the chapter's first step. It comes in two forms with the
-- same content: a floating dialog (the compass dial, /ribbon guides) and a panel docked to the right side of the world
-- map (the Ribbon button on the map). Each is built on first use, so a player without a guide never has the frames.
-- Rows are built from guide/Planner's outline; this file is the view.
local ADDON, ns = ...

local Br = {}
ns.guideBrowser = Br

local planner = ns.guidePlanner
local text = ns.guideText

local ROW = 20
local CARD = 40                          -- height of a chapter card
local LEFT_W, RIGHT_W, HEIGHT = 230, 400, 400   -- the floating dialog
local DOCK_LEFT_W, DOCK_RIGHT_W = 190, 230       -- the panel docked to the map
local TOP = 56                           -- room for the title and the overall bar

local COLORS = {
  done = "|cff808080", current = "|cffe9b949", todo = "|cfff3ead2",
}

local frame, dock, selected   -- the dialog and the docked panel; selected: guide chapter index being browsed

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
  scroll:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, 36)
  scroll:SetWidth(width - 22)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(width - 22, 1)
  scroll:SetScrollChild(content)
  return content
end

-- Fills one panel from the player's state.
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

-- Refreshes every panel that has been built.
function Br.refresh()
  local player = ns.guidePlayer
  if not ((frame or dock) and player.state()) then return end
  local S = player.state()
  if not selected then
    local entry = player.current()
    selected = entry and entry.chapter or (S.view[1] and S.view[1].index)
  end
  if frame then fill(frame, player) end
  if dock then fill(dock, player) end
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

-- Builds a panel. opts: name, parent, leftW, rightW, buttonW, onClose; floating panels also get a size, a place and
-- dragging, docked ones are anchored by the caller.
local function build(opts)
  local f = CreateFrame("Frame", opts.name, opts.parent or UIParent)
  local width = opts.leftW + opts.rightW + 36
  f:SetWidth(width)
  f:EnableMouse(true)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.051, 0.212, 0.275, 0.95)   -- the logo's dark teal

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
  title:SetText(ns.guide and ns.guide.title or "Guide")
  f.title = title
  f.progress = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.progress:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -12)

  -- Overall progress along the whole guide, under the title.
  f.overall = bar(f, width - 24 - 40, 8)
  f.overall.track:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
  f.overallText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.overallText:SetPoint("LEFT", f.overall.track, "RIGHT", 6, 0)

  f.leftRows, f.rightRows = {}, {}
  local left = scroller(f, opts.name .. "Chapters", 8, opts.leftW)
  local right = scroller(f, opts.name .. "Steps", opts.leftW + 20, opts.rightW)
  local makeLeft, makeRight = makeCard(opts.leftW - 22), makeRow(opts.rightW - 22)
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

  local function button(label, x, onClick)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(opts.buttonW, 22)
    b:SetText(label)
    b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 8)
    b:SetScript("OnClick", onClick)
    return b
  end
  f.start = button("Start chapter", 12, function()
    if selected then ns.guidePlayer.jumpToChapter(selected) end
  end)
  f.skip = button("Skip step", 12 + opts.buttonW + 6, function() ns.guidePlayer.skip() end)
  f.close = button("Close", width - 12 - opts.buttonW, opts.onClose)
  return f
end

local function buildDialog()
  frame = build({
    name = "RibbonGuideBrowser", leftW = LEFT_W, rightW = RIGHT_W, buttonW = 110,
    onClose = function() frame:Hide() end,
  })
  frame:SetHeight(HEIGHT)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  if UISpecialFrames then table.insert(UISpecialFrames, "RibbonGuideBrowser") end
end

-- The docked panel is a child of the world map, so it shows and hides with the map, and sits over the map's right side.
local function buildDock()
  dock = build({
    name = "RibbonGuideDock", parent = WorldMapFrame, leftW = DOCK_LEFT_W, rightW = DOCK_RIGHT_W, buttonW = 92,
    onClose = function() Br.setDock(false) end,
  })
  dock:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -6, -66)
  dock:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -6, 6)
  dock:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 50)
end

-- A step change drops the chapter being browsed, so the panels go back to the active chapter (the one just clicked,
-- after a jump).
ns:On("GUIDE_STEP_CHANGED", function()
  selected = nil
  Br.refresh()
end)

-- Open the floating dialog on the current chapter, or close it.
function Br.toggle()
  if not ns.guidePlayer.state() then
    ns:Print("no guide installed.")
    return
  end
  if not frame then buildDialog() end
  if frame:IsShown() and frame.opened then
    frame:Hide()
    frame.opened = false
    return
  end
  selected = nil
  frame:Show()
  frame.opened = true
  Br.refresh()
end

-- Show or hide the panel docked to the world map, and remember the choice for the next session.
function Br.setDock(shown)
  if not ns.guidePlayer.state() then
    ns:Print("no guide installed.")
    return
  end
  if not WorldMapFrame then return end
  if not dock then buildDock() end
  dock:SetShown(shown)
  if ns.db then ns.db.guideDock = shown and true or false end
  if shown then
    selected = nil
    Br.refresh()
  end
end

function Br.toggleDock()
  Br.setDock(not (dock and dock:IsShown()))
end

-- Reopen the docked panel at login if it was open when the player last left.
ns:On("GUIDE_STARTED", function()
  if ns.db and ns.db.guideDock and WorldMapFrame then Br.setDock(true) end
end)

function Br.frame() return frame end
function Br.dock() return dock end

-- /ribbon guides: the same panel as /ribbon guide.
ns.commands.guides = function() Br.toggle() end
