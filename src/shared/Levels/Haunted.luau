--[[
	Haunted.luau - Job 4: Creaky Manor. Combines every skill so far with hazards that interrupt.
	A roofless dusk manor: parlour and dining room on the west, a grand hall and a back
	gallery down the middle, a library and a cellar crypt on the east. A dead-grass garden
	with a graveyard and a pumpkin patch leads down a lantern path to the truck.
	Challenges: long routes through the hall, a coffin and a piano to turn through doors,
	two ghosts patrolling the hall/gallery and the west wing (slap them to stun),
	breakable shortcuts (parlour and dining glass, the boarded library and crypt doors).
	Every required item has a walking route without breaking anything.
	Award times are PROVISIONAL reconstruction targets: retune after playtests.
]]

local wall = Color3.fromRGB(122, 112, 138)
local cap = Color3.fromRGB(62, 50, 74)
local lanternWarm = Color3.fromRGB(255, 176, 80)
local lanternGreen = Color3.fromRGB(150, 255, 170)

return {
	Id = "Haunted",
	Name = "Creaky Manor",
	Tagline = "A spooky old manor at dusk. Mind the ghosts on the way out.",
	Briefing = {
		"Ghosts drift through the halls. If one rears up, slap it to stun it.",
		"The coffin and the piano are long: turn them end-first through the doors.",
		"Boarded doors and old glass make shortcuts - if you can smash them.",
	},
	Camera = { Yaw = 22, Pitch = 52 },
	Bounds = { Min = { -64, -80 }, Max = { 64, 62 } },
	SpawnFacing = 0,
	Lighting = {
		ClockTime = 19.5,
		Brightness = 1.5,
		Ambient = Color3.fromRGB(120, 110, 150),
		OutdoorAmbient = Color3.fromRGB(120, 110, 150),
		FogEnd = 420,
		FogColor = Color3.fromRGB(70, 60, 96),
	},
	Ground = {
		{ Kind = "DeadGrass", Min = { -64, -80 }, Max = { 64, 62 } },
		{ Kind = "Dirt", Min = { -4, -12 }, Max = { 6, 27 }, Top = 0.05 }, -- garden path to the truck
		{ Kind = "Dirt", Min = { -40, 0 }, Max = { -14, 22 }, Top = 0.05, Color = Color3.fromRGB(84, 72, 62) }, -- graveyard
		{ Kind = "Dirt", Min = { 16, 2 }, Max = { 34, 16 }, Top = 0.05, Color = Color3.fromRGB(96, 78, 58) }, -- pumpkin patch
	},
	Floors = {
		{ Kind = "CarpetRed", Min = { -44, -28 }, Max = { -10, -12 } }, -- parlour
		{ Kind = "DarkWood", Min = { -44, -60 }, Max = { -10, -28 } }, -- dining room
		{ Kind = "DarkWood", Min = { -10, -44 }, Max = { 12, -12 } }, -- grand hall
		{ Kind = "DarkWood", Min = { -10, -60 }, Max = { 12, -44 }, Color = Color3.fromRGB(78, 58, 50) }, -- gallery
		{ Kind = "Carpet", Min = { 12, -36 }, Max = { 40, -12 }, Color = Color3.fromRGB(110, 84, 130) }, -- library
		{ Kind = "Concrete", Min = { 12, -60 }, Max = { 40, -36 }, Color = Color3.fromRGB(104, 100, 112) }, -- crypt
	},
	Walls = {
		-- outer walls
		{ A = { -44, -12 }, B = { 40, -12 }, Low = true, Color = wall, CapColor = cap, Openings = {
			{ At = 10, Width = 7, Kind = "BreakWindow" }, -- parlour glass: piano shortcut
			{ At = 24, Width = 5, Kind = "Window" },
			{ At = 45, Width = 8, Kind = "Door" }, -- grand double front door
			{ At = 58, Width = 5, Kind = "Window" },
			{ At = 72, Width = 6, Kind = "BoardedDoor" }, -- boarded library door
		} },
		{ A = { -44, -60 }, B = { 40, -60 }, Color = wall, CapColor = cap, Openings = {
			{ At = 10, Width = 5, Kind = "Window" },
			{ At = 55, Width = 5, Kind = "Window" },
			{ At = 70, Width = 5, Kind = "Window" },
		} },
		{ A = { -44, -60 }, B = { -44, -12 }, Color = wall, CapColor = cap, Openings = {
			{ At = 16, Width = 7, Kind = "BreakWindow" }, -- dining room glass
			{ At = 40, Width = 5, Kind = "Window" },
		} },
		{ A = { 40, -60 }, B = { 40, -12 }, Color = wall, CapColor = cap, Openings = {
			{ At = 12, Width = 5, Kind = "Window" },
			{ At = 36, Width = 5, Kind = "Window" },
		} },
		-- west wing: parlour / dining
		{ A = { -44, -28 }, B = { -10, -28 }, Color = wall, CapColor = cap, Openings = {
			{ At = 26, Width = 7, Kind = "Door" }, -- parlour <-> dining
		} },
		-- hall west wall: parlour door, dining door
		{ A = { -10, -60 }, B = { -10, -12 }, Color = wall, CapColor = cap, Openings = {
			{ At = 22, Width = 7, Kind = "Door" }, -- dining <-> hall
			{ At = 40, Width = 7, Kind = "Door" }, -- parlour <-> hall
		} },
		-- hall / gallery archway
		{ A = { -10, -44 }, B = { 12, -44 }, Color = wall, CapColor = cap, Openings = {
			{ At = 11, Width = 9, Kind = "Gap" },
		} },
		-- hall east wall: crypt door (from the gallery), library door
		{ A = { 12, -60 }, B = { 12, -12 }, Color = wall, CapColor = cap, Openings = {
			{ At = 8, Width = 7, Kind = "Door" }, -- gallery <-> crypt
			{ At = 36, Width = 7, Kind = "Door" }, -- hall <-> library
		} },
		-- library / crypt
		{ A = { 12, -36 }, B = { 40, -36 }, Color = wall, CapColor = cap, Openings = {
			{ At = 14, Width = 6, Kind = "BoardedDoor" }, -- crypt shortcut
		} },
	},
	Props = {
		-- parlour
		{ Kind = "Fireplace", Pos = { -29, -27.2 }, Rot = 0 },
		{ Kind = "Rug", Pos = { -29, -19 }, Size = { 14, 8 }, Color = Color3.fromRGB(90, 40, 60) },
		{ Kind = "Cobweb", Pos = { -43, -27 } },
		-- dining room
		{ Kind = "Rug", Pos = { -27, -45 }, Size = { 14, 10 }, Color = Color3.fromRGB(70, 60, 110) },
		{ Kind = "Block", Pos = { -27, -58.6 }, Size = { 10, 3, 2 }, Color = Color3.fromRGB(70, 48, 40), Material = Enum.Material.Wood }, -- sideboard
		{ Kind = "Lantern", Pos = { -42.5, -30 }, Color = lanternWarm, Range = 18 },
		{ Kind = "Cobweb", Pos = { -43, -59 } },
		-- grand hall
		{ Kind = "Rug", Pos = { 1, -26 }, Size = { 8, 22 }, Color = Color3.fromRGB(120, 30, 40) },
		{ Kind = "Lantern", Pos = { -8.5, -14 }, Color = lanternWarm, Range = 18 },
		{ Kind = "Lantern", Pos = { 10.5, -14 }, Color = lanternWarm, Range = 18 },
		{ Kind = "Lantern", Pos = { -8.5, -42.5 }, Color = lanternWarm, Range = 18 },
		{ Kind = "Block", Pos = { -7, -34 }, Size = { 3, 1.2, 8 }, Color = Color3.fromRGB(60, 44, 40), Material = Enum.Material.Wood }, -- hall bench
		-- gallery
		{ Kind = "Lantern", Pos = { 10.5, -58.5 }, Color = lanternGreen, Range = 18 },
		{ Kind = "Cobweb", Pos = { -9, -59 } },
		-- library
		{ Kind = "Rug", Pos = { 27, -22 }, Size = { 12, 8 }, Color = Color3.fromRGB(60, 90, 80) },
		{ Kind = "Lantern", Pos = { 38.5, -14 }, Color = lanternWarm, Range = 18 },
		-- crypt
		{ Kind = "Tombstone", Pos = { 20, -58.8 } },
		{ Kind = "Tombstone", Pos = { 36, -58.8 } },
		{ Kind = "Lantern", Pos = { 38.5, -38 }, Color = lanternGreen, Range = 18 },
		{ Kind = "Lantern", Pos = { 13.5, -58.5 }, Color = lanternGreen, Range = 18 },
		{ Kind = "Cobweb", Pos = { 39, -59 } },
		{ Kind = "Cobweb", Pos = { 13, -37 } },
		-- garden: lantern path
		{ Kind = "Lantern", Pos = { -6, -4 }, Color = lanternWarm },
		{ Kind = "Lantern", Pos = { 8, -4 }, Color = lanternWarm },
		{ Kind = "Lantern", Pos = { -6, 8 }, Color = lanternWarm },
		{ Kind = "Lantern", Pos = { 8, 8 }, Color = lanternWarm },
		{ Kind = "Lantern", Pos = { -8, 20 }, Color = lanternWarm },
		{ Kind = "Lantern", Pos = { 10, 20 }, Color = lanternWarm },
		{ Kind = "Pumpkin", Pos = { -12, -6 } },
		{ Kind = "Pumpkin", Pos = { 14, -6 } },
		-- graveyard
		{ Kind = "Fence", Pos = { -27, -1 }, Length = 26 },
		{ Kind = "Tombstone", Pos = { -36, 4 } },
		{ Kind = "Tombstone", Pos = { -30, 4 } },
		{ Kind = "Tombstone", Pos = { -24, 4 } },
		{ Kind = "Tombstone", Pos = { -18, 4 } },
		{ Kind = "Tombstone", Pos = { -36, 11 } },
		{ Kind = "Tombstone", Pos = { -27, 11 } },
		{ Kind = "Tombstone", Pos = { -20, 11 } },
		{ Kind = "Tombstone", Pos = { -33, 18 } },
		{ Kind = "Tombstone", Pos = { -24, 18 } },
		{ Kind = "DeadTree", Pos = { -40, 22 }, Scale = 1.2 },
		{ Kind = "DeadTree", Pos = { -15, 15 } },
		{ Kind = "Lantern", Pos = { -14, 1 }, Color = lanternGreen },
		-- pumpkin patch
		{ Kind = "Pumpkin", Pos = { 19, 5 } },
		{ Kind = "Pumpkin", Pos = { 25, 7 } },
		{ Kind = "Pumpkin", Pos = { 31, 5 } },
		{ Kind = "Pumpkin", Pos = { 21, 12 } },
		{ Kind = "Pumpkin", Pos = { 29, 13 } },
		{ Kind = "Sign", Pos = { 12, 2 }, Rot = -20, Text = "BOO!" },
		-- dead trees around the grounds
		{ Kind = "DeadTree", Pos = { -52, -30 }, Scale = 1.3 },
		{ Kind = "DeadTree", Pos = { 50, -24 }, Scale = 1.2 },
		{ Kind = "DeadTree", Pos = { 46, 14 } },
		{ Kind = "DeadTree", Pos = { -54, 30 } },
		{ Kind = "DeadTree", Pos = { 28, -70 }, Scale = 1.3 },
		{ Kind = "Tombstone", Pos = { -50, 6 } },
		{ Kind = "Tombstone", Pos = { 52, 0 } },
		-- iron fence along the lane, gap for the truck
		{ Kind = "Fence", Pos = { -36, 29 }, Length = 44 },
		{ Kind = "Fence", Pos = { 38, 29 }, Length = 44 },
		{ Kind = "Lantern", Pos = { -14, 30 }, Color = lanternWarm },
		{ Kind = "Lantern", Pos = { 16, 30 }, Color = lanternWarm },
	},
	-- parked at the end of the garden path, ramp down toward the manor
	Truck = { Pos = { 1, 0, 33 }, Rot = 180, Length = 17, Width = 11, Height = 6 },
	Items = {
		-- parlour
		{ Kind = "Piano", Pos = { -37, -26 } },
		{ Kind = "Armchair", Pos = { -33.5, -18.5 } },
		{ Kind = "Armchair", Pos = { -24.5, -18.5 } },
		{ Kind = "Vase", Pos = { -41.5, -14.5 } },
		-- dining room
		{ Kind = "DiningTable", Pos = { -27, -45 } },
		{ Kind = "Chair", Pos = { -27, -40.5 }, Rot = 180 },
		{ Kind = "Chair", Pos = { -27, -49.5 } },
		{ Kind = "Candelabra", Pos = { -40, -56 } },
		{ Kind = "Vase", Pos = { -14, -56 } },
		-- grand hall
		{ Kind = "Clock", Pos = { 10.4, -40 }, Rot = 90 },
		-- gallery
		{ Kind = "Mirror", Pos = { -2, -58.8 } },
		{ Kind = "Dresser", Pos = { 5, -58.2 } },
		-- library
		{ Kind = "Bookcase", Pos = { 19, -34.4 } },
		{ Kind = "Bookcase", Pos = { 34, -34.4 } },
		-- crypt
		{ Kind = "Coffin", Pos = { 28, -48 }, Rot = 90 },
		{ Kind = "Candelabra", Pos = { 37, -56 } },
	},
	Spawns = { { -2, -7 }, { 4, -7 }, { -2, -3 }, { 4, -3 } },
	Hazards = {
		-- hall and gallery: everything from the back of the house passes through here
		{ Kind = "Ghost", Patrol = { { -5, -52 }, { 7, -52 }, { 7, -30 }, { -5, -22 } } },
		-- west wing: drifts between the dining room and the parlour
		{ Kind = "Ghost", Patrol = { { -36, -50 }, { -18, -50 }, { -16, -20 }, { -36, -20 } } },
	},
	-- PROVISIONAL reconstruction targets: retune after playtests
	Awards = { Gold = 250, Silver = 375, Bronze = 500 },
}
