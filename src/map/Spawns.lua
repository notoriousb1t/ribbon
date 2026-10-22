-- Objective locations: small red dots on the world map and the minimap for the places an objective's creatures and objects
-- are (the guide's :Spawns points), for the current step, or the step shown from the panel. Dots of an objective that is
-- done are left out. Optional (guide setting "spawnDots", on by default).
local ADDON, ns = ...

local Sp = {}
ns.spawnPins = Sp

local COLOR = { 0.92, 0.12, 0.12 }
local WORLD_SIZE, MINI_SIZE = 6, 5
local WORLD_MAX, MINI_MAX = 150, 30   -- most dots drawn; the minimap shows the ones nearest the player

local owner = {}                      -- the pin library keys icons by owner
local pools = { world = {}, mini = {} }
local shown = { world = {}, mini = {} }
local signature

local function lib() return ns.map and ns.map.lib end

local function dot(kind)
  local f = table.remove(pools[kind])
  if f then return f end
  f = CreateFrame("Frame", nil, UIParent)
  local size = kind == "world" and WORLD_SIZE or MINI_SIZE
  f:SetSize(size, size)
  local t = f:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints()
  t:SetTexture(ns.compassStyle.textures.markerFill)
  t:SetVertexColor(COLOR[1], COLOR[2], COLOR[3], 0.95)
  f.tex = t
  return f
end

local function clear()
  local l = lib()
  for _, f in ipairs(shown.world) do
    if l then l:RemoveWorldMapIcon(owner, f) end
    f:Hide()
    pools.world[#pools.world + 1] = f
  end
  for _, f in ipairs(shown.mini) do
    if l then l:RemoveMinimapIcon(owner, f) end
    f:Hide()
    pools.mini[#pools.mini + 1] = f
  end
  shown = { world = {}, mini = {} }
  signature = nil
end

-- The points of the open objectives of a step: { { map, x, y }, ... }.
local function points(entry)
  local out, ids = {}, {}
  for _, group in ipairs(entry.step.groups or {}) do
    for _, call in ipairs(group.calls or {}) do
      local s = call.spawns
      if s and type(s.map) == "number" and type(s.points) == "table" then
        local state = ns.guidePlayer and ns.guidePlayer.callState(call) or "open"
        if state ~= "done" then
          ids[#ids + 1] = tostring(call)
          for _, p in ipairs(s.points) do out[#out + 1] = { map = s.map, x = p[1], y = p[2] } end
        end
      end
    end
  end
  return out, table.concat(ids, ",")
end

-- Shows the dots for `entry` (a flat step entry of the guide player), or none for nil.
function Sp.show(entry)
  local l = lib()
  local enabled = l and entry and ns.guideSettings and ns.guideSettings.get("spawnDots")
  if not enabled then
    if signature ~= nil or #shown.world > 0 or #shown.mini > 0 then clear() end
    return
  end
  local pts, key = points(entry)
  local sig = tostring(entry.chapter) .. ":" .. tostring(entry.index) .. ":" .. key
  if sig == signature then return end
  clear()
  signature = sig
  local flag = _G.HBD_PINS_WORLDMAP_SHOW_CONTINENT
  for i = 1, math.min(#pts, WORLD_MAX) do
    local p = pts[i]
    local f = dot("world")
    shown.world[#shown.world + 1] = f
    l:AddWorldMapIconMap(owner, f, p.map, p.x / 100, p.y / 100, flag)
  end
  -- The minimap only reaches a short way: the dots nearest the player, on the player's own map.
  local map, px, py = ns.client.playerMapPosition()
  local near = {}
  for _, p in ipairs(pts) do
    if p.map == map then near[#near + 1] = { p = p, d = (p.x - px) ^ 2 + (p.y - py) ^ 2 } end
  end
  table.sort(near, function(a, b) return a.d < b.d end)
  for i = 1, math.min(#near, MINI_MAX) do
    local p = near[i].p
    local f = dot("mini")
    shown.mini[#shown.mini + 1] = f
    l:AddMinimapIconMap(owner, f, p.map, p.x / 100, p.y / 100, true, true)
  end
end

-- Without the step shown from the panel, the player's current step.
local function current()
  local S = ns.guidePlayer and ns.guidePlayer.state()
  return S and not S.finished and S.flat[S.cursor] or nil
end

ns:On("GUIDE_SETTINGS_CHANGED", function(key) if key == "spawnDots" then signature = nil Sp.show(current()) end end)
ns:On("WAYPOINT_CHANGED", function() Sp.show(Sp.target or current()) end)   -- objective progress
ns:On("GUIDE_FINISHED", clear)
