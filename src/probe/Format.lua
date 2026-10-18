-- Probe formatting: pure functions that turn Lua values into readable text. No client calls.
local ADDON, ns = ...

local F = {}
ns.probeFormat = F

local MAX_ENTRIES = 40

local function keyLess(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta < tb end
  if ta == "number" or ta == "string" then return a < b end
  return tostring(a) < tostring(b)
end

-- opts.depth: how many table levels to expand (default 2). opts.skipFunctions: omit function members.
function F.serialize(value, opts, level)
  opts = opts or {}
  level = level or 0
  local t = type(value)
  if t == "string" then return string.format("%q", value) end
  if t == "function" then return "<function>" end
  if t == "userdata" or t == "thread" then return "<" .. t .. ">" end
  if t ~= "table" then return tostring(value) end

  if level >= (opts.depth or 2) then return "{...}" end

  local keys = {}
  for k, v in pairs(value) do
    if not (opts.skipFunctions and type(v) == "function") then keys[#keys + 1] = k end
  end
  table.sort(keys, keyLess)

  local out = {}
  for i, k in ipairs(keys) do
    if i > MAX_ENTRIES then
      out[#out + 1] = "... (" .. (#keys - MAX_ENTRIES) .. " more)"
      break
    end
    local key = type(k) == "string" and k or ("[" .. tostring(k) .. "]")
    out[#out + 1] = key .. "=" .. F.serialize(value[k], opts, level + 1)
  end
  return "{" .. table.concat(out, ", ") .. "}"
end

-- A packed result list ({ n = count, ... }) as "a, b, c".
function F.list(packed, opts)
  local out = {}
  for i = 1, packed.n or #packed do out[#out + 1] = F.serialize(packed[i], opts) end
  return table.concat(out, ", ")
end
