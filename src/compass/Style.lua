-- Compass style: the look of the bar as plain data (colours, sizes, texture paths). No frames.
-- The bar is the logo's ribbon: a teal band with swallowtail ends, cream ticks and labels, and a
-- compass dial under its bottom edge whose needle always points to due north (the coordinates are in the
-- dial's tooltip). The textures are image files in src/textures in the same shapes and
-- palette as the logo.
local ADDON, ns = ...

local S = {}
ns.compassStyle = S

local DIR = "Interface\\AddOns\\Ribbon\\textures\\"

S.textures = {
  capLeft = DIR .. "ribbon-cap-left",
  capRight = DIR .. "ribbon-cap-right",
  dial = DIR .. "compass-dial",
  needle = DIR .. "compass-needle",
  edgeArrow = DIR .. "edge-arrow",   -- points right; the view flips it for the left end
  focusRing = DIR .. "focus-ring",   -- gold ring drawn around the focused marker
}

-- Texture file names (without extension) under src/textures; the specs check they exist.
S.textureFiles = { "ribbon-cap-left", "ribbon-cap-right", "compass-dial", "compass-needle", "edge-arrow", "focus-ring" }

-- Swallowtail end caps, in display pixels. The left cap's box starts `leftEdge` pixels left of the
-- bar; the right cap's box mirrors it, so it starts `rightEdge` pixels left of the bar's right edge.
S.cap = { width = 32, height = 40, leftEdge = 18, rightEdge = 14 }

-- The dial sits centred on the bar and is taller than it, so it stands out above and below. It covers the tick marks
-- (the individual degrees) and the direction names; only the waypoint markers are drawn over it. The caption above the bar
-- is lifted by the dial's overhang so the two never touch.
-- `offsetY` nudges it (pixels, negative = down): it reads a pixel or two high against the icons at its centre.
S.dial = { size = 46, offsetY = -1 }
S.band = { highlight = 2, shadow = 2 }

-- Waypoint markers grow as you get close and shrink with distance (pixels). At `nearYd` yards or
-- closer a marker is `max` (taller than the 28 px ribbon, so it stands out of the band); at `farYd` or
-- beyond it is `min`; in between the size follows the logarithm of the distance, so each doubling of
-- distance shrinks it by the same amount. `default` is used when the distance is unknown.
-- The focused marker is `focusBoost` pixels larger than it would be otherwise.
-- A marker for a waypoint outside the view is held near the end of the bar, `edgeAlpha` opaque, with an
-- arrow `arrow` pixels wide pointing the way; `pad` pixels keep marker and arrow off the ribbon's tail.
S.marker = {
  min = 18, max = 38, nearYd = 15, farYd = 1200, default = 20, focusBoost = 4,
  pad = 3, arrow = 14, edgeAlpha = 0.7,
  -- Inside `settleYd` yards the bearing is eased toward the centre (scaled by distance / settleYd). The bearing of
  -- a point a few yards away swings wildly with every step, which made the marker shake on arrival.
  settleYd = 8,
}

-- The focused marker gets a ring `pad` pixels larger than the marker itself.
S.focusRing = { pad = 10 }

-- A thin bar along the bottom of the ribbon while the player is in combat.
S.combat = { height = 3 }

-- Direction labels (N, NE, ...): font pixels. They are outlined and shadowed to stand out.
S.labelSize = 12

-- How see-through the ribbon is (1 = solid). The default is also in core/Core.lua's saved defaults.
S.opacity = { default = 0.6, min = 0.2, max = 1 }

-- The same for the compass dial's face (its needle stays solid). The degree ticks under the dial are hidden, so a
-- see-through dial does not show them.
S.dialOpacity = { default = 0.7, min = 0.2, max = 1 }

-- Players who never changed the old ribbon default (0.75) get the new one once.
S.oldOpacityDefault = 0.75

-- The caption above the bar: a headline (name and distance) and a short description, on a dark plate
-- so they stay readable over any scenery. Sizes are font pixels; pad is plate padding.
S.caption = { headSize = 13, detailSize = 11, padX = 10, padY = 4, gap = 4, lineGap = 1, minWidth = 120 }

-- r, g, b, a
S.colors = {
  captionPlate = { 0.051, 0.212, 0.275, 0.88 },   -- the logo's dark teal
  detail = { 0.953, 0.918, 0.824, 1 },            -- description text: cream
  band = { 0.122, 0.478, 0.600, 0.92 },       -- #1f7a99
  highlight = { 0.165, 0.576, 0.710, 1 },     -- #2a93b5
  shadow = { 0.051, 0.212, 0.275, 1 },        -- #0d3646
  gold = { 0.914, 0.725, 0.286, 1 },          -- #e9b949
  cream = { 0.953, 0.918, 0.824, 1 },         -- #f3ead2
  north = { 0.886, 0.341, 0.298, 1 },         -- #e2574c
  combat = { 0.86, 0.12, 0.12, 1 },
  notch = { 0.953, 0.918, 0.824, 0.9 },
}
