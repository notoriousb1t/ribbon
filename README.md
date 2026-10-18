<p align="center">
  <img src="assets/logo.svg" alt="Ribbon logo: a ribbon banner with a compass" width="160">
</p>

# Ribbon

Ribbon shows where your destination is on a compass bar at the top of your screen, and on the world map and minimap. It works with your quests, RestedXP, TomTom and your own waypoints, and other addons can send it waypoints too.

Built for the Forever beta client.

## Features

- **Compass ribbon:** a heading bar with a marker for each waypoint, your live coordinates, and the name and distance of the nearest one.
- **Map and minimap pins:** your waypoints drawn on the world map and minimap.
- **Tracked quest:** the quest you track in the game shows on the compass: a skull for a kill objective, a bag for an item objective, a quest icon for a turn-in or anything else, and the pick-up icon for a quest you can accept.
- **RestedXP:** the waypoint RXPGuides is pointing its arrow at shows on the compass as RXP's navigation arrow.
- **TomTom:** waypoints set through TomTom, including `/way`, show on the compass using the map dot from your TomTom theme.

RestedXP and TomTom keep drawing their own arrows and map icons. Ribbon only reads what they point at, so nothing changes for them.

## Install

1. Copy the `src` folder into your game's `Interface\AddOns` folder.
2. Rename it to `Ribbon`, so you have `Interface\AddOns\Ribbon\Ribbon.toc`.
3. Restart the game. (A `/reload` is not enough for new files.)

Ribbon is optional-friendly: it works on its own, and RestedXP, TomTom and HereBeDragons are used only if they are installed.

## Using it

| Command | What it does |
| --- | --- |
| `/ribbon [zone] <x> <y> [description]` | Set a waypoint, for example `/ribbon Stormwind City 49.5 71 Auction House`. Without a zone it uses the one you are in. |
| `/ribbon clear` | Hide every waypoint. |
| `/ribbon show` | Bring hidden waypoints back. |
| `/ribbon list` | List your waypoints with distances. |
| `/ribbon remove <number>` | Remove one waypoint (the number is shown in `list`). |
| `/ribbon compass [show\|hide\|toggle\|lock\|unlock\|reset]` | Show, hide, lock or reset the compass. |
| `/ribbon compass width <500-800>` | Set the bar width. |
| `/ribbon compass fov <90-180>` | Set how wide an angle the bar covers. |

- Drag the compass to move it. `/ribbon compass lock` stops the compass moving.
- Right-click any marker or pin to hide that waypoint everywhere.
- The world map has a **Clear Pins** button that hides every pin.
- Waypoints on another continent are not shown on the compass.

### Troubleshooting

- `/ribbon debug` prints your position as the addon reads it.
- `/ribbon tomtom` and `/ribbon rxp` show whether TomTom or RestedXP was found and what Ribbon is mirroring from it.
- If Ribbon says it is dormant, the game client is missing an API it needs; the message names it.

## For addon authors

Send Ribbon waypoints from your own addon:

```lua
local uid = Ribbon:AddWaypoint(uiMapID, x, y, {
  title = "Anvil Mar",            -- display name
  icon = "turnin",                -- accept, turnin, kill, loot, grind, poi
  minimap = true, worldmap = true, compass = true,   -- where to draw it (default true)
  arrival_distance = 5,           -- yards (default 5)
  on_arrive = function(uid) end,  -- called once when the player arrives
  lines = { "Quest giver" },      -- extra tooltip lines
})
Ribbon:RemoveWaypoint(uid)
Ribbon:ClearAllWaypoints()
Ribbon:SetWaypointVisible(uid, false)
Ribbon:SetFocus(uid)              -- caption this waypoint instead of the nearest
```

- `x` and `y` are 0-100 zone coordinates, and zones are `uiMapID`s (for example `1453` Stormwind City, `1439` Darkshore).
- Every call checks its arguments and returns `nil` (or does nothing) on bad input; it never raises an error.
- `on_arrive` fires once when the player comes within `arrival_distance` yards and again after they leave and return. Arrival ignores height.

## Not yet supported

- Height: the client reports no elevation, so the compass cannot show whether a target is above or below you.
- Quests whose marker is on a different map than the one you are standing in.
- Circles around area waypoints.
