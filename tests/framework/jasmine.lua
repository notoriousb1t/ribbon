-- A small jasmine-style runner for LuaJIT / Lua 5.1.
--   describe, it, beforeEach, afterEach, xdescribe, xit, fdescribe, fit
--   expect(v).toBe / toEqual / toBeNil / toBeTruthy / toBeFalsy / toBeCloseTo / toBeGreaterThan /
--             toBeLessThan / toContain / toMatch / toHaveLength / toThrow /
--             toHaveBeenCalled / toHaveBeenCalledTimes / toHaveBeenCalledWith
--   expect(v).never.<matcher>        (jasmine's .not; "not" is a Lua keyword)
--   spyOn(obj, "method"), createSpy(name)
local Spy = require("tests.framework.spy")

local J = {}

local root = { name = "", children = {}, before = {}, after = {} }
local current = root
local focused = false

-- Formatting ---------------------------------------------------------------

local function fmt(v, depth)
  depth = depth or 0
  local t = type(v)
  if t == "string" then return string.format("%q", v) end
  if Spy.isSpy(v) then return "<spy>" end
  if t == "table" then
    if depth >= 3 then return "{...}" end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do
      out[#out + 1] = (type(k) == "number" and "" or (tostring(k) .. "=")) .. fmt(v[k], depth + 1)
    end
    return "{" .. table.concat(out, ", ") .. "}"
  end
  return tostring(v)
end

local function deepEqual(a, b, seen)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  if Spy.isSpy(a) or Spy.isSpy(b) then return false end
  seen = seen or {}
  if seen[a] == b then return true end
  seen[a] = b
  for k, v in pairs(a) do
    if not deepEqual(v, b[k], seen) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

local function argsEqual(call, expected)
  if call.n ~= expected.n then return false end
  for i = 1, expected.n do
    if not deepEqual(call[i], expected[i]) then return false end
  end
  return true
end

local function fmtArgs(args)
  local out = {}
  for i = 1, args.n do out[#out + 1] = fmt(args[i]) end
  return table.concat(out, ", ")
end

-- Matchers -----------------------------------------------------------------

local function fail(msg) error({ jasmine = true, message = msg }, 0) end

local matchers = {}

matchers.toBe = function(a, e) return rawequal(a, e), "Expected " .. fmt(a) .. " to be " .. fmt(e) end
matchers.toEqual = function(a, e) return deepEqual(a, e), "Expected " .. fmt(a) .. " to equal " .. fmt(e) end
matchers.toBeNil = function(a) return a == nil, "Expected " .. fmt(a) .. " to be nil" end
matchers.toBeTruthy = function(a) return a ~= nil and a ~= false, "Expected " .. fmt(a) .. " to be truthy" end
matchers.toBeFalsy = function(a) return a == nil or a == false, "Expected " .. fmt(a) .. " to be falsy" end
matchers.toBeGreaterThan = function(a, e) return type(a) == "number" and a > e, "Expected " .. fmt(a) .. " to be greater than " .. fmt(e) end
matchers.toBeLessThan = function(a, e) return type(a) == "number" and a < e, "Expected " .. fmt(a) .. " to be less than " .. fmt(e) end

matchers.toBeCloseTo = function(a, e, digits)
  digits = digits or 2
  local ok = type(a) == "number" and math.abs(a - e) < (10 ^ -digits) / 2
  return ok, "Expected " .. fmt(a) .. " to be close to " .. fmt(e) .. " (" .. digits .. " digits)"
end

matchers.toContain = function(a, e)
  if type(a) == "string" then return a:find(e, 1, true) ~= nil, "Expected " .. fmt(a) .. " to contain " .. fmt(e) end
  for _, v in pairs(a) do
    if deepEqual(v, e) then return true, "" end
  end
  return false, "Expected " .. fmt(a) .. " to contain " .. fmt(e)
end

matchers.toMatch = function(a, pattern)
  return type(a) == "string" and a:find(pattern) ~= nil, "Expected " .. fmt(a) .. " to match " .. fmt(pattern)
end

matchers.toHaveLength = function(a, n)
  local len = type(a) == "string" and #a or #a
  return len == n, "Expected length " .. len .. " to be " .. n
end

matchers.toThrow = function(fn, pattern)
  local ok, err = pcall(fn)
  if ok then return false, "Expected function to throw" end
  if pattern and not tostring(type(err) == "table" and err.message or err):find(pattern) then
    return false, "Expected error " .. fmt(err) .. " to match " .. fmt(pattern)
  end
  return true, ""
end

local function needSpy(s)
  if not Spy.isSpy(s) then fail("Expected a spy, got " .. fmt(s)) end
end

matchers.toHaveBeenCalled = function(s)
  needSpy(s)
  return s.callCount > 0, "Expected spy to have been called"
end

matchers.toHaveBeenCalledTimes = function(s, n)
  needSpy(s)
  return s.callCount == n, "Expected spy to have been called " .. n .. " times, was " .. s.callCount
end

matchers.toHaveBeenCalledWith = function(s, ...)
  needSpy(s)
  local expected = { n = select("#", ...), ... }
  for _, call in ipairs(s.calls) do
    if argsEqual(call, expected) then return true, "" end
  end
  local seen = {}
  for i, call in ipairs(s.calls) do seen[#seen + 1] = "  #" .. i .. ": (" .. fmtArgs(call) .. ")" end
  return false, "Expected spy to have been called with (" .. fmtArgs(expected) .. "), calls:\n" ..
    (#seen > 0 and table.concat(seen, "\n") or "  none")
end

local function expectation(actual, negate)
  local e = {}
  for name, fn in pairs(matchers) do
    e[name] = function(...)
      local ok, msg = fn(actual, ...)
      if negate then
        if ok then fail((msg:gsub(" to ", " not to ", 1))) end
      elseif not ok then
        fail(msg)
      end
    end
  end
  return e
end

function J.expect(actual)
  local e = expectation(actual, false)
  e.never = expectation(actual, true)
  return e
end

-- Spies ---------------------------------------------------------------------

local activeSpies = {}

function J.spyOn(obj, name)
  local original = obj[name]
  local spy = Spy.new(original)
  obj[name] = spy
  activeSpies[#activeSpies + 1] = { obj = obj, name = name, original = original }
  return spy
end

function J.createSpy() return Spy.new() end

local function restoreSpies()
  for i = #activeSpies, 1, -1 do
    local s = activeSpies[i]
    s.obj[s.name] = s.original
    activeSpies[i] = nil
  end
end

-- Suites --------------------------------------------------------------------

local function addSuite(name, fn, opts)
  local suite = { name = name, children = {}, before = {}, after = {}, parent = current, skip = opts and opts.skip, focus = opts and opts.focus }
  if suite.focus then focused = true end
  current.children[#current.children + 1] = suite
  local prev = current
  current = suite
  fn()
  current = prev
end

function J.describe(name, fn) addSuite(name, fn) end
function J.xdescribe(name, fn) addSuite(name, fn, { skip = true }) end
function J.fdescribe(name, fn) addSuite(name, fn, { focus = true }) end

local function addSpec(name, fn, opts)
  local spec = { name = name, fn = fn, spec = true, parent = current, skip = opts and opts.skip, focus = opts and opts.focus }
  if spec.focus then focused = true end
  current.children[#current.children + 1] = spec
end

function J.it(name, fn) addSpec(name, fn) end
function J.xit(name, fn) addSpec(name, fn, { skip = true }) end
function J.fit(name, fn) addSpec(name, fn, { focus = true }) end
function J.beforeEach(fn) current.before[#current.before + 1] = fn end
function J.afterEach(fn) current.after[#current.after + 1] = fn end

-- Running -------------------------------------------------------------------

local function describeError(err)
  if type(err) == "table" and err.jasmine then return err.message end
  return tostring(err)
end

local function chain(node)
  local list = {}
  while node and node ~= root do
    table.insert(list, 1, node)
    node = node.parent
  end
  return list
end

local function hasFocus(node)
  if node.focus then return true end
  for _, c in ipairs(node.children or {}) do
    if hasFocus(c) then return true end
  end
  return false
end

local function runNode(node, results, filter, inFocus, skipped)
  local skip = skipped or node.skip
  if node.spec then
    local full = {}
    for _, s in ipairs(chain(node.parent)) do full[#full + 1] = s.name end
    full[#full + 1] = node.name
    local fullName = table.concat(full, " ")
    if filter and not fullName:find(filter, 1, true) then return end
    if skip or (focused and not inFocus) then
      results.skipped = results.skipped + 1
      return
    end
    local suites = chain(node.parent)
    local ok, err = true, nil
    for _, s in ipairs(suites) do
      for _, hook in ipairs(s.before) do
        if ok then ok, err = pcall(hook) end
      end
    end
    if ok then ok, err = pcall(node.fn) end
    for i = #suites, 1, -1 do
      for _, hook in ipairs(suites[i].after) do
        local aok, aerr = pcall(hook)
        if ok and not aok then ok, err = false, aerr end
      end
    end
    restoreSpies()
    if ok then
      results.passed = results.passed + 1
    else
      results.failed = results.failed + 1
      results.failures[#results.failures + 1] = { name = fullName, message = describeError(err) }
      io.write("F")
      return
    end
    io.write(".")
    return
  end
  local focus = inFocus or node.focus
  for _, child in ipairs(node.children) do
    runNode(child, results, filter, focus, skip)
  end
end

function J.run(filter)
  local results = { passed = 0, failed = 0, skipped = 0, failures = {} }
  local start = os.clock()
  runNode(root, results, filter, false, false)
  io.write("\n\n")
  for i, f in ipairs(results.failures) do
    io.write(string.format("%d) %s\n   %s\n\n", i, f.name, (f.message:gsub("\n", "\n   "))))
  end
  io.write(string.format("%d specs, %d failures, %d skipped (%.2fs)\n",
    results.passed + results.failed, results.failed, results.skipped, os.clock() - start))
  return results.failed == 0
end

function J.install(env)
  env = env or _G
  env.describe, env.xdescribe, env.fdescribe = J.describe, J.xdescribe, J.fdescribe
  env.it, env.xit, env.fit = J.it, J.xit, J.fit
  env.beforeEach, env.afterEach = J.beforeEach, J.afterEach
  env.expect, env.spyOn, env.createSpy = J.expect, J.spyOn, J.createSpy
end

return J
