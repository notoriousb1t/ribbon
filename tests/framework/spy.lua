-- Spies: call recorders with stubbing, jasmine 1.x style.
--   local s = Spy.new()            -- records calls, returns nothing
--   s:andReturn(1, 2)              -- always returns 1, 2
--   s:andCall(fn)                  -- delegates to fn
--   s:andCallThrough()             -- delegates to the original function
--   s.calls[i]                     -- { n = count, [1..n] = args }
--   s.callCount, s:reset()
local Spy = {}
Spy.__index = Spy

local function pack(...) return { n = select("#", ...), ... } end

function Spy.new(original, skipSelf)
  return setmetatable({
    calls = {},
    callCount = 0,
    original = original,
    skipSelf = skipSelf and true or false,
    mode = original and "through" or "none",
  }, Spy)
end

function Spy.isSpy(v)
  return type(v) == "table" and getmetatable(v) == Spy
end

Spy.__call = function(self, ...)
  local args = pack(...)
  if self.skipSelf then
    table.remove(args, 1)
    args.n = math.max(args.n - 1, 0)
  end
  self.calls[#self.calls + 1] = args
  self.callCount = #self.calls
  if self.mode == "return" then
    return unpack(self.returns, 1, self.returns.n)
  elseif self.mode == "call" then
    return self.fake(...)
  elseif self.mode == "through" and self.original then
    return self.original(...)
  end
end

function Spy:andReturn(...)
  self.mode, self.returns = "return", pack(...)
  return self
end

function Spy:andCall(fn)
  self.mode, self.fake = "call", fn
  return self
end

function Spy:andCallThrough()
  self.mode = "through"
  return self
end

function Spy:reset()
  self.calls, self.callCount = {}, 0
  return self
end

function Spy:wasCalled() return self.callCount > 0 end

return Spy
