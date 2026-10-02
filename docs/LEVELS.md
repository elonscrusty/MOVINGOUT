# Level data format

Each job is one data module in `src/shared/Levels/<Id>.luau` returning a table. The server
builds it with `src/server/LevelBuilder.luau` (geometry, truck, furniture) and
`src/server/Hazards.luau` (water, conveyors, platforms, traffic, ghosts). The job list
and order live in `src/shared/Jobs.luau`. `Levels/Depot.luau` is the lobby yard.

Check a level with `python3 tools/levels/check.py <Id>` (needs Lune, see below): it draws
`tools/levels/out/<Id>.png` (top-down map) and fails if an item starts inside a wall or
water, if a required item has no route to the truck without breaking anything, or if the
truck is far too small. It approximates the physics; it is not a playtest.

## Conventions

- Studs. X/Z is the ground, Y is up, the ground top is y = 0, room floors top is y = 0.1.
- The camera looks from +Z toward -Z (tilted down ~52 degrees, turned by `Camera.Yaw`).
  So the "front" of a building faces +Z, and **walls on the +Z side of rooms should be
  `Low = true`** (4 studs) so the camera can see in. Other walls are 7.5 studs and fade
  when they hide a mover.
- Scale: a mover is ~4.5 studs tall and ~2-3 wide. Doorways are ~5 wide (sofa 9 x 3.6
  passes only end-first), double doors ~7, the bed (5.6 x 8.6) needs >= 6.6.
- Vectors are plain arrays: `{x, z}` for ground points (y = 0), `{x, y, z}` where noted.

## Fields

| Field | Meaning |
|---|---|
| `Id`, `Name`, `Tagline` | id (= file name), job name, one line for the job board |
| `Briefing` | 2-4 short tips shown before the job |
| `Camera = { Yaw, Pitch }` | degrees; Yaw 15-35, Pitch ~52 |
| `Bounds = { Min = {x,z}, Max = {x,z} }` | items outside are recovered home |
| `SpawnFacing` | degrees, 0 = movers face -Z |
| `Lighting` | optional Lighting properties (`ClockTime`, `Brightness`, `Ambient`, `OutdoorAmbient`, `FogEnd`, `FogColor`, `ExposureCompensation`) |
| `BaseColor`, `BaseMaterial` | the big ground slab under everything (default grass) |
| `Ground` | `{ Kind, Min, Max, Top?, Color?, Material? }` zones; Kind in Grass, Road (dashed line), Pavement, Concrete, Sand, Dirt, DeadGrass, Patio, Metal, Wood, Tile, Carpet. Overlapping zones need a higher `Top` (e.g. 0.05) to avoid flicker |
| `Floors` | room floors `{ Kind, Min, Max, Color?, Material? }`, Kind in Wood, DarkWood, Tile, Carpet, CarpetRed, Concrete, Metal |
| `Walls` | segments `{ A = {x,z}, B = {x,z}, Low?, Height?, Thick?, Color?, CapColor?, Material?, Openings? }` |
| `Openings` | `{ At = distance of the centre from A, Width, Kind, Sill?, Top? }`, Kind: `Door` / `Gap` (open), `Window` (glass above a sill, blocks), `BreakWindow` (floor-length glass with a white cross; breaks on a hard furniture hit or a slap), `SwingDoor` (physical hinged door that swings both ways), `BoardedDoor` (planks; 3 slaps or a very hard hit) |
| `Props` | anchored decoration `{ Kind, Pos, Rot?, ... }` (see below); they collide |
| `Truck` | `{ Pos = {x,0,z}, Rot, Length?, Width?, Height?, RampLength? }` Pos = centre of the rear edge; at Rot 0 the cargo runs toward -Z and the ramp toward +Z; Rot 180 = cargo toward +Z, ramp toward -Z |
| `Items` | furniture `{ Kind, Pos = {x,z}, Rot?, Y?, Required?, Tint?, Home? }` (Required defaults to true; Y = floor height under it, default 0.1 is fine) |
| `Spawns` | 4 points `{x,z}` |
| `Hazards` | see below |
| `Awards` | `{ Gold, Silver, Bronze }` seconds. PROVISIONAL reconstruction targets; retune from playtests |

### Props
Tree, DeadTree, Bush (`Scale`), Hedge / Fence / Counter / Shelf (`Length`, Shelf `Height`),
Stove, Rug (`Size = {w,d}`, `Color`; flat, no collision), Mailbox, StreetLamp, Lantern
(`Color`, `Range`), Pallet, Forklift, Cone, Tombstone, Pumpkin, Parasol (`Color`), Bathtub,
Fireplace, Block (`Size = {x,y,z}`, `Color`, `Material`, `Fadeable`), Sign (`Text`), Cobweb.

### Furniture kinds (`src/shared/FurnitureData.luau`, size X x Y x Z)
Light: Box 2.3, BoxTall 2x3.1x2, Lamp, Stool, SideTable, Plant, BeachBall, Flamingo,
Microwave, Vase, Candelabra, Parcel.
Medium: Chair 2.6x4x2.6, TV 3.6x2.7x1.4, CoffeeTable 5x2x3, Armchair 3.6x3.6x3.4,
DeckChair 2.6x2.2x6, Grill, Cooler, Crate 3.4, Barrel, Mirror, Toolbox, Dresser 4.4x3.6x2.2.
Heavy: Sofa 9x4x3.6, Bed 5.6x2.8x8.6, Fridge 3.2x7x3.2, DiningTable 7.5x3.2x4.2,
Piano 6x5x2.6, Clock 2.4x8x1.8, Coffin 3x2.2x8, Bookcase 4.4x7x1.8, Washer 3x3.6x3,
BigCrate 5x4x4, Sunbed 3x2x8.

### Hazards
- `{ Kind = "Water", Min, Max, Depth?, Color?, FloorColor?, EdgeColor?, Coping? }` a
  basin cut into the ground; movers respawn, items return home after a splash.
- `{ Kind = "Conveyor", Min, Max, Dir = {x,z}, Speed }` belt flush with the floor.
- `{ Kind = "Platform", Path = {{x,y,z},...}, Size = {x,y,z}, Speed, Wait, Color? }`
  ping-pong raft/lift; for a pool raft use y about -0.6 (on the water surface).
- `{ Kind = "Traffic", A = {x,z}, B = {x,z}, Interval = {min,max}, Width }` lane.
- `{ Kind = "Ghost", Patrol = {{x,z},...} }`.

## Lune
`tools/levels/check.py` runs `tools/levels/dump.luau` with Lune 0.10.4
(`/tmp/sh-tools/lune/lune`, override with `LUNE=`). Install:
`curl -fsSL -o /tmp/lune.zip https://github.com/lune-org/lune/releases/download/v0.10.4/lune-0.10.4-linux-x86_64.zip`
then unzip into `/tmp/sh-tools/lune/`. Python needs Pillow.
