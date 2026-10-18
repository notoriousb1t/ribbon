# Product Requirements Document (PRD): Compass Ribbon & Map Navigation Addon

**Feature:** Compass Ribbon, Map/Minimap Pins & Waypoint API
**Target Client:** Not yet confirmed. Run `/dump GetBuildInfo()` on the target server to settle it (see section 4).
**Status:** Draft

---

## 1. Executive Summary & Core Concept

A general-purpose navigation addon. Another addon (a guide, a quest helper, a user's `/way` command) drives it through a public Lua API; the addon itself holds no guide logic.

1. **Compass Ribbon:** A horizontal heading bar showing cardinal bearings, live player coordinates and markers for waypoints.
2. **Map & Minimap Pins:** The same waypoints plotted on the world map and minimap.
3. **Waypoint API:** Register, remove and hide waypoints; arrival callbacks; a TomTom-compatible layer.
4. **Optional Providers:** Any addon may feed waypoints. A guide provider (for example the compiled output of this repository's route engine) is one such client and is not part of the core addon.

---

## 2. Architecture

```
[Driver addon / slash command / TomTom-style caller]
                  |
        ForeverGuide public API (3.4)
                  |
     Waypoint registry (pooled)
        |-- Compass Ribbon frame
        |-- WorldMapFrame pins
        |-- Minimap pins
```

- The core addon has no dependency on any guide data, step schema, or quest state.
- Drivers own their own state (quest progress, grinds, ordering). The addon renders what it is given and reports arrival.

---

## 3. Core Feature Specifications

### 3.1 The Compass Ribbon

#### 3.1.1 Anchor & Display Bounds
- **Default Position:** Top-center of `UIParent`, vertical offset `-40px`, draggable and lockable.
- **Bar Geometry:** Dark translucent horizontal bar.
  - Width: 500px to 800px (configurable, default 600px).
  - Height: 28px track.
  - Center notch: vertical tick marking current heading.
- **Coordinate Badge:** Plaque above the center notch showing the player's map coordinates (for example `48.2, 42.9`).
- **Heading Scale:** Cardinal (N, E, S, W) and ordinal (NE, SE, SW, NW) labels; minor ticks every 5 degrees, major every 15 degrees.
- **Field of View:** Configurable 90 to 180 degrees, default 140.

#### 3.1.2 Projection Formula
For target `(Xt, Yt)`, player `(Xp, Yp)` and player facing `theta_player`:

```
theta_target = atan2(Yt - Yp, Xt - Xp)
delta        = wrap(theta_target - theta_player)   -- wrapped to [-pi, pi]
X_offset     = (delta / (FOV / 2)) * (BarWidth / 2)
```

- Markers clamp to the left or right edge when `|delta| > FOV / 2`.
- Implement `wrap` with the client's available math functions; do not rely on a `%` operator.
- Map coordinates are normalized zone coordinates; a map x/y axis convention (north = decreasing y) must be applied before `atan2`.

#### 3.1.3 Elevation Indicators (optional, fail-open)
Elevation is an enhancement. It never gates a marker, an arrival, or any other behavior.

- **Availability probe:** At load, and again on zone change, call the client's player-position API if one exists and check that it returns a numeric Z. If the API is missing, errors (wrap in `pcall`), returns `nil`, or always returns `0`, elevation is treated as unavailable.
- **Unavailable:** No chevrons are drawn; markers render exactly as on level ground; no warning, error or chat message is shown.
- **Available, but the waypoint has no `z`:** No chevron for that waypoint.
- **Available, and the waypoint has `z`:** `dZ = z_target - z_player`.
  - `dZ > +8 yd`: upward chevron above the icon.
  - `dZ < -8 yd`: downward chevron below the icon.
  - Otherwise: no chevron.
- **Arrival:** Arrival distance is always 2D (x, y). Z is never part of the arrival test.
- **Setting:** `elevation` option (`auto` default, `off`). `auto` follows the probe; `off` forces unavailable.
- **Runtime failure:** Any error while reading or comparing Z disables elevation for the session and leaves everything else running.

#### 3.1.4 Marker Icons
High-contrast white silhouettes: accept (`!`), turn-in (`?`), kill (crossed swords or skull), loot (chest or satchel), grind (crest), poi/transit (chevron).

---

### 3.2 Map & Minimap Overlay Subsystem

#### 3.2.1 World Map Pins
- The same icons as the ribbon, placed on `WorldMapFrame`.
- Pins project onto normalized map coordinates `(x / 100, y / 100)`.
- Optional radius rings for area waypoints (for example grind areas).
- Tooltips via `GameTooltip` showing title and any driver-supplied lines.

#### 3.2.2 Minimap Pins
- Out-of-range waypoints clamp to the minimap rim using polar projection (`angle = atan2(dy, dx)`).
- Distance and direction update as the player moves.

#### 3.2.3 Icon Clearing & Dismissal
- Right-click a pin to hide that waypoint on every surface (map, minimap, ribbon).
- A "Clear All" button in the `WorldMapFrame` header hides all pins.
- `/fg clear` hides all pins; `/fg show` restores them.
- Hidden waypoints stay hidden for the session until restored, or until the driver re-registers them. Hiding never alters any driver's state.

---

### 3.3 Optional Driver: Guide Provider

Not part of the core addon. A guide addon, such as one fed by this repository's route output, may register waypoints through the API and handle its own step logic (pickups, objectives, grinds, level gates). It may call `SetStepIconVisible`-style hiding through the same API. The core addon neither requires nor loads it.

---

### 3.4 Programmatic Lua API (TomTom-Compatible)

#### 3.4.1 Public Methods
- **`ForeverGuide:AddWaypoint(zone, x, y, options)`** returns a unique integer `uid`.
  - `options.title` (string): display name.
  - `options.icon` (string): `"accept"`, `"turnin"`, `"kill"`, `"loot"`, `"grind"`, `"poi"`.
  - `options.z` (number, optional): target height; used only for elevation chevrons (3.1.3).
  - `options.minimap`, `options.worldmap`, `options.compass` (boolean, default `true`).
  - `options.arrival_distance` (number, yards, default `5`; 2D).
  - `options.on_arrive` (function, optional): called once on arrival.
- **`ForeverGuide:RemoveWaypoint(uid)`**: removes it from every surface and returns it to the pool.
- **`ForeverGuide:ClearAllWaypoints()`**: removes all waypoints.
- **`ForeverGuide:SetWaypointVisible(uid, is_visible)`**: hides or restores one waypoint without removing it.

All methods validate arguments and fail soft: an unknown zone, bad coordinate or stale `uid` returns `nil` (or does nothing) rather than raising an error.

#### 3.4.2 TomTom Compatibility
When the standalone TomTom addon is not loaded, register a `TomTom` global and the `/way` command:
- `TomTom:AddZWaypoint(c, z, x, y, desc)` routes to `AddWaypoint`.
- `TomTom:RemoveWaypoint(uid)` routes to `RemoveWaypoint`.
- `/way [zone] <x> <y> [desc]` creates a waypoint.

---

## 4. Technical Constraints & Client Compatibility

- **Target client unconfirmed.** Determine the build with `/dump GetBuildInfo()` before finalizing the API scope.
- **Capability detection, not version assumptions.** Every optional client API (player facing, player position with Z, map position, unit XP) is probed at load and wrapped in `pcall`. A missing API disables only the feature that needs it.
  - Required for the ribbon: a player facing source and a player map position source.
  - Optional: player Z (3.1.3).
- **Frame pooling:** Static pools of 20 recycled frames for ribbon markers and map pins; grow only if a driver registers more.
- **Update throttling:**
  - Ribbon projection: 30 Hz (0.033 s) on `OnUpdate`.
  - Map pins: event-driven on `WORLD_MAP_UPDATE` and zone changes.
  - Minimap pins: throttled to 10 Hz.

---

## 5. Implementation Roadmap

1. **Phase 1: Core registry and API.** Waypoint registry, pooling, capability probes, `/fg` commands.
2. **Phase 2: Compass Ribbon.** Frame, heading scale, coordinate badge, projection, clamping.
3. **Phase 3: Map & Minimap.** `WorldMapFrame` pins, minimap rim clamping, dismissal controls.
4. **Phase 4: TomTom layer.** `TomTom` global and `/way`.
5. **Phase 5 (optional): Elevation chevrons.** Gated on the 3.1.3 probe.
6. **Phase 6 (optional): Guide provider.** A separate addon feeding this API; out of scope for the core.
