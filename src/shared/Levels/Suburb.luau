--[[
	Suburb.luau - Job 1: Starter Home. Teaches the whole moving loop.
	A roofless bungalow (living room, kitchen, study, bedroom), a front lawn, a street
	with occasional traffic, and the truck parked across the road.
	Challenges: the sofa must be turned to fit the front door (or go through the big
	breakable window), the bed only fits the bedroom door lengthwise and needs the
	double front door or the bedroom's breakable patio glass, the truck needs packing.
	Award times are PROVISIONAL reconstruction targets: retune after playtests.
]]

local wall = Color3.fromRGB(250, 236, 206)
local cap = Color3.fromRGB(150, 104, 80)

return {
	Id = "Suburb",
	Name = "Starter Home",
	Tagline = "A cosy bungalow. Learn to lift, turn, throw and pack.",
	Briefing = {
		"Sofa too long for the door? Turn it end-first, or smash the big front window.",
		"The bed only fits through doors lengthwise - or out through the bedroom's glass door.",
		"Watch the road: cars honk and flash before they pass.",
	},
	Camera = { Yaw = 22, Pitch = 52 },
	Bounds = { Min = { -60, -60 }, Max = { 60, 70 } },
	SpawnFacing = 0,
	Lighting = { ClockTime = 14 },
	Ground = {
		{ Kind = "Grass", Min = { -60, -60 }, Max = { 60, 6 } },
		{ Kind = "Pavement", Min = { 1, -8 }, Max = { 7, 6 }, Top = 0.05 }, -- front path
		{ Kind = "Pavement", Min = { -60, 6 }, Max = { 60, 10 } },
		{ Kind = "Road", Min = { -60, 10 }, Max = { 60, 24 } },
		{ Kind = "Pavement", Min = { -60, 24 }, Max = { 60, 28 } },
		{ Kind = "Grass", Min = { -60, 28 }, Max = { 60, 70 } },
	},
	Floors = {
		{ Kind = "Wood", Min = { -8, -26 }, Max = { 26, -8 } }, -- living room
		{ Kind = "Tile", Min = { -30, -26 }, Max = { -8, -8 }, Material = Enum.Material.CeramicTiles, Color = Color3.fromRGB(236, 232, 220) }, -- kitchen
		{ Kind = "Carpet", Min = { -30, -44 }, Max = { 4, -26 }, Color = Color3.fromRGB(170, 196, 150) }, -- study
		{ Kind = "Carpet", Min = { 4, -44 }, Max = { 26, -26 } }, -- bedroom
	},
	Walls = {
		-- outer walls
		{ A = { -30, -44 }, B = { 26, -44 }, Color = wall, CapColor = cap, Openings = {
			{ At = 14, Width = 6, Kind = "Window" },
			{ At = 45, Width = 6, Kind = "Window" },
		} },
		{ A = { -30, -44 }, B = { -30, -8 }, Color = wall, CapColor = cap, Openings = {
			{ At = 26, Width = 5, Kind = "Window" },
		} },
		{ A = { 26, -44 }, B = { 26, -8 }, Color = wall, CapColor = cap, Openings = {
			{ At = 9, Width = 7, Kind = "BreakWindow" }, -- bedroom patio glass: the bed shortcut
			{ At = 27, Width = 5, Kind = "Window" },
		} },
		{ A = { -30, -8 }, B = { 26, -8 }, Low = true, Color = wall, CapColor = cap, Openings = {
			{ At = 11, Width = 5, Kind = "Window" },
			{ At = 34, Width = 7.4, Kind = "Door" }, -- double front door
			{ At = 47, Width = 8, Kind = "BreakWindow" }, -- big living-room window
		} },
		-- interior walls
		{ A = { -30, -26 }, B = { 26, -26 }, Color = wall, CapColor = cap, Openings = {
			{ At = 16, Width = 5, Kind = "Door" }, -- study
			{ At = 45, Width = 6.6, Kind = "Door" }, -- bedroom: bed fits lengthwise only
		} },
		{ A = { 4, -44 }, B = { 4, -26 }, Color = wall, CapColor = cap },
		{ A = { -8, -26 }, B = { -8, -8 }, Color = wall, CapColor = cap, Openings = {
			{ At = 9, Width = 6, Kind = "Gap" }, -- kitchen opening
		} },
	},
	Props = {
		{ Kind = "Counter", Pos = { -21.5, -24.3 }, Length = 6 },
		{ Kind = "Stove", Pos = { -26.5, -24.3 } },
		{ Kind = "Rug", Pos = { 14, -16 }, Size = { 12, 8 }, Color = Color3.fromRGB(230, 150, 90) },
		{ Kind = "Rug", Pos = { 15, -32 }, Size = { 9, 6 }, Color = Color3.fromRGB(150, 120, 200) },
		{ Kind = "Fireplace", Pos = { -1, -25.4 }, Rot = 0 },
		{ Kind = "Tree", Pos = { -24, -1 } },
		{ Kind = "Tree", Pos = { 36, -20 }, Scale = 1.2 },
		{ Kind = "Tree", Pos = { -40, -30 } },
		{ Kind = "Bush", Pos = { -12, -3 } },
		{ Kind = "Bush", Pos = { 22, -3 } },
		{ Kind = "Hedge", Pos = { -20, 5 }, Length = 20 },
		{ Kind = "Hedge", Pos = { 26, 5 }, Length = 22 },
		{ Kind = "Mailbox", Pos = { 9, 4.5 } },
		{ Kind = "Sign", Pos = { -6, 1 }, Text = "SOLD" },
		{ Kind = "StreetLamp", Pos = { -30, 26.5 } },
		{ Kind = "StreetLamp", Pos = { 40, 26.5 } },
		{ Kind = "Fence", Pos = { -30, 30 }, Length = 24 },
		{ Kind = "Fence", Pos = { 42, 30 }, Length = 24 },
		{ Kind = "Tree", Pos = { -36, 44 } },
		{ Kind = "Tree", Pos = { 30, 48 } },
	},
	-- parked across the road, rear facing the house; ramp down onto the far pavement
	Truck = { Pos = { 4, 0, 30 }, Rot = 180, Length = 18, Width = 11, Height = 6 },
	Items = {
		-- living room
		{ Kind = "Sofa", Pos = { 14, -22 } },
		{ Kind = "CoffeeTable", Pos = { 14, -15.5 } },
		{ Kind = "TV", Pos = { 14, -10.4 }, Rot = 180 },
		{ Kind = "Armchair", Pos = { 22.5, -15 }, Rot = -90 },
		{ Kind = "Lamp", Pos = { -4.5, -22.5 } },
		-- kitchen
		{ Kind = "Fridge", Pos = { -27.4, -21 }, Rot = 90 },
		{ Kind = "Chair", Pos = { -19, -14 } },
		{ Kind = "Box", Pos = { -12, -11.5 } },
		-- study
		{ Kind = "Box", Pos = { -25, -40 } },
		{ Kind = "Box", Pos = { -21.5, -40.5 } },
		{ Kind = "BoxTall", Pos = { -26.5, -31 } },
		-- bedroom
		{ Kind = "Bed", Pos = { 15, -37.5 } },
	},
	Spawns = { { 2, -3 }, { 6, -3 }, { 2, 1 }, { 6, 1 } },
	Hazards = {
		{ Kind = "Traffic", A = { -75, 17 }, B = { 75, 17 }, Interval = { 9, 15 }, Width = 12 },
	},
	Awards = { Gold = 180, Silver = 270, Bronze = 360 },
}
