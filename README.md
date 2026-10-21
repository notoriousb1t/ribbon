<p align="center">
  <img src="assets/logo.svg" alt="Ribbon logo: a ribbon banner with a compass" width="160">
</p>

# Ribbon

Ribbon shows where your destination is on a compass bar at the top of your screen, and on the world map and minimap. It works with your quests, RestedXP, TomTom and your own waypoints, and other addons can send it waypoints too.

Built for the Forever beta client.

<p align="center">
  <img src="assets/screenshot.png" alt="Ribbon in game: a caption with the quest step above a teal ribbon bar, a waypoint marker and an off-screen arrow at each end, and a compass dial below" width="720">
</p>

<p align="center"><em>A RestedXP step on the compass: the step text above the bar, the quest target at the right end with an arrow to turn toward it, and the compass dial below.</em></p>

## Features

- **Compass ribbon:** a heading bar with a marker for each waypoint, and a compass dial in the middle of it whose needle always points to due north (hover the dial to see your coordinates, zone and heading; click it to open the guide). The markers pass over the dial; the direction names and the degree ticks stay under it. Above the bar, on a dark plate that stays readable over any scenery, you see the name and distance of the nearest (or focused) waypoint and a short description of what to do there.
- **Distance at a glance:** markers shrink as they get farther and grow as you close in. A waypoint close by is drawn taller than the ribbon itself, a distant one is small (never smaller than 18 px). A waypoint outside your field of view is held inside the end of the bar with an arrow pointing the way to turn. The direction labels (N, NE, ...) are outlined and shadowed so they stand out.
- **Map and minimap pins:** your waypoints drawn on the world map and minimap.
- **Tracked quest:** the quest you track in the game shows on the compass: a sword for a kill objective, a bag for an item objective, a quest icon for a turn-in or anything else, and the pick-up icon for a quest you can accept.
- **RestedXP:** the waypoint RXPGuides is pointing its arrow at shows on the compass as RXP's navigation arrow. Under the bar you see what the step says to do ("Kill Sharptusk Thornmantle (0/1)") rather than the step number, and it updates as you progress.
- **TomTom:** waypoints set through TomTom, including `/way`, show on the compass using the map dot from your TomTom theme.

RestedXP and TomTom keep drawing their own arrows and map icons. Ribbon only reads what they point at, so nothing changes for them.

## Install

1. Copy the `src` folder into your game's `Interface\AddOns` folder.
2. Rename it to `Ribbon`, so you have `Interface\AddOns\Ribbon\Ribbon.toc`.
3. Restart the game. (A `/reload` is not enough for new files.)

Ribbon works on its own: it bundles HereBeDragons for map pins (a newer copy from RestedXP or TomTom is shared if present). RestedXP and TomTom are read only if they are installed.

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
| `/ribbon compass opacity <20-100>` | How see-through the ribbon is, as a percentage (default 60). Text, markers and the caption stay solid. |
| `/ribbon compass dial <20-100>` | How see-through the compass dial is, as a percentage (default 70). Its needle stays solid. |
| `/ribbon compass fov <90-180>` | Set how wide an angle the bar covers. |
| `/ribbon guides` | With a guide installed, open the guide panel beside the world map (opening the map too), on the steps of the chapter you are in. Steps are laid out like quests in the quest log, under a header with the chapter's name that folds them away: a gold title ("[3/12] Turn in ..."), the rest of what the step says as objectives under it, and a check mark once it is done. Each step has the icon of what it asks for: click it to preview it on the world map (the map switches to its zone and centres on it), or use the arrow that appears when you hover it to make it your current step. The search box at the top narrows both the chapters and the steps as you type (the steps of every chapter that match, each chapter under a section header of its own), forgiving typos and missing letters (crssrods finds Crossroads). The back arrow goes to the list of chapters, each with its levels and a progress bar. Your progress through the whole guide is a thin loader bar along the bottom of the map button; hover the button, or a chapter, for the percentage. The same panel opens from the blue Ribbon button above the map's quest log toggle, or by clicking the compass dial in the middle of the ribbon. It reopens next session if you left it open. |

- Drag the compass to move it. `/ribbon compass lock` stops the compass moving.
- Left-click a marker on the compass to focus it: it grows and its name and distance show under the bar. Click it again to go back to the nearest waypoint.
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
  description = "Buy a new hammer",  -- short text shown under the bar (up to two lines)
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
