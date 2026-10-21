# Ribbon

WoW addon for the Forever beta client (build `1.60.1 / 70450 / 16001`): compass ribbon, map and minimap pins, waypoint API, TomTom / RestedXP / tracked-quest bridges. Lua 5.1 semantics (WoW and LuaJIT).

## Layout

- `src/` is the addon (with `src/textures/`). Only this folder ships: copy it to `Interface\AddOns\Ribbon` (the folder name must match `Ribbon.toc`). A new file needs a full client restart, not `/reload`.
- `tests/` is the test suite (runner, jasmine-style framework, fakes, specs). It never ships.
- `README.md` is for players and addon authors; keep developer detail here.
- `src/probe/` (the `/ribbonprobe` inspection tool) is git-ignored and not in the TOC; see `.gitignore` to enable it locally.
- `assets/` holds the logo (`logo.svg`, `logo.png`) and the README screenshot. The textures in `src/textures/` and `src/icon.tga` are plain image files in the logo's colours; there is no build step, edit or replace them directly (32-bit uncompressed TGA, power-of-two sizes, top-left origin). Colours, sizes and texture paths live in `src/compass/Style.lua`; `tests/specs/style_spec.lua` checks that every texture it names exists. The shaped textures (`compass-dial`, `compass-needle`, `marker-fill`, `marker-rim`, `focus-ring`, and the quest badge's `quest-ring`, `quest-exclaim` and `quest-question`) are 128x128 and the bezel pieces (`bezel-corner`, `bezel-edge-h`, `bezel-edge-v`, `bezel-button`) 64x64 and drawn by `node tools/make-textures.js` (edit the script, not the TGAs); they are only ever shown smaller, because scaling a small texture up is what makes icons blurry. Keep every marker, dial and ring size even so they centre on whole pixels.

```
src/
  Ribbon.toc            load order (the specs read it too)
  core/                 Core (events, tickers, saved variables, start-up), Client (the only game-API adapter),
                        Geometry (pure math), Registry (waypoint model, API, distance, arrival),
                        Coordinates (/ribbon text parsing, zone lookup), Commands (/ribbon)
  compass/              Layout (pure placement), Style (colours, sizes, texture paths), Badge (the round icons: compass markers, step rows and the map preview pin share it), Compass (view)
  map/                  PinManager (pin bookkeeping, library injected), Map (wiring, Clear Pins button)
  integrations/         TomTom, RXP, Quest bridges, each with a pure Translate module
  guide/                Builder (chained calls a generated guide file makes; registers the one guide), Planner (pure: who sees which steps, positions, completion), Text (pure: captions from ids and the guide's name tables), Player (state, polling, waypoints, skip/jump), Browser (the chapter list (parent) and a chapter's steps (child page, with a back arrow, always opened first) in a gold-bezelled panel (the map frame's width and shape) docked beside the world map; the one view of the guide)
```

The guide layer is planned in `docs/guide-plan.md` (not shipped). Nothing in Ribbon knows about guides until the first `Ribbon.Guide(id, { schema = 1 })` call; the Builder is pure data, runs before the client is ready, and never raises (errors are kept on `guide.errors` and the bad chapter is skipped). `docs/samples/mulgore.lua` is real emitter output and `tests/specs/guide_spec.lua` loads it.

Data flows one way: `Client` reads the game, `Registry` turns waypoints plus the player's position into `dist` and `delta` at 30 Hz, and the views render what the registry holds. Views never compute positions themselves.

## Commands

```powershell
luajit tests/run.lua              # all specs; exit code 1 on failure (winget install DEVCOM.LuaJIT)
luajit tests/run.lua Registry     # specs whose full name contains "Registry"
.\package.ps1                     # output\Ribbon-<version>.zip: the TOC files, textures and icon under a Ribbon folder (output\ is git-ignored)
```

Run the specs before every commit and after every change under `src/`.

## Rules

- **Client boundary:** Only `src/core/Client.lua` calls game APIs for position, maps and quests (`UnitPosition`, `GetPlayerFacing`, `C_Map.*`, `C_QuestLog.*`, `C_SuperTrack.*`). Everything else calls `ns.client`.
- **Integration boundary:** Only `src/integrations/` touches other addons' globals (TomTom, RXPGuides, HereBeDragons). Observe them with `hooksecurefunc` or by reading; never replace their functions or install their globals (no `TomTom` global, no `/way`). Translating their data stays pure (`*Translate.lua`).
- **Pure logic:** Math, layout and row/model code take plain values and touch no frames or client globals. Keep new logic there and keep the views thin.
- **Fail soft:** Public API calls validate arguments and return `nil` on bad input. Never raise to a caller. Handler and ticker errors go to `geterrorhandler()`.
- **Load order:** `src/Ribbon.toc` is the single source; add every new file there.
- **Every module** starts with `local ADDON, ns = ...` and hangs its API off `ns`. Modules talk through `ns:On` / `ns:Fire` events (`INIT`, `WAYPOINT_ADDED`, `WAYPOINT_REMOVED`, `WAYPOINT_CHANGED`, `WAYPOINT_ARRIVED`, `FOCUS_CHANGED`).
- **Slash keys:** register each slash command under a key no other addon uses (`SlashCmdList["RIBBON_DEBUG"]`, not a short name another addon might choose): a later addon with the same key silently replaces it.
- **Tests:** Every behavior change gets a spec. Use the fakes in `tests/fakes/wow.lua` and verify calls with spies. Specs must pass with no real client.
- **Shell:** PowerShell on Windows. No Python or Go scripts; use PowerShell or Node for tooling.

## Measured client facts (change only after re-measuring)

- World axes: `UnitPosition("player")` returns `first, second, z, instanceID`; `first` increases north, `second` increases west. `C_Map.GetWorldPosFromMapPos` returns the same axes in the same order.
- `GetPlayerFacing()` is radians from north, increasing counter-clockwise. `delta = wrap(atan2(dSecond, dFirst) - facing)`: positive means the target is on the left; ribbon offset is `-delta / (FOV / 2) * (width / 2)`, clamped.
- Zone maps are not square (Stormwind City is about 1737 yd wide and 1158 yd tall), so all geometry uses world yards. Zone coordinates are 0-100; zones are `uiMapID`s. Waypoints on another `instanceID` are not projected.
- The client has the modern `C_Map` API and map data providers; `GetPlayerMapPosition` is absent.
- `UnitPosition` Z read 0 everywhere sampled (all in Stormwind). `C_Navigation.GetDistance` to the tracked quest is a 3D distance (engine² = flat² + height²), but gives the size of the height gap only, not its sign, and only for the one tracked target. Elevation is delayed, not dropped; a baked terrain-height data set from the forever_guide terrain export would give the sign for every waypoint.
- `C_QuestLog.GetQuestsOnMap(mapID)` lists quest points per map as 0-1 fractions; `GetNextWaypoint` returned nothing for the tracked quest probed.
- TomTom (v4.3.12): every way of setting a waypoint ends in `TomTom:AddWaypoint(m, x, y, opts)` with x and y as 0-1 fractions; a handle is `{ m, x, y, title = ... }`; `RemoveWaypoint` and `ClearAllWaypoints` funnel into `ClearWaypoint`. RXPGuides (v4.11.26): the arrow frame is the global `RXPG_ARROW`, its `element` carries `zone`, `x`, `y` (0-100) for zone targets.
- Pins use `LibStub("HereBeDragons-Pins-2.0")`. Ribbon embeds LibStub, CallbackHandler-1.0 and HereBeDragons 2.18 under `src/libs` (copied unmodified from RXPGuides; the 7.x migration file is left out). LibStub keeps the newest copy, so when RXPGuides or TomTom ships a newer one theirs wins and Ribbon shares it. The libraries load first in the TOC and are not run by the specs (the fakes stand in).

## Test suite

- `tests/framework/jasmine.lua`: `describe`, `it`, `beforeEach`, `afterEach`, `xit`, `fit`, `expect(...).toBe / toEqual / toBeCloseTo / toHaveBeenCalledWith / ...`, `.never` for negation (`not` is a Lua keyword).
- `tests/framework/spy.lua`: `andReturn`, `andCall`, `andCallThrough`; `spyOn(obj, "method")` is restored after each spec.
- `tests/fakes/wow.lua`: a fake client with a controllable world (measured Stormwind and Eastern Kingdoms bounds, player position and facing, quest tracking, missing-API simulation) and recording frames where every method is a spy.
- `tests/helpers/addon.lua`: loads `src/` in TOC order into a fresh namespace per spec (`H.use{ boot = true }`) or just pure modules (`H.pure{...}`).
- Specs are `tests/specs/*_spec.lua`, listed in `tests/specs.lua`. Pure modules are tested with plain values; the adapter and views against the fakes. Real frame layout and library rendering still need a check in the game.

## Not built

- Radius rings for area waypoints; elevation chevrons; dungeon and indoor behavior is unmeasured (the ribbon hides markers when position is unavailable).

## Do not

- Put test code, fakes or `luajit` references under `src/`.
- Commit `WTF/` or SavedVariables output.
- Edit the files in `src/libs` (third-party; replace them whole when updating) or load a second copy of a library outside LibStub.
