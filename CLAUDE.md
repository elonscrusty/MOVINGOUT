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

## Where things stand
Empty starter: baseplate, spawn, server/client entry scripts. Game idea not written down yet.
