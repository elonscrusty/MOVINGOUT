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
local Shapes = require(ReplicatedStorage.Shared.Shapes)
local FurnitureModels = require(script.Parent.FurnitureModels)
local TruckBuilder = require(script.Parent.TruckBuilder)

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
local WALL_THICK = 0.5

-- Default wall style (a level overrides any of these with `WallStyle`, a wall with its
-- own fields). Faces are painted per room: a face that looks into a Floors rectangle
-- takes that floor's `Wall` colour, other faces take the exterior colour.
local WALL_STYLE = {
	Inner = Color3.fromRGB(246, 236, 214), -- room face without its own paint
	Outer = Color3.fromRGB(246, 236, 214), -- exterior face
	OuterMaterial = smooth,
	Cap = Color3.fromRGB(74, 58, 54), -- thick cap on top of every wall
	CapHeight = 0.45,
	CapOverhang = 0.18,
	Post = nil :: Color3?, -- wall-end posts (default: the cap colour)
	Frame = Color3.fromRGB(196, 150, 104), -- door frames
	Door = Color3.fromRGB(128, 86, 70), -- door leaves
	WindowFrame = Color3.fromRGB(250, 248, 240),
	Baseboard = nil :: Color3?, -- default: each face's colour, darker
}

local PALETTE = {
	Grass = { Color3.fromRGB(166, 212, 108), Enum.Material.Grass },
	Road = { Color3.fromRGB(80, 82, 94), Enum.Material.Asphalt },
	Pavement = { Color3.fromRGB(216, 210, 198), Enum.Material.Concrete },
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
	if shape == Enum.PartType.Ball then
		Shapes.Ball(p)
	elseif shape then
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

local function noTouch(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
end

type Room = { Min: Vector2, Max: Vector2, Color: Color3?, Material: Enum.Material? }

local function roomAt(rooms: { Room }, p: Vector2): Room?
	for _, r in rooms do
		if p.X > r.Min.X and p.X < r.Max.X and p.Y > r.Min.Y and p.Y < r.Max.Y then
			return r
		end
	end
	return nil
end

-- t-range [t0, t1] where the line o + u * t is inside rectangle r (nil if never)
local function clipLine(o: Vector2, u: Vector2, r: Room): (number?, number?)
	local t0, t1 = -math.huge, math.huge
	for _, axis in { "X", "Y" } do
		local oa, ua = (o :: any)[axis], (u :: any)[axis]
		local lo, hi = (r.Min :: any)[axis], (r.Max :: any)[axis]
		if math.abs(ua) < 1e-6 then
			if oa <= lo or oa >= hi then
				return nil, nil
			end
		else
			local a, b = (lo - oa) / ua, (hi - oa) / ua
			t0 = math.max(t0, math.min(a, b))
			t1 = math.min(t1, math.max(a, b))
		end
	end
	if t1 <= t0 then
		return nil, nil
	end
	return t0, t1
end

-- a door leaf standing open flat against the wall (decoration only)
local function doorLeaf(parent: Instance, cf: CFrame, w: number, h: number, color: Color3)
	local leaf = deco(parent, V(w, h, 0.18), cf * CF(0, h / 2, 0), color, Enum.Material.Wood)
	noTouch(leaf)
	leaf.Name = "DoorLeaf"
	local panel = color:Lerp(Color3.new(1, 1, 1), 0.12)
	for _, y in { h * 0.28, h * 0.7 } do
		local pnl = deco(parent, V(w - 0.8, h * 0.3, 0.06), cf * CF(0, y, 0.11), panel, Enum.Material.Wood)
		noTouch(pnl)
	end
	local knob = deco(parent, V(0.3, 0.3, 0.3), cf * CF(w / 2 - 0.45, h * 0.47, 0.16), Color3.fromRGB(236, 190, 80), Enum.Material.Metal, Enum.PartType.Ball)
	noTouch(knob)
end

-- Builds one wall segment from A to B with openings cut out. A wall is thin, painted per
-- side (see WALL_STYLE), with a thick cap, baseboards, end posts, door frames, open door
-- leaves and window frames. Collision is the two painted halves only (thickness Thick).
local function wall(parent: Instance, w: any, out: Built, style: any, rooms: { Room })
	local a = v2(w.A)
	local b = v2(w.B)
	local height = w.Height or (w.Low and LOW_WALL_HEIGHT or DEFAULT_WALL_HEIGHT)
	local thick = w.Thick or style.Thick or WALL_THICK
	local dir = (b - a)
	local length = dir.Magnitude
	local unit = dir.Unit
	local normal = Vector2.new(-unit.Y, unit.X) -- local +Z of the wall frame
	local yaw = math.atan2(-unit.Y, unit.X)
	local base = CF(V(a.X, 0, a.Y)) * CFrame.Angles(0, yaw, 0) -- local +X runs along the wall
	local capColor = w.CapColor or style.Cap
	local capH = style.CapHeight
	local capW = thick + style.CapOverhang * 2

	local group = Instance.new("Model")
	group.Name = w.Low and "LowWall" or "Wall"
	group:SetAttribute("FadeGroup", true)
	group.Parent = parent

	-- per side (+1 / -1): runs of { t0, t1, color, material, inRoom }
	local function faceRuns(side: number)
		local off = normal * side * (thick / 2 + 0.3)
		local cuts = { 0, length }
		for _, r in rooms do
			local t0, t1 = clipLine(a + off, unit, r)
			if t0 then
				table.insert(cuts, math.clamp(t0 :: number, 0, length))
				table.insert(cuts, math.clamp(t1 :: number, 0, length))
			end
		end
		table.sort(cuts)
		local runs = {}
		for i = 1, #cuts - 1 do
			local t0, t1 = cuts[i], cuts[i + 1]
			if t1 - t0 > 0.01 then
				local room = roomAt(rooms, a + off + unit * ((t0 + t1) / 2))
				local color, material
				local explicit = side > 0 and w.ColorB or w.ColorA
				if explicit then
					color, material = explicit, w.Material or smooth
				elseif room then
					color, material = room.Color or w.Color or style.Inner, room.Material or smooth
				else
					color, material = w.Outer or style.Outer, w.OuterMaterial or style.OuterMaterial or smooth
				end
				local last = runs[#runs]
				if last and last.Color == color and last.Material == material then
					last.T1 = t1
				else
					table.insert(runs, { T0 = t0, T1 = t1, Color = color, Material = material, Room = room ~= nil })
				end
			end
		end
		return runs
	end
	local sides = { [1] = faceRuns(1), [-1] = faceRuns(-1) }

	local function solid(from: number, to: number, y0: number, y1: number)
		if to - from < 0.05 or y1 - y0 < 0.05 then
			return
		end
		for side, runs in sides do
			for _, run in runs do
				local f, t = math.max(from, run.T0), math.min(to, run.T1)
				if t - f > 0.01 then
					local p = part(group, V(t - f, y1 - y0, thick / 2), base * CF((f + t) / 2, (y0 + y1) / 2, side * thick / 4), run.Color, run.Material, "Wall")
					p:SetAttribute("Fadeable", true)
					if y0 < 0.01 then
						local bb = deco(group, V(t - f, 0.5, 0.12), base * CF((f + t) / 2, 0.35, side * (thick / 2 + 0.04)), style.Baseboard or run.Color:Lerp(Color3.new(0.1, 0.06, 0.04), 0.3), smooth)
						noTouch(bb)
					end
				end
			end
		end
		if y1 >= height - 0.01 then
			local cap = deco(group, V(to - from, capH, capW), base * CF((from + to) / 2, y1 + capH / 2, 0), capColor, smooth)
			cap.Name = "Cap"
			cap.CanCollide = false
			cap.CastShadow = false
			cap:SetAttribute("Fadeable", true)
		end
	end

	local function post(t: number, color: Color3, wide: number, h: number)
		local p = deco(group, V(wide, h, thick + 0.24), base * CF(t, h / 2, 0), color, smooth)
		p.Name = "Post"
		p.CanCollide = false
		p:SetAttribute("Fadeable", true)
	end

	local openings: { Opening } = table.clone(w.Openings or {})
	table.sort(openings, function(x, y)
		return x.At < y.At
	end)

	local cursor = 0
	for i, o in openings do
		local from = o.At - o.Width / 2
		local to = o.At + o.Width / 2
		solid(cursor, from, 0, height)
		local mid = base * CF(o.At, 0, 0)
		local frameH = height + capH
		if o.Kind == "Window" then
			local sill = o.Sill or math.min(2.4, height - 1.5)
			local top = o.Top or (w.Low and height or height - 1.2)
			solid(from, to, 0, sill)
			solid(from, to, top, height)
			glassPane(group, V(o.Width, top - sill, 0.2), mid * CF(0, (sill + top) / 2, 0), false)
			local ledge = deco(group, V(o.Width + 0.8, 0.25, thick + 0.4), mid * CF(0, sill + 0.12, 0), style.WindowFrame, smooth)
			noTouch(ledge)
			if top < height - 0.05 then
				local head = deco(group, V(o.Width + 0.8, 0.3, thick + 0.3), mid * CF(0, top, 0), style.WindowFrame, smooth)
				noTouch(head)
			end
			for _, t in { from - 0.15, to + 0.15 } do
				local j = deco(group, V(0.3, top - sill, thick + 0.3), base * CF(t, (sill + top) / 2, 0), style.WindowFrame, smooth)
				noTouch(j)
			end
			local bar = deco(group, V(0.16, top - sill, 0.3), mid * CF(0, (sill + top) / 2, 0), style.WindowFrame, smooth)
			noTouch(bar)
		elseif o.Kind == "BreakWindow" then
			local sill = o.Sill or 0.2
			local top = o.Top or (w.Low and height or height - 1)
			solid(from, to, 0, sill)
			solid(from, to, top, height)
			local pane = glassPane(group, V(o.Width, top - sill, 0.3), mid * CF(0, (sill + top) / 2, 0), true)
			table.insert(out.Breakables, pane)
			for _, t in { from - 0.15, to + 0.15 } do
				local j = deco(group, V(0.3, top - sill, thick + 0.3), base * CF(t, (sill + top) / 2, 0), style.WindowFrame, smooth)
				noTouch(j)
			end
		else
			-- doorways: wooden frame posts on both sides (inside the solid wall, so the
			-- opening keeps its width)
			if o.Frame ~= false then
				post(from - 0.2, o.FrameColor or style.Frame, 0.4, frameH)
				post(to + 0.2, o.FrameColor or style.Frame, 0.4, frameH)
			end
			if o.Kind == "SwingDoor" then
				swingDoor(parent, o.Width, math.min(height, 6.6), base * CF(from, 0, 0), o.Color or style.Door)
			elseif o.Kind == "BoardedDoor" then
				local m = boardedDoor(parent, o.Width, mid)
				local blocker = m:FindFirstChild("Blocker") :: BasePart
				table.insert(out.Breakables, blocker)
			elseif o.Kind == "Door" and o.Leaf ~= false then
				-- open leaves resting flat against the wall beside the doorway
				local prevEnd = 0
				local nextStart = length
				if openings[i - 1] then
					prevEnd = openings[i - 1].At + openings[i - 1].Width / 2
				end
				if openings[i + 1] then
					nextStart = openings[i + 1].At - openings[i + 1].Width / 2
				end
				local double = o.Width >= 7
				local leafW = math.min(double and o.Width / 2 or o.Width, 4)
				local leafH = math.min(6.4, height - 0.5)
				-- on the side the camera sees, unless the level picks one
				local side = o.LeafSide or ((normal:Dot(style.CameraDir) >= 0) and 1 or -1)
				local zOff = side * (thick / 2 + 0.13)
				local roomAfter = nextStart - (to + 0.4)
				local roomBefore = (from - 0.4) - prevEnd
				local placed = 0
				if roomAfter >= leafW and placed < (double and 2 or 1) then
					doorLeaf(group, base * CF(to + 0.4 + leafW / 2, 0, zOff) * CFrame.Angles(0, side > 0 and 0 or math.pi, 0), leafW, leafH, o.Color or style.Door)
					placed += 1
				end
				if roomBefore >= leafW and placed < (double and 2 or 1) then
					doorLeaf(group, base * CF(from - 0.4 - leafW / 2, 0, zOff) * CFrame.Angles(0, side > 0 and 0 or math.pi, 0), leafW, leafH, o.Color or style.Door)
				end
			end
		end
		-- Door and Gap: open (roofless world, so no lintel to snag tall furniture)
		cursor = to
	end
	solid(cursor, length, 0, height)
	if w.Posts ~= false then
		local pc = style.Post or capColor
		post(0, pc, thick + 0.36, height + capH + 0.05)
		post(length, pc, thick + 0.36, height + capH + 0.05)
	end
end

----------------------------------------------------------------------------------------
-- Floor / ground patterns (flat overlay parts on top of one base slab; no collision)

local function flat(parent: Instance, x0: number, z0: number, x1: number, z1: number, y: number, color: Color3, material: Enum.Material?, rot: number?): Part?
	if x1 - x0 < 0.02 or z1 - z0 < 0.02 then
		return nil
	end
	local p = part(parent, V(x1 - x0, 0.04, z1 - z0), CF((x0 + x1) / 2, y + 0.02, (z0 + z1) / 2) * CFrame.Angles(0, rad(rot or 0), 0), color, material or smooth, "Pattern")
	noTouch(p)
	return p
end

local function shade(c: Color3, k: number): Color3
	return k >= 0 and c:Lerp(Color3.new(1, 1, 1), k) or c:Lerp(Color3.new(0, 0, 0), -k)
end
LevelBuilder.Shade = shade

-- Draws spec.Pattern over the rectangle min..max whose top is at y. Base colour c.
-- Patterns: Checker, Dots, Planks, Parquet, SmallTile, Grid, Diamond, Stripes.
local function pattern(parent: Instance, min: Vector2, max: Vector2, y: number, spec: any, c: Color3)
	local kind = spec.Pattern
	if not kind then
		return
	end
	local w, d = max.X - min.X, max.Y - min.Y
	local mat = spec.Material or smooth
	if kind == "Checker" then
		local t = spec.Tile or 3
		local c2 = spec.Color2 or shade(c, -0.55)
		local nx, nz = math.ceil(w / t - 0.01), math.ceil(d / t - 0.01)
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				if (i + j) % 2 == 1 then
					flat(parent, min.X + i * t, min.Y + j * t, math.min(min.X + (i + 1) * t, max.X), math.min(min.Y + (j + 1) * t, max.Y), y, c2, mat)
				end
			end
		end
	elseif kind == "Dots" then
		local t = spec.Tile or 4
		local c2 = spec.Color2 or shade(c, 0.25)
		local r = (spec.DotSize or t * 0.42)
		local row = 0
		local z = min.Y + t / 2
		while z < max.Y - r / 2 do
			local x = min.X + t / 2 + ((row % 2 == 1) and t / 2 or 0)
			while x < max.X - r / 2 do
				local dot = part(parent, V(0.04, r, r), CF(x, y + 0.02, z) * CFrame.Angles(0, 0, rad(90)), c2, mat, "Pattern")
				dot.Shape = Enum.PartType.Cylinder
				noTouch(dot)
				x += t
			end
			z += t
			row += 1
		end
	elseif kind == "Planks" or kind == "Stripes" then
		local t = spec.Tile or (kind == "Planks" and 1.5 or 2)
		local alongX = spec.Dir == "X" or (spec.Dir == nil and w >= d)
		local across = alongX and d or w
		local along = alongX and w or d
		local n = math.ceil(across / t - 0.01)
		local gap = kind == "Planks" and 0.1 or 0
		local c2 = spec.Color2 or shade(c, kind == "Planks" and 0.08 or 0.3)
		for i = 0, n - 1 do
			local a0 = i * t + gap / 2
			local a1 = math.min((i + 1) * t, across) - gap / 2
			local color = (i % 2 == 0) and c2 or shade(c2, kind == "Planks" and -0.05 or -1)
			if kind == "Stripes" and i % 2 == 1 then
				continue
			end
			if kind == "Planks" then
				-- staggered board ends
				local len = spec.Board or 8
				local s0 = -((i * 3.1) % len)
				while s0 < along do
					local b0, b1 = math.max(s0, 0) + gap / 2, math.min(s0 + len, along) - gap / 2
					if alongX then
						flat(parent, min.X + b0, min.Y + a0, min.X + b1, min.Y + a1, y, color, mat)
					else
						flat(parent, min.X + a0, min.Y + b0, min.X + a1, min.Y + b1, y, color, mat)
					end
					s0 += len
				end
			else
				if alongX then
					flat(parent, min.X, min.Y + a0, max.X, min.Y + a1, y, color, mat)
				else
					flat(parent, min.X + a0, min.Y, min.X + a1, max.Y, y, color, mat)
				end
			end
		end
	elseif kind == "Parquet" then
		-- square blocks of two boards, alternating direction (reads as herringbone)
		local t = spec.Tile or 4
		local c2 = spec.Color2 or shade(c, 0.1)
		local g = 0.1
		local nx, nz = math.ceil(w / t - 0.01), math.ceil(d / t - 0.01)
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local x0, z0 = min.X + i * t, min.Y + j * t
				local x1, z1 = math.min(x0 + t, max.X), math.min(z0 + t, max.Y)
				local h = t / 2
				for k = 0, 1 do
					local color = (k == 0) and c2 or shade(c2, -0.07)
					if (i + j) % 2 == 0 then
						flat(parent, x0 + g, z0 + k * h + g, x1 - g, math.min(z0 + (k + 1) * h, z1) - g, y, color, mat)
					else
						flat(parent, x0 + k * h + g, z0 + g, math.min(x0 + (k + 1) * h, x1) - g, z1 - g, y, color, mat)
					end
				end
			end
		end
	elseif kind == "SmallTile" or kind == "Grid" then
		local t = spec.Tile or (kind == "SmallTile" and 1.6 or 8)
		local lw = spec.Line or (kind == "SmallTile" and 0.14 or 0.18)
		local c2 = spec.Color2 or (kind == "SmallTile" and shade(c, 0.45) or shade(c, -0.12))
		local x = min.X + t
		while x < max.X - 0.05 do
			flat(parent, x - lw / 2, min.Y, x + lw / 2, max.Y, y, c2, mat)
			x += t
		end
		local z = min.Y + t
		while z < max.Y - 0.05 do
			flat(parent, min.X, z - lw / 2, max.X, z + lw / 2, y + 0.005, c2, mat)
			z += t
		end
	elseif kind == "Diamond" then
		local t = spec.Tile or 3.2
		local c2 = spec.Color2 or Color3.fromRGB(44, 44, 52)
		local sz = spec.DotSize or t * 0.38
		local x = min.X + t
		while x < max.X - 0.1 do
			local z = min.Y + t
			while z < max.Y - 0.1 do
				flat(parent, x - sz / 2, z - sz / 2, x + sz / 2, z + sz / 2, y, c2, mat, 45)
				z += t
			end
			x += t
		end
	end
end

-- Deterministic scatter of grass tufts and flowers over grassy ground.
local function scatterGrass(parent: Instance, level: any, isGrassAt: (Vector2) -> (string?, Color3?))
	local b = level.Bounds
	local min, max = v2(b.Min), v2(b.Max)
	local seed = 0
	for i = 1, #(level.Id or "x") do
		seed = (seed * 31 + string.byte(level.Id, i)) % 100000
	end
	local rng = Random.new(seed + 7)
	local area = (max.X - min.X) * (max.Y - min.Y)
	local density = level.GrassDetail or 4 -- tufts per 100 square studs
	local n = math.floor(area / 100 * density)
	for _ = 1, n do
		local p = Vector2.new(rng:NextNumber(min.X, max.X), rng:NextNumber(min.Y, max.Y))
		local kind, ground = isGrassAt(p)
		if kind then
			local base = shade(ground or PALETTE.Grass[1], -0.12)
			local roll = rng:NextNumber()
			if kind == "Grass" and roll < 0.1 then
				local fc = ({ Color3.fromRGB(255, 255, 250), Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 150, 180) })[rng:NextInteger(1, 3)]
				local f = deco(parent, V(0.55, 0.55, 0.55), CF(p.X, 0.3, p.Y), fc, smooth, Enum.PartType.Ball)
				noTouch(f)
			else
				local yaw = rng:NextNumber(0, 360)
				local tuft = deco(parent, V(0.18, 0.8, 0.6), CF(p.X, 0.3, p.Y) * CFrame.Angles(0, rad(yaw), rad(rng:NextNumber(-12, 12))), shade(base, (rng:NextNumber() < 0.5) and rng:NextNumber(-0.18, -0.05) or rng:NextNumber(0.15, 0.35)), smooth)
				noTouch(tuft)
			end
		end
	end
end

----------------------------------------------------------------------------------------
-- Props (anchored decoration; they do collide so they shape routes)

local Props: { [string]: (parent: Instance, cf: CFrame, p: any) -> () } = {}

Props.Tree = function(parent, cf, p)
	-- trunk + stacked rounded crowns; crowns don't collide and fade like walls
	local s = p.Scale or 1
	local trunk = deco(parent, V(1.1 * s, 4 * s, 1.1 * s), cf * CF(0, 2 * s, 0), p.TrunkColor or Color3.fromRGB(176, 104, 84), Enum.Material.Wood)
	trunk.Name = "Trunk"
	local leaf = p.Color or Color3.fromRGB(96, 178, 104)
	local crowns = p.Style == "Round" and {
		{ 6.4, 5.2, 6.8, 0 },
		{ 4.6, 4, 9.6, 0.15 },
	} or {
		-- tall cypress-like stack (default)
		{ 5.2, 5.4, 5.6, -0.04 },
		{ 4.4, 4.8, 8.8, 0.06 },
		{ 3, 3.6, 11.6, 0.16 },
	}
	for _, c in crowns do
		local crown = deco(parent, V(c[1] * s, c[2] * s, c[1] * s), cf * CF(0, c[3] * s, 0), shade(leaf, c[4]), smooth, Enum.PartType.Ball)
		crown.Name = "Crown"
		crown.CanCollide = false
		crown:SetAttribute("Fadeable", true)
	end
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
	local c = p.Color or Color3.fromRGB(100, 184, 108)
	deco(parent, V(3.4 * s, 2.8 * s, 3.4 * s), cf * CF(0, 1.3 * s, 0), c, smooth, Enum.PartType.Ball)
	for _, o in { { 1, 0.5, 0.7, 2.2 }, { -0.9, 0.4, 0.6, 2 }, { 0.1, 1.2, -0.9, 1.8 } } do
		local b = deco(parent, V(o[4] * s, o[4] * s, o[4] * s), cf * CF(o[1] * s, (1.3 + o[2] * 0.6) * s, o[3] * s), shade(c, 0.08), smooth, Enum.PartType.Ball)
		b.CanCollide = false
	end
end

Props.Hedge = function(parent, cf, p)
	-- a row of rounded shrubs on a low box (the box is the collision)
	local len = p.Length or 8
	local c = p.Color or Color3.fromRGB(84, 166, 98)
	deco(parent, V(len, 2.2, 2), cf * CF(0, 1.1, 0), c, smooth)
	local n = math.max(1, math.floor(len / 2.4))
	for i = 0, n - 1 do
		local b = deco(parent, V(2.8, 2.6, 2.8), cf * CF(-len / 2 + (i + 0.5) * (len / n), 2.1, 0), shade(c, (i % 2) * 0.06), smooth, Enum.PartType.Ball)
		b.CanCollide = false
	end
end

Props.Fence = function(parent, cf, p)
	-- picket fence (Style = "Wood": weathered board fence)
	local len = p.Length or 8
	local wood = p.Style == "Wood"
	local c = p.Color or (wood and Color3.fromRGB(168, 160, 150) or Color3.fromRGB(246, 240, 214))
	local h = wood and 3.2 or 2.6
	deco(parent, V(len, 0.35, 0.25), cf * CF(0, h * 0.75, 0.2), shade(c, -0.08))
	deco(parent, V(len, 0.35, 0.25), cf * CF(0, h * 0.3, 0.2), shade(c, -0.08))
	local spacing = wood and 0.95 or 1.1
	local n = math.max(2, math.floor(len / spacing))
	for i = 0, n do
		local x = -len / 2 + i * (len / n)
		local ph = h + ((wood and i % 2 == 1) and -0.25 or 0)
		local pk = deco(parent, V(wood and 0.8 or 0.5, ph, 0.2), cf * CF(x, ph / 2, 0), shade(c, (i % 3 - 1) * 0.04))
		pk.CanCollide = false
		if not wood then
			local tip = deco(parent, V(0.36, 0.36, 0.2), cf * CF(x, ph, 0) * CFrame.Angles(0, 0, rad(45)), c)
			noTouch(tip)
		end
	end
	-- one invisible collider for the whole run
	local col = part(parent, V(len, h, 0.45), cf * CF(0, h / 2, 0.1), c, smooth, "FenceCollider")
	col.Transparency = 1
end

Props.Stones = function(parent, cf, p)
	-- stepping-stone path from Pos toward To ({x,z}); decoration only
	local from = cf.Position
	local to = p.To and v3(p.To) or (cf * CF(0, 0, -10)).Position
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local n = math.max(1, math.floor(d.Magnitude / (p.Spacing or 2.6)))
	local c = p.Color or Color3.fromRGB(214, 214, 206)
	for i = 0, n do
		local pos = from + d * (i / n)
		local sz = (p.Size or 2.2) * (i % 2 == 0 and 1 or 0.9)
		local st = deco(parent, V(0.12, sz, sz * 1.15), CF(pos.X + ((i % 2) - 0.5) * 0.5, 0.08, pos.Z) * CFrame.Angles(0, rad(i * 37), rad(90)), c, Enum.Material.Slate)
		st.Shape = Enum.PartType.Cylinder
		noTouch(st)
	end
end

Props.Doormat = function(parent, cf, p)
	local mat = deco(parent, V(3.6, 0.08, 2), cf * CF(0, 0.07, 0), p.Color or Color3.fromRGB(236, 128, 64), Enum.Material.Fabric)
	noTouch(mat)
	local inner = deco(parent, V(3, 0.1, 1.4), cf * CF(0, 0.08, 0), shade(p.Color or Color3.fromRGB(236, 128, 64), 0.18), Enum.Material.Fabric)
	noTouch(inner)
end

Props.FlowerBed = function(parent, cf, p)
	-- a soil strip with round flowers; decoration only
	local s = p.Size or { 6, 1.6 }
	local soil = deco(parent, V(s[1], 0.2, s[2]), cf * CF(0, 0.1, 0), Color3.fromRGB(132, 96, 72), Enum.Material.Ground)
	noTouch(soil)
	local cols = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(250, 250, 250), Color3.fromRGB(190, 130, 230) }
	local n = math.max(2, math.floor(s[1] / 1.2))
	for i = 0, n - 1 do
		local x = -s[1] / 2 + (i + 0.5) * (s[1] / n)
		local leaf = deco(parent, V(1, 0.8, 1), cf * CF(x, 0.5, 0), Color3.fromRGB(96, 170, 90), smooth, Enum.PartType.Ball)
		noTouch(leaf)
		local f = deco(parent, V(0.6, 0.6, 0.6), cf * CF(x, 0.95, (i % 2 - 0.5) * 0.3), cols[i % #cols + 1], smooth, Enum.PartType.Ball)
		noTouch(f)
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
	gui.Face = Enum.NormalId.Back -- +Z, toward the camera
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
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

-- Soft pastel colour grade (a ColorCorrectionEffect in Lighting, replicated to every
-- client). Levels tune it with `Grade = { Saturation, Contrast, Brightness, TintColor }`.
function LevelBuilder.ApplyGrade(level: any)
	local Lighting = game:GetService("Lighting")
	local cc = Lighting:FindFirstChild("LevelGrade") :: ColorCorrectionEffect?
	if not cc then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "LevelGrade"
		made.Parent = Lighting
		cc = made
	end
	local g = level.Grade or {}
	local effect = cc :: ColorCorrectionEffect
	effect.Saturation = g.Saturation or 0.04
	effect.Contrast = g.Contrast or -0.08
	effect.Brightness = g.Brightness or 0.04
	effect.TintColor = g.TintColor or Color3.fromRGB(255, 252, 246)
	effect.Enabled = true
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
	local pieces = { { Min = Vector2.new(bmin.X - 90, bmin.Z - 90), Max = Vector2.new(bmax.X + 90, bmax.Z + 90) } }
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

	local holes = {}
	for _, hz in level.Hazards or {} do
		if hz.Kind == "Water" then
			table.insert(holes, { Min = v2(hz.Min), Max = v2(hz.Max) })
		end
	end
	for _, g in level.Ground or {} do
		local pal = PALETTE[g.Kind] or PALETTE.Concrete
		local zonePieces = { { Min = v2(g.Min), Max = v2(g.Max) } }
		for _, hole in holes do
			local nextPieces = {}
			for _, r in zonePieces do
				for _, piece in subtractRect(r, hole) do
					table.insert(nextPieces, piece)
				end
			end
			zonePieces = nextPieces
		end
		local top = g.Top or 0.02
		local color = g.Color or pal[1]
		for _, r in zonePieces do
			local zone = rect(static, r.Min, r.Max, top, 1, color, g.Material or pal[2], g.Kind)
			zone:SetAttribute("Ground", true)
			if g.Pattern then
				pattern(static, r.Min, r.Max, top, g, color)
			elseif g.Kind == "Pavement" and g.Joints ~= false then
				-- paving slabs: joint lines across the long axis
				pattern(static, r.Min, r.Max, top, { Pattern = "Grid", Tile = g.Tile or 4, Line = 0.14, Color2 = shade(color, -0.14) }, color)
			elseif g.Kind == "Concrete" and g.Joints ~= false then
				pattern(static, r.Min, r.Max, top, { Pattern = "Grid", Tile = g.Tile or 8, Color2 = shade(color, -0.1) }, color)
			end
		end
		if g.Kind == "Road" then
			-- white dashed centre line and kerbs along both long edges
			local min, max = v2(g.Min), v2(g.Max)
			local alongX = (max.X - min.X) > (max.Y - min.Y)
			local len = alongX and (max.X - min.X) or (max.Y - min.Y)
			local n = math.floor(len / 7)
			for i = 0, n - 1 do
				local t = (i + 0.5) / n
				local pos = alongX and V(min.X + t * len, top + 0.02, (min.Y + max.Y) / 2) or V((min.X + max.X) / 2, top + 0.02, min.Y + t * len)
				local dash = deco(static, alongX and V(3.2, 0.04, 0.5) or V(0.5, 0.04, 3.2), CF(pos), Color3.fromRGB(250, 250, 246), smooth)
				noTouch(dash)
			end
			if g.Kerb ~= false then
				local kc = Color3.fromRGB(226, 224, 218)
				for _, e in { 0, 1 } do
					local kerb
					if alongX then
						local z = e == 0 and min.Y + 0.25 or max.Y - 0.25
						kerb = deco(static, V(len, 0.3, 0.5), CF((min.X + max.X) / 2, top + 0.15, z), kc, Enum.Material.Concrete)
					else
						local x = e == 0 and min.X + 0.25 or max.X - 0.25
						kerb = deco(static, V(0.5, 0.3, len), CF(x, top + 0.15, (min.Y + max.Y) / 2), kc, Enum.Material.Concrete)
					end
					noTouch(kerb)
				end
			end
		end
	end

	-- room floors: a slab per room plus its pattern; rooms also paint the walls facing them
	local rooms: { Room } = {}
	for _, r in level.Floors or {} do
		local pal = PALETTE[r.Kind] or PALETTE.Wood
		local color = r.Color or pal[1]
		local f = rect(static, v2(r.Min), v2(r.Max), 0.1, 0.4, color, r.Material or pal[2], "Floor")
		f:SetAttribute("Ground", true)
		pattern(static, v2(r.Min), v2(r.Max), 0.1, r, color)
		table.insert(rooms, { Min = v2(r.Min), Max = v2(r.Max), Color = r.Wall, Material = r.WallMaterial })
	end

	local style = table.clone(WALL_STYLE) :: any
	local camYaw = rad((level.Camera and level.Camera.Yaw) or 25)
	style.CameraDir = Vector2.new(math.sin(camYaw), math.cos(camYaw))
	for k, v in level.WallStyle or {} do
		(style :: any)[k] = v
	end
	for _, w in level.Walls or {} do
		wall(static, w, out, style, rooms)
	end

	-- grass tufts and flowers wherever the visible ground is grass
	if level.GrassDetail ~= 0 then
		local zones = level.Ground or {}
		local baseGrass = (level.BaseMaterial == nil or level.BaseMaterial == Enum.Material.Grass) and "Grass" or nil
		local baseColor = level.BaseColor or PALETTE.Grass[1]
		scatterGrass(static, level, function(p: Vector2): (string?, Color3?)
			for _, r in rooms do
				if p.X > r.Min.X - 1 and p.X < r.Max.X + 1 and p.Y > r.Min.Y - 1 and p.Y < r.Max.Y + 1 then
					return nil
				end
			end
			for _, hole in holes do
				if p.X > hole.Min.X - 1 and p.X < hole.Max.X + 1 and p.Y > hole.Min.Y - 1 and p.Y < hole.Max.Y + 1 then
					return nil
				end
			end
			local best, bestTop, bestColor = baseGrass, -1, baseColor
			for _, g in zones do
				local mn, mx = v2(g.Min), v2(g.Max)
				if p.X >= mn.X and p.X <= mx.X and p.Y >= mn.Y and p.Y <= mx.Y and (g.Top or 0.02) >= bestTop then
					bestTop = g.Top or 0.02
					best = (g.Kind == "Grass" or g.Kind == "DeadGrass") and g.Kind or nil
					bestColor = g.Color or (PALETTE[g.Kind] and PALETTE[g.Kind][1]) or baseColor
				end
			end
			return best, bestColor
		end)
	end

	-- the camera frames this area (house + truck); default: floors and the truck's rear
	local cam = level.Camera or {}
	local vmin, vmax
	if cam.View then
		vmin, vmax = v2(cam.View.Min), v2(cam.View.Max)
	else
		for _, r in rooms do
			vmin = vmin and vmin:Min(r.Min) or r.Min
			vmax = vmax and vmax:Max(r.Max) or r.Max
		end
	end
	if vmin and vmax then
		folder:SetAttribute("ViewMin", V(vmin.X, 0, vmin.Y))
		folder:SetAttribute("ViewMax", V(vmax.X, 0, vmax.Y))
	end

	LevelBuilder.ApplyGrade(level)

	for _, p in level.Props or {} do
		local builder = Props[p.Kind]
		if builder then
			local cf = CF(v3(p.Pos)) * CFrame.Angles(0, rad(p.Rot or 0), 0)
			builder(static, cf, p)
		else
			warn("LevelBuilder: unknown prop " .. tostring(p.Kind))
		end
	end

	local truckModel, cargo, cargoSize, rear = TruckBuilder.Build(folder, level.Truck)
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
LevelBuilder.TruckFloor = TruckBuilder.Floor

return LevelBuilder
