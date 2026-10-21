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
local HEADER_H = 24                          -- the section header ("Steps"), like the quest log's zone header
local TOP = BEZEL.band + BEZEL.title + 6 + SEARCH_H + HEADER_H + 10   -- room for the bezel, title bar, search box and header
local BOTTOM = BEZEL.band + 8               -- room for the bezel

local COLORS = {
  done = "|cff808080", current = "|cffe9b949", todo = "|cfff3ead2",
}

local dock, selected   -- the docked panel; selected: guide chapter index being browsed (nil: the active chapter)
local query = ""       -- what the search box holds, trimmed
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
  local base = 0
  for _, ch in ipairs(S.view) do
    if ch.index == chapter then
      for i, s in ipairs(ch.steps) do
        if not filtering or search.matches(query, stepText(s.step, S.guide.names)) then
          local map, x, y = planner.stepLocation(s.step)
          right[#right + 1] = {
            chapter = s.chapter, step = s.index, state = outline.steps[base + i],
            label = text.summary(s.step, S.guide.names, env),
            icon = text.stepIcon(s.step), map = map, x = x, y = y,
          }
        end
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
local GO = 22                            -- the hover button that moves the player's place to the step

-- Is the mouse over a frame? (Frame:IsMouseOver is the retail call; MouseIsOver the older one.)
local function mouseOver(frame)
  if frame.IsMouseOver then return frame:IsMouseOver() end
  return MouseIsOver and MouseIsOver(frame) or false
end

-- A step row: the step's icon, its text over up to two lines, a blue wash when it is the one being previewed, and a
-- button at the right, shown while the mouse is over the row, that makes this the player's current step.
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
    b.icon = CreateFrame("Frame", nil, b)
    b.icon:SetSize(ICON, ICON)
    b.icon:SetPoint("LEFT", b, "LEFT", 4, 0)
    ns.badge.build(b.icon)
    local left = 4 + ICON + 6
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("LEFT", b, "LEFT", left, 0)
    b.label:SetWidth(width - left - GO - 8)
    b.label:SetJustifyH("LEFT")
    b.label:SetMaxLines(2)       -- two lines per step: a longer summary is cut, it does not run into the next row
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    b.go = CreateFrame("Button", nil, b)
    b.go:SetSize(GO, GO)
    b.go:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.go.bg = b.go:CreateTexture(nil, "ARTWORK")
    b.go.bg:SetTexture(style.textures.bezelButton)
    b.go.bg:SetAllPoints()
    b.go.caret = b.go:CreateTexture(nil, "OVERLAY")
    b.go.caret:SetTexture(style.textures.panelCaret)
    b.go.caret:SetTexCoord(1, 0, 0, 1)   -- pointing right: go here
    b.go.caret:SetSize(12, 12)
    b.go.caret:SetPoint("CENTER", b.go, "CENTER", 1, 0)
    b.go:SetHighlightTexture(style.textures.bezelButton, "ADD")
    b.go:Hide()
    b.go:SetScript("OnClick", function()
      GameTooltip:Hide()
      ns.guidePlayer.jump(b.chapter, b.step)
    end)
    b.go:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Make this your current step")
      GameTooltip:Show()
    end)
    -- The button is a child of the row, so moving onto it leaves the row: only hide when the mouse is on neither.
    b.go:SetScript("OnLeave", function()
      GameTooltip:Hide()
      if not mouseOver(b) then b.go:Hide() end
    end)
    b:SetScript("OnEnter", function() b.go:Show() end)
    b:SetScript("OnLeave", function()
      if not mouseOver(b) then b.go:Hide() end
    end)
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
local function scrollTo(scroll, i, height)
  if not (scroll and scroll.SetVerticalScroll and i) then return end
  local view = scroll:GetHeight()
  view = math.max(type(view) == "number" and view or 0, height)
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
      scrollTo(dock.rightScroll, step or 1, ROW)
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
  for i, row in ipairs(right) do
    local b = f.rightRows.items[i]
    b.label:SetText(colored(row.state, row.label))
    ns.badge.draw(b.icon, row.icon, ICON)
    b.sel:SetShown(preview ~= nil and preview.chapter == row.chapter and preview.step == row.step)
    b.chapter, b.step = row.chapter, row.step
  end
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
  -- The section header, like the quest log's: "Steps" or "Chapters" with a button that folds the list away.
  f.header.title:SetText(onSteps and "Steps" or "Chapters")
  local folded = f.folded[f.page] == true
  f.header.toggle.vertical:SetShown(folded)       -- a plus while folded, a minus while open
  f.leftScroll:SetShown(not onSteps and not folded)
  f.rightScroll:SetShown(onSteps and not folded)
  f.empty:SetShown(query ~= "" and shownRows == 0 and not folded)
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
  local lv = row.levels
  if type(lv) == "table" and lv[1] then
    local text = lv[2] and lv[2] ~= lv[1] and string.format("Lv %d-%d", lv[1], lv[2]) or string.format("Lv %d", lv[1])
    return "|cffb8c7cc" .. text .. "|r"
  end
  return ""
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
    anchor = { frame = content, x = 8, top = 8 + SEARCH_H + HEADER_H + 4, bottom = 8 }
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
  -- Ribbon's own textures, so it is always there; a high frame level keeps it over the title bar's art.
  f.back = CreateFrame("Button", nil, f)
  f.back:SetSize(22, 22)
  local titleBar = native and type(f.TitleContainer) == "table" and f.TitleContainer.SetPoint and f.TitleContainer or nil
  if titleBar then
    f.back:SetPoint("LEFT", titleBar, "LEFT", 6, 0)
  elseif native then
    f.back:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -6)
  else
    f.back:SetPoint("LEFT", f.strip, "LEFT", 2, 0)
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
  f.search = makeSearch(f, width - 2 * (B + 12) - (native and 12 or 0))
  if native then
    f.search:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -8)
  else
    f.search:SetPoint("TOPLEFT", f, "TOPLEFT", B + 12, -(B + style.bezel.title + 6))
  end

  -- The section header under the search box, in the style of the quest log's zone header: a dark bar with a thin gold
  -- border, the name of the section and a button at the right that folds the list away (a minus; a plus while folded).
  local header = CreateFrame("Button", nil, f)
  header:SetHeight(HEADER_H)
  if native then
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(8 + SEARCH_H + 6 - 6))
    header:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, -(8 + SEARCH_H + 6 - 6))
  else
    header:SetPoint("TOPLEFT", f, "TOPLEFT", B + 8, -(B + style.bezel.title + 6 + SEARCH_H))
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(B + 8), -(B + style.bezel.title + 6 + SEARCH_H))
  end
  header.bg = header:CreateTexture(nil, "BACKGROUND")
  header.bg:SetAllPoints()
  header.bg:SetColorTexture(0.10, 0.08, 0.05, 1)
  local gold = style.panel.gold
  for _, edge in ipairs({ "TOP", "BOTTOM" }) do
    local line = header:CreateTexture(nil, "BORDER")
    line:SetColorTexture(gold[1], gold[2], gold[3], 0.45)
    line:SetHeight(1)
    line:SetPoint(edge .. "LEFT")
    line:SetPoint(edge .. "RIGHT")
  end
  header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header.title:SetPoint("LEFT", header, "LEFT", 8, 0)
  header.title:SetTextColor(0.82, 0.78, 0.68)
  -- The fold button: a gold bar, with a second one across it for a plus.
  header.toggle = CreateFrame("Button", nil, header)
  header.toggle:SetSize(18, 18)
  header.toggle:SetPoint("RIGHT", header, "RIGHT", -4, 0)
  header.toggle.horizontal = header.toggle:CreateTexture(nil, "OVERLAY")
  header.toggle.horizontal:SetColorTexture(gold[1], gold[2], gold[3], 1)
  header.toggle.horizontal:SetSize(10, 3)
  header.toggle.horizontal:SetPoint("CENTER")
  header.toggle.vertical = header.toggle:CreateTexture(nil, "OVERLAY")
  header.toggle.vertical:SetColorTexture(gold[1], gold[2], gold[3], 1)
  header.toggle.vertical:SetSize(3, 10)
  header.toggle.vertical:SetPoint("CENTER")
  header.toggle.vertical:Hide()
  local function fold()
    f.folded[f.page] = not f.folded[f.page]
    Br.refresh()
  end
  header.toggle:SetScript("OnClick", fold)
  header:SetScript("OnClick", fold)
  f.header = header
  f.folded = {}

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
    Br.setQuery("")  -- a new look starts with nothing searched for
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
