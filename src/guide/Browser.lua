-- Guide browser: a dialog listing the guide's chapters on the left and the selected chapter's steps on the right.
-- Click a step to jump to it, or "Start chapter" to begin at the chapter's first step. Built on first use, so a
-- player without a guide never has the frames. Rows are built from guide/Planner's outline; this file is the view.
local ADDON, ns = ...

local Br = {}
ns.guideBrowser = Br

local planner = ns.guidePlanner
local text = ns.guideText

local ROW = 20
local CARD = 40                          -- height of a chapter card
local LEFT_W, RIGHT_W, HEIGHT = 230, 400, 400
local TOP = 56                           -- room for the title and the overall bar

local COLORS = {
  done = "|cff808080", current = "|cffe9b949", todo = "|cfff3ead2",
}

local frame, selected   -- selected: guide chapter index being browsed

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
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    return b
  end
end

local function scroller(parent, name, x, width)
  local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -TOP)
  scroll:SetSize(width - 22, HEIGHT - TOP - 36)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(width - 22, 1)
  scroll:SetScrollChild(content)
  return content
end

function Br.refresh()
  local player = ns.guidePlayer
  if not (frame and player.state()) then return end
  local S = player.state()
  if not selected then
    local entry = player.current()
    selected = entry and entry.chapter or (S.view[1] and S.view[1].index)
  end
  local left, right = Br.rows(player, selected)

  frame.setLeft(#left)
  for i, row in ipairs(left) do
    local b = frame.leftRows.items[i]
    local place = text.chapterParts(row.label)
    local state = row.chapter == selected and "current" or row.state
    b.label:SetText(colored(state, place))
    b.sub:SetText(Br.subtitle(row))
    b.bar.set(row.fraction, BAR_COLORS[row.state] or BAR_COLORS.todo)
    b.chapter = row.chapter
  end
  frame.setRight(#right)
  for i, row in ipairs(right) do
    local b = frame.rightRows.items[i]
    b.label:SetText(colored(row.state, row.label))
    b.chapter, b.step = row.chapter, row.step
  end
  local entry, cursor = player.current()
  frame.progress:SetText(entry and string.format("Step %d of %d", cursor, #S.flat) or "Guide finished")
  local overall = planner.progress(S.view, S.flat, S.cursor)
  frame.overall.set(overall.fraction, BAR_COLORS.current)
  frame.overallText:SetText(string.format("%d%%", math.floor(overall.fraction * 100 + 0.5)))
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

local function build()
  frame = CreateFrame("Frame", "RibbonGuideBrowser", UIParent)
  frame:SetSize(LEFT_W + RIGHT_W + 36, HEIGHT)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.051, 0.212, 0.275, 0.95)   -- the logo's dark teal

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
  title:SetText(ns.guide and ns.guide.title or "Guide")
  frame.title = title
  frame.progress = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.progress:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)

  -- Overall progress along the whole guide, under the title.
  local width = LEFT_W + RIGHT_W + 36 - 24 - 40
  frame.overall = bar(frame, width, 8)
  frame.overall.track:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
  frame.overallText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.overallText:SetPoint("LEFT", frame.overall.track, "RIGHT", 6, 0)

  frame.leftRows, frame.rightRows = {}, {}
  local left = scroller(frame, "RibbonGuideChapters", 8, LEFT_W)
  local right = scroller(frame, "RibbonGuideSteps", LEFT_W + 20, RIGHT_W)
  local makeLeft, makeRight = makeCard(LEFT_W - 22), makeRow(RIGHT_W - 22)
  frame.setLeft = pool(left, frame.leftRows, function(parent, i)
    local b = makeLeft(parent, i)
    b:SetScript("OnClick", function(self)
      selected = self.chapter
      Br.refresh()
    end)
    return b
  end, CARD)
  frame.setRight = pool(right, frame.rightRows, function(parent, i)
    local b = makeRight(parent, i)
    b:SetScript("OnClick", function(self)
      ns.guidePlayer.jump(self.chapter, self.step)
    end)
    return b
  end)

  local function button(label, x, onClick)
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(110, 22)
    b:SetText(label)
    b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 8)
    b:SetScript("OnClick", onClick)
    return b
  end
  frame.start = button("Start chapter", 12, function()
    if selected then ns.guidePlayer.jumpToChapter(selected) end
  end)
  frame.skip = button("Skip step", 128, function() ns.guidePlayer.skip() end)
  frame.close = button("Close", LEFT_W + RIGHT_W + 36 - 122, function() frame:Hide() end)

  if UISpecialFrames then table.insert(UISpecialFrames, "RibbonGuideBrowser") end
  ns:On("GUIDE_STEP_CHANGED", function()
    if frame:IsShown() then Br.refresh() end
  end)
end

-- Open the browser on the current chapter, or close it.
function Br.toggle()
  if not ns.guidePlayer.state() then
    ns:Print("no guide installed.")
    return
  end
  if not frame then build() end
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

function Br.frame() return frame end

-- /ribbon guides: the same panel as /ribbon guide.
ns.commands.guides = function() Br.toggle() end
