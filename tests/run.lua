-- Test runner. From the repository root:
--   luajit tests/run.lua            run every spec listed in tests/specs.lua
--   luajit tests/run.lua Registry   run specs whose full name contains "Registry"
package.path = "./?.lua;" .. package.path

local jasmine = require("tests.framework.jasmine")
jasmine.install(_G)

for _, name in ipairs(require("tests.specs")) do
  local chunk, err = loadfile("tests/specs/" .. name .. "_spec.lua")
  if not chunk then
    io.write("cannot load spec " .. name .. ": " .. tostring(err) .. "\n")
    os.exit(1)
  end
  chunk()
end

local ok = jasmine.run(arg and arg[1])
os.exit(ok and 0 or 1)
