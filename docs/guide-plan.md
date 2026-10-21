# Guide player: plan

Ribbon plays the Forever Guide. The Forever Guide generator emits the route as Lua; Ribbon registers it, tracks progress and pushes the active step into the compass, map and minimap. It replaces RestedXP for this guide. This document is the feature set and the order to build it in; nothing here is implemented yet.

## Decisions so far

- **Generator owns the route.** Grouping, order, and spawn lists are computed in Forever Guide (`rust/build`). Ribbon never plans the quest route; it only routes travel between zones with its own coarse mesh.
- **Ribbon plays and counts.** It loads the data, filters it for the character, tracks progress, and feeds `ns:AddWaypoint` and the pin manager. The compass and map views do not change.
- **Nothing shows without a guide.** No frames, tickers, events, commands or saved data for the guide layer until `Ribbon:RegisterGuide` succeeds. One guide at a time; a second registration is refused.
- **Guide data is a separate addon** (for example `Forever_Guide`, `## Dependencies: Ribbon`). It calls the builder at load. Ribbon ships no guide data.
- **Lua builder that mirrors the RXP text format.** Chained calls (`:Goto`, `:Accept`, `:Kill`, ...) that compile to plain tables. Generated files read like the guides people know.
- **Ids, not names.** Zones are `uiMapID`, everything else numeric ids. Each emitted file defines private `local NAME = id` constants so calls read as words.
- **Two-decimal coordinates** everywhere, printed `%.2f`. One decimal causes visible errors on the compass.
- **Captions are generated from objectives** ("Kill Plainstrider (3/7)"), never authored. The emitter still writes the readable name as a trailing comment for reviewers; the runtime ignores it.
- **Steps group objectives across quests** ("kill X and Y, loot N and M, interact with U"), and a quest's objectives may be split over different steps.
- **Grinds with mob counting** are first-class, not a note on a step.
- **Travel steps name a destination only.** Ribbon routes it from the player's position over its own coarse mesh (nodes at zone entrances, docks, towers), like a GPS, instead of one global arrow. No walkmesh in the guide data.

## Architecture

```
Forever Guide (Rust)                         Ribbon (Lua)
  world.db / guide.db / walkmesh               guide/Builder   chained calls -> tables
  rust/build  --emit-->  Forever_Guide addon   guide/Data      validate, filter by class/race
                         (builder calls)       guide/Planner   active step, progress state
                                               guide/Counter   kill counting for grinds
                                               guide/Player    views, events, commands
                                                    |
                                  ns:AddWaypoint / PinManager groups / Ribbon caption
```

- **Pure modules** (`Builder`, `Data`, `Planner`, `Counter`): no client calls, covered by the fake client and specs.
- **`Client.lua`** stays the only game-API adapter; new calls (combat log, level, XP, zone) go there, pcall-wrapped.
- **`Player`** is the single entry (`ns.guide.start(guide)`), called from `RegisterGuide`. Before that, the guide files are inert function definitions.
- **Events** use the existing `ns:On` / `ns:Fire`; new ones: `GUIDE_STEP_CHANGED`, `GUIDE_OBJECTIVE_DONE`, `GUIDE_FINISHED`.

## Builder format

The emitter (`rust/build/ribbon.rs` in Forever Guide) writes one file per chapter; `docs/samples/mulgore.lua` is its output for the Mulgore starting guide. Shape:

```lua
local R = Ribbon.Guide("forever-hordev1", { title = "WoW Forever (1-60)", schema = 1 })   -- get or create, shared by every chapter file

local MAP = { MULGORE = 1412 }                                  -- constant tables, one per kind of id
local NPC = { GRULL_HAWKWIND = 2980, CHIEF_HAWKWIND = 2981 }    -- (tables, not locals: Lua allows 200 locals per chunk)
local SPAWNS = { PLAINSTRIDER_MEAT_MULGORE = { { 42.20, 77.70 }, { 42.30, 81.10 } } }

R:Chapter("1-11 Mulgore (Tauren)", { levels = { 1, 11 }, race = "TAUREN", faction = "HORDE", next = "..." })
  :Step()                                                       -- hub: accepts at two NPCs
    :Goto(MAP.MULGORE, 44.50, 77.50)
    :Accept(QUEST.THE_HUNT_BEGINS):At(NPC.GRULL_HAWKWIND)       -- The Hunt Begins
    :Goto(MAP.MULGORE, 43.90, 76.70)
    :Accept(QUEST.A_HUMBLE_TASK):At(NPC.CHIEF_HAWKWIND)         -- A Humble Task
  :Step()                                                       -- field: two objectives of one quest
    :Goto(MAP.MULGORE, 47.00, 77.80)
    :Loot(ITEM.PLAINSTRIDER_MEAT, 7, { quest = QUEST.THE_HUNT_BEGINS, index = 1, from = { CREATURE.PLAINSTRIDER } })
    :Spawns(MAP.MULGORE, SPAWNS.PLAINSTRIDER_MEAT_MULGORE)
    :Loot(ITEM.PLAINSTRIDER_FEATHER, 7, { quest = QUEST.THE_HUNT_BEGINS, index = 2, from = { CREATURE.PLAINSTRIDER } })
    :Spawns(MAP.MULGORE, SPAWNS.PLAINSTRIDER_MEAT_MULGORE)
  :Done()
```

- **Located groups:** a `:Goto` (or `:Loop`) starts a group; the calls after it, until the next `:Goto`, happen there. A step holds several groups, so "accept at two NPCs" or "kill here, loot there" is one step.
- **`flavor`** (chapter option or `:Only{ flavor = }`): `"FOREVER"`, `"CLASSIC"` (Classic Era) or `"RETAIL"`, from `WOW_PROJECT_ID`; chapters of different flavors may share a name. Without it a chapter shows on every client.
- **`:Only{ class=, race=, faction= }`** directly after `:Step()` locks the whole step. Inside a step it closes the located group before it.
- **`:Spawns(map, SPAWNS.X)`** attaches the map points to the objective call before it. The points live once in the file's `SPAWNS` table, so objectives with one source share them. At most 60 points per objective, evenly thinned.
- **Constants:** `GROUP.NAME` references, upper-case names from the store, a numeric suffix when two records share a name (`QUEST.A_HUMBLE_TASK_753`). Flight points and inns have no ids in the store, so `NODE` holds their names as strings.
- **`:Grind` goals** are `count = N`, `level = L` or `level = L, xp = N` (`until` is a Lua keyword).

| RXP | Builder | Notes |
| --- | --- | --- |
| `.goto Zone,x,y` | `:Goto(mapID, x, y)` | `:Loop(mapID, { {x, y}, ... })` for a search loop |
| `.accept` / `.turnin` | `:Accept(q)` / `:Turnin(q)` + `:At(npc)` | quest and NPC ids |
| `.collect` + `.use` (item starts a quest) | `:Collect(item, 1, { quest = q })`, `:Use(item)` | |
| `.complete id,n` (kill) | `:Kill(creature, n, { quest, index })` | |
| `.complete id,n` (loot) | `:Loot(item, n, { quest, index, from = { creatures }, objects = { objects } })` | |
| `.complete id,n` (use object) | `:Interact(object, { quest, index })` | |
| `.complete` with no log line | `:Explore(q, { index, npc })` | find an NPC or place |
| `.fp` / `.fly` / `.hs` / `.home` | `:Fp(node)` / `:Fly(node)` / `:Hearth(node)` / `:Home(node)` | `node` is a `NODE` name |
| `.xp L` | `:Ding(level)` | |
| `.trainer` | `:Train(npc, { "ability", ... })` | |
| `.deathskip` | `:Deathwarp()` | |
| skipped quest | `:Skip(q)`; `:Skippable()` marks an optional step | |
| `.zone` / `.subzone` | `:Travel()`, `:Enter(map)`, `:Subzone("name")` | routed by Ribbon's travel mesh |
| `<< Class Race` | `:Only{ ... }` | |
| none | `:Grind(map, x, y, radius, { npc = {...}, count / level / xp })` | counted by Ribbon |

- Builder methods validate as they are called (types, 0-100 range, `isValidMap`). A bad call records an error with chapter and step number; the chapter is skipped, the guide still loads.
- Output is plain tables, immutable after registration. The player never interprets builder calls.

## Features

### 1. Registration and gating
- `Ribbon:RegisterGuide(guide)` validates `schema`, structure and ids, returns `nil` on bad input, refuses a second guide.
- Guide layer built lazily inside `RegisterGuide`; no frames or events before it.
- `/ribbon guide` is absent from help and answers "no guide installed" when there is none.
- Saved progress in `RibbonDB.guide[<character>]`, keyed by guide id; resumes if the guide returns.
- RXP bridge pauses while a guide is registered; the tracked-quest bridge keeps running but hides its waypoint when the active step already covers that quest.

### 2. Step player
- **Step kinds:** `hub` (pickups and turn-ins at one place), `objectives` (grouped), `grind`, `travel`, `ding`, `train`, `deathwarp`.
- **Filtering:** `class`, `race`, `faction` evaluated from `UnitClass`/`UnitRace`; one data file serves every character.
- **Progress:** each step `pending`, `active`, `done`. A step completes when all its objectives are done. Out-of-order play marks objectives done early and drops their markers. An abandoned quest flags the step.
- **Advance sources:** `QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, `PLAYER_LEVEL_UP`, zone change, combat log. Registered through pcall (unknown events error in this client).
- **Commands:** `/ribbon guide` (status), `next`, `prev`, `skip`, `reset`, `step <n>`.

### 3. Grouped objectives and markers
- One active step shows a checklist: "Plainstrider 3/7, Plainstrider Feather 1/7, Water Pitcher 0/1".
- **Compass:** one waypoint at the cluster centre or nearest unfinished spawn; caption headline is the primary objective and distance, detail lines list the others.
- **Map and minimap:** a pin group per objective, one dot per spawn plus the centroid icon. Completing an objective removes its group at once; a 8/8 kill disappears while the quest stays open.
- **Scope:** active step only, plus a dimmed preview of the next hub. Spawn points are capped per objective by the generator (about 60) by clustering.
- **PinManager** gains groups: add, replace and clear as a unit.
- Loot objectives that drop from many mobs map to those mobs' spawns through `item_source`.

### 4. Grinds with mob counting
- **Step:** `:Grind(mapID, x, y, radius, { npc = {ids}, count = N })` , `{ level = L }` or `{ level = L, xp = N }` (`until` is a Lua keyword).
- **Counting:** `COMBAT_LOG_EVENT_UNFILTERED` `PARTY_KILL`; parse the NPC id from the GUID, match against the step's targets, count only kills by the player, the party or a pet. Fallback: the XP-gain chat line (name only, localised).
- **Persisted** in `RibbonDB` per step so `/reload` and relog keep it; reset by `/ribbon guide reset`.
- **Display:** away from the area the waypoint is the area centre; inside it the caption becomes the counter ("Greater Plainstrider 23/40").
- **To verify first:** the combat log API exists in the Forever client (use the local probe tool, which is git-ignored).

### 5. Travel: a coarse mesh inside Ribbon (after the guide player works)
- **The guide only names a destination.** `:Travel()` takes its destination from the `:Goto` before it (the emitter already writes that, plus `:Enter(map)` / `:Subzone(name)` when the step names a zone). The guide carries no paths and no walkmesh data.
- **Ribbon owns a small travel mesh**, a graph with a node at each crossing between zones (road and tunnel entrances, docks, zeppelin towers, tram stations, flight masters, portals). Edges are typed `walk`, `boat`, `zeppelin`, `tram`, `flight`, `portal`, each with a cost.
- **GPS behaviour:** from wherever the player is, Ribbon finds the nearest node, runs a shortest path to the node nearest the destination, and puts the next node on the compass. It advances on arrival or on a map change and re-routes when the player leaves the route, so "travel to Menethil Harbor" points at the right tunnel or dock instead of one global bearing.
- **Typed legs are announced once** ("Take the boat to Auberdine"), and the compass waits for the map change before continuing.
- **Source of the mesh:** a static data file in Ribbon (`src/travel/Mesh.lua`), exported once from the Forever Guide travel network (`data/network`: hubs, flight paths, boats, tram, portals, ground links) at zone-crossing granularity only. Pure routing module with specs; no client calls beyond position.
- **Elevation:** none; multi-level cities get nodes close together and short arrival radii.
- **Also usable without a guide:** `/ribbon travel <zone or x y>` routes the same way for any player.

### 6. What replaces RXP
- Needed: step text (generated), auto-advance, class/race filtering, resume, skip, hearth and flight prompts.
- Not at first: use-item buttons, gossip automation, auto-accept, gear and talent advice. Decide per feature later.

## Emitter (Forever Guide)

- **Implemented** in `rust/build/ribbon.rs`: `cargo run --release -- --guide hordev1 build` writes `output/hordev1/ribbon/<chapter>.lua` and `Forever_Guide.toc` beside the RestedXP files. The same hydrated steps feed both, so the two outputs can be compared quest by quest.
- One chapter per file; every call on its own line; constants in tables at the top; trailing comments with names; `%.2f` coordinates; steps grouped with the `phase` mode (consecutive pickups and turn-ins form a hub step, consecutive objectives a field step).
- Spawn lists are shared in a `SPAWNS` table and thinned to 60 points per objective. All 48 Horde chapters load against a strict stub builder with no nil arguments, so every constant reference resolves.
- `validate` gains checks: every id resolves, coordinates are in range and two-decimal, path points are walkable, consecutive path points are within a limit, transition nodes exist in the network.
- The RXP emitter and `Forever_Guide.toc` for RXP are dropped once Ribbon plays the guide.
- Spawn precision: the store's spawns are one decimal; only coordinates the generator computes (centroids, path points) get a real second decimal.

## Tests

- Specs on the fake client for: no frames or events before registration, second registration refused, bad schema refused, builder validation errors, class/race filtering, step advance on quest events, early-completed objective drops its pins, grind counter (credit rules, persistence across a simulated reload), travel segment advance and off-path recovery.
- Generator: golden-file comparison of the Mulgore chapter, plus a check that the builder file and the RXP file describe the same quests, objectives and coordinates.

## Build order

1. **Format, sample and emitter (done for the Horde guide).** The emitter fixes the builder format; `docs/samples/mulgore.lua` is its real output for Mulgore. Not yet: the Alliance guide check.
2. **Builder and registration** in Ribbon (done: `src/guide/Builder.lua`, `tests/specs/guide_spec.lua`; `Ribbon.Guide(id, opts)` is get-or-create and the first call registers the one guide, so there is no separate `RegisterGuide`). All 48 emitted Horde chapters (2194 steps) load with no validation errors. Gating so far: `/ribbon guide` answers "no guide installed" and the command is not advertised without a guide; the player's frames and events come with step 3.
3. **Player, browser, counter, pin groups.** Done: `Planner` (character filtering, positions, completion), `Text` (captions from ids and names), `Player` (state per character in `RibbonDB.guide`, polling the quest log, waypoints on the compass, skip/prev/jump/reset), `Browser` (dialog: chapters left, steps right, click to jump, Start chapter, Skip step; `/ribbon guide`). Not yet: the grind counter, spawn pin groups on the map, pausing the RXP bridge while a guide runs, in-game verification.
4. **Emitter follow-ups:** `validate` checks for the Ribbon output, the Alliance guide, retiring the RestedXP output.
5. **Travel mesh** in Ribbon (last, after the player works): export zone-crossing nodes and edges from the network, routing module with specs, `:Travel` and `/ribbon travel`; then verify in game.

## Open questions

- Mulgore and Barrens `uiMapID`s (1412, 1413 in the retail numbering) must be confirmed in the Forever client with `/ribbon debug`.
- Loot objectives with many sources: pin every source, or only the best-drop mobs?
- Which RXP helpers must the replacement keep (use-item, auto-accept)?
- Data size: whether chapters load on demand (`LoadOnDemand`) or all at login.
- Spawn-density polygon or circle for a grind area; circle first.
- Combat log availability and kill-credit rules (verify before building the counter).
