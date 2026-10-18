# Ribbon

WoW addon for the Forever beta client (build `1.60.1 / 70450 / 16001`): compass ribbon, map and minimap pins, waypoint API, TomTom shim, guide tracking frame. Lua 5.1 semantics (WoW and LuaJIT).

## Layout

- `src/` is the addon. Only this folder ships; `tools/install.ps1` copies it to `AddOns\Ribbon`.
- `tests/` is the test suite (runner, jasmine-style framework, fakes, specs). It never ships.
- `tools/` holds PowerShell helpers.

## Commands

```powershell
luajit tests/run.lua              # all specs; exit code 1 on failure
luajit tests/run.lua Registry     # specs whose full name contains "Registry"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/install.ps1   # install into the game
```

Run the specs before every commit and after every change under `src/`.

## Rules

- **Client boundary:** Only `src/core/Client.lua` calls position and map APIs (`UnitPosition`, `GetPlayerFacing`, `C_Map.*`). Everything else calls `ns.client`.
- **Pure logic:** Math, layout and row/model code (`core/Geometry.lua`, `compass/Layout.lua`, `guide/Rows.lua`, `map/PinManager.lua`) take plain values and touch no frames or client globals. Keep new logic there and keep the views (`Compass.lua`, `Guide.lua`, `Map.lua`) thin.
- **Fail soft:** Public API calls validate arguments and return `nil` on bad input. Never raise to a caller. Handler and ticker errors go to `geterrorhandler()`.
- **Load order:** `src/Ribbon.toc` is the single source of load order; the specs read it. Add every new file there.
- **Every module** starts with `local ADDON, ns = ...` and hangs its API off `ns`. Modules talk through `ns:On` / `ns:Fire` events (`INIT`, `WAYPOINT_ADDED`, `WAYPOINT_REMOVED`, `WAYPOINT_CHANGED`, `WAYPOINT_ARRIVED`, `FOCUS_CHANGED`).
- **Conventions (measured, do not change without re-measuring):** world axes `first` = north-positive, `second` = west-positive; facing is counter-clockwise radians from north; positive `delta` is a target on the left; zone coordinates are 0-100; zones are addressed by `uiMapID`.
- **Tests:** Every behavior change gets a spec. Use the fakes in `tests/fakes/wow.lua` and verify calls with spies rather than reaching into frames. Specs must pass with no real client.
- **Elevation** is delayed, not dropped. The client reports Z = 0 today.
- **Shell:** PowerShell on Windows. No Python or Go scripts; use PowerShell or Node for tooling.

## Do not

- Put test code, fakes or `luajit` references under `src/`.
- Commit `WTF/` or SavedVariables output.
- Replace `LibStub` copies of HereBeDragons: use the instance RXPGuides or Forever_Guide already loaded.
