-- Badges: the icons a waypoint or a guide step is drawn with, on the compass, in the guide's step list, on the world map's
-- pins and on its preview pin. An icon is just its symbol: the quest kinds' gold "!" and "?" (drawn like Blizzard's own
-- quest icons, with a dark outline), the other kinds' inked symbol in the kind's colour, and anything else (TomTom's dot,
-- RXP's arrow, the raid markers) as its plain texture. The tracked (active) one is set on a dark disc inside a ring: the
-- gold bevelled quest ring for the quest kinds, a ring in the kind's colour for the rest. The look is Style.badge; this file
-- only puts it on a frame.
local ADDON, ns = ...

local Bd = {}
ns.badge = Bd

-- Outlined, shadowed text stays readable over any background. The font file comes from the game's own font object so it
-- follows the player's UI font and language.
Bd.DIAMOND = 1.4

function Bd.styleText(fs, size)
  local base = _G.GameFontHighlight
  if base and base.GetFont then
    local ok, path = pcall(base.GetFont, base)
    if ok and path then fs:SetFont(path, size, "OUTLINE") end
  end
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
end

-- The name of the first font object that exists on this client (a font template that is missing is an error).
function Bd.fontObject(...)
  for i = 1, select("#", ...) do
    local name = select(i, ...)
    if _G[name] then return name end
  end
  return "GameFontNormal"
end

-- Adds the icon's parts to a frame: fill (the dark disc) and rim and questRing (the ring) shown while tracked, glyphTex (the symbol of the kinds that have
-- one) and tex (the plain icon of the others).
function Bd.build(f)
  local style = ns.compassStyle
  f.fill = f:CreateTexture(nil, "BACKGROUND")
  f.fill:SetTexture(style.textures.diamondFill)
  f.fill:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.fill:Hide()
  f.rim = f:CreateTexture(nil, "BORDER")
  f.rim:SetTexture(style.textures.diamondRim)
  f.rim:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.rim:Hide()
  f.questRing = f:CreateTexture(nil, "BORDER")
  f.questRing:SetTexture(style.textures.diamondRing)
  f.questRing:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.questRing:Hide()
  f.glyphTex = f:CreateTexture(nil, "OVERLAY")
  f.glyphTex:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.glyphTex:Hide()
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetAllPoints()
end

-- Draws the tracked look so that its diamond is `ring` pixels across, for places with a fixed height (the compass band, the
-- caption): the symbol is sized to fit inside the diamond.
function Bd.drawFitted(f, icon, ring)
  local size = math.max(6, math.floor(ring / Bd.DIAMOND - 2 + 0.5))
  Bd.draw(f, icon, size, true, 2)
end

-- Draws the icon for an icon name (a key of ns.ICONS) at a size in pixels (the frame's own size is the caller's), with the
-- tracked ring around it when `tracked` is true; the ring is `pad` pixels larger than the icon (default Style.focusRing.pad).
function Bd.draw(f, icon, size, tracked, pad)
  local style = ns.compassStyle
  local kind = style.badge.kinds[icon]
  if kind and (kind.quest or kind.glyph) then
    f.glyphTex:SetTexture(style.textures[kind.quest or kind.glyph])
    local c = kind.color
    if c then f.glyphTex:SetVertexColor(c[1], c[2], c[3], 1) else f.glyphTex:SetVertexColor(1, 1, 1, 1) end
    f.glyphTex:SetSize(size, size)
    f.glyphTex:Show()
    f.tex:Hide()
  else
    f.glyphTex:Hide()
    f.tex:SetTexture(ns.ICONS[icon] or ns.ICONS[ns.DEFAULT_ICON])
    f.tex:ClearAllPoints()
    f.tex:SetAllPoints(f)
    f.tex:Show()
  end
  -- The diamond's points touch the middle of its sides, so it is drawn larger than a disc to keep the symbol inside it.
  local ring = math.floor((size + (pad or style.focusRing.pad)) * Bd.DIAMOND + 0.5)
  f.fill:SetSize(ring, ring)
  f.rim:SetSize(ring, ring)
  f.questRing:SetSize(ring, ring)
  f.fill:SetShown(tracked and true or false)
  if tracked and kind and kind.quest then
    f.fill:SetVertexColor(unpack(style.badge.questFill))
    f.rim:Hide()
    f.questRing:Show()
  elseif tracked then
    f.fill:SetVertexColor(unpack(style.badge.fillColor))
    local c = kind and kind.color or style.panel.gold
    f.rim:SetVertexColor(c[1], c[2], c[3], 1)
    f.rim:Show()
    f.questRing:Hide()
  else
    f.rim:Hide()
    f.questRing:Hide()
  end
end
