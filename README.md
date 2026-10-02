# MOVING OUT (working title)

A Roblox physics furniture-moving game for 1-4 movers in the style of the original
*Moving Out*, built with Rojo + Luau. All art is original primitive parts, sounds are
built-in Roblox sounds and the music is generated in-game. It is separate from SWARM
(own repo, place and saves).

> Name warning: "Moving Out" is another company's game title. Pick your own name before
> publishing (`Config.GameName` in `src/shared/Config.luau` and the truck logo text in
> `src/server/LevelBuilder.luau`).

## Run it
1. Build: `rojo build default.project.json -o build/MovingOut.rbxlx` (Rojo 7.4), or use
   the committed `build/MovingOut.rbxlx`.
2. Open it in Roblox Studio and press Play. Co-op test: Test > Clients and Servers, 2-4 players.
3. Saves in Studio need Game Settings > Security > Enable Studio Access to API Services.
   Without it the game still plays and says progress isn't saved. Studio uses a separate
   `_Studio` store.
4. Publish with File > Publish to Roblox As > Create new game (never over SWARM). Set Max
   players to 4.
No external service, API key, purchase or backend.

## Controls
| | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Move | WASD / arrows | left stick | thumbstick |
| Grab / drop | E (or L-Shift) | RB (or RT) | GRAB |
| Throw | Q (or R) | X (or B) | THROW |
| Slap | F (or G) | Y (or LB) | SLAP |
| Jump | Space | A | jump button |
| Pause | P / Esc | Menu | II |
| Menus | arrows + Enter, Esc back | d-pad + A, B back | tap |

Grab / Throw / Slap can be remapped in Settings. Grab is a toggle by default (Settings:
hold-to-carry). Heavy furniture: one mover per end; walk together to carry, walk around
each other to turn it, both press Throw within ~0.3 s to toss it.

## A job
Title > PLAY > the Depot yard (practice, LOOK) > host opens the JOB BOARD (job + assists)
> briefing > 3-2-1 > move every required item into the truck (an item counts when it
rests inside the cargo area and nobody holds it) > results (time, award, best time,
unlock) > replay / next job / job board.
Jobs: Starter Home, Poolside Villa, Bulk Warehouse, Creaky Manor.

## Layout
- `src/shared`: Config (all tuning), FurnitureData, Jobs, Levels/, Movers, Net.
- `src/server`: LevelBuilder, FurnitureModels, MoverBuilder, CarrySystem, TruckService,
  ItemService, Breakables, Hazards, PlayerService, JobManager, DataService.
- `src/client`: Menus, Hud, Input, Targeting, CameraController, MoverAnimator, Effects,
  Audio, UI, State.
- `docs/LEVELS.md` level format; `docs/STATUS.md` verification, assumptions, gaps.

## Checks
- `bash tools/check.sh` type check + compile + Rojo build.
- `python3 tools/levels/check.py` level maps, routes, truck fit (needs Lune + Pillow).
- `lune run tools/tests/logic.luau` logic tests (delivery geometry, saves, awards, levels).
