-- TomTom bridge: mirrors waypoints other addons (or /way) set in TomTom into Ribbon's compass.
-- Ribbon never installs a TomTom global or /way; if TomTom is absent this module does nothing.
-- TomTom is observed with hooksecurefunc, so it behaves exactly as before.
--
-- TomTom already draws its own world map and minimap icons, so mirrored waypoints are compass-only
-- (otherwise every waypoint would be drawn twice on the maps).
local ADDON, ns = ...

local B = {}
ns.tomtomBridge = B

local translate = ns.tomtomTranslate

local mirror = {}      -- key -> Ribbon waypoint uid, for waypoints that came from TomTom
local hooked = {}      -- names of the TomTom functions that were hooked
local tomtom

local function context()
  return { tomtom = tomtom, isValidMap = ns.client.isValidMap }
end

-- Mirroring ------------------------------------------------------------------

-- Use the dot TomTom itself draws on the world map, following the theme the player picked in TomTom.
-- Falls back to the default already in ns.ICONS when TomTom's theme data is not readable.
local function refreshIcon()
  local ok, texture = pcall(function()
    local theme = tomtom.db.profile.worldmap.theme
    return tomtom.waypointThemeRegistry:GetThemeDotTexture(theme)
  end)
  if ok and type(texture) == "string" and texture ~= "" then ns.ICONS.tomtom = texture end
end

local function track(req)
  local key = translate.keyOf(req)
  local existing = mirror[key]
  if existing and ns:GetWaypoint(existing) then return end
  refreshIcon()
  local uid = ns:AddWaypoint(req.mapID, req.x, req.y, {
    title = req.title or "TomTom waypoint",
    icon = "tomtom",
    minimap = false,
    worldmap = false,
    lines = { "Set through TomTom" },
  })
  if uid then mirror[key] = uid end
end

local function untrack(key)
  local uid = mirror[key]
  mirror[key] = nil
  if uid then ns:RemoveWaypoint(uid) end
end

-- Add everything TomTom holds right now (waypoints restored before the hooks were installed).
function B.resync()
  local waypoints = tomtom and tomtom.waypoints
  if type(waypoints) ~= "table" then return 0 end
  local count, ctx = 0, context()
  for _, byKey in pairs(waypoints) do
    if type(byKey) == "table" then
      for _, uid in pairs(byKey) do
        local req = translate.fromUID(uid, ctx)
        if req then
          track(req)
          count = count + 1
        end
      end
    end
  end
  return count
end

-- Hooks --------------------------------------------------------------------------

-- Errors in our code must never reach TomTom's caller.
local function guarded(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
  end
end

-- RemoveWaypoint(uid) is the public removal; ClearWaypoint(uid) is what it, ClearAllWaypoints and
-- arrival clearing all call, so hooking both covers every way a waypoint goes away.
local REMOVERS = { "RemoveWaypoint", "ClearWaypoint" }

function B.install(target)
  tomtom = target
  if type(tomtom.AddWaypoint) == "function" then
    hooksecurefunc(tomtom, "AddWaypoint", guarded(function(...)
      local req = translate.fromAddWaypoint({ n = select("#", ...), ... }, context())
      if req then track(req) end
    end))
    hooked[#hooked + 1] = "AddWaypoint"
  end
  for _, name in ipairs(REMOVERS) do
    if type(tomtom[name]) == "function" then
      hooksecurefunc(tomtom, name, guarded(function(self, uid)
        if self ~= tomtom then uid = self end
        local req = translate.fromUID(uid, context())
        if req then untrack(translate.keyOf(req)) end
      end))
      hooked[#hooked + 1] = name
    end
  end
end

-- Diagnostics: /ribbon tomtom
ns.commands.tomtom = function()
  if not tomtom then
    ns:Print("TomTom is not loaded; nothing to mirror.")
    return
  end
  local mirrored = 0
  for _ in pairs(mirror) do mirrored = mirrored + 1 end
  ns:Print("TomTom found. Hooked: " .. (#hooked > 0 and table.concat(hooked, ", ") or "nothing") ..
    ". Mirrored waypoints: " .. mirrored .. ".")
end

ns:On("INIT", function()
  if type(_G.TomTom) ~= "table" then return end
  B.install(_G.TomTom)
  B.resync()
end)
