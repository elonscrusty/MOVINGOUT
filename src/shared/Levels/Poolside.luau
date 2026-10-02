--[[
	Poolside.luau - Job 2: Poolside Villa. Teaches route choice and throwing.
	A bright roofless villa (bedroom, lounge, kitchen) opening onto a long patio, a swimming
	pool right across the middle, and the truck parked on the driveway just beyond the pool.
	Routes: everything can walk AROUND either end of the pool (safe, longer); light things
	can be thrown ACROSS the pool (about 16 studs from the patio edge to the ramp); a slow
	pool raft ferries movers (and whatever they carry) across as an optional ride.
	The sofa is the big heavy job: it only leaves the lounge end-first through the double
	door (or through the breakable picture window) and must take the long walk round.
	Award times are PROVISIONAL reconstruction targets: retune after playtests.
]]

local coral = Color3.fromRGB(244, 160, 150)
local teal = Color3.fromRGB(86, 182, 184)
local butter = Color3.fromRGB(248, 226, 150)
local palm = Color3.fromRGB(70, 175, 90)

return {
	Id = "Poolside",
	Name = "Poolside Villa",
	Tagline = "Sun, sand and a pool in the way. Walk round it or throw across it.",
	Briefing = {
		"The pool sits between the villa and the truck: walk round either end, or ride the raft.",
		"Light things (beach ball, flamingo, lamp) can be thrown across the pool to the truck.",
		"Anything that lands in the water floats back home - heavy stuff goes the long way.",
		"The sofa only fits the lounge door end-first. Or smash the big picture window.",
	},
	Camera = { Yaw = 28, Pitch = 62, View = { Min = { -38, -52 }, Max = { 32, 0 } } },
	Bounds = { Min = { -50, -60 }, Max = { 50, 54 } },
	SpawnFacing = 0,
	Lighting = { ClockTime = 14.5, Brightness = 2.4 },
	Grade = { Saturation = 0.06 },
	WallStyle = {
		Outer = Color3.fromRGB(96, 104, 156), -- slate-blue brick outside
		OuterMaterial = Enum.Material.Brick,
		Cap = Color3.fromRGB(62, 64, 80),
		Frame = Color3.fromRGB(214, 170, 120),
	},
	Ground = {
		{ Kind = "Patio", Min = { -40, -26 }, Max = { 34, -21 }, Color = Color3.fromRGB(176, 110, 72), Pattern = "Planks", Color2 = Color3.fromRGB(214, 142, 92), Dir = "X" }, -- deck
		{ Kind = "Patio", Min = { -40, -21 }, Max = { -16, -13 }, Color = Color3.fromRGB(176, 110, 72), Pattern = "Planks", Color2 = Color3.fromRGB(214, 142, 92), Dir = "X" }, -- deck, west wing
		{ Kind = "Patio", Min = { 20, -21 }, Max = { 34, -13 }, Color = Color3.fromRGB(176, 110, 72), Pattern = "Planks", Color2 = Color3.fromRGB(214, 142, 92), Dir = "X" }, -- deck, east wing
		{ Kind = "Tile", Min = { -16, -21 }, Max = { 20, 0 }, Top = 0.05, Color = Color3.fromRGB(240, 238, 232), Pattern = "SmallTile", Tile = 2, Color2 = Color3.fromRGB(206, 210, 214) }, -- pool surround
		{ Kind = "Pavement", Min = { -6, 0 }, Max = { 10, 46 } }, -- driveway
		{ Kind = "Pavement", Min = { -1, -60 }, Max = { 5, -50 } }, -- back garden path (decor)
	},
	Floors = {
		{ Kind = "Carpet", Min = { -36, -50 }, Max = { -16, -26 }, Color = Color3.fromRGB(236, 104, 100), Pattern = "Checker", Color2 = Color3.fromRGB(220, 84, 86), Tile = 3.6, Wall = coral }, -- bedroom
		{ Kind = "Wood", Min = { -16, -50 }, Max = { 12, -26 }, Color = Color3.fromRGB(168, 108, 72), Pattern = "Planks", Color2 = Color3.fromRGB(212, 150, 100), Wall = teal }, -- lounge
		{ Kind = "Tile", Min = { 12, -50 }, Max = { 30, -26 }, Color = Color3.fromRGB(120, 196, 196), Pattern = "SmallTile", Tile = 1.8, Wall = butter }, -- kitchen
	},
	Walls = {
		-- outer walls
		{ A = { -36, -50 }, B = { 30, -50 }, Openings = {
			{ At = 10, Width = 6, Kind = "Window" },
			{ At = 34, Width = 8, Kind = "Window" },
			{ At = 57, Width = 6, Kind = "Window" },
		} },
		{ A = { -36, -50 }, B = { -36, -26 }, Openings = {
			{ At = 12, Width = 6, Kind = "Window" },
		} },
		{ A = { 30, -50 }, B = { 30, -26 }, Openings = {
			{ At = 10, Width = 5, Kind = "Window" },
		} },
		-- front (low, faces the camera and the pool)
		{ A = { -36, -26 }, B = { 30, -26 }, Low = true, Openings = {
			{ At = 10, Width = 7.4, Kind = "Door" }, -- bedroom double door (bed goes out lengthwise)
			{ At = 30, Width = 8, Kind = "Door" }, -- lounge double door (sofa end-first)
			{ At = 41, Width = 8, Kind = "BreakWindow" }, -- lounge picture window: sofa shortcut
			{ At = 57, Width = 5, Kind = "Door" }, -- kitchen door
		} },
		-- interior walls
		{ A = { -16, -50 }, B = { -16, -26 }, Openings = {
			{ At = 12, Width = 5, Kind = "Door" }, -- bedroom <-> lounge
		} },
		{ A = { 12, -50 }, B = { 12, -26 }, Openings = {
			{ At = 12, Width = 5, Kind = "SwingDoor" }, -- lounge <-> kitchen
		} },
	},
	Props = {
		-- bedroom
		{ Kind = "Rug", Pos = { -26, -36 }, Size = { 10, 7 }, Color = Color3.fromRGB(240, 200, 120) },
		-- lounge
		{ Kind = "Rug", Pos = { -2, -40 }, Size = { 12, 8 }, Color = Color3.fromRGB(80, 170, 190) },
		{ Kind = "Shelf", Pos = { -11, -48.3 }, Length = 6, Height = 4 },
		-- kitchen
		{ Kind = "Counter", Pos = { 19, -48.3 }, Length = 10 },
		{ Kind = "Stove", Pos = { 26.5, -48.3 } },
		-- patio
		{ Kind = "Parasol", Pos = { -22, -16 }, Color = Color3.fromRGB(250, 120, 90) },
		{ Kind = "Parasol", Pos = { 25.5, -14 }, Color = Color3.fromRGB(80, 190, 200) },
		{ Kind = "Parasol", Pos = { -30, -18 }, Color = Color3.fromRGB(250, 210, 80) },
		{ Kind = "Lantern", Pos = { -36.5, -25 }, Color = Color3.fromRGB(255, 200, 140) },
		{ Kind = "Lantern", Pos = { 30.5, -25 }, Color = Color3.fromRGB(255, 200, 140) },
		{ Kind = "Bush", Pos = { -38, -14 }, Scale = 0.9 },
		{ Kind = "Bush", Pos = { 32, -12 }, Scale = 0.9 },
		-- palms round the pool and along the beach
		{ Kind = "Tree", Pos = { -27, 4 }, Scale = 1.3, Color = palm },
		{ Kind = "Tree", Pos = { 29, 4 }, Scale = 1.3, Color = palm },
		{ Kind = "Tree", Pos = { -42, -40 }, Scale = 1.4, Color = palm },
		{ Kind = "Tree", Pos = { 40, -38 }, Scale = 1.2, Color = palm },
		{ Kind = "Tree", Pos = { -36, 22 }, Scale = 1.3, Color = palm },
		{ Kind = "Tree", Pos = { 34, 26 }, Scale = 1.4, Color = palm },
		{ Kind = "Tree", Pos = { -20, 40 }, Scale = 1.1, Color = palm },
		{ Kind = "Bush", Pos = { 16, 12 } },
		{ Kind = "Bush", Pos = { -14, 14 } },
		{ Kind = "Sign", Pos = { 16, 7 }, Text = "VILLA" },
		{ Kind = "Stones", Pos = { -30, -12 }, To = { -30, 14 } },
		{ Kind = "Stones", Pos = { 32, -10 }, To = { 30, 16 } },
		{ Kind = "FlowerBed", Pos = { -26, -51.4 }, Size = { 12, 1.6 } },
		{ Kind = "FlowerBed", Pos = { 20, -51.4 }, Size = { 12, 1.6 } },
		{ Kind = "Hedge", Pos = { -30, 30 }, Rot = 90, Length = 24 },
		{ Kind = "Hedge", Pos = { 34, 34 }, Rot = 90, Length = 20 },
	},
	-- on the driveway past the pool, rear facing the villa; the ramp comes down toward the pool
	Truck = { Pos = { 2, 0, 3 }, Rot = 180, Length = 22, Width = 12, Height = 6 },
	Items = {
		-- bedroom
		{ Kind = "Bed", Pos = { -26, -42 } },
		{ Kind = "Dresser", Pos = { -33.5, -31 }, Rot = 90 },
		{ Kind = "Lamp", Pos = { -19, -47 } },
		{ Kind = "Suitcase", Pos = { -21, -30 } },
		{ Kind = "Guitar", Pos = { -34, -44 } },
		{ Kind = "BoxSmall", Pos = { -32, -48 } },
		-- lounge
		{ Kind = "Sofa", Pos = { -2, -46 } },
		{ Kind = "TV", Pos = { 4, -33 }, Rot = 180 },
		{ Kind = "Armchair", Pos = { 8, -41 }, Rot = -90 },
		{ Kind = "Box", Pos = { -12, -30 } },
		{ Kind = "BoxFlat", Pos = { -6, -36 } },
		{ Kind = "PlantSmall", Pos = { 9, -48 } },
		-- kitchen
		{ Kind = "Fridge", Pos = { 27.6, -36 }, Rot = -90 },
		{ Kind = "Microwave", Pos = { 16, -31 } },
		{ Kind = "Toaster", Pos = { 20, -44 } },
		{ Kind = "Box", Pos = { 24, -30 } },
		{ Kind = "Bin", Pos = { 28, -29 } },
		-- patio and pool edge
		{ Kind = "Sunbed", Pos = { -18, -11 }, Tint = Color3.fromRGB(250, 250, 245) },
		{ Kind = "Sunbed", Pos = { 21.5, -9 }, Tint = Color3.fromRGB(250, 250, 245) },
		{ Kind = "BeachBall", Pos = { -13, -22.5 } },
		{ Kind = "Flamingo", Pos = { 14, -22.5 } },
		{ Kind = "Grill", Pos = { 27, -18 } },
		{ Kind = "Cooler", Pos = { -20, -5 }, Rot = 90 },
	},
	Spawns = { { -2, -23.5 }, { 2, -23.5 }, { -2, -21 }, { 2, -21 } },
	Hazards = {
		{ Kind = "Water", Min = { -10, -19 }, Max = { 14, -9 }, Depth = 4 },
		-- slow ferry raft across the middle of the pool (optional ride)
		{ Kind = "Platform", Path = { { 2, -0.6, -16 }, { 2, -0.6, -12 } }, Size = { 6, 1, 6 }, Speed = 2.5, Wait = 2 },
	},
	-- PROVISIONAL reconstruction targets: retune from playtests
	Awards = { Gold = 200, Silver = 300, Bronze = 400 },
}
