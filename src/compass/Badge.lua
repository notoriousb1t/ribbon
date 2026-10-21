-- Badges: the round icons a waypoint or a guide step is drawn with, on the compass, in the guide's step list, on the
-- world map's pins and on its preview pin. A badge is a dark disc with a rim and the kind's icon inside. The quest kinds
-- (! and ?) are drawn like Blizzard's own quest icons: a dark warm disc, a gold bevelled ring and a gold symbol with a
-- dark outline. An icon with no entry in Style.badge (TomTom's dot, RXP's arrow, the raid markers) is drawn plain, at
-- the full size. The look is Style.badge; this file only puts it on a frame.
local ADDON, ns = ...

local Bd = {}
ns.badge = Bd

-- Outlined, shadowed text stays readable over any background. The font file comes from the game's own font object so it
-- follows the player's UI font and language.
function Bd.styleText(fs, size)
  local base = _G.GameFontHighlight
  if base and base.GetFont then
    local ok, path = pcall(base.GetFont, base)
    if ok and path then fs:SetFont(path, size, "OUTLINE") end
  end
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
end

-- Adds the badge's parts to a frame: fill (the disc), rim, questRing (the quest badge's gold ring), glyphTex (its symbol)
-- and tex (the icon of the other kinds).
function Bd.build(f)
  local style = ns.compassStyle
  f.fill = f:CreateTexture(nil, "BACKGROUND")
  f.fill:SetTexture(style.textures.markerFill)
  f.fill:SetAllPoints()
  f.fill:SetVertexColor(unpack(style.badge.fillColor))
  f.rim = f:CreateTexture(nil, "BORDER")
  f.rim:SetTexture(style.textures.markerRim)
  f.rim:SetAllPoints()
  f.questRing = f:CreateTexture(nil, "BORDER")
  f.questRing:SetTexture(style.textures.questRing)
  f.questRing:SetAllPoints()
  f.questRing:Hide()
  f.glyphTex = f:CreateTexture(nil, "OVERLAY")
  f.glyphTex:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.glyphTex:Hide()
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetAllPoints()
end

-- Draws the badge for an icon name (a key of ns.ICONS) at a size in pixels (the frame's own size is the caller's).
function Bd.draw(f, icon, size)
  local style = ns.compassStyle
  local badge = style.badge
  local kind = badge.kinds[icon]
  f.tex:SetTexture(ns.ICONS[icon] or ns.ICONS[ns.DEFAULT_ICON])
  f.tex:ClearAllPoints()
  if not kind then
    f.fill:Hide()
    f.rim:Hide()
    f.questRing:Hide()
    f.glyphTex:Hide()
    f.tex:SetAllPoints(f)
    f.tex:Show()
    return
  end
  f.fill:Show()
  if kind.quest then
    -- Blizzard's quest icon: warm dark disc, gold bevelled ring, gold symbol.
    f.fill:SetVertexColor(unpack(badge.questFill))
    f.rim:Hide()
    f.questRing:Show()
    local g = math.floor(size * badge.questGlyphScale + 0.5)
    f.glyphTex:SetTexture(style.textures[kind.quest])
    f.glyphTex:SetVertexColor(1, 1, 1, 1)
    f.glyphTex:SetSize(g, g)
    f.glyphTex:Show()
    f.tex:Hide()
    return
  end
  -- The other kinds: a dark disc, a coloured rim, the kind's icon inside.
  local color = kind.color
  f.fill:SetVertexColor(unpack(badge.fillColor))
  f.rim:SetVertexColor(color[1], color[2], color[3], 1)
  f.rim:Show()
  f.questRing:Hide()
  f.glyphTex:Hide()
  if kind.glyph then
    -- An inked symbol of our own, like the quest kinds'.
    local g = math.floor(size * badge.glyphScale + 0.5)
    f.glyphTex:SetTexture(style.textures[kind.glyph])
    f.glyphTex:SetVertexColor(color[1], color[2], color[3], 1)   -- the symbol takes the rim's colour
    f.glyphTex:SetSize(g, g)
    f.glyphTex:Show()
    f.tex:Hide()
    return
  end
  local icon_ = math.floor(size * badge.iconScale + 0.5)
  f.tex:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.tex:SetSize(icon_, icon_)
  f.tex:Show()
end
