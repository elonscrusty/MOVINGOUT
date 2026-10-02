--[[
	Depot.luau - the lobby yard (not a job). Movers practise grabbing, throwing,
	carrying the practice sofa together and loading the truck while the host picks a
	job. Items here are never required and never finish anything.
	Level data format: see docs/LEVELS.md.
]]

return {
	Id = "Depot",
	Name = "The Depot",
	Camera = { Yaw = 20, Pitch = 62, View = { Min = { -32, -38 }, Max = { 32, 22 } } },
	Bounds = { Min = { -60, -50 }, Max = { 60, 60 } },
	SpawnFacing = 0,
	WallStyle = {
		Outer = Color3.fromRGB(240, 128, 84), -- orange shed planks
		OuterMaterial = Enum.Material.WoodPlanks,
		Inner = Color3.fromRGB(246, 238, 220),
		Cap = Color3.fromRGB(70, 66, 76),
	},
	Ground = {
		{ Kind = "Concrete", Min = { -34, -40 }, Max = { 34, -14 }, Color = Color3.fromRGB(196, 196, 190) },
		{ Kind = "Pavement", Min = { -34, -14 }, Max = { 34, 30 } },
		{ Kind = "Road", Min = { -60, 30 }, Max = { 60, 42 } },
	},
	Floors = {
		{ Kind = "Concrete", Min = { -30, -36 }, Max = { 30, -14 }, Color = Color3.fromRGB(206, 204, 198), Pattern = "Grid", Tile = 6, Wall = Color3.fromRGB(246, 238, 220) },
	},
	Walls = {
		-- the depot shed (back), with a big doorway and a practice breakable window
		{ A = { -30, -36 }, B = { 30, -36 } },
		{ A = { -30, -36 }, B = { -30, -14 } },
		{ A = { 30, -36 }, B = { 30, -14 } },
		{ A = { -30, -14 }, B = { 30, -14 }, Low = true, Openings = {
			{ At = 22, Width = 12, Kind = "Door" },
			{ At = 44, Width = 7, Kind = "BreakWindow" },
		} },
	},
	Props = {
		{ Kind = "Shelf", Pos = { -18, -33 }, Length = 14, Height = 7 },
		{ Kind = "Shelf", Pos = { 16, -33 }, Length = 14, Height = 7 },
		{ Kind = "Forklift", Pos = { 24, -24 }, Rot = 90 },
		{ Kind = "Pallet", Pos = { -24, -22 } },
		{ Kind = "Cone", Pos = { -10, 22 } },
		{ Kind = "Cone", Pos = { -6, 24 } },
		{ Kind = "Sign", Pos = { -24, -10 }, Text = "DEPOT" },
		{ Kind = "Tree", Pos = { -44, 10 } },
		{ Kind = "Tree", Pos = { 46, -6 }, Scale = 1.2 },
		{ Kind = "Bush", Pos = { -40, 30 } },
		{ Kind = "Bush", Pos = { 42, 26 } },
		{ Kind = "StreetLamp", Pos = { -32, 28 } },
		{ Kind = "StreetLamp", Pos = { 32, 28 } },
	},
	Truck = { Pos = { 12, 0, 6 }, Rot = 180, Length = 16, Width = 11, Height = 6 },
	Items = {
		{ Kind = "Box", Pos = { -12, -4 }, Required = false },
		{ Kind = "Box", Pos = { -9, -1 }, Required = false },
		{ Kind = "BoxTall", Pos = { -14, 2 }, Required = false },
		{ Kind = "BeachBall", Pos = { -4, 8 }, Required = false },
		{ Kind = "Chair", Pos = { -18, -6 }, Required = false },
		{ Kind = "Sofa", Pos = { -10, -24 }, Required = false },
		{ Kind = "Crate", Pos = { 4, -26 }, Required = false },
	},
	Spawns = { { -4, 0 }, { 0, 0 }, { -4, 4 }, { 0, 4 } },
	Hazards = {},
	Awards = { Gold = 60, Silver = 90, Bronze = 120 },
}
