-- Pin manager: keeps map and minimap icons in step with waypoints.
-- The pin library and the pin factory are injected, so specs verify the exact library calls:
--   PM.new{ pins = lib, ref = owner, factory = { create = function(kind) -> pin }, icons = {}, defaultIcon = "poi", worldFlag = n }
-- A pin is any object with Configure(uid, texture, icon) and Hide(); kind is "world" or "mini". `icon` is the waypoint's
-- icon name, `texture` its texture; a pin that draws badges uses the name.
local ADDON, ns = ...

local PM = {}
ns.PinManager = PM
PM.__index = PM

function PM.new(opts)
  return setmetatable({
    pins = opts.pins, ref = opts.ref, factory = opts.factory,
    icons = opts.icons, defaultIcon = opts.defaultIcon, worldFlag = opts.worldFlag,
    pool = { world = {}, mini = {} },
    active = {},
  }, PM)
end

function PM:acquire(kind)
  return table.remove(self.pool[kind]) or self.factory.create(kind)
end

function PM:release(entry)
  if not entry then return end
  if entry.world then
    self.pins:RemoveWorldMapIcon(self.ref, entry.world)
    entry.world:Hide()
    self.pool.world[#self.pool.world + 1] = entry.world
  end
  if entry.mini then
    self.pins:RemoveMinimapIcon(self.ref, entry.mini)
    entry.mini:Hide()
    self.pool.mini[#self.pool.mini + 1] = entry.mini
  end
end

function PM:remove(wp)
  self:release(self.active[wp.uid])
  self.active[wp.uid] = nil
end

-- Re-create the icons for one waypoint (none when it is hidden).
function PM:refresh(wp)
  self:remove(wp)
  if not wp.visible then return end

  local entry = {}
  local texture = self.icons[wp.icon] or self.icons[self.defaultIcon]
  local x, y = wp.x / 100, wp.y / 100

  if wp.worldmap then
    local pin = self:acquire("world")
    pin:Configure(wp.uid, texture, wp.icon)
    self.pins:AddWorldMapIconMap(self.ref, pin, wp.mapID, x, y, self.worldFlag)
    entry.world = pin
  end
  if wp.minimap then
    local pin = self:acquire("mini")
    pin:Configure(wp.uid, texture, wp.icon)
    self.pins:AddMinimapIconMap(self.ref, pin, wp.mapID, x, y, true, true)
    entry.mini = pin
  end
  self.active[wp.uid] = entry
end

function PM:resync(waypoints)
  for _, wp in pairs(waypoints) do self:refresh(wp) end
end
