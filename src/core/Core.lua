-- Core: shared namespace, module events, tickers, saved variables and start-up.
-- Everything that touches the WoW client lives in core/Client.lua; pure math in core/Geometry.lua.
local ADDON, ns = ...
_G.Ribbon = ns
ns.version = "1.0.0"

ns.ICONS = {
  accept = "Interface\\GossipFrame\\AvailableQuestIcon",
  turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
  -- Not a raid target marker: the compass is meant to show raid markers (skull, cross, ...) on marked mobs, and a
  -- guide's kill icon must not look like one.
  kill = "Interface\\Icons\\INV_Sword_04",
  loot = "Interface\\Icons\\INV_Misc_Bag_08",
  interact = "Interface\\Icons\\INV_Misc_Gear_01",
  grind = "Interface\\Icons\\Ability_DualWield",
  poi = "Interface\\Icons\\INV_Misc_Map_01",
  -- Raid target markers, by the index GetRaidTargetIndex reports: 1 star, 2 circle, 3 diamond, 4 triangle, 5 moon,
  -- 6 square, 7 cross, 8 skull. No guide icon uses one of these (the specs check), so a marked unit is never
  -- confused with a step.
  raid1 = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1",
  raid2 = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2",
  raid3 = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3",
  raid4 = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4",
  raid5 = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5",
  raid6 = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6",
  raid7 = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7",
  raid8 = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
  fp = "Interface\\Minimap\\Tracking\\FlightMaster",
  hearth = "Interface\\Minimap\\Tracking\\Innkeeper",
  train = "Interface\\Minimap\\Tracking\\Class",
  ding = "Interface\\Icons\\Spell_ChargePositive",
  -- TomTom's own world map dot. The TomTom bridge replaces this with the dot of the theme the player
  -- chose in TomTom; this is TomTom's default (the modern green theme).
  tomtom = "Interface\\AddOns\\TomTom\\Images\\Modern\\Waypoints\\WaypointDotGreen",
  -- RXPGuides' active step target. The RXP bridge replaces this with RXP's navigation arrow (it follows RXP's
  -- theme); until then it is the quest turn-in icon.
  rxp = "Interface\\GossipFrame\\ActiveQuestIcon",
}
ns.DEFAULT_ICON = "poi"

ns.defaults = {
  guideSettings = { autoAdvance = true, autoQuest = true },
  compass = { shown = true, width = 600, fov = 140, opacity = 0.6, dialOpacity = 0.7, locked = false, point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 138 },
}

ns.commands = {}

function ns:Print(msg)
  print("|cff66ccffRibbon|r " .. tostring(msg))
end

-- Events between modules -----------------------------------------------------

local handlers = {}

function ns:On(name, fn)
  handlers[name] = handlers[name] or {}
  handlers[name][#handlers[name] + 1] = fn
end

function ns:Fire(name, ...)
  local list = handlers[name]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], ...)
    if not ok then geterrorhandler()(err) end
  end
end

-- Tickers. A ticker that errors is disabled so one bug cannot spam every frame.

local tickers = {}

function ns:Every(interval, fn)
  tickers[#tickers + 1] = { interval = interval, fn = fn, t = 0 }
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, dt)
  if not ns.ready then return end
  for i = 1, #tickers do
    local tk = tickers[i]
    if not tk.dead then
      tk.t = tk.t + dt
      if tk.t >= tk.interval then
        tk.t = 0
        local ok, err = pcall(tk.fn)
        if not ok then
          tk.dead = true
          geterrorhandler()(err)
          ns:Print("a Ribbon update loop was disabled after an error.")
        end
      end
    end
  end
end)

-- Saved variables and start-up -----------------------------------------------

local function merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      merge(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

ns.merge = merge

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
  RibbonDB = RibbonDB or {}
  merge(RibbonDB, ns.defaults)
  ns.db = RibbonDB
  local missing = ns.client.probe()
  ns.missing = missing
  if #missing > 0 then
    ns:Print("dormant, missing client APIs: " .. table.concat(missing, ", "))
    return
  end
  ns.ready = true
  ns:Fire("INIT")
end)
