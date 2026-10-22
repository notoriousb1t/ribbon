# Changelog

## 1.2.0

### Added

- **In-world marker:** the current step's badge shows in the 3D view, scaled and lifted by distance and semi-transparent. When a step carries a height (`:Goto(map, x, y[, z])`), the marker lifts by the difference from your own height. On by default; toggle it in the guide's cog menu.
- **Objective locations:** red dots on the world map and minimap where the current step's creatures and objects are, taken from the step's spawn list. On by default; toggle it in the cog menu.
- **`/ribbon probe`:** reports which client APIs Ribbon found and how the map layers, for bug reports.
- **Guide calls:** `:Goto` takes an optional fourth argument `z` and accepts coordinates with three decimals.

### Changed

- **Diamond badges:** tracked-quest badges are diamonds, and the compass marker and caption icon are fitted to the band.
- **Map layering:** the world-map pin draws over the game's own waypoint, and the route line over the fog of war.
- **Grinds:** a grind with an XP gate ends as soon as you reach its level and XP, mid-grind or on arrival, without waiting for the next quest step. Its count is the route's estimate: kills still count past it, shown as "Kill Avala (3/~8)", or "Kill ~8 Avala" with no counter.
- **Unknown guide calls:** an unknown call in a guide is ignored instead of dropping its whole chapter; a step left with only ignored calls is dropped. `/ribbon guide errors` lists the ignored calls.
- **README:** new screenshots and a Guide player section.

### Fixed

- **Forever client:** the addon no longer registers the combat log, which the client forbids (it raised `ADDON_ACTION_FORBIDDEN`). Grind kills are counted from the XP chat line, matched by name against the guide's creatures, so chain pulls, damage-over-time and pet kills count. Classic Era still uses the combat log.
