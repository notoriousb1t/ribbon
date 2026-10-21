-- Guide browser: a panel with a blue bezel docked beside the world map. The chapters are the parent list (cards with
-- progress bars) and a chapter's steps are its child page, shown one at a time: click a chapter to go into it, the back
-- arrow in the title bar to return to the list. A step is drawn with the icon of what it asks for; clicking it previews
-- it on the world map (the map switches to its zone and centres on it), and the arrow that appears when the mouse is
-- over it moves the player's place in the guide there. The panel always opens on the child page, at the step the player
-- is on. The map button, the compass dial and /ribbon guides all open this one panel (opening the map
-- if need be). It is built on first use, so a player without a guide never has the frames. Rows are built from
-- guide/Planner's outline; this file is the view.
local ADDON, ns = ...

local Br = {}
ns.guideBrowser = Br

local planner = ns.guidePlanner
local text = ns.guideText
local search = ns.guideSearch

local ROW = 34                           -- height of a step row (two lines of text)
local CARD = 40                          -- height of a chapter card
local COLUMN_W = 300                     -- the width of the list
local BEZEL = ns.compassStyle.bezel
local SEARCH_H = 26                          -- the search box and the gap under it
local COUNTER_W = 84                          -- the box with "Steps: 3/80" beside the search box
local SECTION_H = 24                         -- a chapter's section header in the search results, like the quest log's zone header
local TOP = BEZEL.band + BEZEL.title + 6 + SEARCH_H + 4   -- room for the bezel, the title bar and the search row
local BOTTOM = BEZEL.band + 8               -- room for the bezel

local COLORS = {
  done = "|cff808080", current = "|cffe9b949", todo = "|cfff3ead2",
}
-- A step's title is gold like a quest's name in the quest log, grey once done; its objectives are plain cream.
-- Steps still to come are dimmed until the mouse is over them.
local TITLE_COLORS = { done = "|cff808080", current = "|cffffd24a", todo = "|cffe9b949", dim = "|cff8a6d2c" }
local OBJECTIVE_COLORS = { done = "|cff808080", current = "|cffe6e0cf", todo = "|cffe6e0cf", dim = "|cff7a766b" }
local TICK_GREY = 0.5   -- the check mark takes the colour of a done step's text (|cff808080)

local dock, selected   -- the docked panel; selected: guide chapter index being browsed (nil: the active chapter)
local query = ""       -- what the search box holds, trimmed
local reportedError
local folded = {}   -- chapter index -> true while its section is folded away
local preview          -- { chapter =, step = } of the step shown on the world map, or nil

-- Search text -----------------------------------------------------------------------

-- What a step says and what a chapter holds, for the search. Steps are rebuilt when the plan is, so the caches are
-- keyed by the step or chapter table and let go of it with it.
local stepTexts = setmetatable({}, { __mode = "k" })
local chapterTexts = setmetatable({}, { __mode = "k" })

local function stepText(step, names)
  local t = stepTexts[step]
  if not t then
    t = text.fullText(step, names)
    stepTexts[step] = t
  end
  return t
end

-- The chapter's name (both halves), its level range and every step.
local function chapterText(ch, names)
  local t = chapterTexts[ch]
  if not t then
    local parts = { ch.name }
    if type(ch.levels) == "table" and ch.levels[1] then parts[#parts + 1] = "level " .. ch.levels[1] .. " " .. (ch.levels[2] or ch.levels[1]) end
    for _, s in ipairs(ch.steps) do parts[#parts + 1] = stepText(s.step, names) end
    t = table.concat(parts, " ")
    chapterTexts[ch] = t
  end
  return t
end

-- Rows --------------------------------------------------------------------------------

-- Left rows: { chapter =, label =, state =, levels =, done =, total =, fraction = }. Right rows:
-- { chapter =, step =, label =, state =, icon =, map =, x =, y = } (the icon the step is drawn with and where it is, if it
-- is anywhere). Progress is by position: steps before the current one count as done. With a `query` the lists are
-- narrowed to what matches it (guide/Search.lua): a chapter when its name, its levels or any of its steps match, a step
-- when anything it says matches.
function Br.rows(player, chapter, query)
  local S = player.state()
  local env = player.env()
  local outline = planner.outline(S.view, S.flat, S.cursor)
  local progress = planner.progress(S.view, S.flat, S.cursor)
  local left, right = {}, {}
  local filtering = query ~= nil and #search.words(search.normalize(query)) > 0
  for _, ch in ipairs(S.view) do
    local p = progress.chapters[ch.index]
    if not filtering or search.matches(query, chapterText(ch, S.guide.names)) then
    left[#left + 1] = {
      chapter = ch.index, label = ch.name, state = outline.chapters[ch.index], levels = ch.levels,
      done = p.done, total = p.total, fraction = p.fraction,
    }
    end
  end
  -- The steps of the chapter being browsed; while searching, the matching steps of every chapter, each chapter's under a
  -- section header row ({ header = true, chapter =, label =, count =, folded = }) like the quest log's zone header,
  -- which folds them away (when not searching, the one chapter's header is a frame of its own above the rows). A step row is laid out like a quest in the quest log: a title line (the first thing the step
  -- says) and, under it, the rest of what it says as objectives.
  local base = 0
  for _, ch in ipairs(S.view) do
    if filtering or ch.index == chapter then
      local mine = {}
      for i, s in ipairs(ch.steps) do
        if not filtering or search.matches(query, stepText(s.step, S.guide.names)) then
          local map, x, y = planner.stepLocation(s.step)
          local lines = text.stepLines(s.step, S.guide.names, env)
          local title = table.remove(lines, 1) or "Step"
          mine[#mine + 1] = {
            chapter = s.chapter, step = s.index, state = outline.steps[base + i],
            label = text.summary(s.step, S.guide.names, env),
            title = title, objectives = lines,
            icon = text.stepIcon(s.step), map = map, x = x, y = y,
          }
        end
      end
      if filtering and #mine > 0 then
        right[#right + 1] = {
          header = true, chapter = ch.index, label = text.chapterParts(ch.name), count = #mine, folded = folded[ch.index] == true,
        }
      end
      if not folded[ch.index] then
        for _, row in ipairs(mine) do right[#right + 1] = row end
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
    -- The percentage is only on hover.
    b:SetScript("OnEnter", function(self)
      if not self.total then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(string.format("%d of %d steps (%d%%)", self.done or 0, self.total, math.floor((self.fraction or 0) * 100 + 0.5)))
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
end

local ICON = 24                           -- the icon a step is drawn with

-- Is the mouse over a frame? (Frame:IsMouseOver is the retail call; MouseIsOver the older one.)
local function mouseOver(frame)
  if frame.IsMouseOver then return frame:IsMouseOver() end
  return MouseIsOver and MouseIsOver(frame) or false
end

-- The look of the quest log's zone header on a frame: a dark bar with a thin gold border, a name, and a fold button (a
-- minus; with a second bar across it, a plus). Used by the section header over the list and by the step rows, which
-- become headers while searching.
local function addHeaderLook(b, width)
  local style = ns.compassStyle
  local gold = style.panel.gold
  b.headBg = b:CreateTexture(nil, "BACKGROUND")
  b.headBg:SetAllPoints()
  b.headBg:SetColorTexture(0.10, 0.08, 0.05, 1)
  b.headLines = {}
  for n, edge in ipairs({ "TOP", "BOTTOM" }) do
    local line = b:CreateTexture(nil, "BORDER")
    line:SetColorTexture(gold[1], gold[2], gold[3], 0.45)
    line:SetHeight(1)
    line:SetPoint(edge .. "LEFT")
    line:SetPoint(edge .. "RIGHT")
    b.headLines[n] = line
  end
  b.headText = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  b.headText:SetPoint("LEFT", b, "LEFT", 8, 0)
  b.headText:SetWidth(width - 44)
  b.headText:SetJustifyH("LEFT")
  b.headText:SetWordWrap(false)
  b.headText:SetTextColor(0.82, 0.78, 0.68)
  b.minus = b:CreateTexture(nil, "OVERLAY")
  b.minus:SetColorTexture(gold[1], gold[2], gold[3], 1)
  b.minus:SetSize(10, 3)
  b.minus:SetPoint("RIGHT", b, "RIGHT", -8, 0)
  b.plus = b:CreateTexture(nil, "OVERLAY")
  b.plus:SetColorTexture(gold[1], gold[2], gold[3], 1)
  b.plus:SetSize(3, 10)
  b.plus:SetPoint("CENTER", b.minus, "CENTER")
  b.headBg:Hide()
  b.headText:Hide()
  b.minus:Hide()
  b.plus:Hide()
  for _, line in ipairs(b.headLines) do line:Hide() end
end

-- Shows or hides a frame's header look and sets its name and fold state.
local function setHeaderLook(b, shown, label, isFolded)
  b.headBg:SetShown(shown)
  b.headText:SetShown(shown)
  b.minus:SetShown(shown)
  b.plus:SetShown(shown and isFolded == true)
  for _, line in ipairs(b.headLines) do line:SetShown(shown) end
  if shown then b.headText:SetText(label) end
end

-- Colours and shows a step row for its state and whether the mouse is over it (b.hover): the title and the objectives in
-- their colours (steps still to come dimmed until hovered); a done step shows a check mark in place of its icon until
-- hovered; hovering gives any step the current step's glow, and its icon is the button that makes it the current step.
function Br.paintRow(b)
  local row = b.row
  if not row or b.isHeader then return end
  local hover = b.hover == true
  local state = row.state
  local shade = (state == "todo" and not hover) and "dim" or state
  b.label:SetText((TITLE_COLORS[shade] or TITLE_COLORS.todo) .. row.title .. "|r")
  local lines = {}
  for _, line in ipairs(row.objectives) do lines[#lines + 1] = (OBJECTIVE_COLORS[shade] or OBJECTIVE_COLORS.todo) .. "- " .. line .. "|r" end
  b.objectives:SetText(table.concat(lines, "\n"))
  local ticked = state == "done" and not hover
  b.tick:SetShown(ticked)
  b.icon:SetShown(not ticked)
  b.glow:SetShown(state == "current" or hover)
end

-- A step row, laid out like a quest in the quest log: its icon (with a gold glow when it is the player's step), a gold
-- title over up to two lines, its objectives under the title in plain text, and a check mark at the right once it is
-- done; a blue wash when it is the one being previewed. While the mouse is over the row an arrow takes the check's
-- place and makes this the player's current step. The same row is also a section header (a chapter's name with a
-- fold button), switched by fill().
local function makeRow(width)
  return function(parent, i)
    local style = ns.compassStyle
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, ROW)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * ROW)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetColorTexture(0.25, 0.65, 1.0, 0.22)
    b.sel:Hide()
    addHeaderLook(b, width)

    -- A step: a glow behind the icon, the icon, the title and the objectives. A step that is done shows a check mark
    -- where its icon would be. The icon is also a button: while the mouse is over the row it takes the current step's
    -- look (the glow) and clicking it makes this the player's current step.
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetTexture(style.textures.markerFill)
    b.glow:SetVertexColor(1, 0.82, 0.2, 0.35)
    b.glow:SetSize(ICON + 12, ICON + 12)
    b.glow:Hide()
    b.icon = CreateFrame("Button", nil, b)
    b.icon:SetSize(ICON, ICON)
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -5)
    b.glow:SetPoint("CENTER", b.icon, "CENTER")
    ns.badge.build(b.icon)
    b.tick = b:CreateTexture(nil, "OVERLAY")
    b.tick:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
    if b.tick.SetDesaturated then b.tick:SetDesaturated(true) end
    b.tick:SetVertexColor(TICK_GREY, TICK_GREY, TICK_GREY)
    b.tick:SetSize(ICON, ICON)
    b.tick:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -5)
    b.tick:Hide()
    local left = 6 + ICON + 8
    local textWidth = width - left - 10
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("TOPLEFT", b, "TOPLEFT", left, -5)
    b.label:SetWidth(textWidth)
    b.label:SetJustifyH("LEFT")
    b.label:SetMaxLines(2)       -- a title longer than two lines is cut, it does not run into the next row
    b.objectives = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.objectives:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 6, -2)
    b.objectives:SetWidth(textWidth - 6)
    b.objectives:SetJustifyH("LEFT")
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    b.icon:SetScript("OnClick", function()
      GameTooltip:Hide()
      ns.guidePlayer.jump(b.chapter, b.step)
    end)
    b.icon:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Make this your current step")
      GameTooltip:Show()
    end)
    -- The icon is a child of the row, so moving onto it leaves the row: only stop hovering when the mouse is on neither.
    local function unhover()
      if not mouseOver(b) then
        b.hover = false
        Br.paintRow(b)
      end
    end
    b.icon:SetScript("OnLeave", function()
      GameTooltip:Hide()
      unhover()
    end)
    b:SetScript("OnEnter", function()
      if b.isHeader then return end
      b.hover = true
      Br.paintRow(b)
    end)
    b:SetScript("OnLeave", unhover)
    return b
  end
end

-- A scrolling column: it runs from under the header to above the buttons, whatever the frame's height.
local function scroller(parent, name, x, width, anchor)
  local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
  if anchor then
    scroll:SetPoint("TOPLEFT", anchor.frame, "TOPLEFT", anchor.x, -anchor.top)
    scroll:SetPoint("BOTTOMLEFT", anchor.frame, "BOTTOMLEFT", anchor.x, anchor.bottom)
  else
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -TOP)
    scroll:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, BOTTOM)
  end
  scroll:SetWidth(width - 22)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(width - 22, 1)
  scroll:SetScrollChild(content)
  return content, scroll
end

-- Scrolls a column so row i (rows of the given height) is in the middle of its view, or as near as the column allows.
local function scrollTo(scroll, i, height, top)
  if not (scroll and scroll.SetVerticalScroll and i) then return end
  local view = scroll:GetHeight()
  view = math.max(type(view) == "number" and view or 0, height)
  -- `top` is where the row starts when rows differ in height; otherwise rows are `height` each.
  local y = math.max(0, (top or (i - 1) * height) - (view - height) / 2)
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
  local left, right = Br.rows(player, selected, query)
  local chapter, step
  for i, row in ipairs(left) do
    if row.chapter == selected then chapter = i end
  end
  for i, row in ipairs(right) do
    if row.state == "current" then step = i end
  end
  -- Looking at search results, the place to show is the top of them.
  if query ~= "" then chapter, step = 1, 1 end
  local function go()
    if dock.page == "chapters" then
      scrollTo(dock.leftScroll, chapter, CARD)
    else
      local top, height = dock.rowTop and dock.rowTop[step or 1], dock.rowHeight and dock.rowHeight[step or 1]
      scrollTo(dock.rightScroll, step or 1, height or ROW, top)
    end
  end
  go()
  if C_Timer and C_Timer.After then C_Timer.After(0.05, go) end
end

-- Fills the panel from the player's state.
local function fill(f, player)
  local S = player.state()
  local left, right = Br.rows(player, selected, query)

  f.setLeft(#left)
  for i, row in ipairs(left) do
    local b = f.leftRows.items[i]
    local place = text.chapterParts(row.label)
    local state = row.chapter == selected and "current" or row.state
    b.label:SetText(colored(state, place))
    b.sub:SetText(Br.subtitle(row))
    b.bar.set(row.fraction, BAR_COLORS[row.state] or BAR_COLORS.todo)
    b.chapter, b.done, b.total, b.fraction = row.chapter, row.done, row.total, row.fraction
  end
  f.setRight(#right)
  -- Not searching: the one chapter's section header sits above the rows (searching, each chapter's header is a row).
  local searching = query ~= ""
  local y = 0
  local section = f.section
  section:SetShown(not searching)
  if not searching then
    local label, isFolded
    for _, row in ipairs(left) do
      if row.chapter == selected then label = text.chapterParts(row.label) end
    end
    isFolded = folded[selected] == true
    section.chapter = selected
    setHeaderLook(section, true, label or "", isFolded)
    y = SECTION_H
  end
  f.rowTop, f.rowHeight = {}, {}
  for i, row in ipairs(right) do
    local b = f.rightRows.items[i]
    local header = row.header == true
    b.isHeader = header
    -- A section header names a chapter; any other row is a step.
    -- (while searching, a header also says how many of the chapter's steps matched)
    setHeaderLook(b, header, header and string.format("%s  |cff9a9484(%d)|r", row.label, row.count) or "", row.folded)
    b.label:SetShown(not header)
    b.objectives:SetShown(not header)
    local h
    if header then
      b.row = nil
      b.hover = false
      b.sel:Hide()
      b.glow:Hide()
      b.tick:Hide()
      b.icon:Hide()
      h = SECTION_H
    else
      b.row = row
      ns.badge.draw(b.icon, row.icon, ICON)
      Br.paintRow(b)
      local lines = row.objectives
      b.sel:SetShown(preview ~= nil and preview.chapter == row.chapter and preview.step == row.step)
      -- The row is as tall as its text: the title, then the objectives under it (measured when the client can say, a
      -- line each otherwise), never shorter than its icon needs.
      local titleH = b.label:GetStringHeight()
      titleH = type(titleH) == "number" and titleH > 0 and titleH or 14
      local objectivesH = 0
      if #lines > 0 then
        objectivesH = b.objectives:GetStringHeight()
        objectivesH = type(objectivesH) == "number" and objectivesH > 0 and objectivesH or 12 * #lines
        objectivesH = objectivesH + 2
      end
      h = math.max(ROW, math.ceil(10 + titleH + objectivesH))
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f.rightContent, "TOPLEFT", 0, -y)
    b:SetHeight(h)
    f.rowTop[i], f.rowHeight[i] = y, h
    y = y + h
    b.chapter, b.step = row.chapter, row.step
  end
  f.rightContent:SetHeight(math.max(1, y))
  -- The page: the chapter list shows the whole guide's progress and the guide's title; a chapter's steps show that
  -- chapter's progress and its name, with the back arrow.
  local onSteps = f.page == "steps"
  local shownRows = onSteps and #right or #left
  f.empty:SetShown(query ~= "" and shownRows == 0)
  f.leftScroll:SetShown(not onSteps)
  f.rightScroll:SetShown(onSteps)
  f.back:SetShown(onSteps)
  local title = ns.guide and ns.guide.title or "Guide"
  if onSteps then
    for _, row in ipairs(left) do
      if row.chapter == selected then title = text.chapterParts(row.label) end
    end
  end
  f.title:SetText(title)
  local label, n, total = Br.counter(player, selected, f.page)
  f.counter.text:SetText(string.format("|cffe9b949%s:|r |cffffffff%d/%d|r", label, n, total))
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
  -- A mistake in filling the panel is said once in chat (the error pop-up may be off), then raised as before.
  local ok, err = pcall(fill, dock, player)
  if not ok then
    if not reportedError then
      reportedError = true
      ns:Print("the guide panel hit an error: " .. tostring(err))
    end
    error(err, 0)
  end
end

-- The second line of a chapter card: "Lv 12-14 - 48%".
function Br.subtitle(row)
  local lv = row.levels
  if type(lv) == "table" and lv[1] then
    local text = lv[2] and lv[2] ~= lv[1] and string.format("Lv %d-%d", lv[1], lv[2]) or string.format("Lv %d", lv[1])
    return "|cffb8c7cc" .. text .. "|r"
  end
  return ""
end

-- The count shown beside the search box, like the quest log's "Quests: 1/40": "Steps: 3/80" (the player's step in the
-- chapter being shown: its number once it is the player's chapter, all of them once done, none yet when still to come)
-- on a chapter's steps, "Chapters: 4/55" (the player's chapter) on the list. Returns the label and the two numbers.
function Br.counter(player, chapter, page)
  local S = player.state()
  local left = Br.rows(player, chapter)
  if page == "chapters" then
    local current = 0
    for i, row in ipairs(left) do
      if row.state == "current" then current = i end
    end
    if current == 0 and #left > 0 and left[#left].state == "done" then current = #left end
    return "Chapters", current, #left
  end
  for _, row in ipairs(left) do
    if row.chapter == chapter then
      local n = 0
      if row.state == "done" then n = row.total elseif row.state == "current" then n = math.min(row.total, row.done + 1) end
      return "Steps", n, row.total
    end
  end
  return "Steps", 0, 0
end

-- How far through the guide the player is, for the map button: the whole guide's fraction, and the current chapter's
-- fraction and name. All 0 and no name when there is no plan.
function Br.progress()
  local player = ns.guidePlayer
  local S = player and player.state()
  if not S then return 0, 0, nil end
  local overall = planner.progress(S.view, S.flat, S.cursor)
  local entry = player.current()
  local chapter = entry and entry.chapter
  local fraction, name = 0, nil
  if chapter and overall.chapters[chapter] then
    fraction = overall.chapters[chapter].fraction
    for _, ch in ipairs(S.view) do
      if ch.index == chapter then name = text.chapterParts(ch.name) end
    end
  end
  return overall.fraction, fraction, name
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

-- The search box: an input box with a hint while it is empty and a clear button while it is not. Typing narrows the
-- lists as you go; Escape clears it, then leaves it.
local function makeSearch(parent, width)
  local ok, box = pcall(CreateFrame, "EditBox", "RibbonGuideSearch", parent, "SearchBoxTemplate")
  if not (ok and type(box) == "table" and box.SetAutoFocus) then
    box = CreateFrame("EditBox", "RibbonGuideSearch", parent, "InputBoxTemplate")
  end
  box:SetSize(width, 20)
  box:SetAutoFocus(false)
  box:SetMaxLetters(60)

  -- The game's search box (SearchBoxTemplate) brings its own magnifier, placeholder text and clear button, so a second
  -- hint drawn over it would double up: use its placeholder, keep its scripts and listen alongside them.
  if type(box.Instructions) == "table" and box.Instructions.SetText then
    box.Instructions:SetText("Search chapters and steps")
    box.templated = true
    function box.sync() end
    box:HookScript("OnTextChanged", function(self) Br.setQuery(self:GetText() or "", true) end)
    return box
  end

  box.hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  box.hint:SetPoint("LEFT", box, "LEFT", 6, 0)
  box.hint:SetText("Search chapters and steps")
  box.clear = CreateFrame("Button", nil, box)
  box.clear:SetSize(16, 16)
  box.clear:SetPoint("RIGHT", box, "RIGHT", -2, 0)
  box.clear.x = box.clear:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  box.clear.x:SetPoint("CENTER")
  box.clear.x:SetText("x")
  box.clear:Hide()
  -- The hint and the clear button follow what the box holds.
  function box.sync()
    local t = box:GetText() or ""
    box.hint:SetShown(t == "")
    box.clear:SetShown(t ~= "")
  end
  box.clear:SetScript("OnClick", function()
    box:SetText("")
    box.sync()
    Br.setQuery("")
    box:ClearFocus()
  end)
  box:SetScript("OnTextChanged", function(self)
    self.sync()
    Br.setQuery(self:GetText() or "", true)
  end)
  box:SetScript("OnEscapePressed", function(self)
    if (self:GetText() or "") ~= "" then
      self:SetText("")
      self.sync()
      Br.setQuery("")
    else
      self:ClearFocus()
    end
  end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return box
end

-- Blizzard's own frame (ButtonFrameTemplate: the map's bronze bezel, title bar, red close button and inset), so the panel
-- looks like the map beside it. Only when the template's helper exists and the frame can be made; otherwise the gold
-- bezel drawn in build() stands in, in the same colours and width.
local function nativeFrame()
  if type(_G.ButtonFrameTemplate_HidePortrait) ~= "function" then return nil end
  local ok, f = pcall(CreateFrame, "Frame", "RibbonGuideDock", WorldMapFrame, "ButtonFrameTemplate")
  if not (ok and type(f) == "table") then return nil end
  pcall(_G.ButtonFrameTemplate_HidePortrait, f)
  -- The template reserves a bar for buttons at the bottom and a band under the title; the panel needs neither, so the
  -- content gets the room and sits right under the title bar.
  if type(_G.ButtonFrameTemplate_HideButtonBar) == "function" then pcall(_G.ButtonFrameTemplate_HideButtonBar, f) end
  if type(f.TopTileStreaks) == "table" and f.TopTileStreaks.Hide then f.TopTileStreaks:Hide() end
  local inset = f.Inset
  if type(inset) == "table" and inset.SetPoint then
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -26)
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
  end
  return f
end

-- Builds the panel as a child of the world map, so it shows and hides with the map.
local function build()
  local style = ns.compassStyle
  local B = style.bezel.band
  local width = COLUMN_W + 2 * B + 12
  local f = nativeFrame()
  local native = f ~= nil
  if not native then f = CreateFrame("Frame", "RibbonGuideDock", WorldMapFrame) end
  f.native = native
  f:SetWidth(width)
  f:EnableMouse(true)
  local content, anchor   -- the frame the content hangs from, and how the lists attach to it

  if native then
    -- (A real frame has these as frames; anything else is not one.)
    content = type(f.Inset) == "table" and f.Inset.SetPoint and f.Inset or f
    anchor = { frame = content, x = 8, top = 8 + SEARCH_H + 4, bottom = 8 }
    -- The title goes through the template's own title text.
    f.title = {
      SetText = function(_, t)
        if f.SetTitle then f:SetTitle(t) elseif f.TitleText then f.TitleText:SetText(t) end
      end,
    }
    f.title:SetText(ns.guide and ns.guide.title or "Guide")
    f.close = type(f.CloseButton) == "table" and f.CloseButton.SetScript and f.CloseButton or nil
    if not f.close then
      f.close = CreateFrame("Button", nil, f)
      f.close:SetSize(22, 22)
      f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    end
    f.close:SetScript("OnClick", function() Br.setDock(false) end)
    f.close:Hide()   -- the map button closes the panel, so the frame needs no X
  else
    content = f
    local p = style.panel
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(p.body))
    addBezel(f)

    -- The title bar, like the map's: the title in the middle and a close button on the right.
    local strip = f:CreateTexture(nil, "ARTWORK")
    strip:SetColorTexture(unpack(p.strip))
    strip:SetPoint("TOPLEFT", f, "TOPLEFT", B, -B)
    strip:SetPoint("TOPRIGHT", f, "TOPRIGHT", -B, -B)
    strip:SetHeight(style.bezel.title)
    f.strip = strip
    local rule = f:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(p.gold[1], p.gold[2], p.gold[3], 0.7)   -- a fine gold line under it
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", strip, "BOTTOMLEFT")
    rule:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("CENTER", strip, "CENTER", 0, 0)
    f.title:SetWidth(width - 2 * B - 64)     -- clear of the back arrow and the close button
    f.title:SetWordWrap(false)
    f.title:SetText(ns.guide and ns.guide.title or "Guide")
    f.title:SetTextColor(unpack(p.gold))   -- gold, like "Map & Quest Log"

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
    f.close:Hide()   -- the map button closes the panel, so the frame needs no X
  end
  -- The back arrow, on the child page: a button with the caret pointing left. The same in both looks, and drawn from
  -- Ribbon's own textures, so it is always there.
  f.back = CreateFrame("Button", nil, f)
  f.back:SetSize(22, 22)
  -- It sits at the start of the search row, inside the panel's own content (the title bar is the template's, and
  -- anything put there can be hidden under its art).
  if native then
    f.back:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -7)
  else
    f.back:SetPoint("TOPLEFT", f, "TOPLEFT", B + 8, -(B + style.bezel.title + 5))
  end
  f.back:SetFrameLevel(f:GetFrameLevel() + 20)
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

  -- The search box, under the title bar.
  f.search = makeSearch(f, width - 2 * (B + 8) - 30 - COUNTER_W - 6 - (native and 8 or 0))
  if native then
    f.search:SetPoint("TOPLEFT", content, "TOPLEFT", 38, -8)
  else
    f.search:SetPoint("TOPLEFT", f, "TOPLEFT", B + 8 + 30, -(B + style.bezel.title + 6))
  end

  -- The count, in a box of its own at the right of the search row, like the quest log's "Quests: 1/40".
  f.counter = CreateFrame("Frame", nil, f)
  f.counter:SetSize(COUNTER_W, 20)
  if native then
    f.counter:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, -8)
  else
    f.counter:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(B + 8), -(B + style.bezel.title + 6))
  end
  f.counter.bg = f.counter:CreateTexture(nil, "BACKGROUND")
  f.counter.bg:SetAllPoints()
  f.counter.bg:SetColorTexture(0.09, 0.07, 0.05, 0.9)
  f.counter.edges = {}
  for n, edge in ipairs({ "TOP", "BOTTOM" }) do
    local line = f.counter:CreateTexture(nil, "BORDER")
    line:SetColorTexture(style.panel.gold[1], style.panel.gold[2], style.panel.gold[3], 0.4)
    line:SetHeight(1)
    line:SetPoint(edge .. "LEFT")
    line:SetPoint(edge .. "RIGHT")
    f.counter.edges[n] = line
  end
  f.counter.text = f.counter:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.counter.text:SetPoint("CENTER")


  -- Shown over the lists when a search finds nothing.
  f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  f.empty:SetPoint("TOP", f, "TOP", 0, -(TOP + 24))
  f.empty:SetText("Nothing matches")
  f.empty:Hide()

  -- Two lists in the same place, one per page: the chapters (left rows) and a chapter's steps (right rows).
  f.leftRows, f.rightRows = {}, {}
  f.page = "steps"
  local left, right
  left, f.leftScroll = scroller(f, "RibbonGuideDockChapters", B + 6, COLUMN_W, anchor)
  right, f.rightScroll = scroller(f, "RibbonGuideDockSteps", B + 6, COLUMN_W, anchor)
  f.rightContent = right
  -- The chapter's section header, at the top of the step list: it scrolls with the steps and folds them away.
  f.section = CreateFrame("Button", nil, right)
  f.section:SetSize(COLUMN_W - 22, SECTION_H)
  f.section:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
  addHeaderLook(f.section, COLUMN_W - 22)
  f.section:SetScript("OnClick", function(self) Br.toggleFold(self.chapter) end)
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
      if self.isHeader then
        Br.toggleFold(self.chapter)
        return
      end
      Br.preview(self.chapter, self.step)
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
  -- The back arrow is raised with it, so it stays over the title bar's art whatever level the panel ends up at.
  if dock.back then dock.back:SetFrameLevel(dock:GetFrameLevel() + 20) end
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
  if preview then
    preview = nil
    if ns.map then ns.map.clearPreview() end
  end
  Br.refresh()
  Br.scrollToCurrent()
end)

-- Shows a step on the world map: the map switches to the step's zone, its icon is drawn there and the map centres on it.
-- A step with no place on the map just gets the selection wash. Nothing about the player's place in the guide changes.
function Br.preview(chapter, step)
  if not dock then return end
  preview = { chapter = chapter, step = step }
  Br.refresh()
  local _, right = Br.rows(ns.guidePlayer, selected)
  for _, row in ipairs(right) do
    if row.chapter == chapter and row.step == step then
      if ns.map then
        if row.map then ns.map.preview(row.map, row.x, row.y, row.icon) else ns.map.clearPreview() end
      end
      return
    end
  end
end

-- Puts the preview away (the pin and the selection wash; the map stays where it is).
function Br.clearPreview()
  if not preview then return end
  preview = nil
  if ns.map then ns.map.clearPreview() end
  Br.refresh()
end

-- Folds a chapter's section away, or opens it again.
function Br.toggleFold(chapter)
  folded[chapter] = not folded[chapter] or nil
  Br.refresh()
end

-- The child page: a chapter's steps (the browsed chapter when none is given).
function Br.showSteps(chapter)
  if not dock then return end
  if chapter and chapter ~= selected then Br.clearPreview() end
  if chapter then selected = chapter end
  dock.page = "steps"
  Br.refresh()
  Br.scrollToCurrent()
end

-- The parent page: the chapters.
function Br.showChapters()
  if not dock then return end
  Br.clearPreview()
  dock.page = "chapters"
  Br.refresh()
  Br.scrollToCurrent()
end

-- Narrows the lists to what matches the text (an empty text shows everything). `fromBox` is true when the text came from
-- typing in the box, which must not be rewritten while the player is typing.
function Br.setQuery(q, fromBox)
  q = tostring(q or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if q == query then return end
  query = q
  if not dock then return end
  if not fromBox and (dock.search:GetText() or "") ~= q then
    dock.search:SetText(q)
    dock.search.sync()
  end
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
  if not shown then Br.clearPreview() end
  if ns.db then ns.db.guideDock = shown and true or false end
  if shown then
    selected = nil
    folded = {}      -- a new look starts with every section open
    Br.setQuery("")  -- ... and nothing searched for
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
