--[[
	FurnitureModels.luau
	Builds the look of every furniture kind out of primitive parts: chunky, bevelled,
	soft-cushioned cartoon furniture with contrasting trims, clean smooth colours (no
	textured materials) and silhouettes that read from the steep overhead camera.

	Each builder gets add(size, cframe, colour, material?, shape?) where cframe is relative
	to the item's collider centre (the collider is FurnitureData Size, bottom at -Size.Y/2).
	Visual parts are welded to the collider, massless, never collide and never block queries.

	Shape helpers:
	  bevel     a box with a chamfered, lighter top (5-6 parts)
	  softX/Z   a cushion slab whose ends are rounded by cylinders (3 parts)
	  roundTop  a box whose top is a half-cylinder (2 parts): sofa arms and backs
	  arrow     a printed "this way up" arrow on a face (3 parts)
]]

local FurnitureData = require(game:GetService("ReplicatedStorage").Shared.FurnitureData)
local Shapes = require(game:GetService("ReplicatedStorage").Shared.Shapes)

local FurnitureModels = {}

type Add = (size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?) -> BasePart

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local C = {
	wood = rgb(214, 152, 94),
	darkWood = rgb(136, 88, 58),
	lightWood = rgb(238, 198, 138),
	cardboard = rgb(224, 172, 112),
	cardboardDark = rgb(190, 136, 82),
	tape = rgb(204, 148, 88),
	print = rgb(46, 40, 44),
	white = rgb(246, 244, 238),
	cream = rgb(252, 238, 208),
	grey = rgb(160, 166, 178),
	dark = rgb(56, 58, 70),
	screen = rgb(46, 66, 96),
	glare = rgb(150, 196, 236),
	red = rgb(232, 86, 76),
	teal = rgb(62, 176, 172),
	blue = rgb(80, 138, 232),
	navy = rgb(52, 76, 150),
	yellow = rgb(248, 198, 80),
	orange = rgb(244, 140, 70),
	green = rgb(96, 184, 92),
	leaf = rgb(70, 160, 86),
	mint = rgb(150, 220, 178),
	pink = rgb(244, 132, 170),
	purple = rgb(136, 104, 190),
	gold = rgb(236, 190, 76),
	pot = rgb(214, 112, 76),
	metal = rgb(190, 196, 206),
	glow = rgb(255, 240, 190),
}
FurnitureModels.Colors = C

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad
local SP = Enum.PartType.Ball
local CY = Enum.PartType.Cylinder
local WG = Enum.PartType.Wedge
local smooth = Enum.Material.SmoothPlastic
local metalM = Enum.Material.Metal
local glassM = Enum.Material.Glass
local neon = Enum.Material.Neon
local upright = CFrame.Angles(0, 0, rad(90)) -- cylinder axis X -> Y
local alongZ = CFrame.Angles(0, rad(90), 0) -- cylinder axis X -> Z
local faceX = CFrame.Angles(0, rad(90), 0) -- local +Z (face normal) -> +X
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function light(c: Color3, t: number?): Color3
	return c:Lerp(WHITE, t or 0.18)
end
local function shade(c: Color3, t: number?): Color3
	return c:Lerp(BLACK, t or 0.15)
end

-- A box with a lighter top and chamfered top edges, so it reads as bevelled from above.
local function bevel(add: Add, size: Vector3, cf: CFrame, color: Color3, top: Color3?, b: number?)
	local e = b or 0.14
	local topC = top or light(color, 0.14)
	add(V(size.X, size.Y - e, size.Z), cf * CF(0, -e / 2, 0), color)
	local y = size.Y / 2 - e / 2
	add(V(size.X - 2 * e, e, size.Z - 2 * e), cf * CF(0, y, 0), topC)
	add(V(size.X - 2 * e, e, e), cf * CF(0, y, -size.Z / 2 + e / 2), color, smooth, WG)
	add(V(size.X - 2 * e, e, e), cf * CF(0, y, size.Z / 2 - e / 2) * CFrame.Angles(0, math.pi, 0), color, smooth, WG)
	add(V(size.Z - 2 * e, e, e), cf * CF(-size.X / 2 + e / 2, y, 0) * CFrame.Angles(0, rad(90), 0), color, smooth, WG)
	add(V(size.Z - 2 * e, e, e), cf * CF(size.X / 2 - e / 2, y, 0) * CFrame.Angles(0, rad(-90), 0), color, smooth, WG)
end

-- A cushion slab with its front and back (±Z) edges rounded.
local function softX(add: Add, size: Vector3, cf: CFrame, color: Color3)
	if size.Z <= size.Y then
		add(size, cf, color)
		return
	end
	add(V(size.X, size.Y, size.Z - size.Y), cf, color)
	for _, sz in { -1, 1 } do
		add(V(size.X, size.Y, size.Y), cf * CF(0, 0, sz * (size.Z - size.Y) / 2), color, smooth, CY)
	end
end

-- A cushion slab with its left and right (±X) edges rounded.
local function softZ(add: Add, size: Vector3, cf: CFrame, color: Color3)
	if size.X <= size.Y then
		add(size, cf, color)
		return
	end
	add(V(size.X - size.Y, size.Y, size.Z), cf, color)
	for _, sx in { -1, 1 } do
		add(V(size.Z, size.Y, size.Y), cf * CF(sx * (size.X - size.Y) / 2, 0, 0) * alongZ, color, smooth, CY)
	end
end

-- A box whose top is a half-cylinder running along its longer horizontal side.
local function roundTop(add: Add, size: Vector3, cf: CFrame, color: Color3)
	if size.X <= size.Z then
		local r = size.X / 2
		add(V(size.X, size.Y - r, size.Z), cf * CF(0, -r / 2, 0), color)
		add(V(size.Z, size.X, size.X), cf * CF(0, size.Y / 2 - r, 0) * alongZ, color, smooth, CY)
	else
		local r = size.Z / 2
		add(V(size.X, size.Y - r, size.Z), cf * CF(0, -r / 2, 0), color)
		add(V(size.X, size.Z, size.Z), cf * CF(0, size.Y / 2 - r, 0), color, smooth, CY)
	end
end

-- A printed upward arrow centred on a face. cf: face point, local +Z out of the face.
local function arrow(add: Add, cf: CFrame, k: number, color: Color3)
	add(V(0.16 * k, 0.32 * k, 0.03), cf * CF(0, -0.14 * k, 0), color)
	local hw, hh = 0.42 * k, 0.26 * k
	local right = CFrame.fromMatrix(Vector3.zero, V(0, 0, 1), V(0, 1, 0))
	local left = CFrame.fromMatrix(Vector3.zero, V(0, 0, -1), V(0, 1, 0))
	add(V(0.03, hh, hw / 2), cf * CF(hw / 4, 0.15 * k, 0) * right, color, smooth, WG)
	add(V(0.03, hh, hw / 2), cf * CF(-hw / 4, 0.15 * k, 0) * left, color, smooth, WG)
end

local function legs(add: Add, s: Vector3, h: number, inset: number, thick: number, color: Color3, round: boolean?)
	local y = -s.Y / 2 + h / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			if round then
				add(V(h, thick, thick), CF(sx * (s.X / 2 - inset), y, sz * (s.Z / 2 - inset)) * upright, color, smooth, CY)
			else
				add(V(thick, h, thick), CF(sx * (s.X / 2 - inset), y, sz * (s.Z / 2 - inset)), color)
			end
		end
	end
end

local B: { [string]: (add: Add, s: Vector3, tint: Color3?) -> () } = {}

----------------------------------------------------------------------------------------
-- boxes

-- Tan cardboard box: bevelled body, darker tape cross over the top running down two
-- sides, and a black "this way up" arrow printed on two faces.
B.Box = function(add, s, tint)
	local body = tint or C.cardboard
	local tape = shade(body, 0.14)
	bevel(add, s, CF(), body, light(body, 0.06), 0.1)
	local tw = math.min(s.X, s.Z) * 0.26
	add(V(tw, 0.04, s.Z + 0.02), CF(0, s.Y / 2 + 0.01, 0), tape)
	add(V(s.X + 0.02, 0.04, tw * 0.55), CF(0, s.Y / 2 + 0.015, 0), tape)
	for _, sz in { -1, 1 } do
		add(V(tw, s.Y * 0.36, 0.04), CF(0, s.Y * 0.32, sz * (s.Z / 2 + 0.01)), tape)
	end
	local k = math.min(s.Y, s.X, s.Z) * 0.5
	arrow(add, CF(s.X * 0.27, -s.Y * 0.08, s.Z / 2 + 0.02), k, C.print)
	arrow(add, CF(s.X / 2 + 0.02, -s.Y * 0.08, -s.Z * 0.25) * faceX, k, C.print)
end
B.BoxTall = B.Box
B.BoxSmall = function(add, s, tint)
	B.Box(add, s, tint or rgb(214, 160, 100))
end
B.BoxFlat = function(add, s, tint)
	B.Box(add, s, tint or rgb(232, 186, 128))
end
B.Parcel = function(add, s, tint)
	B.Box(add, s, tint or rgb(206, 156, 104))
	add(V(s.X * 0.3, 0.05, s.Z * 0.28), CF(-s.X * 0.24, s.Y / 2 + 0.03, s.Z * 0.22), C.white) -- address label
	add(V(s.X * 0.2, 0.06, 0.06), CF(-s.X * 0.24, s.Y / 2 + 0.05, s.Z * 0.2), C.print)
	add(V(s.X * 0.32, s.Y * 0.2, 0.04), CF(-s.X * 0.18, s.Y * 0.1, -s.Z / 2 - 0.02), C.red) -- fragile sticker
end

----------------------------------------------------------------------------------------
-- light items

B.Lamp = function(add, s, tint)
	local col = tint or C.yellow
	add(V(0.3, s.X * 0.85, s.X * 0.85), CF(0, -s.Y / 2 + 0.15, 0) * upright, C.dark, smooth, CY)
	add(V(0.08, s.X * 0.6, s.X * 0.6), CF(0, -s.Y / 2 + 0.33, 0) * upright, C.grey, smooth, CY)
	add(V(s.Y * 0.62, 0.22, 0.22), CF(0, -s.Y / 2 + s.Y * 0.33, 0) * upright, C.metal, metalM, CY)
	add(V(0.8, s.X, s.X), CF(0, s.Y / 2 - 1.1, 0) * upright, col, smooth, CY)
	add(V(0.8, s.X * 0.82, s.X * 0.82), CF(0, s.Y / 2 - 0.4, 0) * upright, col, smooth, CY)
	add(V(0.06, s.X * 0.6, s.X * 0.6), CF(0, s.Y / 2 - 0.02, 0) * upright, light(col, 0.5), smooth, CY)
	add(V(0.07, s.X * 0.86, s.X * 0.86), CF(0, s.Y / 2 - 0.82, 0) * upright, light(col, 0.35), smooth, CY)
	add(V(0.5, 0.5, 0.5), CF(0, s.Y / 2 - 1.45, 0), C.glow, neon, SP)
end

B.Stool = function(add, s, tint)
	local col = tint or C.red
	add(V(0.3, s.X, s.X), CF(0, s.Y / 2 - 0.25, 0) * upright, shade(col, 0.1), smooth, CY)
	add(V(0.2, s.X * 0.86, s.X * 0.86), CF(0, s.Y / 2 - 0.1, 0) * upright, light(col, 0.12), smooth, CY)
	for _, a in { 45, 135, 225, 315 } do
		local d = s.X * 0.3
		local x, z = math.cos(rad(a)) * d, math.sin(rad(a)) * d
		add(V(0.24, s.Y - 0.4, 0.24), CF(x, -0.2, z) * CFrame.Angles(math.sin(rad(a)) * rad(-6), 0, math.cos(rad(a)) * rad(6)), C.darkWood)
	end
	add(V(s.X * 0.6, 0.12, 0.12), CF(0, -s.Y * 0.18, 0), C.darkWood)
	add(V(0.12, 0.12, s.X * 0.6), CF(0, -s.Y * 0.18, 0), C.darkWood)
end

B.SideTable = function(add, s, tint)
	local col = tint or C.wood
	bevel(add, V(s.X, 0.32, s.Z), CF(0, s.Y / 2 - 0.16, 0), col, light(col, 0.2), 0.1)
	add(V(s.X - 0.4, 0.8, s.Z - 0.4), CF(0, s.Y / 2 - 0.72, 0), shade(col, 0.08))
	add(V(s.X - 0.7, 0.55, 0.06), CF(0, s.Y / 2 - 0.72, s.Z / 2 - 0.18), light(col, 0.25))
	add(V(0.26, 0.26, 0.26), CF(0, s.Y / 2 - 0.72, s.Z / 2 - 0.12), C.gold, smooth, SP)
	legs(add, s, s.Y - 0.32, 0.28, 0.26, C.darkWood)
	add(V(s.X - 0.5, 0.14, s.Z - 0.5), CF(0, -s.Y / 2 + 0.55, 0), shade(col, 0.1))
end

local function leaves(add: Add, y: number, count: number, len: number, col: Color3, lift: number)
	for i = 1, count do
		local a = (i / count) * 360 + 20
		local cf = CF(0, y, 0) * CFrame.Angles(0, rad(a), 0) * CF(0, 0, -len * 0.38) * CFrame.Angles(rad(lift), 0, 0)
		add(V(len * 0.42, 0.18, len), cf, i % 2 == 0 and col or light(col, 0.15), smooth, SP)
	end
end

B.Plant = function(add, s, tint)
	local col = tint or C.leaf
	local potH = 1.3
	add(V(potH, s.X * 0.72, s.X * 0.72), CF(0, -s.Y / 2 + potH / 2, 0) * upright, C.pot, smooth, CY)
	add(V(0.3, s.X * 0.82, s.X * 0.82), CF(0, -s.Y / 2 + potH - 0.1, 0) * upright, light(C.pot, 0.12), smooth, CY)
	add(V(0.06, s.X * 0.66, s.X * 0.66), CF(0, -s.Y / 2 + potH + 0.03, 0) * upright, C.darkWood, smooth, CY)
	add(V(1.2, 0.2, 0.2), CF(0, -s.Y / 2 + potH + 0.5, 0) * upright, shade(col, 0.2), smooth, CY)
	leaves(add, -s.Y / 2 + potH + 0.75, 5, 2, col, 35)
	leaves(add, -s.Y / 2 + potH + 1.25, 3, 1.5, light(col, 0.08), 60)
	add(V(0.7, 0.9, 0.7), CF(0, s.Y / 2 - 0.6, 0), light(col, 0.2), smooth, SP)
end

-- Small potted cactus with a pink flower.
B.PlantSmall = function(add, s, tint)
	local col = tint or C.green
	local potH = 0.9
	add(V(potH, s.X * 0.8, s.X * 0.8), CF(0, -s.Y / 2 + potH / 2, 0) * upright, rgb(110, 170, 220), smooth, CY)
	add(V(0.22, s.X * 0.92, s.X * 0.92), CF(0, -s.Y / 2 + potH - 0.05, 0) * upright, light(rgb(110, 170, 220), 0.3), smooth, CY)
	add(V(0.05, s.X * 0.7, s.X * 0.7), CF(0, -s.Y / 2 + potH + 0.07, 0) * upright, rgb(226, 196, 140), smooth, CY)
	local bodyH = s.Y - potH - 0.2
	add(V(0.75, bodyH, 0.75), CF(0, -s.Y / 2 + potH + bodyH / 2, 0), col, smooth, SP)
	for _, sx in { -1, 1 } do
		add(V(0.36, 0.7, 0.36), CF(sx * 0.42, -s.Y / 2 + potH + bodyH * 0.6, 0) * CFrame.Angles(0, 0, sx * rad(-20)), light(col, 0.08), smooth, SP)
	end
	add(V(0.32, 0.22, 0.32), CF(0, s.Y / 2 - 0.2, 0), C.pink, smooth, SP)
end

-- Beach ball: four overlapping spheres nudged into quadrants make alternating panels.
B.BeachBall = function(add, s, tint)
	local d = 0.07
	local r = math.min(s.X, s.Y, s.Z) - 2 * d * 1.42
	local panels = { tint or C.red, C.white, C.blue, C.white }
	for i, c in panels do
		local a = rad(45 + i * 90)
		add(V(r, r, r), CF(math.cos(a) * d * 1.42, 0, math.sin(a) * d * 1.42), c, smooth, SP)
	end
	add(V(0.06, r * 0.26, r * 0.26), CF(0, r / 2 + 0.02, 0) * upright, C.yellow, smooth, CY)
	add(V(0.06, r * 0.26, r * 0.26), CF(0, -r / 2 - 0.02, 0) * upright, C.yellow, smooth, CY)
end

-- Pool flamingo float.
B.Flamingo = function(add, s, tint)
	local pink = tint or C.pink
	add(V(s.X * 0.86, 1.1, s.Z), CF(-s.X * 0.06, -s.Y / 2 + 0.55, 0), pink, smooth, SP)
	add(V(s.X * 0.5, 0.4, s.Z * 0.6), CF(-s.X * 0.12, -s.Y / 2 + 1.05, 0), light(pink, 0.25), smooth, SP)
	add(V(s.X * 0.25, 0.8, s.Z * 0.5), CF(-s.X * 0.42, -s.Y / 2 + 1.0, 0) * CFrame.Angles(0, 0, rad(30)), shade(pink, 0.06), smooth, SP)
	add(V(0.55, 2.0, 0.55), CF(s.X * 0.24, -s.Y / 2 + 1.9, 0) * CFrame.Angles(0, 0, rad(-14)), pink, smooth, SP)
	add(V(0.9, 0.85, 0.8), CF(s.X * 0.33, s.Y / 2 - 0.45, 0), pink, smooth, SP)
	add(V(0.5, 0.26, 0.3), CF(s.X * 0.33 + 0.55, s.Y / 2 - 0.55, 0) * CFrame.Angles(0, 0, rad(-25)), C.white, smooth, SP)
	add(V(0.22, 0.2, 0.24), CF(s.X / 2 - 0.12, s.Y / 2 - 0.72, 0), C.print, smooth, SP)
	for _, sz in { -1, 1 } do
		add(V(0.14, 0.14, 0.06), CF(s.X * 0.38, s.Y / 2 - 0.35, sz * 0.38), C.print, smooth, SP)
	end
end

B.Microwave = function(add, s, tint)
	local col = tint or C.white
	bevel(add, s, CF(), col, nil, 0.14)
	add(V(s.X * 0.6, s.Y * 0.62, 0.06), CF(-s.X * 0.12, -0.05, s.Z / 2 + 0.01), C.dark)
	add(V(s.X * 0.48, s.Y * 0.44, 0.06), CF(-s.X * 0.12, -0.05, s.Z / 2 + 0.03), C.screen, glassM)
	add(V(s.X * 0.18, s.Y * 0.1, 0.06), CF(-s.X * 0.22, s.Y * 0.08, s.Z / 2 + 0.05), C.glare)
	add(V(s.X * 0.22, s.Y * 0.62, 0.06), CF(s.X * 0.33, -0.05, s.Z / 2 + 0.01), C.grey)
	add(V(0.07, 0.24, 0.24), CF(s.X * 0.33, s.Y * 0.12, s.Z / 2 + 0.06) * alongZ * upright, C.dark, smooth, CY)
	add(V(s.X * 0.12, s.Y * 0.08, 0.06), CF(s.X * 0.33, -s.Y * 0.18, s.Z / 2 + 0.05), C.teal, neon)
end

-- Two-slot toaster.
B.Toaster = function(add, s, tint)
	local col = tint or rgb(120, 200, 208)
	bevel(add, V(s.X, s.Y - 0.12, s.Z), CF(0, 0.06, 0), col, light(col, 0.22), 0.18)
	add(V(s.X + 0.06, 0.12, s.Z + 0.06), CF(0, -s.Y / 2 + 0.06, 0), C.dark)
	for _, sx in { -1, 1 } do
		add(V(s.X * 0.32, 0.03, s.Z * 0.22), CF(sx * s.X * 0.2, s.Y / 2 + 0.005, 0), C.dark)
		add(V(s.X * 0.26, 0.08, s.Z * 0.12), CF(sx * s.X * 0.2, s.Y / 2 + 0.03, 0), rgb(232, 182, 110)) -- toast
	end
	add(V(0.18, 0.3, 0.12), CF(s.X / 2 + 0.06, s.Y * 0.15, 0), C.dark)
	add(V(s.X * 0.6, 0.06, 0.04), CF(0, -s.Y * 0.05, s.Z / 2 + 0.02), C.white)
end

B.Vase = function(add, s, tint)
	local col = tint or C.teal
	add(V(s.X, s.Y * 0.68, s.Z), CF(0, -s.Y * 0.15, 0), col, smooth, SP)
	add(V(s.X * 1.02, s.Y * 0.1, s.Z * 1.02), CF(0, -s.Y * 0.15, 0), light(col, 0.45), smooth, SP)
	add(V(s.Y * 0.34, s.X * 0.42, s.X * 0.42), CF(0, s.Y * 0.2, 0) * upright, col, smooth, CY)
	add(V(0.14, s.X * 0.6, s.X * 0.6), CF(0, s.Y * 0.36, 0) * upright, light(col, 0.2), smooth, CY)
	for i, c in { C.red, C.yellow, C.pink } do
		local a = rad(i * 120)
		add(V(0.42, 0.34, 0.42), CF(math.cos(a) * 0.24, s.Y / 2 - 0.12, math.sin(a) * 0.24), c, smooth, SP)
	end
end

B.Candelabra = function(add, s, tint)
	local gold = tint or C.gold
	add(V(0.3, 1.2, 1.2), CF(0, -s.Y / 2 + 0.15, 0) * upright, gold, metalM, CY)
	add(V(s.Y * 0.6, 0.25, 0.25), CF(0, -s.Y * 0.1, 0) * upright, gold, metalM, CY)
	add(V(s.X, 0.22, 0.22), CF(0, s.Y * 0.18, 0), gold, metalM, CY)
	for _, x in { -s.X / 2 + 0.15, 0, s.X / 2 - 0.15 } do
		add(V(0.12, 0.42, 0.42), CF(x, s.Y * 0.18 + 0.18, 0) * upright, shade(gold, 0.1), metalM, CY)
		add(V(0.25, 0.7, 0.25), CF(x, s.Y * 0.18 + 0.55, 0), C.cream)
		add(V(0.2, 0.32, 0.2), CF(x, s.Y * 0.18 + 1.05, 0), rgb(255, 196, 90), neon, SP)
	end
end

-- Acoustic guitar lying on its back.
B.Guitar = function(add, s, tint)
	local col = tint or rgb(232, 150, 70)
	local bodyY = -s.Y / 2 + 0.25
	add(V(s.X, 0.5, s.X * 1.05), CF(0, bodyY, s.Z / 2 - s.X * 0.52), col, smooth, SP)
	add(V(s.X * 0.8, 0.5, s.X * 0.8), CF(0, bodyY, s.Z / 2 - s.X * 1.25), col, smooth, SP)
	add(V(s.X * 0.62, 0.52, s.X * 0.62), CF(0, bodyY, s.Z / 2 - s.X * 0.52), light(col, 0.25), smooth, SP)
	add(V(0.06, s.X * 0.32, s.X * 0.32), CF(0, bodyY + 0.26, s.Z / 2 - s.X * 0.95) * upright, C.print, smooth, CY)
	add(V(0.34, 0.16, s.Z * 0.5), CF(0, bodyY + 0.12, -s.Z * 0.17), C.darkWood)
	add(V(0.5, 0.18, 0.55), CF(0, bodyY + 0.12, -s.Z / 2 + 0.28), shade(C.darkWood, 0.2))
	add(V(0.4, 0.05, 0.14), CF(0, bodyY + 0.27, s.Z / 2 - s.X * 0.32), C.darkWood)
	add(V(0.12, 0.03, s.Z * 0.62), CF(0, bodyY + 0.21, -s.Z * 0.02), C.cream)
end

-- Kitchen pedal bin.
B.Bin = function(add, s, tint)
	local col = tint or rgb(96, 186, 120)
	add(V(s.Y - 0.3, s.X * 0.9, s.X * 0.9), CF(0, -0.15, 0) * upright, col, smooth, CY)
	add(V(0.3, s.X, s.X), CF(0, s.Y / 2 - 0.15, 0) * upright, light(col, 0.15), smooth, CY)
	add(V(0.06, s.X * 0.7, s.X * 0.7), CF(0, s.Y / 2 + 0.01, 0) * upright, light(col, 0.3), smooth, CY)
	add(V(s.X * 0.4, 0.12, 0.16), CF(0, s.Y / 2 + 0.06, 0), C.dark)
	add(V(0.2, s.X * 0.92, s.X * 0.92), CF(0, -s.Y / 2 + 0.1, 0) * upright, C.dark, smooth, CY)
	add(V(0.4, 0.12, 0.3), CF(0, -s.Y / 2 + 0.12, s.X / 2), C.metal, metalM)
end

-- Rolled-up striped rug.
B.RugRoll = function(add, s, tint)
	local col = tint or rgb(228, 92, 96)
	add(V(s.X, s.Y, s.Z), CF(), col, smooth, CY)
	for _, x in { -s.X * 0.3, 0, s.X * 0.3 } do
		add(V(0.3, s.Y * 1.02, s.Z * 1.02), CF(x, 0, 0), C.cream, smooth, CY)
	end
	for _, sx in { -1, 1 } do
		add(V(0.04, s.Y * 0.7, s.Z * 0.7), CF(sx * s.X / 2, 0, 0), shade(col, 0.25), smooth, CY)
		add(V(0.05, s.Y * 0.3, s.Z * 0.3), CF(sx * s.X / 2, 0, 0), C.cream, smooth, CY)
	end
end

-- Standing electric fan.
B.Fan = function(add, s, tint)
	local col = tint or rgb(120, 190, 230)
	add(V(0.25, s.X * 0.9, s.X * 0.9), CF(0, -s.Y / 2 + 0.13, 0) * upright, col, smooth, CY)
	add(V(s.Y * 0.55, 0.2, 0.2), CF(0, -s.Y / 2 + s.Y * 0.3, 0) * upright, C.metal, metalM, CY)
	local headY = s.Y / 2 - s.X / 2
	add(V(0.5, 0.5, 0.7), CF(0, headY, -s.Z / 2 + 0.35), col, smooth, SP)
	add(V(0.3, s.X, s.X), CF(0, headY, s.Z / 2 - 0.2) * CFrame.Angles(0, rad(90), 0), C.white, smooth, CY)
	add(V(0.32, s.X * 0.82, s.X * 0.82), CF(0, headY, s.Z / 2 - 0.2) * CFrame.Angles(0, rad(90), 0), light(col, 0.4), smooth, CY)
	for i = 0, 2 do
		add(V(s.X * 0.36, 0.3, 0.06), CF(0, headY, s.Z / 2 - 0.12) * CFrame.Angles(0, 0, rad(i * 120)) * CF(s.X * 0.18, 0, 0), col)
	end
	add(V(0.12, 0.3, 0.3), CF(0, headY, s.Z / 2 - 0.05) * CFrame.Angles(0, rad(90), 0), C.dark, smooth, CY)
end

-- Suitcase lying flat, with straps and a handle.
B.Suitcase = function(add, s, tint)
	local col = tint or rgb(170, 104, 70)
	bevel(add, s, CF(), col, light(col, 0.1), 0.16)
	add(V(s.X + 0.04, s.Y * 0.18, s.Z + 0.04), CF(0, 0, 0), shade(col, 0.25))
	for _, sx in { -1, 1 } do
		add(V(0.28, 0.04, s.Z + 0.06), CF(sx * s.X * 0.27, s.Y / 2 + 0.01, 0), rgb(236, 210, 150))
		add(V(0.28, s.Y + 0.06, 0.04), CF(sx * s.X * 0.27, 0, s.Z / 2 + 0.02), rgb(236, 210, 150))
	end
	add(V(0.8, 0.16, 0.26), CF(0, 0.05, s.Z / 2 + 0.13), C.dark)
	for _, sx in { -1, 1 } do
		add(V(0.24, 0.24, 0.24), CF(sx * (s.X / 2 - 0.06), s.Y * 0.3, s.Z / 2 - 0.06), C.gold, smooth, SP)
	end
end

----------------------------------------------------------------------------------------
-- medium

B.Chair = function(add, s, tint)
	local col = tint or C.wood
	local seatY = -s.Y / 2 + s.Y * 0.45
	bevel(add, V(s.X, 0.32, s.Z), CF(0, seatY, 0), col, nil, 0.1)
	softX(add, V(s.X - 0.5, 0.3, s.Z - 0.6), CF(0, seatY + 0.28, 0.1), C.red)
	local backH = s.Y / 2 - seatY
	for _, sx in { -1, 1 } do
		add(V(0.28, backH, 0.28), CF(sx * (s.X / 2 - 0.2), seatY + backH / 2, -s.Z / 2 + 0.2), shade(col, 0.1))
	end
	roundTop(add, V(s.X, 0.6, 0.3), CF(0, s.Y / 2 - 0.3, -s.Z / 2 + 0.2), col)
	add(V(s.X - 0.7, 0.18, 0.2), CF(0, seatY + backH * 0.45, -s.Z / 2 + 0.2), col)
	legs(add, s, s.Y * 0.45 - 0.16, 0.2, 0.28, C.darkWood)
end

B.TV = function(add, s, tint)
	local col = tint or C.dark
	local bodyH = s.Y - 0.45
	bevel(add, V(s.X, bodyH, s.Z * 0.62), CF(0, s.Y / 2 - bodyH / 2, -s.Z * 0.12), col, light(col, 0.15), 0.16)
	add(V(s.X - 0.45, bodyH - 0.45, 0.06), CF(0, s.Y / 2 - bodyH / 2, s.Z * 0.19 + 0.01), C.screen, glassM)
	add(V(s.X * 0.32, 0.18, 0.06), CF(-s.X * 0.18, s.Y / 2 - bodyH * 0.3, s.Z * 0.19 + 0.03) * CFrame.Angles(0, 0, rad(18)), C.glare)
	add(V(s.X * 0.14, 0.12, 0.06), CF(-s.X * 0.3, s.Y / 2 - bodyH * 0.38, s.Z * 0.19 + 0.03) * CFrame.Angles(0, 0, rad(18)), C.glare)
	add(V(0.16, 0.16, 0.06), CF(s.X / 2 - 0.4, -s.Y / 2 + 0.6, s.Z * 0.19 + 0.02), C.red, neon)
	add(V(0.4, 0.4, 0.3), CF(0, -s.Y / 2 + 0.3, -s.Z * 0.12), shade(col, 0.1))
	softZ(add, V(s.X * 0.5, 0.22, s.Z), CF(0, -s.Y / 2 + 0.11, 0), shade(col, 0.1))
end

B.CoffeeTable = function(add, s, tint)
	local col = tint or C.lightWood
	bevel(add, V(s.X, 0.42, s.Z), CF(0, s.Y / 2 - 0.21, 0), col, light(col, 0.15), 0.14)
	add(V(s.X - 0.5, 0.3, s.Z - 0.5), CF(0, s.Y / 2 - 0.55, 0), shade(col, 0.15))
	add(V(s.X - 0.8, 0.15, s.Z - 0.8), CF(0, -s.Y / 2 + 0.5, 0), shade(col, 0.1))
	legs(add, s, s.Y - 0.42, 0.35, 0.36, C.darkWood, true)
	add(V(1.2, 0.16, 0.9), CF(-s.X * 0.22, s.Y / 2 + 0.08, 0.2) * CFrame.Angles(0, rad(12), 0), C.blue)
	add(V(1.0, 0.1, 0.75), CF(-s.X * 0.22, s.Y / 2 + 0.2, 0.2) * CFrame.Angles(0, rad(-6), 0), C.yellow)
	add(V(0.4, 0.42, 0.42), CF(s.X * 0.25, s.Y / 2 + 0.2, -0.3) * upright, C.white, smooth, CY)
	add(V(0.42, 0.3, 0.3), CF(s.X * 0.25, s.Y / 2 + 0.22, -0.3) * upright, C.darkWood, smooth, CY)
end

B.Armchair = function(add, s, tint)
	local col = tint or C.teal
	local baseH = s.Y * 0.32
	add(V(s.X, baseH, s.Z - 0.2), CF(0, -s.Y / 2 + 0.25 + baseH / 2, 0.1), shade(col, 0.08))
	roundTop(add, V(s.X, s.Y - 0.25, 0.9), CF(0, 0.125, -s.Z / 2 + 0.45), col)
	for _, sx in { -1, 1 } do
		roundTop(add, V(0.8, s.Y * 0.62, s.Z - 0.2), CF(sx * (s.X / 2 - 0.4), -s.Y / 2 + 0.25 + s.Y * 0.31, 0.1), col)
	end
	softX(add, V(s.X - 1.6, 0.55, s.Z - 1.1), CF(0, -s.Y / 2 + 0.25 + baseH + 0.27, 0.35), light(col, 0.16))
	softX(add, V(s.X - 1.7, 1.2, 0.5), CF(0, s.Y * 0.08, -s.Z / 2 + 1.05) * CFrame.Angles(rad(-90), 0, 0), light(col, 0.1))
	legs(add, s, 0.25, 0.35, 0.3, C.darkWood, true)
end

B.Sofa = function(add, s, tint)
	local col = tint or C.yellow
	local legH = 0.3
	local baseH = s.Y * 0.32
	local armW = 1
	add(V(s.X - 0.2, baseH, s.Z - 0.2), CF(0, -s.Y / 2 + legH + baseH / 2, 0.1), shade(col, 0.1))
	roundTop(add, V(s.X - 0.2, s.Y - legH, 1), CF(0, legH / 2, -s.Z / 2 + 0.5), col)
	for _, sx in { -1, 1 } do
		roundTop(add, V(armW, s.Y * 0.6, s.Z), CF(sx * (s.X / 2 - armW / 2), -s.Y / 2 + legH + s.Y * 0.3, 0), col)
	end
	local inner = s.X - 2 * armW - 0.1
	local seatTop = -s.Y / 2 + legH + baseH
	for i = 0, 1 do
		local w = inner / 2 - 0.08
		local x = -inner / 2 + w / 2 + 0.04 + i * (inner / 2)
		softX(add, V(w, 0.6, s.Z - 1.2), CF(x, seatTop + 0.3, 0.45), light(col, 0.16))
		softX(add, V(w - 0.3, 1.3, 0.55), CF(x, seatTop + 1.0, -s.Z / 2 + 1.25) * CFrame.Angles(rad(-90), 0, 0), light(col, 0.1))
	end
	add(V(1.1, 1.1, 0.45), CF(-inner / 2 + 0.5, seatTop + 1.0, -s.Z / 2 + 1.6) * CFrame.Angles(rad(-12), 0, rad(14)), C.teal, smooth, SP)
	legs(add, s, legH, 0.5, 0.35, C.darkWood, true)
end

B.Bed = function(add, s, tint)
	local col = tint or rgb(112, 204, 140)
	local wood = C.wood
	local frameH = s.Y * 0.4
	add(V(s.X, frameH, s.Z - 0.4), CF(0, -s.Y / 2 + frameH / 2 + 0.2, 0.2), wood)
	legs(add, s, 0.3, 0.3, 0.4, C.darkWood, true)
	roundTop(add, V(s.X, s.Y, 0.55), CF(0, 0, -s.Z / 2 + 0.28), shade(wood, 0.1))
	roundTop(add, V(s.X, s.Y * 0.62, 0.4), CF(0, -s.Y * 0.19, s.Z / 2 - 0.2), shade(wood, 0.1))
	local mattY = -s.Y / 2 + 0.2 + frameH
	add(V(s.X - 0.3, 0.6, s.Z - 1.2), CF(0, mattY + 0.3, -0.05), C.white)
	softX(add, V(s.X - 0.15, 0.7, s.Z * 0.66), CF(0, mattY + 0.4, s.Z * 0.13), col)
	add(V(s.X - 0.1, 0.72, 0.55), CF(0, mattY + 0.41, s.Z * 0.13 - s.Z * 0.33 + 0.45), C.white)
	add(V(s.X - 0.12, 0.74, 0.18), CF(0, mattY + 0.42, s.Z * 0.13 - s.Z * 0.33 + 0.82), light(col, 0.3))
	for _, sx in { -1, 1 } do
		add(V(s.X * 0.4, 0.55, 1.3), CF(sx * s.X * 0.22, mattY + 0.75, -s.Z / 2 + 1.35), C.cream, smooth, SP)
	end
end

B.Fridge = function(add, s, tint)
	local col = tint or rgb(232, 240, 244)
	bevel(add, s - V(0.05, 0, 0.05), CF(), col, light(col, 0.4), 0.2)
	add(V(s.X - 0.2, 0.08, 0.06), CF(0, s.Y * 0.16, s.Z / 2 - 0.01), C.grey)
	for _, y in { s.Y * 0.34, -s.Y * 0.06 } do
		roundTop(add, V(0.22, 1.5, 0.22), CF(s.X / 2 - 0.42, y, s.Z / 2 + 0.1), C.metal)
	end
	add(V(0.55, 0.55, 0.06), CF(-0.6, s.Y * 0.37, s.Z / 2), C.red)
	add(V(0.45, 0.45, 0.06), CF(-0.15, s.Y * 0.28, s.Z / 2), C.yellow)
	add(V(0.8, 1.0, 0.04), CF(-0.5, -s.Y * 0.05, s.Z / 2), C.white)
	add(V(s.X - 0.3, 0.25, s.Z - 0.3), CF(0, -s.Y / 2 + 0.06, 0), C.dark)
end

B.DiningTable = function(add, s, tint)
	local col = tint or C.wood
	bevel(add, V(s.X, 0.5, s.Z), CF(0, s.Y / 2 - 0.25, 0), col, light(col, 0.15), 0.16)
	add(V(s.X - 0.8, 0.4, s.Z - 0.8), CF(0, s.Y / 2 - 0.7, 0), shade(col, 0.15))
	legs(add, s, s.Y - 0.5, 0.55, 0.5, C.darkWood, true)
	add(V(s.X * 0.6, 0.05, s.Z * 0.42), CF(0, s.Y / 2 + 0.02, 0), C.cream)
	add(V(0.3, 1.5, 1.5), CF(0, s.Y / 2 + 0.15, 0) * upright, C.white, smooth, CY)
	for i, c in { C.red, C.orange, C.green } do
		local a = rad(i * 120)
		add(V(0.5, 0.5, 0.5), CF(math.cos(a) * 0.3, s.Y / 2 + 0.45, math.sin(a) * 0.3), c, smooth, SP)
	end
end

B.Piano = function(add, s, tint)
	local col = tint or rgb(58, 46, 44)
	local backZ = -s.Z / 2 + s.Z * 0.28
	bevel(add, V(s.X, s.Y * 0.92, s.Z * 0.56), CF(0, s.Y * 0.04, backZ), col, light(col, 0.12), 0.16)
	local kbY = -s.Y * 0.08
	add(V(s.X - 0.2, 0.4, s.Z * 0.44), CF(0, kbY, s.Z / 2 - s.Z * 0.22), shade(col, 0.05))
	add(V(s.X - 0.7, 0.1, s.Z * 0.3), CF(0, kbY + 0.24, s.Z / 2 - s.Z * 0.2), C.white)
	local n = 8
	for i = 0, n - 1 do
		if i % 4 ~= 2 then
			add(V(0.2, 0.08, s.Z * 0.16), CF(-s.X / 2 + 0.75 + i * (s.X - 1.4) / (n - 1), kbY + 0.32, s.Z / 2 - s.Z * 0.27), C.print)
		end
	end
	add(V(1.4, 1.1, 0.08), CF(0, s.Y * 0.26, backZ + s.Z * 0.28 + 0.02) * CFrame.Angles(rad(-10), 0, 0), C.cream)
	add(V(0.8, 0.06, 0.08), CF(0, s.Y * 0.3, backZ + s.Z * 0.28 + 0.07), C.print)
	for _, sx in { -1, 1 } do
		add(V(0.4, s.Y * 0.45, 0.4), CF(sx * (s.X / 2 - 0.3), -s.Y / 2 + s.Y * 0.225, s.Z / 2 - 0.3), col)
		add(V(0.5, 0.5, 0.5), CF(sx * 1.2, s.Y / 2 + 0.05, backZ), C.gold, smooth, SP)
	end
end

B.Clock = function(add, s, tint)
	local col = tint or C.darkWood
	add(V(s.X + 0.2, 0.5, s.Z + 0.2), CF(0, -s.Y / 2 + 0.25, 0), shade(col, 0.15))
	add(V(s.X - 0.4, s.Y * 0.62, s.Z - 0.2), CF(0, -s.Y * 0.14, 0), col)
	add(V(s.X - 1.1, s.Y * 0.42, 0.06), CF(0, -s.Y * 0.16, s.Z / 2 - 0.08), C.screen, glassM)
	add(V(0.12, s.Y * 0.26, 0.06), CF(0, -s.Y * 0.1, s.Z / 2 - 0.04), C.gold)
	add(V(0.1, 0.6, 0.6), CF(0, -s.Y * 0.23, s.Z / 2 - 0.03) * CFrame.Angles(0, rad(90), 0), C.gold, metalM, CY)
	roundTop(add, V(s.X, s.Y * 0.3, s.Z), CF(0, s.Y * 0.35, 0), light(col, 0.08))
	add(V(0.1, s.X * 0.72, s.X * 0.72), CF(0, s.Y * 0.33, s.Z / 2 + 0.03) * CFrame.Angles(0, rad(90), 0), C.gold, metalM, CY)
	add(V(0.1, s.X * 0.6, s.X * 0.6), CF(0, s.Y * 0.33, s.Z / 2 + 0.06) * CFrame.Angles(0, rad(90), 0), C.cream, smooth, CY)
	add(V(0.1, 0.55, 0.06), CF(0, s.Y * 0.33 + 0.22, s.Z / 2 + 0.12), C.print)
	add(V(0.4, 0.1, 0.06), CF(0.16, s.Y * 0.33, s.Z / 2 + 0.12), C.print)
end

B.Coffin = function(add, s, tint)
	local col = tint or rgb(110, 70, 58)
	add(V(s.X, s.Y * 0.8, s.Z), CF(0, -s.Y * 0.1, 0), col)
	bevel(add, V(s.X + 0.2, s.Y * 0.2, s.Z + 0.2), CF(0, s.Y * 0.4, 0), shade(col, 0.2), light(col, 0.1), 0.12)
	add(V(0.32, 0.08, 2.2), CF(0, s.Y / 2 + 0.03, -0.6), C.gold, metalM)
	add(V(1.4, 0.08, 0.32), CF(0, s.Y / 2 + 0.03, -1.1), C.gold, metalM)
	for _, sx in { -1, 1 } do
		for _, z in { -s.Z * 0.25, s.Z * 0.25 } do
			add(V(0.12, 0.2, 0.9), CF(sx * (s.X / 2 + 0.06), -s.Y * 0.05, z), C.gold, metalM)
		end
	end
end

B.Bookcase = function(add, s, tint)
	local col = tint or C.wood
	add(V(s.X - 0.4, s.Y - 0.3, 0.2), CF(0, 0, -s.Z / 2 + 0.1), shade(col, 0.25))
	for _, sx in { -1, 1 } do
		add(V(0.3, s.Y, s.Z), CF(sx * (s.X / 2 - 0.15), 0, 0), col)
	end
	bevel(add, V(s.X + 0.1, 0.32, s.Z + 0.1), CF(0, s.Y / 2 - 0.16, 0), col, light(col, 0.15), 0.1)
	local books = { C.red, C.blue, C.yellow, C.green, C.purple, C.teal, C.pink }
	local rows = 3
	local rowH = (s.Y - 0.6) / rows
	for row = 0, rows - 1 do
		local y = -s.Y / 2 + 0.15 + row * rowH
		add(V(s.X - 0.4, 0.26, s.Z), CF(0, y, 0), col)
		local x = -s.X / 2 + 0.4
		local i = row * 2
		while x < s.X / 2 - 1.1 do
			local w = 0.55 + (i % 3) * 0.18
			local h = rowH * (0.62 + (i % 4) * 0.07)
			add(V(w, h, s.Z - 0.5), CF(x + w / 2, y + 0.13 + h / 2, 0.1), books[i % #books + 1])
			x += w + 0.04
			i += 1
		end
	end
end

B.Washer = function(add, s, tint)
	local col = tint or C.white
	bevel(add, s - V(0.05, 0, 0.05), CF(), col, light(col, 0.4), 0.18)
	add(V(s.X - 0.1, 0.6, 0.06), CF(0, s.Y / 2 - 0.5, s.Z / 2 - 0.01), C.grey)
	add(V(0.1, 0.36, 0.36), CF(s.X * 0.3, s.Y / 2 - 0.5, s.Z / 2 + 0.03) * CFrame.Angles(0, rad(90), 0), C.dark, smooth, CY)
	add(V(s.X * 0.3, 0.16, 0.06), CF(-s.X * 0.18, s.Y / 2 - 0.5, s.Z / 2 + 0.02), C.teal, neon)
	add(V(0.12, s.X * 0.66, s.X * 0.66), CF(0, -0.3, s.Z / 2) * CFrame.Angles(0, rad(90), 0), C.metal, metalM, CY)
	add(V(0.14, s.X * 0.48, s.X * 0.48), CF(0, -0.3, s.Z / 2 + 0.02) * CFrame.Angles(0, rad(90), 0), C.screen, glassM, CY)
	add(V(0.06, 0.4, 0.12), CF(-0.25, -0.05, s.Z / 2 + 0.09) * CFrame.Angles(0, 0, rad(30)), C.glare)
end

-- Wooden crate: pale boards with darker framing planks and a diagonal brace.
B.Crate = function(add, s, tint)
	local col = tint or C.lightWood
	local plank = shade(col, 0.22)
	add(s - V(0.12, 0.12, 0.12), CF(), col)
	local t = 0.36
	for _, f in { 1, -1 } do
		-- framed front/back faces with a diagonal
		add(V(s.X, t, 0.1), CF(0, s.Y / 2 - t / 2, f * s.Z / 2), plank)
		add(V(s.X, t, 0.1), CF(0, -s.Y / 2 + t / 2, f * s.Z / 2), plank)
		add(V(t, s.Y, 0.1), CF(s.X / 2 - t / 2, 0, f * s.Z / 2), plank)
		add(V(t, s.Y, 0.1), CF(-s.X / 2 + t / 2, 0, f * s.Z / 2), plank)
		local d = math.sqrt((s.X - t) ^ 2 + (s.Y - t) ^ 2)
		add(V(d - 0.3, t * 0.9, 0.12), CF(0, 0, f * s.Z / 2) * CFrame.Angles(0, 0, f * math.atan2(s.Y - t, s.X - t)), plank)
	end
	-- top: framed edges along X plus board seams
	for _, sx in { -1, 1 } do
		add(V(t, 0.1, s.Z - 0.1), CF(sx * (s.X / 2 - t / 2), s.Y / 2, 0), plank)
	end
	for _, z in { -s.Z / 6, s.Z / 6 } do
		add(V(s.X - 2 * t, 0.04, 0.08), CF(0, s.Y / 2 - 0.04, z), plank)
	end
end
B.BigCrate = function(add, s, tint)
	B.Crate(add, s, tint or rgb(226, 184, 120))
	add(V(1.6, 0.7, 0.06), CF(0, 0.3, s.Z / 2 + 0.08), C.red)
	add(V(1.3, 0.12, 0.06), CF(0, 0.3, s.Z / 2 + 0.12), C.white)
	add(V(1.4, 0.06, 1.0), CF(s.X * 0.15, s.Y / 2 + 0.03, 0), C.red)
end

B.Barrel = function(add, s, tint)
	local col = tint or C.blue
	add(V(s.Y - 0.2, s.X * 0.92, s.X * 0.92), CF() * upright, col, smooth, CY)
	add(V(s.Y * 0.5, s.X, s.X), CF() * upright, col, smooth, CY)
	for _, y in { -s.Y * 0.33, s.Y * 0.33 } do
		add(V(0.24, s.X * 0.97, s.X * 0.97), CF(0, y, 0) * upright, C.dark, metalM, CY)
	end
	add(V(0.06, s.X * 0.8, s.X * 0.8), CF(0, s.Y / 2 - 0.08, 0) * upright, light(col, 0.2), smooth, CY)
	add(V(0.12, 0.4, 0.4), CF(s.X * 0.22, s.Y / 2 - 0.02, 0) * upright, C.dark, smooth, CY)
end

B.Mirror = function(add, s, tint)
	local col = tint or C.gold
	add(V(s.X, s.Y - 0.6, 0.35), CF(0, 0.3, 0), col, smooth, SP)
	local g = add(V(s.X - 0.45, s.Y - 1.1, 0.4), CF(0, 0.3, 0.02), rgb(196, 226, 242), glassM, SP)
	g.Reflectance = 0.25
	add(V(0.25, 1.4, 0.42), CF(-s.X * 0.18, 0.7, 0.04) * CFrame.Angles(0, 0, rad(-20)), C.white, smooth, SP)
	for _, sx in { -1, 1 } do
		add(V(0.3, 0.3, s.Z), CF(sx * s.X * 0.28, -s.Y / 2 + 0.15, 0), shade(col, 0.15))
	end
	add(V(0.3, 1, 0.3), CF(0, -s.Y / 2 + 0.6, 0), shade(col, 0.15))
end

B.Toolbox = function(add, s, tint)
	local col = tint or C.red
	bevel(add, V(s.X, s.Y - 0.45, s.Z), CF(0, -0.225, 0), col, light(col, 0.15), 0.12)
	add(V(s.X + 0.04, 0.2, s.Z + 0.04), CF(0, s.Y * 0.05, 0), shade(col, 0.2))
	for _, sx in { -1, 1 } do
		add(V(0.18, 0.4, 0.18), CF(sx * s.X * 0.22, s.Y / 2 - 0.25, 0), C.dark)
		add(V(0.3, 0.26, 0.06), CF(sx * s.X * 0.3, s.Y * 0.05, s.Z / 2 + 0.04), C.metal, metalM)
	end
	add(V(s.X * 0.5, 0.18, 0.22), CF(0, s.Y / 2 - 0.09, 0), C.dark)
end

B.Dresser = function(add, s, tint)
	local col = tint or C.lightWood
	local legH = 0.3
	bevel(add, V(s.X, s.Y - legH, s.Z), CF(0, legH / 2, 0), col, light(col, 0.18), 0.16)
	local inner = s.Y - legH - 0.5
	for row = 0, 2 do
		local h = inner / 3 - 0.12
		local y = -s.Y / 2 + legH + 0.2 + h / 2 + row * (inner / 3)
		add(V(s.X - 0.4, h, 0.1), CF(0, y, s.Z / 2 + 0.03), light(col, 0.12))
		for _, sx in { -1, 1 } do
			add(V(0.26, 0.26, 0.2), CF(sx * s.X * 0.22, y, s.Z / 2 + 0.1), C.gold, smooth, SP)
		end
	end
	legs(add, s, legH, 0.3, 0.3, C.darkWood, true)
	add(V(0.5, 0.9, 0.9), CF(s.X * 0.28, s.Y / 2 + 0.25, 0) * upright, C.teal, smooth, CY)
end

B.DeckChair = function(add, s, tint)
	local frame = C.lightWood
	local stripe = tint or C.blue
	local seatY = -s.Y / 2 + 0.9
	local seatL, seatZ = s.Z * 0.56, s.Z * 0.18
	-- backrest rises toward -Z from the back end of the seat
	local backL, tilt = s.Z * 0.42, rad(30)
	local z0 = seatZ - seatL / 2
	local backCF = CF(0, seatY + backL / 2 * math.sin(tilt), z0 - backL / 2 * math.cos(tilt)) * CFrame.Angles(tilt, 0, 0)
	-- sling: alternating stripes across the width
	local n = 5
	for i = 0, n - 1 do
		local w = s.X * 0.86 / n
		local x = -s.X * 0.43 + w / 2 + i * w
		local c = (i % 2 == 0) and stripe or C.white
		add(V(w, 0.12, seatL), CF(x, seatY, seatZ), c)
		add(V(w, 0.12, backL), backCF * CF(x, 0, 0), c)
	end
	for _, sx in { -1, 1 } do
		local x = sx * (s.X / 2 - 0.09)
		add(V(0.18, 0.22, seatL + 0.1), CF(x, seatY, seatZ), frame)
		add(V(0.18, 0.22, backL + 0.1), backCF * CF(x, 0, 0), frame)
	end
	legs(add, s, 0.8, 0.2, 0.2, frame)
end

B.Sunbed = function(add, s, tint)
	local frame = C.white
	local col = tint or C.yellow
	local seatY = -s.Y / 2 + 0.75
	local seatL, seatZ = s.Z * 0.62, s.Z * 0.19
	local backL, tilt = s.Z * 0.34, rad(22)
	local z0 = seatZ - seatL / 2
	local backCF = CF(0, seatY + backL / 2 * math.sin(tilt), z0 - backL / 2 * math.cos(tilt)) * CFrame.Angles(tilt, 0, 0)
	add(V(s.X, 0.3, seatL), CF(0, seatY, seatZ), frame)
	add(V(s.X, 0.3, backL), backCF, frame)
	softX(add, V(s.X - 0.3, 0.34, seatL - 0.1), CF(0, seatY + 0.3, seatZ), col)
	softX(add, V(s.X - 0.3, 0.34, backL - 0.1), backCF * CF(0, 0.3, 0), col)
	for _, z in { seatZ - seatL * 0.17, seatZ + seatL * 0.17 } do
		add(V(s.X - 0.28, 0.36, 0.3), CF(0, seatY + 0.31, z), C.white)
	end
	add(V(s.X - 0.8, 0.45, 1), backCF * CF(0, 0.6, -backL * 0.22), C.white, smooth, SP)
	legs(add, s, 0.6, 0.3, 0.25, C.grey)
end

B.Grill = function(add, s, tint)
	local col = tint or C.red
	local bodyY = s.Y / 2 - 1.15
	bevel(add, V(s.X * 0.7, 1, s.Z), CF(0, bodyY, 0), shade(col, 0.1), nil, 0.1)
	add(V(s.X * 0.7, s.Z, s.Z), CF(0, bodyY + 0.5, 0), col, smooth, CY) -- rounded hood
	add(V(s.X * 0.72, 0.15, s.Z * 0.6), CF(0, bodyY + 0.5 + s.Z / 2 - 0.02, 0), light(col, 0.2))
	add(V(0.2, 0.2, s.Z * 0.5), CF(0, bodyY + 0.6, s.Z / 2 + 0.1), C.dark)
	for _, sx in { -1, 1 } do
		add(V(s.X * 0.15, 0.15, s.Z * 0.8), CF(sx * s.X * 0.42, bodyY - 0.1, 0), C.lightWood)
	end
	local legH = s.Y - 1.65
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add(V(0.2, legH, 0.2), CF(sx * s.X * 0.28, -s.Y / 2 + legH / 2, sz * (s.Z / 2 - 0.3)), C.dark)
		end
		add(V(0.2, 0.5, 0.5), CF(sx * s.X * 0.32, -s.Y / 2 + 0.25, s.Z / 2 - 0.3), C.dark, smooth, CY)
	end
	add(V(s.X * 0.5, 0.12, s.Z - 0.6), CF(0, -s.Y / 2 + 0.8, 0), C.grey)
end

B.Cooler = function(add, s, tint)
	local col = tint or C.blue
	add(V(s.X, s.Y - 0.45, s.Z), CF(0, -0.225, 0), col)
	bevel(add, V(s.X + 0.1, 0.45, s.Z + 0.1), CF(0, s.Y / 2 - 0.225, 0), C.white, nil, 0.12)
	add(V(s.X * 0.4, 0.12, 0.3), CF(0, s.Y / 2 + 0.05, 0), light(col, 0.2))
	for _, sx in { -1, 1 } do
		add(V(0.12, 0.3, 0.7), CF(sx * (s.X / 2 + 0.06), s.Y * 0.05, 0), C.white)
	end
	add(V(s.X * 0.5, 0.25, 0.04), CF(0, -0.3, s.Z / 2 + 0.02), C.white)
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
		p.Size = size
		if shape == SP then
			Shapes.Ball(p)
		elseif shape then
			p.Shape = shape
		end
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
