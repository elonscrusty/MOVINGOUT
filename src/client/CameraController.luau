--[[
	CameraController.luau
	Elevated, angled, restrained-perspective camera (Config.Camera; levels can set yaw /
	pitch). It frames every mover in the job plus held furniture with a margin, between a
	minimum and maximum distance, and moves / zooms smoothly with a dead band so it never
	"breathes". If the group is too spread out to fit, it follows the local mover.

	Walls between the camera and any mover fade (collision is unchanged).
	Before PLAY (title screen) it slowly circles the depot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local CameraController = {}

local focus = Vector3.new(0, 0, 0)
local distance = 100
local targetDistance = 100
local shake = 0
local faded: { [BasePart]: boolean } = {}
local rad = math.rad

function CameraController.Shake(amount: number)
	if State.Settings().ReducedShake then
		return
	end
	shake = math.max(shake, amount)
end

local function moverPositions(): { Vector3 }
	local list = {}
	for _, p in Players:GetPlayers() do
		if ((p:GetAttribute("Slot") :: number?) or 0) > 0 and p.Character then
			local root = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.Y > -20 then
				table.insert(list, root.Position)
				local holding = p:GetAttribute("Holding")
				if holding then
					local level = Workspace:FindFirstChild("Level")
					local item = level and level:FindFirstChild("Items") and (level :: any).Items:FindFirstChild(holding)
					if item and item:IsA("Model") and item.PrimaryPart then
						table.insert(list, item.PrimaryPart.Position)
					end
				end
			end
		end
	end
	return list
end

local function fade(camPos: Vector3, targets: { Vector3 })
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local level = Workspace:FindFirstChild("Level")
	if not level then
		return
	end
	params.FilterDescendantsInstances = { level }
	local now: { [BasePart]: boolean } = {}
	for _, t in targets do
		local origin = camPos
		for _ = 1, 4 do
			local d = (t + Vector3.new(0, 1.5, 0)) - origin
			local hit = Workspace:Raycast(origin, d, params)
			if not hit then
				break
			end
			local part = hit.Instance
			if part:GetAttribute("Fadeable") then
				now[part] = true
				-- a wall is a group of parts (two painted faces, cap, trim): fade it whole
				local group = part.Parent
				if group and group:GetAttribute("FadeGroup") then
					for _, desc in group:GetDescendants() do
						if desc:IsA("BasePart") then
							now[desc] = true
						end
					end
				end
			end
			origin = hit.Position + d.Unit * 0.5
		end
	end
	for part in faded do
		if not now[part] then
			part.LocalTransparencyModifier = 0
			faded[part] = nil
		end
	end
	for part in now do
		part.LocalTransparencyModifier = Config.Camera.FadeTransparency
		faded[part] = true
	end
end

-- Fits ground points on screen: returns a focus (on the ground) and the camera distance
-- that shows all of them for this rotation, vertical FOV (degrees) and aspect ratio.
-- Exact for a perspective camera; two passes re-centre the focus on the projected box.
function CameraController.Fit(points: { Vector3 }, centre: Vector3, rot: CFrame, fov: number, aspect: number): (Vector3, number)
	local tanV = math.tan(rad(fov) / 2) * (1 - Config.Camera.ScreenPad)
	local tanH = math.tan(rad(fov) / 2) * aspect * (1 - Config.Camera.ScreenPad)
	local right, up, back = rot.XVector, rot.YVector, rot.ZVector
	local fwd = Vector3.new(-back.X, 0, -back.Z)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.new(0, 0, -1)
	local f = Vector3.new(centre.X, 0, centre.Z)
	local d = 0
	for _ = 1, 3 do
		d = 0
		for _, p in points do
			local rel = p - f
			local o = rel:Dot(back)
			d = math.max(d, o + math.abs(rel:Dot(right)) / tanH, o + math.abs(rel:Dot(up)) / tanV)
		end
		-- centre the projected box
		local sx0, sx1, sy0, sy1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in points do
			local rel = p - f
			local depth = math.max(d - rel:Dot(back), 1)
			local sx, sy = rel:Dot(right) / depth, rel:Dot(up) / depth
			sx0, sx1 = math.min(sx0, sx), math.max(sx1, sx)
			sy0, sy1 = math.min(sy0, sy), math.max(sy1, sy)
		end
		local cx, cy = (sx0 + sx1) / 2, (sy0 + sy1) / 2
		local upPerFwd = math.max(fwd:Dot(up), 0.2)
		f += right * (cx * d) + fwd * (cy * d / upPerFwd)
	end
	return f, d
end

function CameraController.Init()
	local cam = Workspace.CurrentCamera
	local t0 = os.clock()
	local fadeAcc = 0
	RunService:BindToRenderStep("MO_Camera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		cam = Workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = Config.Camera.FieldOfView
		local game_ = State.Game()
		local yaw = rad((game_:GetAttribute("CameraYaw") :: number?) or Config.Camera.Yaw)
		local pitch = rad((game_:GetAttribute("CameraPitch") :: number?) or Config.Camera.Pitch)

		local positions = moverPositions()
		local wantFocus = focus
		local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(-pitch, 0, 0)
		if not State.Joined then
			-- title screen: slow orbit around the yard
			local tt = os.clock() - t0
			yaw += tt * 0.05
			rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(-pitch, 0, 0)
			wantFocus = Vector3.new(0, 0, 0)
			targetDistance = 150
		elseif #positions > 0 then
			-- frame the level's view area (house + truck, set by LevelBuilder) plus every
			-- mover, held item and the truck's rear, like the fixed overhead shot of the
			-- original: the house fills the screen and only grows when someone leaves it
			local framing: { Vector3 } = {}
			local level = Workspace:FindFirstChild("Level")
			local vMin = level and level:GetAttribute("ViewMin")
			local vMax = level and level:GetAttribute("ViewMax")
			if typeof(vMin) == "Vector3" and typeof(vMax) == "Vector3" then
				for _, x in { vMin.X, vMax.X } do
					for _, z in { vMin.Z, vMax.Z } do
						table.insert(framing, Vector3.new(x, 0, z))
					end
				end
			end
			local m = Config.Camera.Margin
			for _, p in positions do
				for _, o in { Vector3.new(-m, 0, -m), Vector3.new(m, 0, -m), Vector3.new(-m, 0, m), Vector3.new(m, 0, m) } do
					table.insert(framing, Vector3.new(p.X, 0, p.Z) + o)
				end
			end
			local truck = game_:GetAttribute("TruckPos")
			if typeof(truck) == "Vector3" then
				table.insert(framing, Vector3.new(truck.X, 0, truck.Z))
			end
			local minV, maxV = framing[1], framing[1]
			for _, p in framing do
				minV = minV:Min(p)
				maxV = maxV:Max(p)
			end
			local vp = cam.ViewportSize
			local aspect = (vp.Y > 0) and vp.X / vp.Y or 16 / 9
			local want
			wantFocus, want = CameraController.Fit(framing, (minV + maxV) / 2, rot, Config.Camera.FieldOfView, aspect)
			local root = State.Root()
			if want > Config.Camera.MaxDistance and root then
				wantFocus = root.Position
				want = Config.Camera.MaxDistance
			end
			want = math.clamp(want, Config.Camera.MinDistance, Config.Camera.MaxDistance)
			if math.abs(want - targetDistance) > Config.Camera.ZoomDeadband then
				targetDistance = want
			end
		end
		local alpha = 1 - math.exp(-Config.Camera.FollowSpeed * dt)
		focus = focus:Lerp(Vector3.new(wantFocus.X, math.max(wantFocus.Y, 0), wantFocus.Z), alpha)
		distance += (targetDistance - distance) * (1 - math.exp(-Config.Camera.ZoomSpeed * dt))

		local camPos = focus + rot * Vector3.new(0, 0, distance)
		local cf = CFrame.lookAt(camPos, focus)
		if shake > 0 then
			shake = math.max(0, shake - dt * 3)
			local s = shake * 0.6
			cf *= CFrame.new(math.noise(os.clock() * 25, 1) * s, math.noise(os.clock() * 25, 2) * s, 0)
		end
		cam.CFrame = cf
		cam.Focus = CFrame.new(focus)

		fadeAcc += dt
		if fadeAcc > 0.1 then
			fadeAcc = 0
			fade(camPos, positions)
		end
	end)
end

return CameraController
