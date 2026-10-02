# MOVING OUT: notes for Claude

New Roblox game (Rojo + Luau). Not related to SWARM: never copy saves, DataStore names,
place IDs or code across without the owner asking.
The owner (kcdrewcarter, Roblox user 20194281) plays on a phone, isn't a programmer, and has no
Studio access during sessions, so nothing is verified in Studio unless they say so.

## How to work here
- Chat replies in caveman style; code, commits and docs in normal prose.
- Save straight to `main` and push. No PRs unless asked.
- Never put model names in code or commits.
- Rebuild and commit `build/MovingOut.rbxlx` at the end of a batch:
  `rojo build default.project.json -o build/MovingOut.rbxlx`.

## Rules that must hold
- Never pay-to-win. Don't publish, deploy, buy assets, create products or set prices.
- Don't enable Studio API access, HTTP or other security settings; give the owner steps.
- No secrets in client code or ReplicatedStorage. Player text always goes through Roblox filtering.
- Never present a mock or unconnected feature as working. Report verified vs assumed.

## Commands
- `bash tools/check.sh` type check + compile + Rojo build (`--quick` skips the build).
- `python3 tools/levels/check.py [Id]` level maps + route / truck-fit checks (docs/LEVELS.md).
- `/tmp/sh-tools/lune/lune run tools/tests/logic.luau` logic tests.
- `bash tools/preview/render.sh level --set level=Suburb --set hud=on --devices pc,phone` screenshots (docs/PREVIEW.md).
- Tools live in /tmp/sh-tools (rojo, luau-lsp, lune): reinstall per session (see docs/LEVELS.md, tools/preview/setup.sh).

## Where things stand
v0.1.0 first playable: 4 jobs + depot lobby, all systems in. Visual pass 2 matched the real game's Steam screenshots (steep camera, two-tone walls, patterned floors, open van with arrow drop zone, blocky-head movers, box-count + stopwatch HUD, 20-23 items per job). Type check, logic tests,
level checks and preview renders pass. NOT tested in Studio: physics handling needs a
playtest and tuning. See docs/STATUS.md for verification, assumptions and gaps.
