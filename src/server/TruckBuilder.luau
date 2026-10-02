--[[
	TruckBuilder.luau
	Builds the moving truck. Local frame: origin = centre of the rear edge at ground
	level, the cargo runs toward -Z, the ramp runs toward +Z down to the ground.
	Returns (model, cargo CFrame at the cargo volume centre, cargo size, rear CFrame).
	TruckService counts delivery inside the cargo volume, so keep those two in sync
	with the walls you build.
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
	local red = t.Color or Color3.fromRGB(232, 96, 60)
	local cream = Color3.fromRGB(250, 240, 220)
	local function p(size: Vector3, local_: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
		local x = part(model, size, root * local_, color, material, name or "TruckPart")
		return x
	end
	-- chassis and cargo floor
	p(V(W + 0.6, TRUCK_FLOOR - 1, L + 6), CF(0, (TRUCK_FLOOR - 1) / 2 + 0.6, -L / 2 - 3), Color3.fromRGB(60, 62, 70), smooth, "Chassis")
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
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
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


TruckBuilder.Floor = TRUCK_FLOOR

return TruckBuilder
