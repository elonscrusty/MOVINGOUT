# Offline preview renderer (no Studio needed)

`tools/preview/` runs the **real game** headlessly on a mock Roblox API and draws what it
builds: the 3D world with three.js and the GUI laid out the way Roblox would, in headless
Chromium. The server (`src/server/init.server.luau`) and the client
(`src/client/init.client.luau`) both run in one mock DataModel, like Play Solo in Studio,
and scenes drive them like players do (the PLAY button, the `Action` remote, menu
buttons). Use it for screenshots, level reviews and layout checks on PC and phone. It is
an approximation of Roblox: close, but not a substitute for a Studio playtest.

## Quick start

```
bash tools/preview/setup.sh                                   # once per machine (idempotent)
bash tools/preview/render.sh level                            # -> tools/preview/out/level-pc.png
bash tools/preview/render.sh level --device phone --set level=Depot --set movers=4
bash tools/preview/render.sh level --set level=Poolside --set hud=on --out /tmp/pool.png
bash tools/preview/render.sh overview --set level=Haunted --devices pc,phone --outdir /tmp/ov
bash tools/preview/render.sh title,board,briefing,pause,results,settings --devices pc,phone --outdir /tmp/menus
bash tools/preview/render.sh --all                            # every scene on pc + phone -> out/all
bash tools/preview/render.sh level --ref HEAD                 # a committed version (clean snapshot)
```

Options: `--device` / `--devices pc,phone` (also `laptop`, `phone-portrait`, `tablet`),
`--out file.png`, `--outdir DIR` (PNG + scene JSON + metrics per scene and device),
`--seed N` (default 1), `--set key=value` (scene arguments), `--set balls=uniform` (see
Shapes below), `--studio` (RunService:IsStudio() = true), `--no-coreui` (hide the ghost of
Roblox's top-bar buttons and touch jump button), `--max-time S` (simulated-seconds limit,
default 120), `--repo PATH` / `--ref GIT_REF` (render another checkout or a commit).
`PREVIEW_JOBS=N` sets how many scenes run in parallel (default 4).

Setup installs Lune 0.10.4 into `$MO_TOOLS/lune` (default `/tmp/sh-tools`), three.js
(npm, into `tools/preview/node_modules`) and Google Fonts with measured advance widths
into `tools/preview/.cache/fonts`. Chromium comes from the global Playwright install
(`/opt/pw-browsers`); never run `playwright install`. `node_modules`, `.cache` and `out`
are git-ignored.

## Scenes (`tools/preview/scenes/*.luau`)

| Scene | Shows |
|---|---|
| `level` | a level in play from the game camera. `--set level=<Id>` (Suburb default; Depot = the lobby yard; Poolside, Warehouse, Haunted, any module in `src/shared/Levels`), `--set movers=N` (1-4, default 2; each mover gets the next style so hats differ), `--set hud=on` (the client's ScreenGuis; default off = world, mover tags and floor rings only), `--set phase=Briefing` (movers frozen at the spawns before the countdown; default Playing), `--set focus=x,z` / `--set dist=N` (camera focus / distance; default the real CameraController framing the movers), `--set t=S` (seconds after the start, default 1.5) |
| `overview` | the whole level from high above, fitted to everything the level built (not the ground slabs). `--set level=<Id>`, `--set pitch=N` (default 68), `--set yaw=N` (default the level's), `--set fov=N` (34), `--set ortho=on` (straight-down plan view), `--set movers=N` (0 = none), `--set fit=bounds` (fit the level's Bounds), `--set hud=on` |
| `title` | the title screen before PLAY over the orbiting depot (`--set t=S` orbit time) |
| `look` | the LOOK (mover style) screen, opened with the lobby button |
| `board` | the JOB BOARD in the lobby (host's view); `--set unlocked=all` unlocks every job in the profile first |
| `briefing` | the briefing after the host picked a job (`--set level=<Id>`, default Suburb) |
| `pause` | the pause menu during a job (the `Pause` action) |
| `results` | the results screen through the real server path (`JobManager.OnAllDelivered`: time, award, best time, unlock, the `Results` Fx); `--set seconds=N` plays N simulated seconds first (default 2) |
| `settings` | the SETTINGS screen from the lobby button (`--set from=title`: from the title screen) |
| `controls` | the CONTROLS screen from the title screen |

Locked jobs are unlocked in the server profile (`DataService.Get(player).Unlocked`) before
`SelectJob`, so any level can be shown. Levels missing from `src/shared/Levels` fail with
the list of levels that exist.

### Writing a scene

Add `scenes/<name>.luau` returning `function(preview) ... end`. It gets the game globals
plus `preview` and `lib(name)` (`scenes/lib/*.luau`):

* `lib("game")`: `G.boot{ level, movers, phase, join, styles, assists }` (starts the
  server and client, presses PLAY, adds movers through the `Action` remote, selects the
  job and starts it), `G.action(player, name, ...)` (an `Action` remote call as any
  player), `G.server(name)` (the server module tables the game uses), `G.levelData(id)`,
  `G.frame(positions)` / `G.cameraCFrame(focus, dist, yaw, pitch)` / `G.yawPitch(level)`
  (CameraController's maths), `G.moverRoots()`, `G.hud(on)`.
* `lib("menu")`: `M.start{...}`, `M.press("BUTTON TEXT")` (taps a visible button),
  `M.open(name)` (`Menus.Open`), `M.current()`.
* `preview`: `advance(seconds, fps?)`, `startServer()`, `startClient()`, `addPlayer(name,
  userId)`, `fireServerAs(player, remote, ...)`, `fireClient(remote, ...)`,
  `click(button)`, `findGui(text)`, `isShown(obj)`, `shared(name)`, `server(name)`,
  `client(name)`, `require(moduleScript)`, `camera = { cf, fov, ortho = { height } }`,
  `render.hideScreenGui`, `render.background`, `overlay{...}`, `metrics`, `log(...)`,
  `warn(msg)`, `note(msg)`.

Every step is protected: a failing game module is printed with its stack, the scene still
renders whatever exists, and the run summary counts errors and warnings.

## How it works

1. `runtime/main.luau` (Lune) builds the DataModel from `default.project.json` (Rojo
   rules: `init.server.luau` -> Script, `init.client.luau` -> LocalScript, `.luau` ->
   ModuleScript, project `$properties`), runs the scene in a simulated scheduler (time
   only moves when the scene advances it; each frame: RenderStepped / BindToRenderStep ->
   waits -> ground snap + Align constraints -> Stepped / PreSimulation / Heartbeat ->
   tweens -> deferred -> GUI layout at most 20 times a second) and writes scene JSON.
   * `mock/instance.luau`: Instance as userdata with properties and defaults from Lune's
     reflection database, type-checked writes, signals (Changed, property and attribute
     signals, ChildAdded, DescendantAdded, AncestryChanged, Destroying ...), attributes,
     tags, Clone, Destroy, WaitForChild (errors after 10 simulated seconds). Unknown
     members fail loudly like Roblox. Every class in the reflection database can be
     created (constraints, Highlight, SurfaceGui, PointLight, HumanoidDescription ...).
   * `mock/classes/*`: services (Players with one LocalPlayer plus scene-added players,
     RunService, TweenService, UserInputService per device, GuiService, DataStoreService
     in memory, MarketplaceService stubs ...), parts, models, joints (Motor6D / Weld /
     WeldConstraint move Part1 when Part0 moves; Motor6D.Transform too), camera, lighting,
     remotes (client and server share the DataModel; `FireServer` reaches
     `OnServerEvent` as the local player, `FireClient` reaches the local client).
   * `mock/classes/character.luau`: `Player:LoadCharacter*` /
     `LoadCharacterWithHumanoidDescription(Async)` build a block R15 rig (Roblox part
     and Motor6D / rig attachment names, blocky R15 proportions) scaled by the
     description's HeightScale / WidthScale / DepthScale / HeadScale, with HipHeight set;
     it is parented to Workspace and `CharacterAdded` fires. No avatar meshes.
   * `mock/classes/physics.luau`: `Workspace:Raycast` against parts (oriented boxes,
     Ball parts as ellipsoids, CanQuery and RaycastParams filters, RespectCanCollide),
     `GetPartBoundsInBox / InRadius / GetPartsInPart` (world bounding boxes), a ground
     snap that stands every unanchored character on whatever collidable part is below it
     (a stand-in for gravity), and AlignPosition / AlignOrientation that snap their part
     to the goal each frame.
   * A stub `PlayerModule` sits in PlayerScripts (`GetControls():Enable/Disable` tracked
     for the touch jump-button ghost).
   * `mock/layout.luau` + `mock/text.luau`: Roblox GUI layout and text (below).
   * Lune datatypes for the maths; added TweenInfo, Random (deterministic),
     RaycastParams, OverlapParams, DateTime; Lune 0.10.4's backwards `CFrame.lookAt` and
     `ColorSequence.new(a, b)` are fixed.
2. `renderer/render.mjs` (Node + Playwright) opens `renderer/page/` in headless Chromium
   (SwiftShader WebGL) and screenshots it. `world.js` draws parts, lights, sun / moon,
   shadows and fog, `surface.js` paints SurfaceGuis into textures on their part faces,
   `gui.js` draws ScreenGuis and BillboardGuis as DOM.

### GUI rules implemented

ScreenGui area per device (ScreenInsets: CoreUISafeInsets / DeviceSafeInsets apply the
device safe area, None does not; without IgnoreGuiInset the area starts below the 58 px
top bar); UDim2 Position / Size, AnchorPoint, SizeConstraint; UIScale; AutomaticSize;
UIListLayout (fill direction, padding, alignment, sort order, wraps, flex basics);
UIGridLayout; UIPageLayout (first page); UIPadding; UIAspectRatioConstraint;
UISizeConstraint; UITextSizeConstraint; UICorner; UIStroke (border rings, text outlines);
UIGradient; ScrollingFrame canvas; CanvasGroup; ViewportFrame; Rotation; Visible;
ClipsDescendants; ZIndex (Sibling / Global); DisplayOrder; BillboardGuis projected from
their Adornee (drawn over the 3D view, never occluded); SurfaceGuis (SizingMode FixedSize
with CanvasSize, or PixelsPerStud) painted on their face. Text: TextScaled, TextWrapped,
alignment, LineHeight, transparency, strokes, truncation, MaxVisibleGraphemes, RichText.

Fonts: FredokaOne (the game's font), Merriweather and Source Sans 3 are the same fonts
Roblox uses. Substitutes: Gotham -> Montserrat, BuilderSans -> Inter, Arial / Legacy ->
Arimo, Code -> Inconsolata, anything else -> Source Sans 3 (listed in the scene notes).

### Devices

| Profile | Size (GUI px) | Pixel ratio | Input | Safe insets (L / R / T / B) |
|---|---|---|---|---|
| `pc` | 1920 x 1080 | 1 | mouse + keyboard | 0 |
| `laptop` | 1366 x 768 | 1 | mouse + keyboard | 0 |
| `phone` | 844 x 390 landscape | 2 | touch | 47 / 47 / 0 / 21 |
| `phone-portrait` | 390 x 844 | 2 | touch | 0 / 0 / 47 / 34 |
| `tablet` | 1024 x 768 | 1.5 | touch | 0 / 0 / 0 / 20 |

Ghosts of Roblox's own UI are drawn so layouts can be checked against them: the menu and
chat buttons at the top left (inside the safe area) on every device, and on touch devices
the jump button at the bottom right while the character can jump and the controls are
enabled. `--no-coreui` (or `hud` off in `level` / `overview`) hides them.

## What is approximated / known gaps

* **Physics**: none beyond the ground snap and Align constraints. Nothing falls, slides,
  collides or swings: hinged doors stay shut, ropes and springs do nothing, thrown items
  stay put, movers stand at their spawns. Platforms and cars move only when game code
  moves them (they do, through `Hazards.Step`).
* **Lighting**: sun direction from ClockTime and GeographicLatitude; below the horizon a
  dim, cool moon opposite the sun lights the scene (an approximation of Roblox's night);
  hemisphere ambient from OutdoorAmbient / Ambient; PCF soft shadows from the sun / moon
  only; point / spot lights without shadows (the 32 nearest the view); legacy Lighting
  fog (FogStart / FogEnd / FogColor) or Atmosphere fog; ExposureCompensation; neutral
  tone mapping. `Lighting.Technology` is not modelled. Sky textures, clouds and sun rays
  are not drawn.
* **Materials**: flat colours, no textures (WoodPlanks, Concrete, Grass ... are plain
  colours). SmoothPlastic / Plastic semi-matte, Metal / DiamondPlate metallic, Neon
  glows, Glass transparent. Decals and Textures are not drawn.
* **Shapes**: Block, Wedge, CornerWedge, Cylinder (along the part's X axis, diameter =
  the smaller of Y / Z, like Roblox), Ball, SpecialMesh shapes; MeshParts are boxes.
  **Ball parts are drawn as ellipsoids stretched to their Size** (the default, matching
  how the game's code sizes them). Roblox itself keeps Ball parts uniform (a sphere of
  the smallest axis); `--set balls=uniform` draws them that way so the difference can be
  checked. Confirm in Studio which one the game gets.
* **SurfaceGuis**: painted with canvas 2D (backgrounds, corners, strokes, text, image
  placeholders; gradients use their first colour). Canvas axes per face: Front / Back /
  Left / Right read upright from outside the face; Top / Bottom put the canvas top toward
  the part's -Z / +Z (Roblox's exact Top / Bottom orientation is unverified).
* **Effects**: ParticleEmitters as a few glow sprites, Fire as glow sprites, Highlight
  as a fill plus an inverted-hull outline, Beams as flat strips; Trails, Smoke and
  Sparkles are not drawn. Sounds are silent.
* **GUI**: images are striped placeholders tinted with ImageColor3; BillboardGuis are
  never occluded; text metrics differ from Roblox by a pixel or two.
* **Players**: one LocalPlayer runs the client; scene-added players (other movers) are
  real server-side Players with characters but run no client.

## Notes for this game

* Jobs are unlocked in the server profile before `SelectJob`; the profile is the real
  `DataService` one (in-memory DataStore), so nothing is saved anywhere.
* `CameraController` frames the movers with its smoothing; scenes advance long enough for
  it to settle. `--set focus` / `--set dist` recompute the same CFrame from
  `Config.Camera` and the level's `Camera.Yaw / Pitch`.
* The mover look is the real `MoverBuilder.Dress` on the mock R15 rig, so the costume
  welds land where they would on a 0.78-height R15 character.
