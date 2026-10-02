--[[
	Warehouse.luau - Job 3: Bulk Warehouse. Teaches environmental motion.
	A roofless warehouse: a shelved storage bay (back left), an office (front left), a
	packing room (back right) and a dispatch hall along the front. The truck backs up to a
	cramped loading yard on the east side.
	Conveyors: the packing belt carries things out of the packing room into the hall
	(and drags anyone crossing the hall toward the camera); the dispatch belt runs along
	the front of the hall, out through a hatch and round to the foot of the truck ramp;
	the yard belt runs across the path from the loading door to the ramp and pushes
	movers sideways. Every required item can also be carried on foot.
	Shortcut: the packing room's boarded side door opens straight onto the yard.
	Award times are PROVISIONAL reconstruction targets: retune after playtests.
	Level data format: see docs/LEVELS.md.
]]

local grey = Color3.fromRGB(206, 210, 212)
local cream = Color3.fromRGB(240, 228, 190)
local sage = Color3.fromRGB(176, 206, 186)

return {
	Id = "Warehouse",
	Name = "Bulk Warehouse",
	Tagline = "Crates, belts and a busy loading bay. Let the conveyors do the walking.",
	Briefing = {
		"Conveyors carry anything on them: drop a crate on the dispatch belt and it rides to the truck.",
		"Crossing a belt pushes you sideways - step over it square-on, or ride it.",
		"Big crates and the washer are heavy: grab a friend, or drag them.",
		"The packing room's boarded side door is a shortcut to the yard.",
	},
	Camera = { Yaw = 25, Pitch = 62, View = { Min = { -38, -48 }, Max = { 42, 4 } } },
	Bounds = { Min = { -50, -60 }, Max = { 80, 20 } },
	SpawnFacing = 0,
	Lighting = { ClockTime = 12 },
	WallStyle = {
		Outer = Color3.fromRGB(184, 92, 70), -- red brick outside
		OuterMaterial = Enum.Material.Brick,
		Inner = grey,
		Cap = Color3.fromRGB(70, 72, 82),
		Frame = Color3.fromRGB(150, 156, 164),
		Door = Color3.fromRGB(120, 132, 148),
	},
	Ground = {
		{ Kind = "Concrete", Min = { 24, -40 }, Max = { 70, 6 }, Color = Color3.fromRGB(184, 184, 178) }, -- loading yard
		{ Kind = "Pavement", Min = { -40, 0 }, Max = { 24, 6 } }, -- front apron
		{ Kind = "Pavement", Min = { -40, -50 }, Max = { -36, 0 } }, -- side path
		{ Kind = "Road", Min = { -50, 6 }, Max = { 80, 18 } }, -- service road (decor)
	},
	Floors = {
		{ Kind = "Concrete", Min = { -36, -46 }, Max = { 4, -16 }, Color = Color3.fromRGB(170, 174, 178), Pattern = "Grid", Tile = 8 }, -- storage bay
		{ Kind = "Carpet", Min = { -36, -16 }, Max = { -18, 0 }, Color = Color3.fromRGB(104, 128, 176), Pattern = "Checker", Color2 = Color3.fromRGB(92, 114, 160), Tile = 3, Wall = cream }, -- office
		{ Kind = "Metal", Min = { 4, -46 }, Max = { 24, -22 }, Color = Color3.fromRGB(150, 158, 168), Pattern = "Grid", Tile = 4, Wall = sage }, -- packing room
		{ Kind = "Concrete", Min = { -18, -16 }, Max = { 4, 0 }, Color = Color3.fromRGB(196, 196, 190), Pattern = "Grid", Tile = 6 }, -- dispatch hall (west)
		{ Kind = "Concrete", Min = { 4, -22 }, Max = { 24, 0 }, Color = Color3.fromRGB(196, 196, 190), Pattern = "Grid", Tile = 6 }, -- dispatch hall (east)
	},
	Walls = {
		-- outer walls
		{ A = { -36, -46 }, B = { 24, -46 }, Openings = {
			{ At = 18, Width = 6, Kind = "Window", Sill = 3.5 },
			{ At = 50, Width = 6, Kind = "Window", Sill = 3.5 },
		} },
		{ A = { -36, -46 }, B = { -36, 0 }, Openings = {
			{ At = 38, Width = 5, Kind = "Window" },
		} },
		{ A = { 24, -46 }, B = { 24, 0 }, Openings = {
			{ At = 12, Width = 6, Kind = "BoardedDoor" }, -- packing room side door: shortcut to the yard
			{ At = 34, Width = 8, Kind = "Door" }, -- loading door
			{ At = 42, Width = 4.4, Kind = "Gap" }, -- dispatch belt hatch
		} },
		{ A = { -36, 0 }, B = { 24, 0 }, Low = true, Openings = {
			{ At = 9, Width = 6, Kind = "Window" },
			{ At = 34, Width = 8, Kind = "Window" },
			{ At = 50, Width = 6, Kind = "Window" },
		} },
		-- interior walls
		{ A = { -36, -16 }, B = { 4, -16 }, Low = true, Openings = {
			{ At = 9, Width = 5, Kind = "Door" }, -- storage <-> office
			{ At = 28, Width = 8, Kind = "Gap" }, -- storage <-> hall
		} },
		{ A = { 4, -46 }, B = { 4, -16 }, Openings = {
			{ At = 16, Width = 5, Kind = "Door" }, -- tight storage <-> packing door
		} },
		{ A = { 4, -22 }, B = { 24, -22 }, Low = true, Openings = {
			{ At = 10, Width = 6, Kind = "Door" }, -- packing room -> hall
			{ At = 15.6, Width = 4.4, Kind = "Gap" }, -- packing belt hatch
		} },
		{ A = { -18, -16 }, B = { -18, 0 }, Openings = {
			{ At = 8, Width = 5, Kind = "Door" }, -- office -> hall
		} },
	},
	Props = {
		-- storage bay aisles
		{ Kind = "Shelf", Pos = { -30, -34 }, Rot = 90, Length = 16 },
		{ Kind = "Shelf", Pos = { -20, -34 }, Rot = 90, Length = 16 },
		{ Kind = "Shelf", Pos = { -10, -34 }, Rot = 90, Length = 16 },
		{ Kind = "Shelf", Pos = { -6, -44.2 }, Length = 8, Height = 6 },
		{ Kind = "Forklift", Pos = { 0, -38 } },
		{ Kind = "Pallet", Pos = { -32, -20 } },
		-- office
		{ Kind = "Block", Pos = { -27, -3 }, Size = { 5, 3, 2.4 }, Color = Color3.fromRGB(150, 110, 80), Material = Enum.Material.WoodPlanks }, -- desk
		{ Kind = "Rug", Pos = { -27, -8 }, Size = { 8, 6 }, Color = Color3.fromRGB(60, 80, 140) },
		-- packing room
		{ Kind = "Counter", Pos = { 12, -44.2 }, Length = 8 },
		-- dispatch hall
		{ Kind = "Pallet", Pos = { -2, -12 } },
		{ Kind = "Sign", Pos = { 14, -0.8 }, Text = "DISPATCH" },
		-- loading yard: cramped in front of the ramp
		{ Kind = "Forklift", Pos = { 40, -31 }, Rot = 90 },
		{ Kind = "Pallet", Pos = { 34, -28.5 } },
		{ Kind = "Block", Pos = { 26.6, -20 }, Size = { 3, 3, 3 }, Color = Color3.fromRGB(196, 150, 96), Material = Enum.Material.WoodPlanks },
		{ Kind = "Block", Pos = { 37.5, -26.8 }, Size = { 2.5, 2.5, 2.5 }, Color = Color3.fromRGB(196, 150, 96), Material = Enum.Material.WoodPlanks },
		{ Kind = "Cone", Pos = { 39, -9 } },
		{ Kind = "Cone", Pos = { 46, -9 } },
		{ Kind = "Fence", Pos = { 47, -38 }, Length = 46 },
		{ Kind = "Fence", Pos = { 62, 4 }, Length = 16 },
		{ Kind = "StreetLamp", Pos = { 30, 3 } },
		{ Kind = "StreetLamp", Pos = { 30, -36 } },
		{ Kind = "Sign", Pos = { 50, -7 }, Text = "BAY 3" },
		{ Kind = "Tree", Pos = { -44, -10 } },
		{ Kind = "Tree", Pos = { -44, -36 }, Scale = 1.1 },
		{ Kind = "Tree", Pos = { 2, -54 }, Style = "Round" },
		{ Kind = "Tree", Pos = { 64, -46 } },
		{ Kind = "Bush", Pos = { -30, 3 }, Scale = 0.8 },
		{ Kind = "Bush", Pos = { 18, 3.2 }, Scale = 0.8 },
	},
	-- backed up to the yard from the east: cargo runs toward +X, ramp down toward -X
	Truck = { Pos = { 40, 0, -18 }, Rot = -90, Length = 19, Width = 11, Height = 6 },
	Items = {
		-- storage bay
		{ Kind = "Crate", Pos = { -25, -38 } },
		{ Kind = "Crate", Pos = { -15, -29 } },
		{ Kind = "Barrel", Pos = { -33.5, -40 } },
		{ Kind = "Barrel", Pos = { -5, -27 } },
		{ Kind = "Toolbox", Pos = { -25, -28 } },
		{ Kind = "Parcel", Pos = { -15, -41 } },
		{ Kind = "BoxSmall", Pos = { -25, -44 } },
		{ Kind = "Box", Pos = { -5, -33 } },
		-- office
		{ Kind = "Bookcase", Pos = { -32, -14.4 } },
		{ Kind = "Dresser", Pos = { -34.2, -6 }, Rot = 90 },
		{ Kind = "Chair", Pos = { -27, -7 }, Rot = 180 },
		{ Kind = "Box", Pos = { -21, -12 } },
		{ Kind = "BoxFlat", Pos = { -31, -2 } },
		{ Kind = "Bin", Pos = { -21, -3 } },
		-- packing room
		{ Kind = "BigCrate", Pos = { 9.5, -40 } },
		{ Kind = "BigCrate", Pos = { 13, -28 } },
		{ Kind = "Washer", Pos = { 13.5, -35 } },
		{ Kind = "Parcel", Pos = { 22.4, -41 }, Rot = 90 },
		{ Kind = "Toolbox", Pos = { 22.4, -26 }, Rot = 90 },
		{ Kind = "Box", Pos = { 8, -25 } },
		{ Kind = "BoxSmall", Pos = { 8, -34 } },
		-- dispatch hall
		{ Kind = "Crate", Pos = { -10, -9 } },
		{ Kind = "BoxTall", Pos = { 14, -8 } },
	},
	Spawns = { { 6, -12 }, { 10, -12 }, { 6, -16 }, { 10, -16 } },
	Hazards = {
		-- packing belt: packing room -> hall (crossing it in the hall drags you toward +Z)
		{ Kind = "Conveyor", Min = { 18, -42 }, Max = { 21, -14 }, Dir = { 0, 1 }, Speed = 6 },
		-- dispatch belt: along the front of the hall, out through the hatch ...
		{ Kind = "Conveyor", Min = { -14, -5.5 }, Max = { 34.5, -2.5 }, Dir = { 1, 0 }, Speed = 7 },
		-- ... and round the corner to the foot of the truck ramp
		{ Kind = "Conveyor", Min = { 31.5, -14 }, Max = { 34.5, -2.5 }, Dir = { 0, -1 }, Speed = 7 },
		-- yard belt: runs across the path from the loading door to the ramp
		{ Kind = "Conveyor", Min = { 28, -34 }, Max = { 31, -8 }, Dir = { 0, -1 }, Speed = 8 },
	},
	-- PROVISIONAL: retune from playtests
	Awards = { Gold = 230, Silver = 345, Bronze = 460 },
}
