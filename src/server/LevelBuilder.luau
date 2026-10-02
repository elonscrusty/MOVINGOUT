--[[
	LevelBuilder.luau
	Turns a level data table (src/shared/Levels/*.luau) into a roofless, furnished world:
	ground zones, room floors, walls with doorways / windows / breakable glass / swinging
	doors / boarded doors, decorative props, the moving truck and the furniture.

	Everything goes into one Folder (workspace.Level). Unloading = destroying that folder,
	so a restart can never duplicate parts, constraints or furniture.

	Coordinates: X/Z ground plane, Y up, studs. Ground top is y = 0.
	Hazards (water, traffic, conveyors, platforms, ghosts) are built by Hazards.luau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FurnitureData = require(ReplicatedStorage.Shared.FurnitureData)
local FurnitureModels = require(script.Parent.FurnitureModels)

local LevelBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad
local smooth = Enum.Material.SmoothPlastic

export type Opening = {
	At: number, -- distance of the opening centre from wall point A
	Width: number,
	Kind: string, -- Door | Window | BreakWindow | SwingDoor | BoardedDoor | Gap
	Sill: number?,
	Top: number?,
}

export type Built = {
	Folder: Folder,
	Static: Folder,
	ItemsFolder: Folder,
	Items: { [string]: Model },
	ItemOrder: { string },
	ItemHomes: { [string]: CFrame },
	Truck: { Model: Model, Cargo: CFrame, CargoSize: Vector3, Rear: CFrame },
	Spawns: { Vector3 },
	Breakables: { BasePart },
	Bounds: { Min: Vector3, Max: Vector3 },
}

local DEFAULT_WALL_HEIGHT = 7.5
local LOW_WALL_HEIGHT = 4
local WALL_THICK = 0.8

local PALETTE = {
	Grass = { Color3.fromRGB(110, 190, 80), Enum.Material.Grass },
	Road = { Color3.fromRGB(86, 90, 100), Enum.Material.Asphalt },
	Pavement = { Color3.fromRGB(196, 192, 184), Enum.Material.Concrete },
	Concrete = { Color3.fromRGB(176, 176, 172), Enum.Material.Concrete },
	Wood = { Color3.fromRGB(202, 150, 96), Enum.Material.WoodPlanks },
	DarkWood = { Color3.fromRGB(122, 84, 64), Enum.Material.WoodPlanks },
	Tile = { Color3.fromRGB(226, 228, 224), Enum.Material.CeramicTiles },
	Carpet = { Color3.fromRGB(140, 170, 214), Enum.Material.Fabric },
	CarpetRed = { Color3.fromRGB(176, 72, 80), Enum.Material.Fabric },
	Patio = { Color3.fromRGB(226, 206, 170), Enum.Material.Slate },
	Sand = { Color3.fromRGB(236, 214, 160), Enum.Material.Sand },
	Dirt = { Color3.fromRGB(110, 92, 74), Enum.Material.Ground },
	DeadGrass = { Color3.fromRGB(96, 104, 74), Enum.Material.Grass },
	Metal = { Color3.fromRGB(150, 156, 164), Enum.Material.DiamondPlate },
}
LevelBuilder.Palette = PALETTE

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Part"
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or smooth
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
LevelBuilder.Part = part

local function deco(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = part(parent, size, cf, color, material, "Deco")
	if shape then
		p.Shape = shape
	end
	return p
end

local function rect(parent: Instance, min: Vector2, max: Vector2, topY: number, thick: number, color: Color3, material: Enum.Material, name: string): Part
	local size = V(max.X - min.X, thick, max.Y - min.Y)
	local centre = V((min.X + max.X) / 2, topY - thick / 2, (min.Y + max.Y) / 2)
	return part(parent, size, CF(centre), color, material, name)
end

local subtractRect: (any, any) -> { any }

local function v2(t: any): Vector2
	if typeof(t) == "Vector2" then
		return t
	end
	return Vector2.new(t[1], t[2])
end

-- rectangle minus a hole -> up to four rectangles
type R = { Min: Vector2, Max: Vector2 }
subtractRect = function(r: R, hole: R): { R }
	local hMin = Vector2.new(math.max(r.Min.X, hole.Min.X), math.max(r.Min.Y, hole.Min.Y))
	local hMax = Vector2.new(math.min(r.Max.X, hole.Max.X), math.min(r.Max.Y, hole.Max.Y))
	if hMin.X >= hMax.X or hMin.Y >= hMax.Y then
		return { r }
	end
	local out = {}
	local function add(a: Vector2, b: Vector2)
		if b.X - a.X > 0.01 and b.Y - a.Y > 0.01 then
			table.insert(out, { Min = a, Max = b })
		end
	end
	add(r.Min, Vector2.new(r.Max.X, hMin.Y)) -- strip before the hole (low Z)
	add(Vector2.new(r.Min.X, hMax.Y), r.Max) -- strip after the hole (high Z)
	add(Vector2.new(r.Min.X, hMin.Y), Vector2.new(hMin.X, hMax.Y)) -- left
	add(Vector2.new(hMax.X, hMin.Y), Vector2.new(r.Max.X, hMax.Y)) -- right
	return out
end

local function v3(t: any, y: number?): Vector3
	if typeof(t) == "Vector3" then
		return t
	end
	if #t == 3 then
		return V(t[1], t[2], t[3])
	end
	return V(t[1], y or 0, t[2])
end
LevelBuilder.V3 = v3

----------------------------------------------------------------------------------------
-- Walls

local function glassPane(parent: Instance, size: Vector3, cf: CFrame, breakable: boolean): Part
	local p = part(parent, size, cf, Color3.fromRGB(170, 214, 236), Enum.Material.Glass, breakable and "BreakGlass" or "Glass")
	p.Transparency = 0.45
	p.Reflectance = 0.15
	if breakable then
		p:SetAttribute("Breakable", "Glass")
		-- a white cross so breakable glass reads as a shortcut
		local frame = deco(parent, V(size.X, 0.2, size.Z + 0.05), cf, Color3.new(1, 1, 1), smooth)
		frame.Name = "GlassMullion"
		frame.CanCollide = false
		frame.CanQuery = false
		local m2 = deco(parent, V(0.2, size.Y, size.Z + 0.05), cf, Color3.new(1, 1, 1), smooth)
		m2.Name = "GlassMullion"
		m2.CanCollide = false
		m2.CanQuery = false
		-- keep a reference to the mullions so Breakables can hide them with the pane
		local o1 = Instance.new("ObjectValue")
		o1.Name = "Linked"
		o1.Value = frame
		o1.Parent = p
		local o2 = Instance.new("ObjectValue")
		o2.Name = "Linked"
		o2.Value = m2
		o2.Parent = p
	end
	return p
end

local function swingDoor(parent: Instance, width: number, height: number, hingeCF: CFrame, color: Color3): Model
	-- a free-swinging door leaf on a hinge with a spring that pulls it shut
	local model = Instance.new("Model")
	model.Name = "SwingDoor"
	model.Parent = parent
	local post = part(model, V(0.3, height, 0.3), hingeCF * CF(0, height / 2, 0), color, smooth, "HingePost")
	post.Transparency = 1
	post.CanCollide = false
	local leafW = width - 0.3
	local leaf = Instance.new("Part")
	leaf.Name = "Leaf"
	leaf.Size = V(leafW, height - 0.3, 0.35)
	leaf.CFrame = hingeCF * CF(leafW / 2 + 0.15, height / 2 + 0.1, 0)
	leaf.Color = color
	leaf.Material = Enum.Material.WoodPlanks
	leaf.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0.1)
	leaf.Parent = model
	local knob = Instance.new("Part")
	knob.Shape = Enum.PartType.Ball
	knob.Size = V(0.4, 0.4, 0.4)
	knob.CFrame = leaf.CFrame * CF(leafW / 2 - 0.5, -0.4, 0.3)
	knob.Color = Color3.fromRGB(230, 184, 70)
	knob.Massless = true
	knob.CanCollide = false
	knob.Parent = model
	local kw = Instance.new("WeldConstraint")
	kw.Part0 = leaf
	kw.Part1 = knob
	kw.Parent = knob
	local a0 = Instance.new("Attachment")
	a0.CFrame = CFrame.Angles(0, 0, rad(90))
	a0.Parent = post
	local a1 = Instance.new("Attachment")
	a1.Position = V(-leafW / 2 - 0.15, -0.1, 0)
	a1.CFrame = CF(a1.Position) * CFrame.Angles(0, 0, rad(90))
	a1.Parent = leaf
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = a0
	hinge.Attachment1 = a1
	hinge.LimitsEnabled = true
	hinge.LowerAngle = -100
	hinge.UpperAngle = 100
	hinge.Parent = model
	local spring = Instance.new("TorsionSpringConstraint")
	spring.Attachment0 = a0
	spring.Attachment1 = a1
	spring.Stiffness = 60
	spring.Damping = 12
	spring.MaxTorque = 2000
	spring.Parent = model
	return model
end

local function boardedDoor(parent: Instance, width: number, cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "BoardedDoor"
	model.Parent = parent
	local blocker = part(model, V(width, 6, 0.6), cf * CF(0, 3, 0), Color3.new(), smooth, "Blocker")
	blocker.Transparency = 1
	blocker:SetAttribute("Breakable", "Boards")
	blocker:SetAttribute("Hits", 0)
	local plankColor = Color3.fromRGB(150, 108, 70)
	for i, y in { 1.4, 3.1, 4.8 } do
		local tilt = (i % 2 == 0) and 8 or -8
		local plank = deco(model, V(width + 0.6, 0.7, 0.3), cf * CF(0, y, 0.25) * CFrame.Angles(0, 0, rad(tilt)), plankColor, Enum.Material.WoodPlanks)
		plank.CanCollide = false
		plank.CanQuery = false
		local link = Instance.new("ObjectValue")
		link.Name = "Linked"
		link.Value = plank
		link.Parent = blocker
	end
	return model
end

-- Builds one wall segment from A to B with openings cut out.
local function wall(parent: Instance, w: any, out: Built)
	local a = v2(w.A)
	local b = v2(w.B)
	local height = w.Height or (w.Low and LOW_WALL_HEIGHT or DEFAULT_WALL_HEIGHT)
	local thick = w.Thick or WALL_THICK
	local color = w.Color or Color3.fromRGB(246, 236, 214)
	local material = w.Material or smooth
	local dir = (b - a)
	local length = dir.Magnitude
	local unit = dir.Unit
	local yaw = math.atan2(-unit.Y, unit.X)
	local base = CF(V(a.X, 0, a.Y)) * CFrame.Angles(0, yaw, 0) -- local +X runs along the wall

	local openings: { Opening } = table.clone(w.Openings or {})
	table.sort(openings, function(x, y)
		return x.At < y.At
	end)

	local function solid(from: number, to: number, y0: number, y1: number)
		if to - from < 0.05 or y1 - y0 < 0.05 then
			return
		end
		local p = part(parent, V(to - from, y1 - y0, thick), base * CF((from + to) / 2, (y0 + y1) / 2, 0), color, material, "Wall")
		if w.Low then
			p.Name = "LowWall"
		end
		p:SetAttribute("Fadeable", true)
		-- a darker baseboard / cap so walls read clearly from above
		if y1 >= height - 0.01 then
			local cap = deco(parent, V(to - from, 0.25, thick + 0.1), base * CF((from + to) / 2, y1 + 0.12, 0), w.CapColor or Color3.fromRGB(120, 92, 74), smooth)
			cap.CanCollide = false
			cap:SetAttribute("Fadeable", true)
		end
	end

	local cursor = 0
	for _, o in openings do
		local from = o.At - o.Width / 2
		local to = o.At + o.Width / 2
		solid(cursor, from, 0, height)
		local mid = base * CF(o.At, 0, 0)
		if o.Kind == "Window" then
			local sill = o.Sill or math.min(2.4, height - 1.5)
			local top = o.Top or (w.Low and height or height - 1.2)
			solid(from, to, 0, sill)
			solid(from, to, top, height)
			glassPane(parent, V(o.Width, top - sill, 0.25), mid * CF(0, (sill + top) / 2, 0), false)
		elseif o.Kind == "BreakWindow" then
			local sill = o.Sill or 0.2
			local top = o.Top or (w.Low and height or height - 1)
			solid(from, to, 0, sill)
			solid(from, to, top, height)
			local pane = glassPane(parent, V(o.Width, top - sill, 0.3), mid * CF(0, (sill + top) / 2, 0), true)
			table.insert(out.Breakables, pane)
		elseif o.Kind == "SwingDoor" then
			swingDoor(parent, o.Width, math.min(height, 6.6), base * CF(from, 0, 0), o.Color or Color3.fromRGB(186, 128, 80))
		elseif o.Kind == "BoardedDoor" then
			local m = boardedDoor(parent, o.Width, mid)
			local blocker = m:FindFirstChild("Blocker") :: BasePart
			table.insert(out.Breakables, blocker)
		end
		-- Door and Gap: nothing (roofless world, so no lintel to snag tall furniture)
		cursor = to
	end
	solid(cursor, length, 0, height)
end

----------------------------------------------------------------------------------------
-- Props (anchored decoration; they do collide so they shape routes)

local Props: { [string]: (parent: Instance, cf: CFrame, p: any) -> () } = {}

Props.Tree = function(parent, cf, p)
	local s = p.Scale or 1
	deco(parent, V(1.4 * s, 6 * s, 1.4 * s), cf * CF(0, 3 * s, 0), Color3.fromRGB(130, 90, 60), Enum.Material.Wood)
	local leaf = p.Color or Color3.fromRGB(80, 170, 70)
	deco(parent, V(7 * s, 6 * s, 7 * s), cf * CF(0, 7.5 * s, 0), leaf, Enum.Material.Grass, Enum.PartType.Ball)
	deco(parent, V(4.5 * s, 4.5 * s, 4.5 * s), cf * CF(1.8 * s, 9.5 * s, 0.6 * s), leaf:Lerp(Color3.new(1, 1, 0.6), 0.12), Enum.Material.Grass, Enum.PartType.Ball)
end

Props.DeadTree = function(parent, cf, p)
	local s = p.Scale or 1
	local bark = Color3.fromRGB(70, 60, 64)
	deco(parent, V(1.3 * s, 8 * s, 1.3 * s), cf * CF(0, 4 * s, 0), bark, Enum.Material.Wood)
	deco(parent, V(0.6 * s, 4 * s, 0.6 * s), cf * CF(1.2 * s, 7 * s, 0) * CFrame.Angles(0, 0, rad(-40)), bark, Enum.Material.Wood)
	deco(parent, V(0.5 * s, 3.5 * s, 0.5 * s), cf * CF(-1 * s, 6 * s, 0.5 * s) * CFrame.Angles(rad(20), 0, rad(45)), bark, Enum.Material.Wood)
end

Props.Bush = function(parent, cf, p)
	local s = p.Scale or 1
	local c = p.Color or Color3.fromRGB(90, 176, 76)
	deco(parent, V(3.4 * s, 2.6 * s, 3.4 * s), cf * CF(0, 1.1 * s, 0), c, Enum.Material.Grass, Enum.PartType.Ball)
	deco(parent, V(2.2 * s, 2 * s, 2.2 * s), cf * CF(1.1 * s, 1.5 * s, 0.4 * s), c:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Grass, Enum.PartType.Ball)
end

Props.Hedge = function(parent, cf, p)
	local len = p.Length or 8
	deco(parent, V(len, 3, 2), cf * CF(0, 1.5, 0), Color3.fromRGB(70, 150, 64), Enum.Material.Grass)
end

Props.Fence = function(parent, cf, p)
	local len = p.Length or 8
	local c = p.Color or Color3.fromRGB(250, 248, 240)
	deco(parent, V(len, 0.4, 0.3), cf * CF(0, 2.2, 0), c)
	deco(parent, V(len, 0.4, 0.3), cf * CF(0, 1.1, 0), c)
	local n = math.max(2, math.floor(len / 1.6))
	for i = 0, n do
		deco(parent, V(0.45, 3, 0.4), cf * CF(-len / 2 + i * (len / n), 1.5, 0), c)
	end
end

Props.Counter = function(parent, cf, p)
	local len = p.Length or 6
	deco(parent, V(len, 3.2, 2.4), cf * CF(0, 1.6, 0), p.Color or Color3.fromRGB(240, 236, 226))
	deco(parent, V(len + 0.2, 0.3, 2.6), cf * CF(0, 3.3, 0), Color3.fromRGB(70, 74, 84), Enum.Material.Granite)
	for i = 0, math.floor(len / 2) - 1 do
		deco(parent, V(0.5, 0.15, 0.1), cf * CF(-len / 2 + 1 + i * 2, 2.6, 1.22), Color3.fromRGB(180, 180, 186), Enum.Material.Metal)
	end
end

Props.Stove = function(parent, cf, p)
	deco(parent, V(3, 3.2, 2.4), cf * CF(0, 1.6, 0), Color3.fromRGB(230, 232, 236))
	deco(parent, V(3, 0.1, 2.4), cf * CF(0, 3.25, 0), Color3.fromRGB(40, 40, 46))
	for _, x in { -0.7, 0.7 } do
		deco(parent, V(0.12, 0.9, 0.9), cf * CF(x, 3.32, 0) * CFrame.Angles(0, 0, rad(90)), Color3.fromRGB(80, 80, 86), smooth, Enum.PartType.Cylinder)
	end
	deco(parent, V(2.2, 1.4, 0.1), cf * CF(0, 1.4, 1.22), Color3.fromRGB(40, 40, 46), Enum.Material.Glass)
end

Props.Rug = function(parent, cf, p)
	local s = p.Size or { 6, 4 }
	local r = deco(parent, V(s[1], 0.08, s[2]), cf * CF(0, 0.08, 0), p.Color or Color3.fromRGB(230, 170, 90), Enum.Material.Fabric)
	r.CanCollide = false
	local inner = deco(parent, V(s[1] - 1, 0.1, s[2] - 1), cf * CF(0, 0.09, 0), (p.Color or Color3.fromRGB(230, 170, 90)):Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Fabric)
	inner.CanCollide = false
end

Props.Mailbox = function(parent, cf, _p)
	deco(parent, V(0.4, 3, 0.4), cf * CF(0, 1.5, 0), Color3.fromRGB(120, 90, 70), Enum.Material.Wood)
	deco(parent, V(1, 1, 1.8), cf * CF(0, 3.3, 0), Color3.fromRGB(70, 110, 200))
	deco(parent, V(0.1, 0.8, 0.3), cf * CF(0.55, 3.8, 0.4), Color3.fromRGB(230, 60, 60))
end

Props.StreetLamp = function(parent, cf, _p)
	deco(parent, V(0.5, 11, 0.5), cf * CF(0, 5.5, 0), Color3.fromRGB(60, 64, 72), Enum.Material.Metal)
	local bulb = deco(parent, V(1.4, 0.8, 1.4), cf * CF(0, 11.2, 0), Color3.fromRGB(255, 236, 180), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 226, 170)
	light.Parent = bulb
end

Props.Lantern = function(parent, cf, p)
	deco(parent, V(0.4, 5, 0.4), cf * CF(0, 2.5, 0), Color3.fromRGB(50, 46, 56), Enum.Material.Metal)
	local glow = deco(parent, V(1, 1.2, 1), cf * CF(0, 5.4, 0), p.Color or Color3.fromRGB(255, 190, 90), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = p.Range or 16
	light.Brightness = 1.6
	light.Color = glow.Color
	light.Parent = glow
end

Props.Shelf = function(parent, cf, p)
	local len = p.Length or 8
	local h = p.Height or 9
	local c = Color3.fromRGB(70, 110, 190)
	for _, x in { -len / 2 + 0.3, len / 2 - 0.3 } do
		deco(parent, V(0.5, h, 3), cf * CF(x, h / 2, 0), c, Enum.Material.Metal)
	end
	local colors = { Color3.fromRGB(205, 160, 105), Color3.fromRGB(190, 150, 100), Color3.fromRGB(220, 180, 120) }
	for i, y in { 0.4, h * 0.4, h * 0.8 } do
		deco(parent, V(len, 0.3, 3), cf * CF(0, y, 0), Color3.fromRGB(230, 140, 60), Enum.Material.Metal)
		for j = 0, math.floor(len / 2.4) - 1 do
			deco(parent, V(2, 1.6, 2.2), cf * CF(-len / 2 + 1.4 + j * 2.4, y + 0.95, 0), colors[(i + j) % 3 + 1], Enum.Material.Cardboard)
		end
	end
end

Props.Pallet = function(parent, cf, _p)
	deco(parent, V(4, 0.6, 4), cf * CF(0, 0.3, 0), Color3.fromRGB(200, 160, 110), Enum.Material.WoodPlanks)
end

Props.Forklift = function(parent, cf, _p)
	local y = Color3.fromRGB(246, 196, 50)
	deco(parent, V(3.6, 2.4, 5), cf * CF(0, 1.8, 0), y, smooth)
	deco(parent, V(3.4, 0.3, 3.4), cf * CF(0, 5.4, -0.5), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	for _, x in { -1.6, 1.6 } do
		deco(parent, V(0.3, 4.6, 0.3), cf * CF(x, 3.3, -1.8), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
		deco(parent, V(0.3, 4.6, 0.3), cf * CF(x, 3.3, 1), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	end
	for _, x in { -1, 1 } do
		deco(parent, V(0.6, 0.3, 3), cf * CF(x * 0.9, 0.4, -4), Color3.fromRGB(80, 80, 86), Enum.Material.Metal)
	end
	deco(parent, V(0.5, 4.6, 0.5), cf * CF(0, 2.3, -2.7), Color3.fromRGB(80, 80, 86), Enum.Material.Metal)
end

Props.Cone = function(parent, cf, _p)
	deco(parent, V(1.4, 0.2, 1.4), cf * CF(0, 0.1, 0), Color3.fromRGB(240, 110, 40))
	deco(parent, V(0.9, 1.6, 0.9), cf * CF(0, 1, 0), Color3.fromRGB(240, 110, 40), smooth, Enum.PartType.Ball)
end

Props.Tombstone = function(parent, cf, _p)
	deco(parent, V(2.2, 2.8, 0.7), cf * CF(0, 1.4, 0), Color3.fromRGB(150, 150, 160), Enum.Material.Slate)
	deco(parent, V(0.7, 2.2, 2.2), cf * CF(0, 2.8, 0) * CFrame.Angles(0, rad(90), rad(90)), Color3.fromRGB(150, 150, 160), Enum.Material.Slate, Enum.PartType.Cylinder)
end

Props.Pumpkin = function(parent, cf, _p)
	deco(parent, V(2, 1.6, 2), cf * CF(0, 0.8, 0), Color3.fromRGB(240, 130, 40), smooth, Enum.PartType.Ball)
	deco(parent, V(0.3, 0.6, 0.3), cf * CF(0, 1.8, 0), Color3.fromRGB(80, 120, 50))
	local glow = deco(parent, V(0.6, 0.4, 0.1), cf * CF(0, 0.9, 0.95), Color3.fromRGB(255, 220, 90), Enum.Material.Neon)
	glow.CanCollide = false
end

Props.Parasol = function(parent, cf, p)
	deco(parent, V(0.3, 7, 0.3), cf * CF(0, 3.5, 0), Color3.fromRGB(240, 240, 240))
	local c = p.Color or Color3.fromRGB(240, 90, 90)
	local top = deco(parent, V(1.2, 7, 7), cf * CF(0, 7, 0) * CFrame.Angles(0, 0, rad(90)), c, Enum.Material.Fabric, Enum.PartType.Cylinder)
	top.CanCollide = false
end

Props.Bathtub = function(parent, cf, _p)
	deco(parent, V(3.4, 2.4, 6.4), cf * CF(0, 1.2, 0), Color3.fromRGB(245, 245, 248))
	local water = deco(parent, V(2.6, 0.1, 5.6), cf * CF(0, 2.2, 0), Color3.fromRGB(150, 210, 240), Enum.Material.Glass)
	water.Transparency = 0.3
end

Props.Fireplace = function(parent, cf, _p)
	deco(parent, V(6, 6, 1.6), cf * CF(0, 3, 0), Color3.fromRGB(170, 90, 70), Enum.Material.Brick)
	local hole = deco(parent, V(3, 2.6, 0.2), cf * CF(0, 1.5, 0.75), Color3.fromRGB(30, 24, 22))
	hole.CanCollide = false
	local fire = deco(parent, V(1.6, 1.2, 0.3), cf * CF(0, 1, 0.8), Color3.fromRGB(255, 150, 60), Enum.Material.Neon, Enum.PartType.Ball)
	fire.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Parent = fire
end

Props.Block = function(parent, cf, p)
	local s = p.Size or { 4, 4, 4 }
	local b = deco(parent, V(s[1], s[2], s[3]), cf * CF(0, s[2] / 2, 0), p.Color or Color3.fromRGB(200, 200, 200), p.Material or smooth)
	if p.Fadeable then
		b:SetAttribute("Fadeable", true)
	end
end

Props.Sign = function(parent, cf, p)
	deco(parent, V(0.3, 4, 0.3), cf * CF(-1.6, 2, 0), Color3.fromRGB(120, 90, 70), Enum.Material.Wood)
	deco(parent, V(0.3, 4, 0.3), cf * CF(1.6, 2, 0), Color3.fromRGB(120, 90, 70), Enum.Material.Wood)
	local board = deco(parent, V(4.4, 2, 0.3), cf * CF(0, 3.6, 0), p.Color or Color3.fromRGB(250, 240, 210), Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = p.Text or "SOLD"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(200, 60, 60)
	label.Parent = gui
end

Props.Cobweb = function(parent, cf, _p)
	local w = deco(parent, V(3, 3, 0.1), cf * CF(0, 6, 0) * CFrame.Angles(0, 0, rad(45)), Color3.fromRGB(230, 230, 240), Enum.Material.Fabric)
	w.Transparency = 0.6
	w.CanCollide = false
end

----------------------------------------------------------------------------------------
-- The moving truck. Local frame: origin = centre of the rear edge at ground level, the
-- cargo runs toward -Z, the ramp runs toward +Z down to the ground.

local TRUCK_FLOOR = 2
local function buildTruck(parent: Instance, t: any): (Model, CFrame, Vector3, CFrame)
	local model = Instance.new("Model")
	model.Name = "Truck"
	model.Parent = parent
	local L = t.Length or 18
	local W = t.Width or 11
	local H = t.Height or 7
	local root = CF(v3(t.Pos)) * CFrame.Angles(0, rad(t.Rot or 0), 0)
	local red = t.Color or Color3.fromRGB(232, 96, 60)
	local cream = Color3.fromRGB(250, 240, 220)
	local function p(size: Vector3, local_: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
		local x = part(model, size, root * local_, color, material, name or "TruckPart")
		return x
	end
	-- chassis and cargo floor
	p(V(W + 0.6, TRUCK_FLOOR - 0.6, L + 6), CF(0, (TRUCK_FLOOR - 0.6) / 2 + 0.6, -L / 2 - 3), Color3.fromRGB(60, 62, 70), smooth, "Chassis")
	local floor = p(V(W, 0.4, L), CF(0, TRUCK_FLOOR - 0.2, -L / 2), Color3.fromRGB(176, 140, 100), Enum.Material.WoodPlanks, "CargoFloor")
	floor.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.6, 0.05)
	-- side walls and front wall (the camera-side wall fades when it hides players)
	for _, sx in { -1, 1 } do
		local wall = p(V(0.6, H, L), CF(sx * (W / 2 + 0.3), TRUCK_FLOOR + H / 2, -L / 2), red, smooth, "CargoWall")
		wall:SetAttribute("Fadeable", true)
		p(V(0.7, 0.5, L), CF(sx * (W / 2 + 0.3), TRUCK_FLOOR + H + 0.25, -L / 2), cream, smooth, "Trim")
		p(V(0.1, 1.4, L * 0.6), CF(sx * (W / 2 + 0.62), TRUCK_FLOOR + H * 0.55, -L / 2), cream, smooth, "Stripe")
	end
	local front = p(V(W + 1.2, H + 0.5, 0.6), CF(0, TRUCK_FLOOR + (H + 0.5) / 2, -L - 0.3), red, smooth, "CargoFront")
	front:SetAttribute("Fadeable", true)
	-- cab
	p(V(W + 0.6, 6.5, 6), CF(0, TRUCK_FLOOR + 3.25 - 0.6, -L - 3.6), Color3.fromRGB(246, 246, 240), smooth, "Cab")
	local glass = p(V(W - 1, 2.6, 0.2), CF(0, TRUCK_FLOOR + 4, -L - 6.6), Color3.fromRGB(120, 180, 220), Enum.Material.Glass, "Windscreen")
	glass.Transparency = 0.3
	-- wheels (decoration, no collision so they never snag furniture)
	for _, z in { -3, -L + 2, -L - 4 } do
		for _, sx in { -1, 1 } do
			local wheel = p(V(1.4, 3, 3), CF(sx * (W / 2 + 0.2), 1.5, z) * CFrame.Angles(0, 0, 0), Color3.fromRGB(34, 34, 38), smooth, "Wheel")
			wheel.Shape = Enum.PartType.Cylinder
			wheel.CanCollide = false
		end
	end
	-- ramp from the rear edge down to the ground
	local rampLen = t.RampLength or 6
	local angle = math.atan2(TRUCK_FLOOR, rampLen)
	local slope = math.sqrt(rampLen * rampLen + TRUCK_FLOOR * TRUCK_FLOOR)
	local ramp = p(V(W, 0.4, slope), CF(0, TRUCK_FLOOR / 2 - 0.15, rampLen / 2) * CFrame.Angles(-angle, 0, 0), Color3.fromRGB(160, 166, 176), Enum.Material.DiamondPlate, "Ramp")
	ramp.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.7, 0.05)
	-- cargo boundary: a bright line around the opening plus a translucent floor marker
	local line = p(V(W, 0.06, 0.4), CF(0, TRUCK_FLOOR + 0.03, -0.2), Color3.fromRGB(255, 220, 70), Enum.Material.Neon, "CargoLine")
	line.CanCollide = false
	line.CanQuery = false
	-- company sign
	for _, sx in { -1, 1 } do
		local board = p(V(0.1, 2.4, 8), CF(sx * (W / 2 + 0.68), TRUCK_FLOOR + H * 0.62, -L / 2), cream, smooth, "Logo")
		board.CanCollide = false
		local gui = Instance.new("SurfaceGui")
		gui.Face = sx > 0 and Enum.NormalId.Right or Enum.NormalId.Left
		gui.PixelsPerStud = 30
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "MOVING OUT"
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = red
		label.Parent = gui
	end
	local cargo = root * CF(0, TRUCK_FLOOR + H / 2, -L / 2)
	local cargoSize = V(W, H, L)
	return model, cargo, cargoSize, root
end

----------------------------------------------------------------------------------------

-- Spawns one furniture item and records its home (recovery) transform.
function LevelBuilder.SpawnItem(out: Built, spec: any, index: number)
	local data = FurnitureData.Get(spec.Kind)
	local model = FurnitureModels.Build(spec.Kind, spec.Tint)
	local id = spec.Id or (spec.Kind .. "_" .. index)
	model.Name = id
	local pos = v3(spec.Pos)
	local y = (spec.Y or pos.Y) + data.Size.Y / 2 + 0.05
	local cf = CF(pos.X, y, pos.Z) * CFrame.Angles(0, rad(spec.Rot or 0), 0)
	model:PivotTo(cf)
	model:SetAttribute("ItemId", id)
	model:SetAttribute("Kind", spec.Kind)
	model:SetAttribute("Class", data.Class)
	model:SetAttribute("Required", spec.Required ~= false)
	model:SetAttribute("Delivered", false)
	model:SetAttribute("Holders", 0)
	model:SetAttribute("MaxHolders", data.Holders)
	model:SetAttribute("DisplayName", data.Name)
	model.Parent = out.ItemsFolder
	out.Items[id] = model
	table.insert(out.ItemOrder, id)
	out.ItemHomes[id] = spec.Home and (CF(v3(spec.Home)) + V(0, data.Size.Y / 2 + 0.05, 0)) or cf
end

function LevelBuilder.Build(level: any, parent: Instance): Built
	local folder = Instance.new("Folder")
	folder.Name = "Level"
	local static = Instance.new("Folder")
	static.Name = "Static"
	static.Parent = folder
	local itemsFolder = Instance.new("Folder")
	itemsFolder.Name = "Items"
	itemsFolder.Parent = folder

	local out: Built = {
		Folder = folder,
		Static = static,
		ItemsFolder = itemsFolder,
		Items = {},
		ItemOrder = {},
		ItemHomes = {},
		Truck = nil :: any,
		Spawns = {},
		Breakables = {},
		Bounds = {
			Min = v3(level.Bounds.Min, -40),
			Max = v3(level.Bounds.Max, 80),
		},
	}

	-- a big base so nothing falls through gaps between zones, with holes for water
	local bmin, bmax = out.Bounds.Min, out.Bounds.Max
	local pieces = { { Min = Vector2.new(bmin.X - 30, bmin.Z - 30), Max = Vector2.new(bmax.X + 30, bmax.Z + 30) } }
	for _, hz in level.Hazards or {} do
		if hz.Kind == "Water" then
			local hole = { Min = v2(hz.Min), Max = v2(hz.Max) }
			local nextPieces = {}
			for _, r in pieces do
				for _, piece in subtractRect(r, hole) do
					table.insert(nextPieces, piece)
				end
			end
			pieces = nextPieces
		end
	end
	for _, r in pieces do
		local base = rect(static, r.Min, r.Max, -0.02, 4, level.BaseColor or PALETTE.Grass[1], level.BaseMaterial or PALETTE.Grass[2], "Base")
		base:SetAttribute("Ground", true)
	end

	for _, g in level.Ground or {} do
		local pal = PALETTE[g.Kind] or PALETTE.Concrete
		local zone = rect(static, v2(g.Min), v2(g.Max), g.Top or 0.02, 1, g.Color or pal[1], g.Material or pal[2], g.Kind)
		zone:SetAttribute("Ground", true)
		if g.Kind == "Road" then
			-- dashed centre line
			local min, max = v2(g.Min), v2(g.Max)
			local alongX = (max.X - min.X) > (max.Y - min.Y)
			local len = alongX and (max.X - min.X) or (max.Y - min.Y)
			local n = math.floor(len / 6)
			for i = 0, n - 1 do
				local t = (i + 0.5) / n
				local pos = alongX and V(min.X + t * len, 0.04, (min.Y + max.Y) / 2) or V((min.X + max.X) / 2, 0.04, min.Y + t * len)
				local dash = deco(static, alongX and V(3, 0.05, 0.4) or V(0.4, 0.05, 3), CF(pos), Color3.fromRGB(250, 220, 90), smooth)
				dash.CanCollide = false
			end
		end
	end

	for _, r in level.Floors or {} do
		local pal = PALETTE[r.Kind] or PALETTE.Wood
		local f = rect(static, v2(r.Min), v2(r.Max), 0.1, 0.4, r.Color or pal[1], r.Material or pal[2], "Floor")
		f:SetAttribute("Ground", true)
	end

	for _, w in level.Walls or {} do
		wall(static, w, out)
	end

	for _, p in level.Props or {} do
		local builder = Props[p.Kind]
		if builder then
			local cf = CF(v3(p.Pos)) * CFrame.Angles(0, rad(p.Rot or 0), 0)
			builder(static, cf, p)
		else
			warn("LevelBuilder: unknown prop " .. tostring(p.Kind))
		end
	end

	local truckModel, cargo, cargoSize, rear = buildTruck(folder, level.Truck)
	out.Truck = { Model = truckModel, Cargo = cargo, CargoSize = cargoSize, Rear = rear }

	for i, spec in level.Items or {} do
		LevelBuilder.SpawnItem(out, spec, i)
	end

	for _, s in level.Spawns do
		table.insert(out.Spawns, v3(s, 3))
	end

	folder.Parent = parent
	return out
end

LevelBuilder.Props = Props
LevelBuilder.TruckFloor = TRUCK_FLOOR

return LevelBuilder
