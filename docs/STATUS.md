# Status: first playable release (v0.1.0)

## Platform decision
The repo is a Rojo + Luau Roblox project and the owner plays Roblox, so the game is built
on Roblox instead of a browser. Consequences:
- Co-op is **online, 1-4 Roblox players per server**, each on their own device
  (keyboard, gamepad or touch). Roblox has no couch co-op with several local players,
  so "two players on one keyboard" is not possible.
- Physics, rendering, input, audio and UI use Roblox's own systems (no custom engine).
- Pausing freezes the whole server, because all movers share one job.

## Verification

| Check | How | Result |
|---|---|---|
| Type check, zero diagnostics | `bash tools/check.sh` (luau-lsp) | PASS |
| Every script compiles, Rojo place builds | same | PASS |
| Logic: delivery geometry, hysteresis, saves (malformed data, merge, best-time rule), awards, level item counts | `lune run tools/tests/logic.luau` | PASS, 229 checks |
| Every required item has a walking route to the truck without breaking anything; nothing starts inside walls or water; truck fill 84-89% | `python3 tools/levels/check.py` | PASS, all 5 levels |
| Real server and client boot with no errors; all menus, HUD and all levels render | `tools/preview` renders on a mock Roblox API | PASS, 0 errors (approximation, not Roblox) |
| Carrying, cooperative handling, throwing, doors, ropes, conveyors, cars, ghosts and truck packing under real physics | needs Roblox Studio | **NOT TESTED** |
| Frame rate | needs a device | **NOT MEASURED** |
| DataStore saving | needs Studio API access or a published place | **NOT TESTED** (the code falls back to memory) |

Nothing has been played in Studio yet. Physics handling is the top risk; all tuning
values are in `src/shared/Config.luau`.

## Reconstruction assumptions (not from the original game)
- Every number is a starting default: walk speed 16 studs/s, mover ~4.5 studs tall,
  reach 4.2 studs, throw speeds, 0.3 s co-op throw window, gravity 140, camera pitch
  52 degrees / FOV 34, delivery rule (7 of 8 box corners inside for 0.5 s, out below 5 of
  8), and the award times.
- Award times are provisional: about 15 s per required item for gold, then x1.5 and x2.
  Retune them from real clear times.
- Heavy items: one mover in a group can only drag them, two can lift. Solo play gets
  extra lift so every job can be finished alone.
- Light items fly far; heavy items can only be thrown together.
- A job never ends when an award time passes.
- Grab is a toggle by default.

## Known gaps
- No Studio playtest yet, so handling, packing difficulty and hazard fairness are untuned.
- No licensed music: the music is a short generated loop made from one tone, and the
  sound effects are built-in Roblox sounds.
- Animation is procedural (arm poses on top of Roblox's walk cycle); there are no
  authored animations.
- Only 4 jobs; the original has a much larger campaign.
- Traffic does not appear in jobs 2-4. Only the Suburb has cars; the Warehouse uses
  conveyors and the Manor uses ghosts.
- A held item's physics runs on its first holder's device. That is smooth for them but can
  lag slightly for a second holder, and a cheater could move their own held item.
  Records are local best times only, with no public leaderboard.
- The title "MOVING OUT" belongs to another game; rename before publishing.

## Owner steps
1. Open `build/MovingOut.rbxlx` in Studio and press Play. Try Clients and Servers with 2 players.
2. Optional, to test saves: Game Settings > Security > Enable Studio Access to API Services.
3. Report anything that feels wrong (too heavy, sticky doors, throws too short), and
   it can be tuned in Config.
