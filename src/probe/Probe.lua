-- Probe: a development tool for inspecting the game client.
--   /ribbonprobe                 list probes
--   /ribbonprobe <name> [args]   run one, print the result and save it in RibbonDB.probes
-- Probes call arbitrary client APIs, so this module is exempt from the Client boundary rule. Every
-- probe takes (args, env) and returns lines; env is _G in the game and a fake table in the specs.
-- Add a probe with ns.probe.register(name, description, fn).
local ADDON, ns = ...

local P = {}
ns.probe = P

local MAX_RUNS = 10
local probes, order = {}, {}
local serialize = function(v, opts) return ns.probeFormat.serialize(v, opts) end

function P.register(name, description, fn)
  if not probes[name] then order[#order + 1] = name end
  probes[name] = { description = description, run = fn }
end

-- Helpers for probes ------------------------------------------------------------

-- Value at a dotted path ("C_QuestLog.GetNextWaypoint") in env, or nil.
function P.resolve(env, path)
  local obj = env
  for part in string.gmatch(path, "[^%.]+") do
    if type(obj) ~= "table" then return nil end
    local ok, nxt = pcall(function() return obj[part] end)
    if not ok or nxt == nil then return nil end
    obj = nxt
  end
  return obj
end

-- Call the function at path. Returns nil when it does not exist, else ok and the packed results.
function P.call(env, path, ...)
  local fn = P.resolve(env, path)
  if type(fn) ~= "function" then return nil end
  local function pack(...) return { n = select("#", ...), ... } end
  local ok, result = pcall(function(...) return pack(fn(...)) end, ...)
  if not ok then return false, result end
  return true, result
end

-- One line describing a call: "path(args) -> results", "path: missing" or "path(args) errored: ...".
function P.line(env, path, ...)
  local args = {}
  for i = 1, select("#", ...) do args[#args + 1] = serialize((select(i, ...))) end
  local label = path .. "(" .. table.concat(args, ", ") .. ")"
  local ok, result = P.call(env, path, ...)
  if ok == nil then return path .. ": missing" end
  if not ok then return label .. " errored: " .. tostring(result) end
  return label .. " -> " .. ns.probeFormat.list(result, { skipFunctions = true })
end

-- "a=true, b=false" for whether each path exists in env.
function P.exists(env, paths)
  local out = {}
  for _, path in ipairs(paths) do out[#out + 1] = path .. "=" .. tostring(P.resolve(env, path) ~= nil) end
  return table.concat(out, ", ")
end

-- Running and saving -------------------------------------------------------------

local function now()
  return (date or os.date)("%Y-%m-%d %H:%M:%S")
end

local function save(name, args, lines)
  local db = ns.db or _G.RibbonDB
  if type(db) ~= "table" then return end
  db.probes = db.probes or {}
  local runs = db.probes[name] or {}
  runs[#runs + 1] = { time = now(), args = args, lines = lines }
  while #runs > MAX_RUNS do table.remove(runs, 1) end
  db.probes[name] = runs
end

-- Run a probe by name. Returns its lines, or nil and a message. env defaults to _G.
function P.run(name, args, env)
  local probe = probes[name]
  if not probe then return nil, "unknown probe: " .. tostring(name) end
  local ok, result = pcall(probe.run, args or "", env or _G)
  if not ok then result = { "probe errored: " .. tostring(result) } end
  if type(result) == "string" then result = { result } end
  save(name, args or "", result)
  return result
end

function P.handle(msg, env)
  local name, args = string.match(msg or "", "^(%S*)%s*(.-)$")
  if name == "" then
    ns:Print("probes (/ribbonprobe <name> [args]; results are also saved in RibbonDB.probes):")
    for _, n in ipairs(order) do ns:Print("  " .. n .. " - " .. probes[n].description) end
    return
  end
  local lines, err = P.run(string.lower(name), args, env)
  if not lines then
    ns:Print(err)
    return
  end
  for _, line in ipairs(lines) do ns:Print(line) end
end

-- Built-in probes -------------------------------------------------------------------

P.register("quest", "the super-tracked quest: title, next waypoint, objectives (optional arg: a quest id)",
  function(args, env)
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    local ok, result = P.call(env, "C_SuperTrack.GetSuperTrackedQuestID")
    local questID = tonumber(args) or (ok and result[1]) or nil
    add(P.line(env, "C_SuperTrack.GetSuperTrackedQuestID"))
    if questID and questID ~= 0 then
      add(P.line(env, "C_QuestLog.GetTitleForQuestID", questID))
      add(P.line(env, "C_QuestLog.GetNextWaypoint", questID))
      add(P.line(env, "C_QuestLog.GetQuestObjectives", questID))
      add(P.line(env, "C_QuestLog.GetLogIndexForQuestID", questID))
    else
      add("no quest: click one in the tracker or log, or pass a quest id")
    end

    local okMap, map = P.call(env, "C_Map.GetBestMapForUnit", "player")
    if okMap and map[1] then add(P.line(env, "C_QuestLog.GetQuestsOnMap", map[1])) end
    add(P.line(env, "C_QuestLog.GetNumQuestWatches"))
    add(P.line(env, "C_QuestLog.GetNumQuestLogEntries"))
    add("APIs: " .. P.exists(env, {
      "C_QuestLog.GetNextWaypoint", "C_QuestLog.GetQuestsOnMap", "C_QuestLog.GetQuestObjectives",
      "C_QuestLog.GetTitleForQuestID", "C_SuperTrack.GetSuperTrackedQuestID",
      "C_SuperTrack.SetSuperTrackedQuestID",
    }))
    return lines
  end)

P.register("player", "facing, position, map and world coordinates", function(args, env)
  local lines = {}
  local function add(s) lines[#lines + 1] = s end
  add(P.line(env, "GetPlayerFacing"))
  add(P.line(env, "UnitPosition", "player"))
  add(P.line(env, "C_Map.GetBestMapForUnit", "player"))
  local ok, map = P.call(env, "C_Map.GetBestMapForUnit", "player")
  if ok and map[1] then
    add(P.line(env, "C_Map.GetPlayerMapPosition", map[1], "player"))
    add(P.line(env, "C_Map.GetMapInfo", map[1]))
  end
  add(P.line(env, "GetRealZoneText"))
  add(P.line(env, "GetMinimapZoneText"))
  return lines
end)

P.register("apis", "whether APIs exist: /ribbonprobe apis C_QuestLog.GetInfo C_Map (default: a common set)",
  function(args, env)
    local paths = {}
    for path in string.gmatch(args, "%S+") do paths[#paths + 1] = path end
    if #paths == 0 then
      paths = { "C_Map", "C_QuestLog", "C_SuperTrack", "C_TaskQuest", "C_Minimap", "C_Timer",
        "UnitPosition", "GetPlayerFacing", "hooksecurefunc", "LibStub", "TomTom", "WorldMapFrame" }
    end
    return { P.exists(env, paths) }
  end)

P.register("dump", "serialize a global: /ribbonprobe dump C_QuestLog (functions shown by name)",
  function(args, env)
    if args == "" then return { "usage: /ribbonprobe dump <expression>" } end
    local chunk, err = loadstring("return " .. args)
    if not chunk then return { "cannot parse: " .. tostring(err) } end
    if env ~= _G and setfenv then setfenv(chunk, env) end
    local ok, value = pcall(chunk)
    if not ok then return { "errored: " .. tostring(value) } end
    return { args .. " = " .. serialize(value, { depth = 2 }) }
  end)

P.register("addons", "the addons that are loaded", function(args, env)
  local out = {}
  local get = P.resolve(env, "C_AddOns.GetNumAddOns") or P.resolve(env, "GetNumAddOns")
  local info = P.resolve(env, "C_AddOns.GetAddOnInfo") or P.resolve(env, "GetAddOnInfo")
  local loaded = P.resolve(env, "C_AddOns.IsAddOnLoaded") or P.resolve(env, "IsAddOnLoaded")
  if not (get and info and loaded) then return { "addon list API missing" } end
  for i = 1, get() do
    local name = info(i)
    if name and loaded(name) then out[#out + 1] = name end
  end
  return { table.concat(out, ", ") }
end)

-- Distance in yards between the player and a point on a map, from world coordinates; nil if unknown.
local function worldDistance(env, mapID, x, y)
  local okPos, pos = P.call(env, "UnitPosition", "player")
  if not (okPos and pos[1] and pos[2]) then return nil end
  local make = P.resolve(env, "CreateVector2D")
  if not make then return nil end
  local okWorld, world = P.call(env, "C_Map.GetWorldPosFromMapPos", mapID, make(x, y))
  local vec = okWorld and world[2]
  if not (vec and vec.x and vec.y) then return nil end
  local d1, d2 = vec.x - pos[1], vec.y - pos[2]
  return math.sqrt(d1 * d1 + d2 * d2)
end

-- The navigation target (the super-tracked quest or map pin) as the engine sees it. Read-only.
-- GetDistance is compared with the 2D world distance to the quest's map point: if they differ
-- by more than rounding when the player and target are at different heights, the engine uses Z.
P.register("navigation", "C_Navigation target state, distance and screen position, vs our 2D distance to the tracked quest",
  function(args, env)
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    add(P.line(env, "C_Navigation.GetTargetState"))
    add(P.line(env, "C_Navigation.GetDistance"))
    add(P.line(env, "C_Navigation.HasValidScreenPosition"))
    add(P.line(env, "C_Navigation.WasClampedToScreen"))

    local okMap, map = P.call(env, "C_Map.GetBestMapForUnit", "player")
    local mapID = okMap and map[1]
    if mapID then add(P.line(env, "C_Navigation.GetNextWaypointForMap", mapID)) end

    local okFrame, frame = P.call(env, "C_Navigation.GetFrame")
    local f = okFrame and frame[1]
    if type(f) == "table" and f.GetPoint then
      local okPoint, info = pcall(function()
        local point, _, relPoint, x, y = f:GetPoint()
        return string.format("frame shown=%s point=%s relPoint=%s x=%s y=%s",
          tostring(f:IsShown()), tostring(point), tostring(relPoint), tostring(x), tostring(y))
      end)
      add(okPoint and info or ("frame errored: " .. tostring(info)))
    else
      add("C_Navigation.GetFrame() -> no frame")
    end

    local okQuest, quest = P.call(env, "C_SuperTrack.GetSuperTrackedQuestID")
    local questID = okQuest and quest[1]
    local okList, list = P.call(env, "C_QuestLog.GetQuestsOnMap", mapID)
    if questID and questID ~= 0 and okList and type(list[1]) == "table" then
      for _, q in ipairs(list[1]) do
        if q.questID == questID then
          local d = worldDistance(env, mapID, q.x, q.y)
          add("tracked quest " .. questID .. " map point " .. serialize(q.x) .. ", " .. serialize(q.y) ..
            (d and string.format("; 2D distance %.1f yd", d) or "; 2D distance unknown"))
          add(P.line(env, "UnitPosition", "player"))
          local okDist, engine = P.call(env, "C_Navigation.GetDistance")
          if d and okDist and type(engine[1]) == "number" then
            local extra = engine[1] * engine[1] - d * d
            add(string.format("engine %.1f yd vs flat %.1f yd: implied height difference %.1f yd if the engine measures in 3D (0 when the engine is shorter)",
              engine[1], d, extra > 0 and math.sqrt(extra) or 0))
          end
        end
      end
    else
      add("no tracked quest point on this map to compare with")
    end
    return lines
  end)

-- Commands --------------------------------------------------------------------------

ns.commands.probe = function(args) P.handle(args) end

SLASH_RIBBON_PROBE1 = "/ribbonprobe"
SlashCmdList["RIBBON_PROBE"] = function(msg) P.handle(msg) end
