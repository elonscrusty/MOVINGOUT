--[[
	Poolside.luau - Job 2: Poolside Villa. Teaches route choice and throwing.
	A bright roofless villa (bedroom, lounge, kitchen) opening onto a long patio, a swimming
	pool right across the middle, and the truck parked on the driveway beyond the pool.
	Routes: everything can walk AROUND either end of the pool (safe, longer); light things
	can be thrown ACROSS the pool (about 19 studs from the patio edge to the ramp); a slow
	pool raft ferries movers (and whatever they carry) across as an optional ride.
	The sofa is the big heavy job: it only leaves the lounge end-first through the double
	door (or through the breakable picture window) and must take the long walk round.
	Award times are PROVISIONAL reconstruction targets: retune after playtests.
]]

local wall = Color3.fromRGB(252, 246, 236)
local cap = Color3.fromRGB(70, 160, 175)
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
	Camera = { Yaw = 28, Pitch = 52 },
	Bounds = { Min = { -50, -60 }, Max = { 50, 54 } },
	SpawnFacing = 0,
	Lighting = {
		ClockTime = 15,
		Brightness = 3,
		Ambient = Color3.fromRGB(120, 110, 100),
		OutdoorAmbient = Color3.fromRGB(170, 150, 125),
		ExposureCompensation = 0.15,
	},
	BaseColor = Color3.fromRGB(236, 214, 160),
	BaseMaterial = Enum.Material.Sand,
	Ground = {
		{ Kind = "Patio", Min = { -40, -26 }, Max = { 34, -13 }, Color = Color3.fromRGB(214, 180, 140) }, -- deck
		{ Kind = "Tile", Min = { -20, -17 }, Max = { 24, 3 }, Top = 0.05, Color = Color3.fromRGB(240, 236, 226) }, -- pool surround
		{ Kind = "Pavement", Min = { -6, 3 }, Max = { 10, 46 } }, -- driveway
		{ Kind = "Pavement", Min = { -1, -60 }, Max = { 5, -50 } }, -- back garden path (decor)
	},
	Floors = {
		{ Kind = "Carpet", Min = { -36, -50 }, Max = { -16, -26 }, Color = Color3.fromRGB(150, 200, 210) }, -- bedroom
		{ Kind = "Wood", Min = { -16, -50 }, Max = { 12, -26 }, Color = Color3.fromRGB(205, 160, 115) }, -- lounge
		{ Kind = "Tile", Min = { 12, -50 }, Max = { 30, -26 }, Material = Enum.Material.CeramicTiles, Color = Color3.fromRGB(235, 240, 238) }, -- kitchen
	},
	Walls = {
		-- outer walls
		{ A = { -36, -50 }, B = { 30, -50 }, Color = wall, CapColor = cap, Openings = {
			{ At = 10, Width = 6, Kind = "Window" },
			{ At = 34, Width = 8, Kind = "Window" },
			{ At = 57, Width = 6, Kind = "Window" },
		} },
		{ A = { -36, -50 }, B = { -36, -26 }, Color = wall, CapColor = cap, Openings = {
			{ At = 12, Width = 6, Kind = "Window" },
		} },
		{ A = { 30, -50 }, B = { 30, -26 }, Color = wall, CapColor = cap, Openings = {
			{ At = 10, Width = 5, Kind = "Window" },
		} },
		-- front (low, faces the camera and the pool)
		{ A = { -36, -26 }, B = { 30, -26 }, Low = true, Color = wall, CapColor = cap, Openings = {
			{ At = 10, Width = 7.4, Kind = "Door" }, -- bedroom double door (bed goes out lengthwise)
			{ At = 30, Width = 8, Kind = "Door" }, -- lounge double door (sofa end-first)
			{ At = 41, Width = 8, Kind = "BreakWindow" }, -- lounge picture window: sofa shortcut
			{ At = 57, Width = 5, Kind = "Door" }, -- kitchen door
		} },
		-- interior walls
		{ A = { -16, -50 }, B = { -16, -26 }, Color = wall, CapColor = cap, Openings = {
			{ At = 12, Width = 5, Kind = "Door" }, -- bedroom <-> lounge
		} },
		{ A = { 12, -50 }, B = { 12, -26 }, Color = wall, CapColor = cap, Openings = {
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
		{ Kind = "Parasol", Pos = { -19, -15.5 }, Color = Color3.fromRGB(250, 120, 90) },
		{ Kind = "Parasol", Pos = { 18, -15 }, Color = Color3.fromRGB(80, 190, 200) },
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
	},
	-- on the driveway past the pool, rear facing the villa; the ramp comes down toward the pool
	Truck = { Pos = { 2, 0, 12 }, Rot = 180, Length = 21, Width = 12, Height = 6 },
	Items = {
		-- bedroom
		{ Kind = "Bed", Pos = { -26, -42 } },
		{ Kind = "Dresser", Pos = { -33.5, -31 }, Rot = 90 },
		{ Kind = "Lamp", Pos = { -19, -47 } },
		-- lounge
		{ Kind = "Sofa", Pos = { -2, -46 } },
		{ Kind = "TV", Pos = { 4, -33 }, Rot = 180 },
		{ Kind = "Armchair", Pos = { 8, -41 }, Rot = -90 },
		-- kitchen
		{ Kind = "Fridge", Pos = { 27.6, -36 }, Rot = -90 },
		{ Kind = "Microwave", Pos = { 16, -31 } },
		-- patio and pool edge
		{ Kind = "Sunbed", Pos = { -13, -15.5 }, Rot = 90, Tint = Color3.fromRGB(250, 250, 245) },
		{ Kind = "Sunbed", Pos = { 12, -15.5 }, Rot = 90, Tint = Color3.fromRGB(250, 250, 245) },
		{ Kind = "BeachBall", Pos = { 2, -15 } },
		{ Kind = "Flamingo", Pos = { 5, -15.2 } },
		{ Kind = "Grill", Pos = { 27, -18 } },
		{ Kind = "Cooler", Pos = { -20, -5 }, Rot = 90 },
	},
	Spawns = { { -2, -22 }, { 2, -22 }, { -2, -19 }, { 2, -19 } },
	Hazards = {
		{ Kind = "Water", Min = { -16, -13 }, Max = { 20, -1 }, Depth = 4 },
		-- slow ferry raft across the middle of the pool (optional ride)
		{ Kind = "Platform", Path = { { 2, -0.6, -9 }, { 2, -0.6, -5 } }, Size = { 8, 1, 8 }, Speed = 2.5, Wait = 2 },
	},
	-- PROVISIONAL reconstruction targets: retune from playtests
	Awards = { Gold = 200, Silver = 300, Bronze = 400 },
}
