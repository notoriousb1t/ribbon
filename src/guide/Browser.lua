-- Guide browser: a dialog listing the guide's chapters on the left and the selected chapter's steps on the right.
-- Click a step to jump to it, or "Start chapter" to begin at the chapter's first step. Built on first use, so a
-- player without a guide never has the frames. Rows are built from guide/Planner's outline; this file is the view.
local ADDON, ns = ...

local Br = {}
ns.guideBrowser = Br

local planner = ns.guidePlanner
local text = ns.guideText

local ROW = 20
local LEFT_W, RIGHT_W, HEIGHT = 210, 400, 380

local COLORS = {
  done = "|cff808080", current = "|cffe9b949", todo = "|cfff3ead2",
}

local frame, selected   -- selected: guide chapter index being browsed

-- Rows --------------------------------------------------------------------------------

-- Left rows: { chapter =, label =, state = }. Right rows: { chapter =, step =, label =, state = }.
function Br.rows(player, chapter)
  local S = player.state()
  local env = player.env()
  local outline = planner.outline(S.view, S.flat, S.cursor)
  local left, right = {}, {}
  for _, ch in ipairs(S.view) do
    left[#left + 1] = { chapter = ch.index, label = ch.name, state = outline.chapters[ch.index] }
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

local function pool(parent, rows, make)
  rows.items = rows.items or {}
  return function(n)
    for i = #rows.items + 1, n do rows.items[i] = make(parent, i) end
    for i = 1, #rows.items do rows.items[i]:SetShown(i <= n) end
    parent:SetHeight(math.max(1, n * ROW))
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
  scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -34)
  scroll:SetSize(width - 22, HEIGHT - 70)
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
    b.label:SetText(colored(row.chapter == selected and "current" or row.state, row.label))
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

  frame.leftRows, frame.rightRows = {}, {}
  local left = scroller(frame, "RibbonGuideChapters", 8, LEFT_W)
  local right = scroller(frame, "RibbonGuideSteps", LEFT_W + 20, RIGHT_W)
  local makeLeft, makeRight = makeRow(LEFT_W - 22), makeRow(RIGHT_W - 22)
  frame.setLeft = pool(left, frame.leftRows, function(parent, i)
    local b = makeLeft(parent, i)
    b:SetScript("OnClick", function(self)
      selected = self.chapter
      Br.refresh()
    end)
    return b
  end)
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
