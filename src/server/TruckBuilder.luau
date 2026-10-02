--[[
	TruckBuilder.luau
	Builds the moving truck. Local frame: origin = centre of the rear edge at ground
	level, the cargo runs toward -Z, the ramp runs toward +Z down to the ground.
	Returns (model, cargo CFrame at the cargo volume centre, cargo size, rear CFrame).
	TruckService counts delivery inside the cargo volume, so keep those two in sync
	with the walls you build.

	Look: a chunky grey and white box van with an open top so the steep camera sees the
	cargo, thick walls with rounded caps, a low cab with windows at the front, a wide
	ribbed ramp at the rear, and a pale tiled cargo floor printed with blue chevron
	clusters pointing inward (the delivery zone).
]]

local TruckBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local rad = math.rad
local smooth = Enum.Material.SmoothPlastic

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

local function v3(t: any): Vector3
	if typeof(t) == "Vector3" then
		return t
	end
	if #t == 3 then
		return V(t[1], t[2], t[3])
	end
	return V(t[1], 0, t[2])
end

-- Decoration only: never collides, never blocks raycasts or touches.
local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local COL = {
	body = Color3.fromRGB(214, 218, 224), -- light grey walls
	bodyLight = Color3.fromRGB(240, 242, 245), -- wall caps, cab
	bodyDark = Color3.fromRGB(150, 156, 166), -- skirts, ramp ribs
		floor = Color3.fromRGB(226, 233, 240), -- pale cargo tiles
	arrow = Color3.fromRGB(62, 108, 232), -- delivery chevrons
	chassis = Color3.fromRGB(58, 60, 68),
	tyre = Color3.fromRGB(38, 38, 44),
	hub = Color3.fromRGB(200, 204, 210),
	glass = Color3.fromRGB(130, 196, 232),
	lamp = Color3.fromRGB(255, 236, 160),
	tail = Color3.fromRGB(232, 72, 64),
	ramp = Color3.fromRGB(176, 182, 192),
}

-- Prints the delivery zone on the cargo floor's top face: clusters of four blue
-- chevrons pointing at each tile centre, like the original's drop zone. GUI frames,
-- not parts, so the whole pattern costs no physics.
local function paintCargoFloor(floor: BasePart, W: number, L: number)
	local stud = 24
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DropZone"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = stud
	gui.LightInfluence = 1
	gui.Parent = floor
	local nx = math.max(2, math.floor(W / 3.4 + 0.5))
	local nz = math.max(2, math.floor(L / 3.4 + 0.5))
	local tx, tz = W / nx, L / nz
	local function bar(cx: number, cy: number, w: number, h: number, angle: number)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = COL.arrow
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(cx * stud, cy * stud)
		f.Size = UDim2.fromOffset(w * stud, h * stud)
		f.Rotation = angle
		f.Parent = gui
	end
	local head = 0.62 -- side of the diamond arrow head
	local half = head * math.sqrt(0.5)
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local cx, cy = (ix + 0.5) * tx, (iz + 0.5) * tz
			for _, u in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local ux, uy = u[1], u[2]
				local tip = 0.16 -- gap between the tips and the cluster centre
				-- head: a diamond whose inner corner is the tip, then a short stem
				bar(cx + ux * (tip + half), cy + uy * (tip + half), head, head, 45)
				local st = tip + half * 2 + 0.05
				bar(cx + ux * st, cy + uy * st, ux ~= 0 and 0.5 or 0.24, ux ~= 0 and 0.24 or 0.5, 0)
			end
		end
	end
end

----------------------------------------------------------------------------------------
-- The moving truck. Local frame: origin = centre of the rear edge at ground level, the
-- cargo runs toward -Z, the ramp runs toward +Z down to the ground.

local TRUCK_FLOOR = 2
function TruckBuilder.Build(parent: Instance, t: any): (Model, CFrame, Vector3, CFrame)
	local model = Instance.new("Model")
	model.Name = "Truck"
	model.Parent = parent
	local L = t.Length or 18
	local W = t.Width or 11
	local H = t.Height or 7
	local root = CF(v3(t.Pos)) * CFrame.Angles(0, rad(t.Rot or 0), 0)
	local accent = t.Color or Color3.fromRGB(70, 130, 220)
	local function p(size: Vector3, local_: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
		return part(model, size, root * local_, color, material, name or "TruckPart")
	end
	local function cyl(len: number, dia: number, local_: CFrame, color: Color3, name: string?): Part
		local c = p(V(len, dia, dia), local_, color, smooth, name)
		c.Shape = Enum.PartType.Cylinder
		return c
	end
	local alongZ = CFrame.Angles(0, rad(90), 0) -- cylinder axis X -> Z
	local function fade(x: BasePart): BasePart
		x:SetAttribute("Fadeable", true)
		return x
	end
	-- trim on the faded walls: queryable (so the camera can fade it) and collidable
	-- like the wall it sits on, so reach checks still treat the wall as solid
	local function fadeDeco(x: BasePart): BasePart
		x.CanTouch = false
		return fade(x)
	end

	local T = 1.1 -- wall thickness
	local top = TRUCK_FLOOR + H -- wall top
	local outer = W / 2 + T -- outside face of the side walls

	-- chassis and cargo floor (the floor carries the printed delivery zone)
	p(V(2 * outer - 0.6, TRUCK_FLOOR - 1.2, L + 7), CF(0, 0.8 + (TRUCK_FLOOR - 1.2) / 2, -L / 2 - 3.5), COL.chassis, smooth, "Chassis")
	local floor = p(V(W, 0.4, L), CF(0, TRUCK_FLOOR - 0.2, -L / 2), COL.floor, smooth, "CargoFloor")
	floor.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.6, 0.05)
	paintCargoFloor(floor, W, L)

	-- side walls: thick light-grey slabs with a rounded cap; the camera-side one fades
	for _, sx in { -1, 1 } do
		local x = sx * (W / 2 + T / 2)
		fade(p(V(T, H, L), CF(x, TRUCK_FLOOR + H / 2, -L / 2), COL.body, smooth, "CargoWall"))
		fadeDeco(cyl(L, T + 0.2, CF(x, top, -L / 2) * alongZ, COL.bodyLight, "WallCap"))
		fadeDeco(p(V(0.08, 0.9, L + 0.2), CF(sx * (outer + 0.04), TRUCK_FLOOR + 0.25, -L / 2), COL.bodyDark, smooth, "Skirt"))
		fadeDeco(p(V(0.08, 0.6, L - 1.2), CF(sx * (outer + 0.04), TRUCK_FLOOR + H - 1, -L / 2), accent, smooth, "Stripe"))
	end
	-- front wall
	fade(p(V(2 * outer, H, T), CF(0, TRUCK_FLOOR + H / 2, -L - T / 2), COL.body, smooth, "CargoFront"))
	fadeDeco(cyl(2 * outer, T + 0.2, CF(0, top, -L - T / 2), COL.bodyLight, "WallCap"))
	-- rear corner posts framing the open back, with tail lights
	for _, sx in { -1, 1 } do
		fade(p(V(T + 0.3, H + 0.4, 0.6), CF(sx * (W / 2 + T / 2), TRUCK_FLOOR + (H + 0.4) / 2, -0.3), COL.bodyLight, smooth, "RearPost"))
		deco(p(V(0.6, 0.4, 0.12), CF(sx * (W / 2 + T / 2), TRUCK_FLOOR + 0.6, 0.06), COL.tail, Enum.Material.Neon, "TailLight"))
	end

	-- cab: low, rounded, white with the accent band; kept below the cargo walls so it
	-- hides as little of the cargo as possible, and fadeable like the walls
	local cabL = 6
	local cabZ = -L - T - cabL / 2
	local nose = cabZ - cabL / 2
	local cabTop = top - 1.4
	local cabW = 2 * outer - 0.2
	fade(p(V(cabW, cabTop - 2, cabL), CF(0, 1 + (cabTop - 2) / 2, cabZ), COL.bodyLight, smooth, "Cab"))
	fade(cyl(cabW, 2, CF(0, cabTop - 1, nose + 1), COL.bodyLight, "CabRoof"))
	fade(p(V(cabW, 2, cabL - 1), CF(0, cabTop - 1, cabZ + 0.5), COL.bodyLight, smooth, "CabRoof"))
	fadeDeco(p(V(cabW + 0.12, 0.7, cabL + 0.12), CF(0, 2.4, cabZ), accent, smooth, "CabBand"))
	local winY = cabTop - 1.6
	fadeDeco(p(V(cabW - 1.4, 1.7, 0.12), CF(0, winY, nose - 0.02), COL.glass, Enum.Material.Glass, "Windscreen")).Transparency = 0.1
	for _, sx in { -1, 1 } do
		fadeDeco(p(V(0.12, 1.6, cabL * 0.45), CF(sx * (cabW / 2 + 0.02), winY, cabZ - cabL * 0.15), COL.glass, Enum.Material.Glass, "SideWindow")).Transparency = 0.1
		deco(p(V(0.3, 0.9, 0.5), CF(sx * (cabW / 2 + 0.25), winY, nose + 0.8), COL.chassis, smooth, "Mirror"))
		deco(p(V(1.4, 0.7, 0.12), CF(sx * (cabW / 2 - 1.3), 2.4, nose - 0.1), COL.lamp, Enum.Material.Neon, "Headlight"))
	end
	deco(p(V(cabW + 0.3, 0.8, 0.6), CF(0, 1.3, nose - 0.2), COL.chassis, smooth, "Bumper"))
	deco(p(V(W * 0.4, 0.9, 0.1), CF(0, 2.4, nose - 0.08), COL.bodyDark, smooth, "Grille"))

	-- wheels with grey hubs (decoration, no collision so they never snag furniture)
	for _, z in { -2.6, -L + 3, cabZ } do
		for _, sx in { -1, 1 } do
			local x = sx * (outer - 0.5)
			deco(cyl(1.2, 3, CF(x, 1.5, z), COL.tyre, "Wheel"))
			deco(cyl(1.3, 1.4, CF(x, 1.5, z), COL.hub, "Hub"))
		end
	end

	-- ramp from the rear edge down to the ground: wide, grey, ribbed, with side rails
	local rampLen = t.RampLength or 6
	local angle = math.atan2(TRUCK_FLOOR, rampLen)
	local slope = math.sqrt(rampLen * rampLen + TRUCK_FLOOR * TRUCK_FLOOR)
	local rampCF = CF(0, TRUCK_FLOOR / 2 - 0.15, rampLen / 2) * CFrame.Angles(-angle, 0, 0)
	local ramp = p(V(W, 0.4, slope), rampCF, COL.ramp, smooth, "Ramp")
	ramp.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.7, 0.05)
	for i = -2, 2 do
		deco(p(V(0.25, 0.06, slope - 0.6), rampCF * CF(i * W / 5.5, 0.22, 0), COL.bodyDark, smooth, "RampRib"))
	end
	for _, sx in { -1, 1 } do
		deco(p(V(0.4, 0.4, slope), rampCF * CF(sx * (W / 2 - 0.2), 0.3, 0), COL.bodyDark, smooth, "RampRail"))
	end

	-- cargo boundary: a blue line across the opening
	deco(p(V(W, 0.06, 0.35), CF(0, TRUCK_FLOOR + 0.03, -0.2), COL.arrow, smooth, "CargoLine"))

	-- company sign on both sides
	for _, sx in { -1, 1 } do
		local board = fadeDeco(p(V(0.1, 2.2, 8), CF(sx * (outer + 0.06), TRUCK_FLOOR + H * 0.42, -L / 2), COL.bodyLight, smooth, "Logo"))
		local gui = Instance.new("SurfaceGui")
		gui.Face = sx > 0 and Enum.NormalId.Right or Enum.NormalId.Left
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 1
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "MOVING OUT"
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = accent
		label.Parent = gui
	end

	local cargo = root * CF(0, TRUCK_FLOOR + H / 2, -L / 2)
	local cargoSize = V(W, H, L)
	return model, cargo, cargoSize, root
end

TruckBuilder.Floor = TRUCK_FLOOR

return TruckBuilder
