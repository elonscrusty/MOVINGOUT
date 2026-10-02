# MOVING OUT

New Roblox game (Rojo + Luau). Separate from SWARM: own repo, own place, own saves.

## Layout
- `src/server` server scripts (ServerScriptService.Server)
- `src/client` client scripts (StarterPlayerScripts.Client)
- `src/shared` shared modules (ReplicatedStorage.Shared)
- `build/MovingOut.rbxlx` built place file to open in Studio

## Build
`rojo build default.project.json -o build/MovingOut.rbxlx`

Publish it to a NEW Roblox experience in Studio (File > Publish to Roblox As > Create new game),
never over the SWARM place.
