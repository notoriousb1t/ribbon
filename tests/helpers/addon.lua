-- Loads the addon files exactly as the TOC lists them, against the fake client.
--   local ctx = H.use({ boot = true })   -- inside describe(); ctx.ns / ctx.world are fresh per spec
local Fake = require("tests.fakes.wow")

local H = {}

local function tocFiles()
  local files = {}
  for line in io.lines("src/Ribbon.toc") do
    local f = line:match("^%s*(.-%.lua)%s*$")
    -- Embedded third-party libraries (src/libs) are not run against the fake client; the fakes stand in for them.
    if f and not f:match("^libs[\\/]") then files[#files + 1] = (f:gsub("\\", "/")) end
  end
  return files
end

H.files = tocFiles()

-- Load the addon. opts.files: subset (default: every TOC file). opts.boot: fire PLAYER_LOGIN.
function H.load(opts)
  opts = opts or {}
  local world = Fake.install()
  if opts.world then opts.world(world) end
  local ns = {}
  for _, f in ipairs(opts.files or H.files) do
    local chunk = assert(loadfile("src/" .. f))
    chunk("Ribbon", ns)
  end
  if opts.boot then world:fireEvent("PLAYER_LOGIN") end
  return ns, world
end

function H.use(opts)
  local ctx = {}
  beforeEach(function()
    ctx.ns, ctx.world = H.load(opts)
  end)
  afterEach(function()
    Fake.uninstall()
    ctx.ns, ctx.world = nil, nil
  end)
  return ctx
end

-- Standalone chunk loader for modules that need no fake world (pure logic).
function H.pure(files)
  local ns = {}
  for _, f in ipairs(files) do assert(loadfile("src/" .. f))("Ribbon", ns) end
  return ns
end

return H
