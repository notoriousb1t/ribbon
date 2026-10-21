-- Badges: the round icons a waypoint or a guide step is drawn with, on the compass, in the guide's step list and on
-- the world map's preview pin. A badge is a dark disc with a coloured rim and a symbol in the same colour: text for
-- ! and ?, the kind's icon for the rest. An icon with no entry in Style.badge (TomTom's dot, RXP's arrow, the raid
-- markers) is drawn plain, at the full size. The look is Style.badge; this file only puts it on a frame.
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

-- Adds the badge's parts to a frame: fill, rim, glyph and tex (the icon).
function Bd.build(f)
  local style = ns.compassStyle
  f.fill = f:CreateTexture(nil, "BACKGROUND")
  f.fill:SetTexture(style.textures.markerFill)
  f.fill:SetAllPoints()
  f.fill:SetVertexColor(unpack(style.badge.fillColor))
  f.rim = f:CreateTexture(nil, "BORDER")
  f.rim:SetTexture(style.textures.markerRim)
  f.rim:SetAllPoints()
  f.glyph = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.glyph:SetPoint("CENTER", f, "CENTER", 0, style.badge.glyphOffsetY)
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetAllPoints()
end

-- Draws the badge for an icon name (a key of ns.ICONS) at a size in pixels (the frame's own size is the caller's).
function Bd.draw(f, icon, size)
  local badge = ns.compassStyle.badge
  local kind = badge.kinds[icon]
  f.tex:SetTexture(ns.ICONS[icon] or ns.ICONS[ns.DEFAULT_ICON])
  f.tex:ClearAllPoints()
  if not kind then
    f.fill:Hide()
    f.rim:Hide()
    f.glyph:Hide()
    f.tex:SetAllPoints(f)
    f.tex:Show()
    return
  end
  -- Usual badge: dark disc, coloured rim and symbol. Flipped: a solid disc in the colour, a dark symbol.
  local color, dark = kind.color, badge.fillColor
  if kind.flip then
    f.fill:SetVertexColor(color[1], color[2], color[3], 1)
    f.rim:SetVertexColor(color[1] * badge.flipRim, color[2] * badge.flipRim, color[3] * badge.flipRim, 1)
  else
    f.fill:SetVertexColor(unpack(dark))
    f.rim:SetVertexColor(color[1], color[2], color[3], 1)
  end
  f.fill:Show()
  f.rim:Show()
  if kind.glyph then
    local px = math.floor(size * badge.glyphScale + 0.5)
    if f.glyphSize ~= px then
      f.glyphSize = px
      Bd.styleText(f.glyph, px)
    end
    f.glyph:SetText(kind.glyph)
    if kind.flip then
      f.glyph:SetTextColor(dark[1], dark[2], dark[3], 1)
    else
      f.glyph:SetTextColor(color[1], color[2], color[3], 1)
    end
    f.glyph:Show()
    f.tex:Hide()
  else
    local icon = math.floor(size * badge.iconScale + 0.5)
    f.tex:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.tex:SetSize(icon, icon)
    f.tex:Show()
    f.glyph:Hide()
  end
end
