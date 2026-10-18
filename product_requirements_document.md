# Product Requirements Document (PRD): Compass Ribbon & Map Navigation Addon

**Feature:** Compass Ribbon, Map/Minimap Pins & Waypoint API
**Target Client:** Forever beta, build `1.60.1 / 70450 / 16001` (`WOW_PROJECT_ID` 18), install at `_classic_beta_`. Measured with the RibbonProbe addon (section 4).
**Status:** Draft v2 (client confirmed; elevation delayed; HereBeDragons adopted)

---

## 1. Executive Summary & Core Concept

A general-purpose navigation addon. Another addon (a guide, a quest helper, a user's `/way` command) drives it through a public Lua API; the addon itself holds no guide logic.

1. **Compass Ribbon:** A horizontal heading bar showing cardinal bearings, live player coordinates and markers for waypoints.
2. **Map & Minimap Pins:** The same waypoints plotted on the world map and minimap.
3. **Waypoint API:** Register, remove and hide waypoints; arrival callbacks; a TomTom-compatible layer.
4. **Optional Providers:** Any addon may feed waypoints. A guide provider (for example the compiled output of this repository's route engine) is one such client and is not part of the core addon.

### Non-goals (v1)
- Elevation chevrons: delayed, not dropped. The client reports Z = 0 today; see 4 and Phase 6.
- Guide, quest or step logic inside the core addon.
- Any client other than the Forever beta build in the header.
- Waypoint persistence across sessions.

---

## 2. Architecture

```
[Driver addon / slash command / TomTom-style caller]
                  |
        Public API (3.4)  (global name: see Open Questions)
                  |
     Waypoint registry (pooled; world-yard coordinates)
        |-- Compass Ribbon frame
        |-- World map pins   (HereBeDragons-Pins)
        |-- Minimap pins     (HereBeDragons-Pins)
```

- The core addon has no dependency on any guide data, step schema, or quest state.
- Drivers own their own state (quest progress, grinds, ordering). The addon renders what it is given and reports arrival.
- **Library:** HereBeDragons-2.0 and HereBeDragons-Pins-2.0 via LibStub. The Forever beta client already has `HereBeDragonsPinsTemplate` registered on the world map (loaded by RXPGuides or Forever_Guide), so this addon must obtain the shared instance through `LibStub` and embed nothing that would register a second copy. `HereBeDragons` is not a global; only `LibStub` reaches it.

---

## 3. Core Feature Specifications

### 3.1 The Compass Ribbon

#### 3.1.1 Anchor & Display Bounds
- **Default Position:** Top-center of `UIParent`, vertical offset `-40px`, draggable and lockable.
- **Bar Geometry:** Dark translucent horizontal bar.
  - Width: 500px to 800px (configurable, default 600px).
  - Height: 28px track.
  - Center notch: vertical tick marking current heading.
- **Coordinate Badge:** Plaque above the center notch showing the player's map coordinates (for example `48.2, 42.9`), from `C_Map.GetPlayerMapPosition(mapID, "player")`. Hidden when no position is available (indoors, instances).
- **Heading Scale:** Cardinal (N, E, S, W) and ordinal (NE, SE, SW, NW) labels; minor ticks every 5 degrees, major every 15 degrees.
- **Field of View:** Configurable 90 to 180 degrees, default 140.

#### 3.1.2 Projection Formula
All geometry is in **world yards**, never normalized map coordinates (zone maps are not square: Stormwind City is 1737 yd wide by 1158 yd tall).

Position sources (measured, section 4):
- Player: `UnitPosition("player")` returns `first, second, z, instanceID`.
- Waypoint: `C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(x/100, y/100))` returns `instanceID, Vector2D`, where `Vector2D.x` is the same axis as `first` and `Vector2D.y` the same as `second`.
- `first` increases **north**. `second` increases **west**.
- `GetPlayerFacing()` is in radians, 0 = north, increasing **counter-clockwise**.

```
dFirst        = target.first  - player.first
dSecond       = target.second - player.second
theta_target  = atan2(dSecond, dFirst)        -- 0 = north, CCW positive (same convention as facing)
delta         = wrap(theta_target - facing)   -- wrapped to [-pi, pi]; positive = target is to the LEFT
X_offset      = (-delta / (FOV / 2)) * (BarWidth / 2)   -- negate so left targets draw left
distance      = sqrt(dFirst^2 + dSecond^2)    -- yards, 2D
```

- Markers clamp to the left or right edge when `|delta| > FOV / 2`.
- Implement `wrap` with the client's available math functions; do not rely on a `%` operator.
- Waypoints on a different `instanceID` than the player are not projected (hidden on the ribbon and minimap; listed in the tooltip only if the driver asks).
- Waypoints in a different zone but the same `instanceID` project normally, since world coordinates are continuous within a continent.
- No position (`UnitPosition` returns nil or the map position is nil): ribbon markers hide; the heading scale still renders from `GetPlayerFacing`.

#### 3.1.3 Marker Icons
High-contrast white silhouettes: accept (`!`), turn-in (`?`), kill (crossed swords or skull), loot (chest or satchel), grind (crest), poi/transit (chevron).

#### 3.1.4 Marker Priority & Declutter
- The nearest waypoint (by distance) is drawn on top; its title and distance are shown in the badge.
- Markers within 8 px of each other stack; only the nearest shows a label.
- Maximum 20 markers drawn on the ribbon at once; the rest are skipped nearest-first.

---

### 3.2 Map & Minimap Overlay Subsystem

#### 3.2.1 World Map Pins
- Placed through HereBeDragons-Pins (`AddWorldMapIconMap`), keyed by `uiMapID` and normalized `(x / 100, y / 100)`; the library owns the data provider and refresh.
- Optional radius rings for area waypoints (for example grind areas).
- Tooltips via `GameTooltip` showing title and any driver-supplied lines.

#### 3.2.2 Minimap Pins
- Placed through HereBeDragons-Pins (`AddMinimapIconMap`). The library handles zoom yards-per-pixel, edge clamping and `rotateMinimap`, so the addon does not implement polar projection itself.
- Out-of-range waypoints clamp to the rim (library option); the addon passes the rim-clamp flag per waypoint.
- Distance and direction update as the player moves (library-driven).

#### 3.2.3 Icon Clearing & Dismissal
- Right-click a pin to hide that waypoint on every surface (map, minimap, ribbon).
- A "Clear All" button in the `WorldMapFrame` header hides all pins.
- `/ribbon clear` hides all pins; `/ribbon show` restores them.
- Hidden state is stored per `uid`. Re-registering the same waypoint (same `uid` via `SetWaypoint`-style update) keeps it hidden; a new `AddWaypoint` call returns a new `uid` and is visible. Hiding never alters any driver's state.

---

### 3.3 Optional Driver: Guide Provider

Not part of the core addon. A guide addon, such as one fed by this repository's route output, may register waypoints through the API and handle its own step logic (pickups, objectives, grinds, level gates). It may hide waypoints through the same API. The core addon neither requires nor loads it.

---

### 3.4 Programmatic Lua API (TomTom-Compatible)

#### 3.4.1 Public Methods
Zones are identified by `uiMapID` (for example `1439` Darkshore, `1453` Stormwind City). Localized zone names are accepted only as a convenience lookup and never stored.

- **`<Addon>:AddWaypoint(uiMapID, x, y, options)`** returns a unique integer `uid`. `x`, `y` are 0-100.
  - `options.title` (string): display name.
  - `options.icon` (string): `"accept"`, `"turnin"`, `"kill"`, `"loot"`, `"grind"`, `"poi"`.
  - `options.minimap`, `options.worldmap`, `options.compass` (boolean, default `true`).
  - `options.arrival_distance` (number, yards, default `5`; 2D world yards).
  - `options.on_arrive` (function, optional): called once per arrival; see arrival rules below.
- **`<Addon>:RemoveWaypoint(uid)`**: removes it from every surface and returns it to the pool.
- **`<Addon>:ClearAllWaypoints()`**: removes all waypoints.
- **`<Addon>:SetWaypointVisible(uid, is_visible)`**: hides or restores one waypoint without removing it.

All methods validate arguments and fail soft: an unknown `uiMapID`, bad coordinate or stale `uid` returns `nil` (or does nothing) rather than raising an error.

**Arrival rules**
- Checked at the ribbon update rate against 2D world-yard distance; Z is never used.
- `on_arrive` fires once on entering the radius, runs under `pcall`, and re-arms only after the player leaves the radius by at least `arrival_distance * 1.5`.
- An arrived waypoint is not removed automatically; the driver decides.

#### 3.4.2 TomTom Compatibility
`TomTom` is not loaded in the target client (`TomTom` global is `nil`), so register a `TomTom` global and `/way` only when the standalone addon is absent (check `OptionalDeps` or `ADDON_LOADED` for it, so load order never lets two copies fight).
- `TomTom:AddWaypoint(uiMapID, x, y, opts)` and `TomTom:AddZWaypoint(c, z, x, y, desc, ...)` route to `AddWaypoint`. Real TomTom passes continent `c` and zone index `z`; both are resolved to a `uiMapID` through `C_Map.GetMapInfo` children, and unresolved pairs return `nil`.
- `TomTom:RemoveWaypoint(uid)` accepts the returned handle. Real TomTom returns a table `uid`; here the handle is the integer, and callers only treat it as opaque.
- `/way [zone] <x> <y> [desc]` creates a waypoint in the current map when `zone` is omitted.

---

## 4. Technical Constraints & Client Compatibility

### 4.1 Measured client facts (RibbonProbe, 2026-10-17)
- **Build:** `1.60.1 / 70450 / 16001`, `WOW_PROJECT_ID` 18, locale `enUS`.
- **Map API:** `C_Map` present; `GetPlayerMapPosition` and `SetMapToCurrentZone` absent. `C_Map.GetBestMapForUnit`, `GetPlayerMapPosition(mapID, "player")`, `GetWorldPosFromMapPos`, `GetMapRectOnMap`, `GetMapWorldSize`, `GetMapPosFromWorldPos`, `GetMapInfo` and `GetMapChildrenInfo` all exist.
- **World map:** Data-provider model; `WorldMapFrame.AddDataProvider`, `AcquirePin`, `RemoveAllPinsByTemplate` and `pinPools` exist. `WorldMapFrame.ScrollContainer.GetCanvas` does not (use `WorldMapFrame:GetCanvas()` or `ScrollContainer.Child` if the canvas is needed).
- **Facing:** `GetPlayerFacing`, radians, increases counter-clockwise (4.8129 to 6.2266 after a quarter turn left).
- **Position:** `UnitPosition("player")` returns `first, second, z, instanceID`; `first` north-positive, `second` west-positive; both match `C_Map.GetWorldPosFromMapPos` output in axis and order.
- **Z:** always `0` (flat city and canal samples). Elevation unavailable for now; delayed (Phase 6).
- **Minimap:** 198 x 198 px, 6 zoom levels, `rotateMinimap` = 0, no `GetMinimapShape`. Yards per pixel not measured; delegated to HereBeDragons-Pins.
- **Protection:** `Minimap` and `WorldMapFrame` are unprotected out of combat.
- **Other loaded addons:** `RXPGuides`, `Forever_Guide`. `HereBeDragonsPinsTemplate` is already on the world map.
- **Probe addon:** `Ribbon\RibbonProbe` (`/rprobe`, `/rprobe sample <label>`); output at `WTF\Account\<ACCOUNT>\SavedVariables\RibbonProbe.lua`.

### 4.2 Requirements
- **Capability detection.** Every optional client API is probed at load and wrapped in `pcall`. A missing API disables only the feature that needs it.
  - Required: `GetPlayerFacing`, `UnitPosition`, `C_Map.GetWorldPosFromMapPos`, `LibStub` with HereBeDragons-Pins.
  - If a required API is missing, the addon prints one chat line and stays dormant.
- **Frame pooling:** Pools sized 20 for ribbon markers and map pins; grow when a driver registers more; never shrink within a session.
- **Update throttling:**
  - Ribbon projection and arrival: 30 Hz (0.033 s) on `OnUpdate`, only while the ribbon is shown.
  - Map and minimap pins: handled by HereBeDragons-Pins; the addon updates only on waypoint add, remove or visibility change.
- **Saved variables:** Ribbon position, width, FOV, lock state and hidden-surface toggles. Waypoints and hidden-waypoint state are session-only.
- **Combat:** Frame creation and show/hide of the ribbon and pins is allowed in combat (unprotected frames); no secure templates are used.

---

## 5. Implementation Roadmap

1. **Phase 1: Core registry and API.** Waypoint registry, pooling, capability probes, world-yard conversion, arrival checks, `/ribbon` commands.
2. **Phase 2: Compass Ribbon.** Frame, heading scale, coordinate badge, projection (3.1.2), clamping, declutter.
3. **Phase 3: Map & Minimap.** HereBeDragons-Pins integration, dismissal controls.
4. **Phase 4: TomTom layer.** `TomTom` global and `/way`.
5. **Phase 5 (optional): Guide provider.** A separate addon feeding this API; out of scope for the core.
6. **Phase 6 (delayed): Elevation chevrons.** Optional `options.z`; availability probe (API present, numeric, not always `0`), fail-open, chevron above for dZ > +8 yd and below for dZ < -8 yd, 2D arrival unchanged, `elevation` setting `auto`/`off`, any Z error disables it for the session. Start only after the probe shows non-zero Z.

---

## 6. Acceptance Criteria
- Bearing error at most 2 degrees against `UnitPosition` ground truth on a 5-point test route in one zone and one cross-zone leg on the same continent.
- Turning the character left moves ribbon markers right.
- 20 waypoints on screen cost under 0.5 ms per ribbon update (profile with `debugprofilestop`).
- Zero Lua errors with the following disabled in turn: HereBeDragons-Pins, `C_Map` waypoint conversion, `GetPlayerFacing`.
- Arrival callback fires exactly once per approach and re-arms only after leaving the 1.5x radius.
- Hidden waypoints stay hidden after `/reload`-free zone changes and are restored by `/ribbon show`.

---

## 7. Open Questions
1. **Addon and global name.** `ForeverGuide` collides with the existing `Forever_Guide` output addon. Choose a neutral name (working title: `Ribbon`) and keep `ForeverGuide` for the optional provider.
2. **HereBeDragons-Pins version.** Confirm which copy is already loaded (RXPGuides or Forever_Guide) and that its API matches `AddWorldMapIconMap` / `AddMinimapIconMap`.
3. **Z.** Re-probe after any client update; the elevation feature starts when Z is non-zero, or when a driver supplies `z`.
4. **Instances and indoor maps.** Verify `UnitPosition` and `C_Map.GetPlayerMapPosition` behavior in a dungeon; the ribbon hides markers there until measured.
