--[[
	FurnitureModels.luau
	Builds the look of every furniture kind out of primitive parts: chunky, rounded,
	readable silhouettes in the cheerful cartoon style of the brief (original art).

	Each builder gets add(size, cframe, colour, material?, shape?) where cframe is relative
	to the item's collider centre (the collider is FurnitureData Size, bottom at -Size.Y/2).
	Visual parts are welded to the collider, massless, never collide and never block queries.
]]

local FurnitureData = require(game:GetService("ReplicatedStorage").Shared.FurnitureData)

local FurnitureModels = {}

type Add = (size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?) -> BasePart

local C = {
	wood = Color3.fromRGB(196, 140, 86),
	darkWood = Color3.fromRGB(128, 82, 52),
	lightWood = Color3.fromRGB(226, 186, 128),
	cardboard = Color3.fromRGB(205, 160, 105),
	tape = Color3.fromRGB(232, 210, 160),
	white = Color3.fromRGB(242, 240, 232),
	grey = Color3.fromRGB(150, 156, 166),
	dark = Color3.fromRGB(52, 54, 64),
	screen = Color3.fromRGB(40, 60, 90),
	red = Color3.fromRGB(222, 76, 70),
	teal = Color3.fromRGB(64, 176, 170),
	blue = Color3.fromRGB(84, 128, 220),
	yellow = Color3.fromRGB(246, 204, 70),
	green = Color3.fromRGB(96, 178, 80),
	pink = Color3.fromRGB(242, 126, 170),
	purple = Color3.fromRGB(120, 92, 170),
	gold = Color3.fromRGB(230, 184, 70),
	pot = Color3.fromRGB(206, 108, 70),
	metal = Color3.fromRGB(176, 182, 192),
}
FurnitureModels.Colors = C

local V = Vector3.new
local CF = CFrame.new
local SP = Enum.PartType.Ball
local CY = Enum.PartType.Cylinder
local smooth = Enum.Material.SmoothPlastic
local fabric = Enum.Material.Fabric
local woodM = Enum.Material.WoodPlanks
local metalM = Enum.Material.Metal
local glassM = Enum.Material.Glass
local neon = Enum.Material.Neon
local upright = CFrame.Angles(0, 0, math.rad(90)) -- cylinders stand on their axis

local function legs(add: Add, s: Vector3, h: number, inset: number, thick: number, color: Color3)
	local y = -s.Y / 2 + h / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add(V(thick, h, thick), CF(sx * (s.X / 2 - inset), y, sz * (s.Z / 2 - inset)), color, smooth)
		end
	end
end

local B: { [string]: (add: Add, s: Vector3, tint: Color3?) -> () } = {}

B.Box = function(add, s, tint)
	add(s - V(0.04, 0.04, 0.04), CF(), tint or C.cardboard, Enum.Material.Cardboard)
	add(V(s.X * 0.3, 0.05, s.Z + 0.02), CF(0, s.Y / 2, 0), C.tape, smooth)
	add(V(s.X * 0.3, s.Y * 0.4, 0.05), CF(0, s.Y * 0.3, s.Z / 2), C.tape, smooth)
	add(V(s.X * 0.3, s.Y * 0.4, 0.05), CF(0, s.Y * 0.3, -s.Z / 2), C.tape, smooth)
	add(V(0.05, s.Y * 0.25, s.Z * 0.35), CF(s.X / 2, 0, 0), C.dark, smooth) -- arrow label
end
B.BoxTall = B.Box
B.Parcel = function(add, s, tint)
	B.Box(add, s, tint or Color3.fromRGB(190, 150, 110))
	add(V(s.X + 0.02, 0.1, 0.25), CF(0, s.Y / 2 - 0.02, 0), C.red, smooth)
end

B.Lamp = function(add, s, tint)
	add(V(0.3, s.X * 0.9, s.X * 0.9), CF(0, -s.Y / 2 + 0.15, 0) * upright, C.dark, smooth, CY)
	add(V(s.Y * 0.62, 0.22, 0.22), CF(0, -s.Y / 2 + s.Y * 0.33, 0) * upright, C.metal, metalM, CY)
	local shade = add(V(1.6, s.X, s.X), CF(0, s.Y / 2 - 0.85, 0) * upright, tint or C.yellow, fabric, CY)
	shade.Transparency = 0.05
	add(V(0.5, 0.5, 0.5), CF(0, s.Y / 2 - 1.2, 0), Color3.fromRGB(255, 240, 190), neon, SP)
end

B.Stool = function(add, s, tint)
	add(V(0.35, s.X, s.X), CF(0, s.Y / 2 - 0.18, 0) * upright, tint or C.red, smooth, CY)
	legs(add, s, s.Y - 0.35, 0.35, 0.25, C.darkWood)
end

B.SideTable = function(add, s, tint)
	add(V(s.X, 0.3, s.Z), CF(0, s.Y / 2 - 0.15, 0), tint or C.wood, woodM)
	add(V(s.X - 0.4, 0.9, s.Z - 0.4), CF(0, s.Y / 2 - 0.75, 0), C.lightWood, woodM)
	add(V(0.4, 0.15, 0.1), CF(0, s.Y / 2 - 0.75, s.Z / 2 - 0.15), C.gold, metalM)
	legs(add, s, s.Y - 0.3, 0.25, 0.25, C.darkWood)
end

B.Plant = function(add, s, tint)
	add(V(1.4, s.X * 0.9, s.X * 0.9), CF(0, -s.Y / 2 + 0.7, 0) * upright, C.pot, smooth, CY)
	add(V(2, 2, 2), CF(0, s.Y / 2 - 1.1, 0), tint or C.green, Enum.Material.Grass, SP)
	add(V(1.3, 1.3, 1.3), CF(0.5, s.Y / 2 - 0.6, 0.3), (tint or C.green):Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Grass, SP)
end

B.BeachBall = function(add, s, tint)
	add(s, CF(), tint or C.white, smooth, SP)
	add(V(s.X * 1.01, s.Y * 1.01, s.Z * 0.3), CF(), C.red, smooth, SP)
	add(V(s.X * 0.3, s.Y * 1.01, s.Z * 1.01), CF(), C.blue, smooth, SP)
end

B.Flamingo = function(add, s, tint)
	local pink = tint or C.pink
	add(V(s.X, 1, s.Z), CF(0, -s.Y / 2 + 0.5, 0), pink, smooth, SP)
	add(V(0.5, 2.4, 0.5), CF(s.X * 0.28, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-12)), pink, smooth)
	add(V(0.9, 0.9, 0.9), CF(s.X * 0.4, s.Y / 2 - 0.45, 0), pink, smooth, SP)
	add(V(0.6, 0.25, 0.25), CF(s.X / 2, s.Y / 2 - 0.55, 0), C.dark, smooth)
end

B.Microwave = function(add, s, tint)
	add(s, CF(), tint or C.white, smooth)
	add(V(s.X * 0.6, s.Y * 0.7, 0.06), CF(-s.X * 0.12, 0, s.Z / 2), C.screen, glassM)
	add(V(s.X * 0.18, s.Y * 0.7, 0.06), CF(s.X * 0.36, 0, s.Z / 2), C.grey, smooth)
end

B.Vase = function(add, s, tint)
	add(V(s.X, s.Y * 0.7, s.Z), CF(0, -s.Y * 0.12, 0), tint or C.teal, Enum.Material.Glass, SP)
	add(V(s.Y * 0.4, s.X * 0.5, s.X * 0.5), CF(0, s.Y * 0.28, 0) * upright, tint or C.teal, smooth, CY)
	add(V(0.8, 0.8, 0.8), CF(0, s.Y / 2, 0), C.red, smooth, SP)
end

B.Candelabra = function(add, s, tint)
	local gold = tint or C.gold
	add(V(0.3, 1.2, 1.2), CF(0, -s.Y / 2 + 0.15, 0) * upright, gold, metalM, CY)
	add(V(s.Y * 0.6, 0.25, 0.25), CF(0, -s.Y * 0.1, 0) * upright, gold, metalM, CY)
	add(V(s.X, 0.2, 0.2), CF(0, s.Y * 0.18, 0), gold, metalM)
	for _, x in { -s.X / 2 + 0.15, 0, s.X / 2 - 0.15 } do
		add(V(0.25, 0.8, 0.25), CF(x, s.Y * 0.18 + 0.5, 0), C.white, smooth)
		add(V(0.2, 0.3, 0.2), CF(x, s.Y * 0.18 + 1.05, 0), Color3.fromRGB(255, 200, 90), neon, SP)
	end
end

B.Chair = function(add, s, tint)
	local seatY = -s.Y / 2 + s.Y * 0.45
	add(V(s.X, 0.35, s.Z), CF(0, seatY, 0), tint or C.wood, woodM)
	add(V(s.X, s.Y * 0.5, 0.3), CF(0, seatY + s.Y * 0.25, -s.Z / 2 + 0.15), tint or C.wood, woodM)
	add(V(s.X - 0.4, 0.3, s.Z - 0.4), CF(0, seatY + 0.3, 0.05), C.red, fabric)
	local legH = s.Y * 0.45
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add(V(0.28, legH, 0.28), CF(sx * (s.X / 2 - 0.2), -s.Y / 2 + legH / 2, sz * (s.Z / 2 - 0.2)), C.darkWood, smooth)
		end
	end
end

B.TV = function(add, s, tint)
	add(V(s.X, s.Y - 0.4, 0.5), CF(0, 0.2, 0), tint or C.dark, smooth)
	add(V(s.X - 0.4, s.Y - 0.8, 0.06), CF(0, 0.2, 0.26), C.screen, glassM)
	add(V(s.X * 0.6, s.Y * 0.35, 0.07), CF(-s.X * 0.1, 0.4, 0.27), Color3.fromRGB(90, 140, 200), glassM).Transparency = 0.4
	add(V(1.4, 0.4, s.Z), CF(0, -s.Y / 2 + 0.2, 0), C.dark, smooth)
end

B.CoffeeTable = function(add, s, tint)
	add(V(s.X, 0.4, s.Z), CF(0, s.Y / 2 - 0.2, 0), tint or C.lightWood, woodM)
	add(V(s.X - 0.6, 0.15, s.Z - 0.6), CF(0, -s.Y / 2 + 0.6, 0), C.wood, woodM)
	legs(add, s, s.Y - 0.4, 0.35, 0.35, C.darkWood)
	add(V(1, 0.15, 0.8), CF(1, s.Y / 2 + 0.05, 0.3), C.red, smooth)
end

B.Armchair = function(add, s, tint)
	local col = tint or C.teal
	add(V(s.X, s.Y * 0.4, s.Z), CF(0, -s.Y / 2 + s.Y * 0.2 + 0.3, 0), col, fabric)
	add(V(s.X, s.Y * 0.55, 0.8), CF(0, s.Y * 0.2, -s.Z / 2 + 0.4), col, fabric)
	for _, sx in { -1, 1 } do
		add(V(0.7, s.Y * 0.55, s.Z), CF(sx * (s.X / 2 - 0.35), -s.Y / 2 + s.Y * 0.3 + 0.3, 0), col:Lerp(Color3.new(0, 0, 0), 0.1), fabric)
	end
	add(V(s.X - 1.6, 0.5, s.Z - 1), CF(0, -s.Y / 2 + s.Y * 0.4 + 0.5, 0.3), col:Lerp(Color3.new(1, 1, 1), 0.15), fabric)
	legs(add, s, 0.3, 0.3, 0.3, C.darkWood)
end

B.Sofa = function(add, s, tint)
	local col = tint or Color3.fromRGB(226, 106, 84)
	local seatH = s.Y * 0.42
	add(V(s.X, seatH, s.Z), CF(0, -s.Y / 2 + seatH / 2 + 0.3, 0), col, fabric) -- base
	add(V(s.X, s.Y * 0.62, 1), CF(0, s.Y * 0.12, -s.Z / 2 + 0.5), col, fabric) -- backrest
	for _, sx in { -1, 1 } do
		add(V(0.9, s.Y * 0.62, s.Z), CF(sx * (s.X / 2 - 0.45), -s.Y / 2 + s.Y * 0.31 + 0.3, 0), col:Lerp(Color3.new(0, 0, 0), 0.12), fabric)
	end
	local cushion = col:Lerp(Color3.new(1, 1, 1), 0.18)
	local inner = s.X - 1.9
	for i = 0, 2 do
		local w = inner / 3 - 0.1
		add(V(w, 0.55, s.Z - 1.1), CF(-inner / 2 + w / 2 + i * (inner / 3), -s.Y / 2 + seatH + 0.55, 0.45), cushion, fabric)
	end
	add(V(1.2, 1.2, 0.5), CF(-s.X / 2 + 1.7, s.Y * 0.02, -s.Z / 2 + 1.15) * CFrame.Angles(0, 0, math.rad(12)), C.yellow, fabric)
	legs(add, s, 0.3, 0.4, 0.35, C.darkWood)
end

B.Bed = function(add, s, tint)
	local frameH = s.Y * 0.45
	add(V(s.X, frameH, s.Z), CF(0, -s.Y / 2 + frameH / 2, 0), C.wood, woodM)
	add(V(s.X, s.Y + 1, 0.5), CF(0, 0.5, -s.Z / 2 + 0.25), C.darkWood, woodM) -- headboard
	add(V(s.X - 0.3, s.Y * 0.35, s.Z - 0.7), CF(0, -s.Y / 2 + frameH + s.Y * 0.175, 0.2), C.white, fabric)
	add(V(s.X - 0.2, s.Y * 0.38, s.Z * 0.62), CF(0, -s.Y / 2 + frameH + s.Y * 0.19, s.Z * 0.18), tint or C.blue, fabric)
	for _, sx in { -1, 1 } do
		add(V(s.X * 0.4, 0.6, 1.3), CF(sx * s.X * 0.23, -s.Y / 2 + frameH + s.Y * 0.35 + 0.2, -s.Z / 2 + 1.3), C.white, fabric)
	end
end

B.Fridge = function(add, s, tint)
	local col = tint or Color3.fromRGB(226, 236, 240)
	add(s - V(0.05, 0, 0.05), CF(), col, smooth)
	add(V(s.X - 0.1, 0.08, 0.1), CF(0, s.Y * 0.18, s.Z / 2), C.grey, smooth) -- door split
	add(V(0.2, 1.6, 0.25), CF(s.X / 2 - 0.4, s.Y * 0.35, s.Z / 2 + 0.1), C.metal, metalM)
	add(V(0.2, 1.8, 0.25), CF(s.X / 2 - 0.4, -s.Y * 0.05, s.Z / 2 + 0.1), C.metal, metalM)
	add(V(0.7, 0.7, 0.06), CF(-0.6, s.Y * 0.36, s.Z / 2 + 0.03), C.red, smooth) -- magnet
	add(V(0.5, 0.5, 0.06), CF(-0.2, s.Y * 0.26, s.Z / 2 + 0.03), C.yellow, smooth)
end

B.DiningTable = function(add, s, tint)
	add(V(s.X, 0.5, s.Z), CF(0, s.Y / 2 - 0.25, 0), tint or C.wood, woodM)
	legs(add, s, s.Y - 0.5, 0.5, 0.5, C.darkWood)
	add(V(s.X * 0.5, 0.06, s.Z * 0.5), CF(0, s.Y / 2 + 0.02, 0), C.white, fabric)
end

B.Piano = function(add, s, tint)
	local col = tint or Color3.fromRGB(40, 32, 30)
	add(V(s.X, s.Y * 0.9, s.Z * 0.55), CF(0, s.Y * 0.05, -s.Z * 0.22), col, smooth)
	add(V(s.X, 0.4, s.Z * 0.45), CF(0, -s.Y * 0.05, s.Z * 0.27), col, smooth)
	add(V(s.X - 0.6, 0.12, s.Z * 0.3), CF(0, -s.Y * 0.05 + 0.25, s.Z * 0.3), C.white, smooth)
	for i = 0, 9 do
		add(V(0.18, 0.1, s.Z * 0.15), CF(-s.X / 2 + 0.6 + i * 0.52, -s.Y * 0.05 + 0.33, s.Z * 0.22), C.dark, smooth)
	end
	legs(add, s, s.Y * 0.45, 0.3, 0.4, col)
	add(V(1.2, 1.4, 0.1), CF(0, s.Y * 0.25, s.Z * 0.06), C.gold, smooth) -- music sheet
end

B.Clock = function(add, s, tint)
	local col = tint or C.darkWood
	add(V(s.X, s.Y * 0.75, s.Z), CF(0, -s.Y * 0.125, 0), col, woodM)
	add(V(s.X + 0.2, s.Y * 0.25, s.Z + 0.2), CF(0, s.Y * 0.375, 0), col:Lerp(Color3.new(0, 0, 0), 0.15), woodM)
	add(V(0.1, s.X * 0.75, s.X * 0.75), CF(0, s.Y * 0.375, s.Z / 2 + 0.1) * CFrame.Angles(0, math.rad(90), 0), C.white, smooth, CY)
	add(V(0.1, 0.6, 0.1), CF(0, s.Y * 0.375 + 0.25, s.Z / 2 + 0.17), C.dark, smooth)
	add(V(0.5, 0.5, 0.1), CF(0, -s.Y * 0.1, s.Z / 2 + 0.03), C.gold, metalM, SP)
end

B.Coffin = function(add, s, tint)
	local col = tint or Color3.fromRGB(96, 62, 50)
	add(V(s.X, s.Y * 0.8, s.Z), CF(0, -s.Y * 0.1, 0), col, woodM)
	add(V(s.X + 0.2, s.Y * 0.2, s.Z + 0.2), CF(0, s.Y * 0.4, 0), col:Lerp(Color3.new(0, 0, 0), 0.2), woodM)
	add(V(0.3, 0.1, 2.2), CF(0, s.Y / 2 + 0.03, -0.6), C.gold, metalM)
	add(V(1.4, 0.1, 0.3), CF(0, s.Y / 2 + 0.03, -1.1), C.gold, metalM)
end

B.Bookcase = function(add, s, tint)
	local col = tint or C.wood
	add(V(s.X, s.Y, 0.3), CF(0, 0, -s.Z / 2 + 0.15), col:Lerp(Color3.new(0, 0, 0), 0.15), woodM)
	for _, sx in { -1, 1 } do
		add(V(0.3, s.Y, s.Z), CF(sx * (s.X / 2 - 0.15), 0, 0), col, woodM)
	end
	local books = { C.red, C.blue, C.yellow, C.green, C.purple, C.teal }
	for row = 0, 3 do
		local y = -s.Y / 2 + 0.15 + row * (s.Y / 4)
		add(V(s.X, 0.3, s.Z), CF(0, y, 0), col, woodM)
		local x = -s.X / 2 + 0.5
		local i = row
		while x < s.X / 2 - 0.7 do
			local w = 0.35 + (i % 3) * 0.12
			local h = s.Y / 4 * (0.6 + (i % 4) * 0.08)
			add(V(w, h, s.Z - 0.6), CF(x + w / 2, y + 0.15 + h / 2, 0.1), books[i % #books + 1], smooth)
			x += w + 0.05
			i += 1
		end
	end
	add(V(s.X, 0.3, s.Z), CF(0, s.Y / 2 - 0.15, 0), col, woodM)
end

B.Washer = function(add, s, tint)
	add(s - V(0.05, 0, 0.05), CF(), tint or C.white, smooth)
	add(V(0.1, s.X * 0.62, s.X * 0.62), CF(0, -0.2, s.Z / 2) * CFrame.Angles(0, math.rad(90), 0), C.grey, metalM, CY)
	add(V(0.12, s.X * 0.45, s.X * 0.45), CF(0, -0.2, s.Z / 2 + 0.02) * CFrame.Angles(0, math.rad(90), 0), C.screen, glassM, CY)
	add(V(s.X, 0.5, 0.1), CF(0, s.Y / 2 - 0.35, s.Z / 2), C.grey, smooth)
end

B.Crate = function(add, s, tint)
	local col = tint or C.lightWood
	add(s - V(0.1, 0.1, 0.1), CF(), col, woodM)
	for _, f in { 1, -1 } do
		add(V(s.X + 0.02, 0.35, 0.12), CF(0, s.Y * 0.3, f * s.Z / 2), C.wood, woodM)
		add(V(s.X + 0.02, 0.35, 0.12), CF(0, -s.Y * 0.3, f * s.Z / 2), C.wood, woodM)
		add(V(0.12, 0.35, s.Z * 1.25), CF(f * s.X / 2, 0, 0) * CFrame.Angles(math.rad(45), 0, 0), C.wood, woodM)
	end
end
B.BigCrate = function(add, s, tint)
	B.Crate(add, s, tint or Color3.fromRGB(210, 170, 110))
	add(V(1.4, 0.8, 0.06), CF(0, 0.3, s.Z / 2 + 0.04), C.red, smooth) -- "fragile" label
end

B.Barrel = function(add, s, tint)
	add(V(s.Y, s.X, s.X), CF() * upright, tint or C.blue, metalM, CY)
	for _, y in { -s.Y * 0.3, s.Y * 0.3 } do
		add(V(0.25, s.X + 0.1, s.X + 0.1), CF(0, y, 0) * upright, C.dark, metalM, CY)
	end
end

B.Mirror = function(add, s, tint)
	add(V(s.X, s.Y - 0.6, 0.35), CF(0, 0.3, 0), tint or C.gold, smooth)
	add(V(s.X - 0.5, s.Y - 1.1, 0.06), CF(0, 0.3, 0.18), Color3.fromRGB(200, 226, 240), glassM).Reflectance = 0.3
	add(V(s.X * 0.8, 0.6, s.Z), CF(0, -s.Y / 2 + 0.3, 0), tint or C.gold, smooth)
end

B.Toolbox = function(add, s, tint)
	add(s - V(0, 0.4, 0), CF(0, -0.2, 0), tint or C.red, metalM)
	add(V(s.X * 0.5, 0.35, 0.25), CF(0, s.Y / 2 - 0.2, 0), C.dark, smooth)
	add(V(0.3, 0.2, 0.05), CF(0, 0, s.Z / 2), C.metal, metalM)
end

B.Dresser = function(add, s, tint)
	local col = tint or C.lightWood
	add(s - V(0, 0.3, 0), CF(0, 0.15, 0), col, woodM)
	for row = 0, 2 do
		local y = -s.Y / 2 + 0.5 + 0.2 + row * ((s.Y - 0.6) / 3)
		add(V(s.X - 0.4, (s.Y - 0.6) / 3 - 0.2, 0.08), CF(0, y + 0.35, s.Z / 2), col:Lerp(Color3.new(1, 1, 1), 0.15), woodM)
		add(V(0.6, 0.15, 0.12), CF(0, y + 0.35, s.Z / 2 + 0.08), C.gold, metalM)
	end
	legs(add, s, 0.3, 0.3, 0.3, C.darkWood)
end

B.DeckChair = function(add, s, tint)
	local col = tint or C.white
	add(V(s.X, 0.3, s.Z * 0.65), CF(0, -s.Y / 2 + 0.9, s.Z * 0.17), col, smooth)
	add(V(s.X, 0.3, s.Z * 0.4), CF(0, -s.Y / 2 + 1.4, -s.Z * 0.3) * CFrame.Angles(math.rad(-35), 0, 0), col, smooth)
	add(V(s.X - 0.3, 0.12, s.Z * 0.9), CF(0, -s.Y / 2 + 1.12, 0), C.teal, fabric)
	legs(add, s, 0.8, 0.3, 0.25, C.grey)
end

B.Sunbed = function(add, s, tint)
	B.DeckChair(add, s, tint or C.lightWood)
	add(V(s.X - 0.6, 0.5, 1.2), CF(0, -s.Y / 2 + 1.9, -s.Z * 0.38) * CFrame.Angles(math.rad(-35), 0, 0), C.yellow, fabric)
end

B.Grill = function(add, s, tint)
	add(V(s.X, 1.4, s.Z), CF(0, s.Y / 2 - 1.1, 0), tint or C.red, metalM)
	add(V(s.X, 0.7, s.Z), CF(0, s.Y / 2 - 0.2, -0.1) * CFrame.Angles(math.rad(-20), 0, 0), C.dark, metalM)
	legs(add, s, s.Y - 1.8, 0.3, 0.2, C.dark)
	add(V(0.2, 0.2, s.Z * 1.1), CF(s.X / 2 + 0.1, s.Y / 2 - 1, 0), C.metal, metalM)
end

B.Cooler = function(add, s, tint)
	add(s - V(0, 0.4, 0), CF(0, -0.2, 0), tint or C.blue, smooth)
	add(V(s.X + 0.1, 0.4, s.Z + 0.1), CF(0, s.Y / 2 - 0.2, 0), C.white, smooth)
	add(V(s.X * 0.4, 0.2, 0.3), CF(0, s.Y / 2 + 0.05, 0), C.white, smooth)
end

local MassScale = FurnitureData.MassScale

-- Builds a furniture model. The returned model's PrimaryPart "Body" is the only collider.
function FurnitureModels.Build(kind: string, tint: Color3?): Model
	local data = FurnitureData.Get(kind)
	local s = data.Size
	local model = Instance.new("Model")
	model.Name = kind

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = s
	body.Transparency = 1
	body.CanCollide = true
	body.CanTouch = true
	body.CanQuery = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	local volume = s.X * s.Y * s.Z
	local density = math.clamp(data.Mass * MassScale / volume, 0.02, 99)
	body.CustomPhysicalProperties = PhysicalProperties.new(density, data.Friction or 0.45, data.Elasticity or 0.12, 1, 1)
	body.Parent = model
	model.PrimaryPart = body

	local function add(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
		local p = Instance.new("Part")
		p.Name = "Look"
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = body.CFrame * cf
		p.Color = color
		p.Material = material or smooth
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = p
		w.Parent = p
		p.Parent = model
		return p
	end

	local builder = B[kind]
	if builder then
		builder(add, s, tint)
	else
		add(s, CF(), tint or C.wood, smooth)
	end
	return model
end

function FurnitureModels.Has(kind: string): boolean
	return B[kind] ~= nil
end

return FurnitureModels
