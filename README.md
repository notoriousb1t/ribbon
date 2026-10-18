# Ribbon

A navigation HUD for the Forever beta client (build `1.60.1 / 70450 / 16001`).

- **Compass ribbon:** a heading bar with cardinal and ordinal labels, 5° and 15° ticks, a live coordinate badge and a marker per waypoint.
- **Map and minimap pins:** the same waypoints on the world map and minimap, through the HereBeDragons-Pins instance already loaded by RXPGuides or Forever_Guide.
- **Waypoint API:** register, remove, hide and track waypoints from any addon, with arrival callbacks.
- **TomTom shim:** a `TomTom` global and `/way` when the real TomTom is not installed.
- **Guide tracking frame:** a small list of the nearest waypoints, with a header a guide addon can set.

The core addon holds no guide logic. A guide (for example the output of the Forever Guide route engine) is just another client of the API.

## Install

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/install.ps1
```

Copies `src/` to `...\_classic_beta_\Interface\AddOns\Ribbon`. Pass `-AddOns "<path>"` for another client. Only `src/` ships; tests and tools never reach the game folder.

## Use

| Command | Effect |
| --- | --- |
| `/way [zone] <x> <y> [description]` | Create a waypoint (zone name optional; current zone by default) |
| `/ribbon clear` / `/ribbon show` | Hide / restore every waypoint |
| `/ribbon list` | Print visible waypoints with distances |
| `/ribbon remove <uid>` | Remove one waypoint |
| `/ribbon compass [show\|hide\|toggle\|lock\|unlock\|reset\|width <500-800>\|fov <90-180>]` | Configure the ribbon |
| `/ribbon guide [show\|hide\|toggle]` | Toggle the tracking frame |
| `/ribbon debug` | Print the client's position and map for diagnosis |

Right-click any marker or pin to hide that waypoint on every surface. The world map has a **Clear Pins** button. Drag the ribbon or the tracking frame to move them; `lock` pins the ribbon.

### Lua API

```lua
local uid = Ribbon:AddWaypoint(uiMapID, x, y, {
  title = "Anvil Mar",            -- display name
  icon = "turnin",                -- accept, turnin, kill, loot, grind, poi
  minimap = true, worldmap = true, compass = true,   -- surfaces, default true
  arrival_distance = 5,           -- yards, 2D, default 5
  on_arrive = function(uid) end,  -- once per approach
  lines = { "Quest giver" },      -- extra tooltip lines
})
Ribbon:RemoveWaypoint(uid)
Ribbon:ClearAllWaypoints()
Ribbon:SetWaypointVisible(uid, false)
Ribbon:SetFocus(uid)              -- caption this waypoint instead of the nearest
Ribbon.Guide:SetHeader("Chapter 1")
```

`x` and `y` are 0-100 zone coordinates and zones are `uiMapID`s (for example `1453` Stormwind City, `1439` Darkshore). Every method validates its arguments and returns `nil` (or does nothing) on bad input instead of raising an error.

Arrival fires once when the player is within `arrival_distance` yards and re-arms after the player is 1.5× that distance away. Arrival is 2D; height is never used.

### Events

`ns:On(name, fn)` events used between modules: `INIT`, `WAYPOINT_ADDED`, `WAYPOINT_REMOVED`, `WAYPOINT_CHANGED`, `WAYPOINT_ARRIVED`, `FOCUS_CHANGED`.

## Architecture

```
src/
  Ribbon.toc          load order (the specs read it too)
  core/
    Core.lua          namespace, module events, tickers, saved variables, start-up
    Client.lua        the only module that calls position and map APIs
    Geometry.lua      pure math: wrap, heading, bearing, marker offset
    Registry.lua      waypoint model, public API, distance and arrival
    TomTom.lua        TomTom global and /way
    Commands.lua      /ribbon
  compass/
    Layout.lua        pure: heading scale and marker placement
    Compass.lua       view: frames from the layout
  map/
    PinManager.lua    pure(ish): keeps pins in step with waypoints; library and factory injected
    Map.lua           wiring: pin frames, HereBeDragons-Pins, Clear Pins button
  guide/
    Rows.lua          pure: tracking-frame rows
    Guide.lua         view: the tracking frame
tests/                runner, jasmine-style framework, fakes, specs (never ships)
tools/install.ps1     copies src/ to AddOns\Ribbon
```

Data flows one way: `Client` reads the game, `Registry` turns waypoints plus the player's position into `dist` and `delta` at 30 Hz, and the views (ribbon, pins, tracking frame) render what the registry holds. Views never compute positions themselves.

### Coordinates and projection

All geometry uses world yards, never normalized map coordinates (a zone map is not square: Stormwind City is about 1737 yd wide and 1158 yd tall). Measured on this client:

- `UnitPosition("player")` returns `first, second, z, instanceID`; `first` increases north and `second` increases west. `C_Map.GetWorldPosFromMapPos` returns the same axes in the same order, so waypoints and the player share one frame.
- `GetPlayerFacing()` is radians from north, increasing counter-clockwise.
- Therefore `delta = wrap(atan2(dSecond, dFirst) - facing)`: positive means the target is on the left, and ribbon offset is `-delta / (FOV / 2) * (width / 2)`, clamped to the bar edge.
- Waypoints on another `instanceID` (continent) are not projected.

### Client facts

The client exposes the modern `C_Map` API and map data providers (`WorldMapFrame.pinPools`); `GetPlayerMapPosition` is absent. Whether `WORLD_MAP_UPDATE` fires was not probed, and the addon does not depend on it. `TomTom` is not preinstalled. `UnitPosition` Z read `0` in every sample taken (two Stormwind spots, one of them the canal), so elevation chevrons are on hold until a re-probe shows otherwise. Pins use `LibStub("HereBeDragons-Pins-2.0")`, which RXPGuides or Forever_Guide already load; if it is missing, pins are disabled and the ribbon still works.

## Tests

The suite runs outside the game on LuaJIT (Lua 5.1, the same semantics as WoW) against a fake client.

```powershell
winget install DEVCOM.LuaJIT          # once
luajit tests/run.lua                  # all specs
luajit tests/run.lua Registry         # specs whose full name contains "Registry"
```

The runner exits with code 1 on any failure.

How it is organised, in the style of jasmine:

- `tests/framework/jasmine.lua`: `describe`, `it`, `beforeEach`, `afterEach`, `xit`, `fit`, `expect(...).toBe / toEqual / toBeCloseTo / toHaveBeenCalledWith / ...`, and `.never` for negation (`not` is a Lua keyword).
- `tests/framework/spy.lua`: spies with `andReturn`, `andCall`, `andCallThrough`; `spyOn(obj, "method")` is restored after each spec.
- `tests/fakes/wow.lua`: a fake client. A controllable world (maps with measured Stormwind and Eastern Kingdoms bounds, player position and facing, missing-API simulation) and recording frames where every method is a spy, so specs verify calls such as `expect(frame.SetPoint).toHaveBeenCalledWith("CENTER", parent, "CENTER", x, 0)`.
- `tests/helpers/addon.lua`: loads `src/` files in TOC order into a fresh namespace per spec (`H.use{ boot = true }`), or just the pure modules (`H.pure{...}`).
- `tests/specs/*_spec.lua`, listed in `tests/specs.lua`: geometry, layout, rows, pin manager, client, core, registry, TomTom, commands, and the compass, guide and map views.

The pure modules are tested with plain values. The adapter (`Client.lua`) and the views are tested against the fakes. Real frame layout and HereBeDragons rendering still need a check in the game.

## Status and roadmap

Implemented and covered by the specs, but not yet run in the game client: registry and API, ribbon, map and minimap pins (via HereBeDragons-Pins), dismissal controls, TomTom layer, tracking frame, `/ribbon` commands, saved ribbon position, width, FOV and lock.

Notes:

- The tracking frame (`guide/`) ships in the addon. A separate guide addon can drive it through the API.
- `TomTom:AddWaypoint(x, y, desc)` follows real TomTom (current zone); `AddZWaypoint` accepts a `uiMapID` as the zone and returns `nil` for continent and zone-index pairs it cannot resolve.
- Arrival runs on the 30 Hz geometry tick; the minimap rim clamp and rotation are handled by HereBeDragons-Pins.

Not yet:

- Radius rings for area waypoints.
- Elevation chevrons: on hold until the client reports a non-zero Z. Plan: an optional `options.z` per waypoint, a fail-open availability probe, an up chevron above +8 yd and a down chevron below -8 yd, arrival still 2D.
- Dungeon and indoor behavior is unmeasured; the ribbon hides markers when position is unavailable.
