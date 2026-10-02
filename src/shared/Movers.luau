--[[
	Movers.luau
	The selectable mover looks (original designs) and the costume builder that dresses a
	rig in one. Movers are small and chunky: a big blocky head (a rounded cube) with a
	simple face, a short body, big brown work gloves and chunky boots. The shirt always
	takes the player's slot colour and carries the slot number on the chest and back, so
	colour is never the only identifier; each style has its own head silhouette.

	Movers.Build dresses any set of R15-named anchor parts: the server uses the real
	character (MoverBuilder.luau, parts welded on), the Look menu uses a static preview
	model in a ViewportFrame (Movers.PreviewModel, anchored, no welds).
]]

local Shapes = require(script.Parent.Shapes)

local Movers = {}

local V = Vector3.new
local CF = CFrame.new
local Angles = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB

local GLOVE = rgb(168, 108, 62)
local CUFF = rgb(112, 70, 42)
local SHOE = rgb(104, 66, 44)
local SOLE = rgb(60, 44, 36)
local PANTS = rgb(56, 62, 86)
local INK = rgb(34, 26, 30)

Movers.Styles = {
	{ Name = "Boxy", Head = "Box", Color = rgb(214, 166, 112), Size = V(2.35, 2.04, 2.20), Card = rgb(232, 150, 70), Pants = rgb(70, 64, 60) },
	{ Name = "Cap Kid", Head = "Cap", Color = rgb(255, 212, 168), Size = V(2.24, 2.10, 2.14), Card = rgb(70, 150, 220), Pants = PANTS, Accent = rgb(255, 120, 60), Hair = rgb(120, 72, 40) },
	{ Name = "Bear", Head = "Bear", Color = rgb(150, 98, 62), Size = V(2.35, 2.04, 2.14), Card = rgb(200, 70, 60), Pants = rgb(70, 90, 60), Accent = rgb(236, 204, 160) },
	{ Name = "Robot", Head = "Robot", Color = rgb(176, 192, 208), Size = V(2.35, 2.04, 2.14), Card = rgb(110, 110, 170), Pants = rgb(60, 66, 80), Accent = rgb(90, 230, 255) },
	{ Name = "Frog", Head = "Frog", Color = rgb(116, 200, 92), Size = V(2.55, 1.79, 2.14), Card = rgb(60, 160, 80), Pants = rgb(80, 60, 50) },
	{ Name = "Bunny", Head = "Bunny", Color = rgb(246, 240, 234), Size = V(2.24, 2.04, 2.10), Card = rgb(230, 120, 170), Pants = rgb(90, 120, 170), Accent = rgb(255, 160, 190) },
	{ Name = "Pumpkin", Head = "Pumpkin", Color = rgb(246, 140, 40), Size = V(2.49, 2.04, 2.29), Card = rgb(130, 80, 160), Pants = rgb(60, 50, 70) },
	{ Name = "Sock Hat", Head = "Sock", Color = rgb(124, 82, 56), Size = V(2.24, 2.10, 2.14), Card = rgb(200, 170, 50), Pants = PANTS, Accent = rgb(60, 170, 160), Hair = rgb(30, 22, 20) },
}

function Movers.Get(i: number?)
	return Movers.Styles[math.clamp(math.floor(i or 1), 1, #Movers.Styles)]
end

----------------------------------------------------------------------------------------
-- Costume builder

type Ctx = { Parent: Instance, Weld: boolean }

local Ball = "Ball"
local Cyl = "Cyl"

local function piece(ctx: Ctx, anchor: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: string?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = "Costume"
	p.Size = size
	if shape == Ball then
		Shapes.Ball(p)
	elseif shape == Cyl then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = anchor.CFrame * offset
	if ctx.Weld then
		local w = Instance.new("Weld")
		w.Part0 = anchor
		w.Part1 = p
		w.C0 = offset
		w.Parent = p
	else
		p.Anchored = true
	end
	p.Parent = ctx.Parent
	return p
end

-- A box with rounded edges: three crossed blocks, edge cylinders and corner balls
-- (full), or only the four vertical edges rounded (cheaper, for small pieces).
local function roundBox(ctx: Ctx, anchor: BasePart, size: Vector3, offset: CFrame, color: Color3, r: number, material: Enum.Material?, full: boolean?): Part
	local x, y, z = size.X, size.Y, size.Z
	r = math.min(r, x / 2 - 0.01, y / 2 - 0.01, z / 2 - 0.01)
	local d = r * 2
	local hx, hy, hz = x / 2 - r, y / 2 - r, z / 2 - r
	local main
	if full then
		main = piece(ctx, anchor, V(x - d, y - d, z), offset, color, nil, material)
		piece(ctx, anchor, V(x, y - d, z - d), offset, color, nil, material)
		piece(ctx, anchor, V(x - d, y, z - d), offset, color, nil, material)
		for _, a in { -1, 1 } do
			for _, b in { -1, 1 } do
				piece(ctx, anchor, V(x - d, d, d), offset * CF(0, a * hy, b * hz), color, Cyl, material)
				piece(ctx, anchor, V(y - d, d, d), offset * CF(a * hx, 0, b * hz) * Angles(0, 0, rad(90)), color, Cyl, material)
				piece(ctx, anchor, V(z - d, d, d), offset * CF(a * hx, b * hy, 0) * Angles(0, rad(90), 0), color, Cyl, material)
				for _, c in { -1, 1 } do
					piece(ctx, anchor, V(d, d, d), offset * CF(a * hx, b * hy, c * hz), color, Ball, material)
				end
			end
		end
	else
		main = piece(ctx, anchor, V(x - d, y, z), offset, color, nil, material)
		piece(ctx, anchor, V(x, y, z - d), offset, color, nil, material)
		for _, a in { -1, 1 } do
			for _, b in { -1, 1 } do
				piece(ctx, anchor, V(y, d, d), offset * CF(a * hx, 0, b * hz) * Angles(0, 0, rad(90)), color, Cyl, material)
			end
		end
	end
	return main
end

-- Simple face on the head's front (-Z): dot eyes with a glint, brows, a small grin,
-- blush. `o` tweaks: EyeY, Spread, Brows, BrowColor, Mouth, MouthY, Cheeks.
local function face(ctx: Ctx, head: BasePart, HO: CFrame, size: Vector3, skin: Color3, o: any)
	local fz = -size.Z / 2
	local ey = o.EyeY or 0.08
	local spread = o.Spread or 0.42
	for _, sx in { -1, 1 } do
		piece(ctx, head, V(0.26, 0.4, 0.08), HO * CF(sx * spread, ey, fz - 0.02), INK, Ball)
		piece(ctx, head, V(0.09, 0.11, 0.04), HO * CF(sx * spread + 0.04, ey + 0.09, fz - 0.06), Color3.new(1, 1, 1), Ball)
		if o.Brows ~= false then
			piece(ctx, head, V(0.34, 0.08, 0.05), HO * CF(sx * spread, ey + 0.38, fz - 0.01) * Angles(0, 0, rad(-sx * 8)), o.BrowColor or INK)
		end
		if o.Cheeks ~= false then
			piece(ctx, head, V(0.32, 0.17, 0.05), HO * CF(sx * (spread + 0.34), ey - 0.3, fz - 0.01), skin:Lerp(rgb(255, 110, 120), 0.4), Ball)
		end
	end
	if o.Mouth ~= false then
		local my = ey - 0.42 + (o.MouthY or 0)
		piece(ctx, head, V(0.5, 0.26, 0.06), HO * CF(0, my, fz - 0.01), rgb(130, 40, 46), Ball)
		piece(ctx, head, V(0.24, 0.1, 0.06), HO * CF(0, my - 0.06, fz - 0.025), rgb(240, 110, 120), Ball)
		-- covers the top half of the oval so it reads as a grin
		piece(ctx, head, V(0.58, 0.14, 0.07), HO * CF(0, my + 0.08, fz - 0.015), skin)
	end
end

local function buildHead(ctx: Ctx, head: BasePart, style: any)
	local HO = CF(0, 0.74, 0)
	local s = style.Size :: Vector3
	local x, y, z = s.X, s.Y, s.Z
	local col = style.Color :: Color3
	local fz = -z / 2
	local kind = style.Head
	local radius = kind == "Box" and 0.07 or (kind == "Pumpkin" and 0.5 or 0.36)
	local material = kind == "Box" and Enum.Material.Cardboard or nil
	local h = roundBox(ctx, head, s, HO, col, radius, material, true)
	h.Name = "BigHead"

	if kind == "Box" then
		local tape = rgb(236, 206, 150)
		piece(ctx, head, V(0.46, 0.04, z + 0.02), HO * CF(0, y / 2 + 0.005, 0), tape)
		piece(ctx, head, V(0.46, 0.34, 0.04), HO * CF(0, y / 2 - 0.17, fz - 0.005), tape)
		piece(ctx, head, V(0.46, 0.34, 0.04), HO * CF(0, y / 2 - 0.17, -fz + 0.005), tape)
		for _, sz in { -1, 1 } do
			piece(ctx, head, V(x * 0.94, 0.05, z * 0.42), HO * CF(0, y / 2, sz * z / 2) * Angles(rad(sz * -40), 0, 0) * CF(0, 0, sz * z * 0.21), col:Lerp(rgb(120, 80, 40), 0.15), nil, Enum.Material.Cardboard)
		end
		-- a printed "this way up" arrow on one side
		piece(ctx, head, V(0.05, 0.5, 0.14), HO * CF(x / 2 + 0.01, 0, 0), rgb(120, 70, 40))
		piece(ctx, head, V(0.05, 0.22, 0.22), HO * CF(x / 2 + 0.01, 0.28, 0) * Angles(rad(45), 0, 0), rgb(120, 70, 40))
		face(ctx, head, HO, s, col, {})
	elseif kind == "Cap" then
		local cap = style.Accent :: Color3
		roundBox(ctx, head, V(x + 0.12, 0.62, z + 0.12), HO * CF(0, y / 2 - 0.12, 0.02), cap, 0.3, Enum.Material.Fabric, true)
		piece(ctx, head, V(x * 0.78, 0.1, 0.8), HO * CF(0, y / 2 - 0.4, fz - 0.32) * Angles(rad(-6), 0, 0), cap:Lerp(Color3.new(0, 0, 0), 0.12), nil, Enum.Material.Fabric)
		piece(ctx, head, V(0.3, 0.3, 0.3), HO * CF(0, y / 2 + 0.22, 0), cap:Lerp(Color3.new(1, 1, 1), 0.3), Ball)
		for _, sx in { -1, 1 } do
			piece(ctx, head, V(0.08, 0.55, 0.7), HO * CF(sx * (x / 2 + 0.02), 0.25, 0.2), style.Hair)
		end
		piece(ctx, head, V(x * 0.86, 0.75, 0.08), HO * CF(0, 0.2, -fz + 0.02), style.Hair)
		face(ctx, head, HO, s, col, { EyeY = 0.02 })
	elseif kind == "Bear" then
		local light = style.Accent :: Color3
		for _, sx in { -1, 1 } do
			piece(ctx, head, V(0.78, 0.78, 0.42), HO * CF(sx * 0.78, y / 2 + 0.12, 0.25), col, Ball)
			piece(ctx, head, V(0.44, 0.44, 0.1), HO * CF(sx * 0.78, y / 2 + 0.1, 0.03), light, Ball)
		end
		piece(ctx, head, V(1.1, 0.72, 0.4), HO * CF(0, -0.4, fz - 0.06), light, Ball)
		piece(ctx, head, V(0.38, 0.24, 0.16), HO * CF(0, -0.22, fz - 0.24), INK, Ball)
		piece(ctx, head, V(0.06, 0.18, 0.04), HO * CF(0, -0.4, fz - 0.26), INK)
		face(ctx, head, HO, s, col, { EyeY = 0.25, Mouth = false, Cheeks = false, BrowColor = rgb(80, 50, 30) })
	elseif kind == "Robot" then
		local glow = style.Accent :: Color3
		roundBox(ctx, head, V(x * 0.82, 0.86, 0.14), HO * CF(0, 0.12, fz), rgb(36, 44, 64), 0.12, nil, false)
		for _, sx in { -1, 1 } do
			piece(ctx, head, V(0.34, 0.34, 0.06), HO * CF(sx * 0.42, 0.2, fz - 0.08), glow, nil, Enum.Material.Neon)
			piece(ctx, head, V(0.22, 0.6, 0.6), HO * CF(sx * (x / 2 + 0.08), 0, 0), col:Lerp(INK, 0.35), Cyl)
		end
		piece(ctx, head, V(0.52, 0.09, 0.05), HO * CF(0, -0.12, fz - 0.08), glow, nil, Enum.Material.Neon)
		for i = -1, 1 do
			piece(ctx, head, V(0.42, 0.06, 0.04), HO * CF(0, -0.55 + i * 0.13, fz - 0.01), col:Lerp(INK, 0.4))
		end
		piece(ctx, head, V(0.55, 0.1, 0.1), HO * CF(0, y / 2 + 0.27, 0) * Angles(0, 0, rad(90)), col:Lerp(INK, 0.3), Cyl)
		piece(ctx, head, V(0.3, 0.3, 0.3), HO * CF(0, y / 2 + 0.6, 0), rgb(255, 80, 70), Ball, Enum.Material.Neon)
	elseif kind == "Frog" then
		for _, sx in { -1, 1 } do
			piece(ctx, head, V(0.82, 0.82, 0.82), HO * CF(sx * 0.62, y / 2 + 0.12, fz + 0.45), col, Ball)
			piece(ctx, head, V(0.56, 0.56, 0.2), HO * CF(sx * 0.62, y / 2 + 0.16, fz + 0.06), Color3.new(1, 1, 1), Ball)
			piece(ctx, head, V(0.24, 0.32, 0.08), HO * CF(sx * 0.6, y / 2 + 0.14, fz - 0.05), INK, Ball)
			piece(ctx, head, V(0.34, 0.17, 0.05), HO * CF(sx * 0.85, -0.18, fz - 0.01), rgb(250, 140, 140), Ball)
		end
		piece(ctx, head, V(1.3, 0.08, 0.05), HO * CF(0, -0.28, fz - 0.01), INK)
		for _, sx in { -1, 1 } do
			piece(ctx, head, V(0.2, 0.08, 0.05), HO * CF(sx * 0.7, -0.22, fz - 0.01) * Angles(0, 0, rad(sx * 35)), INK)
		end
	elseif kind == "Bunny" then
		local pink = style.Accent :: Color3
		for _, sx in { -1, 1 } do
			local ear = HO * CF(sx * 0.5, y / 2 + 0.68, 0.15) * Angles(0, 0, rad(-sx * 9))
			roundBox(ctx, head, V(0.48, 1.55, 0.32), ear, col, 0.2, nil, false)
			piece(ctx, head, V(0.26, 1.1, 0.05), ear * CF(0, -0.05, -0.17), pink)
		end
		piece(ctx, head, V(0.3, 0.2, 0.12), HO * CF(0, -0.15, fz - 0.05), pink, Ball)
		piece(ctx, head, V(0.24, 0.18, 0.05), HO * CF(0, -0.5, fz - 0.03), Color3.new(1, 1, 1))
		face(ctx, head, HO, s, col, { EyeY = 0.18, MouthY = 0.03 })
	elseif kind == "Pumpkin" then
		local groove = col:Lerp(rgb(160, 70, 20), 0.5)
		for _, gx in { -0.62, 0, 0.62 } do
			piece(ctx, head, V(0.09, 0.04, z * 0.8), HO * CF(gx, y / 2 + 0.005, 0), groove)
			piece(ctx, head, V(0.09, y * 0.7, 0.04), HO * CF(gx, 0, -fz + 0.005), groove)
		end
		for _, sx in { -1, 1 } do
			piece(ctx, head, V(0.04, y * 0.7, 0.09), HO * CF(sx * (x / 2 + 0.005), 0, 0), groove)
		end
		piece(ctx, head, V(0.5, 0.3, 0.3), HO * CF(0.05, y / 2 + 0.2, 0) * Angles(0, 0, rad(80)), rgb(96, 120, 50), Cyl)
		piece(ctx, head, V(0.55, 0.05, 0.32), HO * CF(0.38, y / 2 + 0.06, 0.1) * Angles(0, rad(20), rad(-12)), rgb(90, 170, 70))
		local carve = rgb(70, 30, 10)
		for _, sx in { -1, 1 } do
			piece(ctx, head, V(0.34, 0.34, 0.05), HO * CF(sx * 0.48, 0.18, fz - 0.01) * Angles(0, 0, rad(45)), carve)
		end
		piece(ctx, head, V(1.15, 0.28, 0.05), HO * CF(0, -0.42, fz - 0.01), carve)
		for _, tx in { -0.22, 0.22 } do
			piece(ctx, head, V(0.18, 0.13, 0.05), HO * CF(tx, -0.35, fz - 0.03), col)
		end
	elseif kind == "Sock" then
		local a = style.Accent :: Color3
		local b = rgb(250, 244, 230)
		roundBox(ctx, head, V(x + 0.14, 0.45, z + 0.14), HO * CF(0, y / 2 - 0.2, 0), b, 0.22, Enum.Material.Fabric, true)
		roundBox(ctx, head, V(x * 0.86, 0.5, z * 0.86), HO * CF(0, y / 2 + 0.22, 0.08), a, 0.3, Enum.Material.Fabric, true)
		roundBox(ctx, head, V(x * 0.62, 0.42, z * 0.62), HO * CF(0, y / 2 + 0.52, 0.42) * Angles(rad(-25), 0, 0), b, 0.2, Enum.Material.Fabric, false)
		roundBox(ctx, head, V(x * 0.42, 0.38, z * 0.42), HO * CF(0, y / 2 + 0.66, 0.88) * Angles(rad(-55), 0, 0), a, 0.14, Enum.Material.Fabric, false)
		piece(ctx, head, V(0.55, 0.55, 0.55), HO * CF(0, y / 2 + 0.7, 1.28), b, Ball, Enum.Material.Fabric)
		for _, sx in { -1, 1 } do
			piece(ctx, head, V(0.08, 0.4, 0.6), HO * CF(sx * (x / 2 + 0.02), 0.2, 0.25), style.Hair)
		end
		face(ctx, head, HO, s, col, { EyeY = 0.0, BrowColor = style.Hair })
	end
	-- neck
	local neck = (kind == "Robot" and col:Lerp(INK, 0.4)) or ((kind == "Box" or kind == "Pumpkin") and rgb(236, 190, 150)) or col
	piece(ctx, head, V(0.5, 0.75, 0.75), CF(0, -0.45, 0) * Angles(0, 0, rad(90)), neck, Cyl)
end

local function numberBadge(ctx: Ctx, torso: BasePart, offset: CFrame, faceId: Enum.NormalId, slot: number)
	local badge = piece(ctx, torso, V(0.66, 0.66, 0.06), offset, Color3.new(1, 1, 1))
	badge.Name = "Badge"
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BadgeGui"
	gui.Face = faceId
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.Parent = badge
	local label = Instance.new("TextLabel")
	label.Name = "Number"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = rgb(40, 40, 50)
	label.Text = slot > 0 and tostring(slot) or ""
	label.Parent = gui
end

-- Dresses the anchors (R15 part names -> parts) in style `styleIndex`. With `weld` the
-- pieces are welded to the anchors (a live character); otherwise they're anchored.
function Movers.Build(parent: Instance, parts: { [string]: BasePart }, styleIndex: number, shirt: Color3, slot: number, weld: boolean)
	local ctx: Ctx = { Parent = parent, Weld = weld }
	local style = Movers.Get(styleIndex)
	local pants = style.Pants or PANTS
	local head = parts.Head
	local upper = parts.UpperTorso
	local lower = parts.LowerTorso
	if head then
		buildHead(ctx, head, style)
	end
	if upper then
		roundBox(ctx, upper, V(1.85, 1.42, 1.35), CF(0, -0.1, 0), shirt, 0.36, nil, true)
		roundBox(ctx, upper, V(1.2, 0.18, 1.0), CF(0, 0.64, 0), shirt:Lerp(Color3.new(1, 1, 1), 0.3), 0.1, nil, false) -- collar
		if slot > 0 and weld then -- SurfaceGuis don't draw inside ViewportFrames
			numberBadge(ctx, upper, CF(0, -0.05, -0.68), Enum.NormalId.Front, slot)
			numberBadge(ctx, upper, CF(0, -0.05, 0.68), Enum.NormalId.Back, slot)
		end
	end
	if lower then
		roundBox(ctx, lower, V(1.72, 0.9, 1.28), CF(0, -0.12, 0), pants, 0.28, nil, false)
		piece(ctx, lower, V(1.76, 0.14, 1.32), CF(0, 0.26, 0), pants:Lerp(INK, 0.35))
	end
	for _, side in { "Left", "Right" } do
		local ua = parts[side .. "UpperArm"]
		local la = parts[side .. "LowerArm"]
		local hand = parts[side .. "Hand"]
		local ul = parts[side .. "UpperLeg"]
		local ll = parts[side .. "LowerLeg"]
		local foot = parts[side .. "Foot"]
		local sx = side == "Left" and 1 or -1 -- towards the body centre
		if ua then
			roundBox(ctx, ua, V(0.7, 0.72, 0.7), CF(sx * 0.12, 0.1, 0), shirt, 0.22, nil, false)
			piece(ctx, ua, V(0.78, 0.78, 0.78), CF(sx * 0.12, 0.32, 0), shirt, Ball)
		end
		if la then
			roundBox(ctx, la, V(0.64, 0.66, 0.64), CF(sx * 0.12, 0.1, 0), GLOVE, 0.2, nil, false)
			roundBox(ctx, la, V(0.8, 0.24, 0.8), CF(sx * 0.12, 0.36, 0), CUFF, 0.24, nil, false)
		end
		if hand then
			local mitt = piece(ctx, hand, V(1.0, 1.0, 0.92), CF(sx * 0.12, 0.12, 0), GLOVE, Ball)
			mitt.Name = side .. "Mitt"
			piece(ctx, hand, V(0.36, 0.52, 0.36), CF(sx * 0.02, 0.3, -0.42) * Angles(rad(25), 0, 0), GLOVE, Ball)
		end
		if ul then
			piece(ctx, ul, V(0.62, ul.Size.Y + 0.15, 0.62), CF(sx * 0.05, 0, 0), pants)
		end
		if ll then
			piece(ctx, ll, V(0.54, ll.Size.Y + 0.1, 0.54), CF(sx * 0.05, 0, 0), pants:Lerp(INK, 0.2))
		end
		if foot then
			roundBox(ctx, foot, V(0.78, 0.5, 1.05), CF(sx * 0.05, 0.12, -0.14), SHOE, 0.2, nil, true)
			piece(ctx, foot, V(0.82, 0.12, 1.08), CF(sx * 0.05, -0.1, -0.14), SOLE)
		end
	end
end

----------------------------------------------------------------------------------------
-- Static preview model (for ViewportFrames): blocky R15 proportions at the movers' scale.

local RIG = {
	{ "LowerTorso", V(2, 0.4, 1), 2.2, 0 },
	{ "UpperTorso", V(2, 1.6, 1), 3.2, 0 },
	{ "LeftUpperArm", V(1, 1, 1), 3.5, -1.5 },
	{ "LeftLowerArm", V(1, 0.9, 1), 2.55, -1.5 },
	{ "LeftHand", V(1, 0.3, 1), 1.95, -1.5 },
	{ "RightUpperArm", V(1, 1, 1), 3.5, 1.5 },
	{ "RightLowerArm", V(1, 0.9, 1), 2.55, 1.5 },
	{ "RightHand", V(1, 0.3, 1), 1.95, 1.5 },
	{ "LeftUpperLeg", V(1, 0.85, 1), 1.575, -0.5 },
	{ "LeftLowerLeg", V(1, 0.85, 1), 0.725, -0.5 },
	{ "LeftFoot", V(1, 0.3, 1), 0.15, -0.5 },
	{ "RightUpperLeg", V(1, 0.85, 1), 1.575, 0.5 },
	{ "RightLowerLeg", V(1, 0.85, 1), 0.725, 0.5 },
	{ "RightFoot", V(1, 0.3, 1), 0.15, 0.5 },
}

-- A dressed, anchored mover standing on the origin and facing -Z.
function Movers.PreviewModel(styleIndex: number, shirt: Color3, slot: number, heightScale: number): Model
	local hs = heightScale
	local model = Instance.new("Model")
	model.Name = "MoverPreview"
	local parts: { [string]: BasePart } = {}
	local function anchor(name: string, size: Vector3, cf: CFrame)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.Transparency = 1
		parts[name] = p
	end
	for _, def in RIG do
		local size = def[2] :: Vector3
		anchor(def[1] :: string, V(size.X, size.Y * hs, size.Z), CF(def[4] :: number, (def[3] :: number) * hs, 0))
	end
	anchor("Head", V(1.2, 1.2, 1.2), CF(0, 4.0 * hs + 0.6, 0))
	Movers.Build(model, parts, styleIndex, shirt, slot, false)
	return model
end

return Movers
