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
		if not State.Joined then
			-- title screen: slow orbit around the yard
			local tt = os.clock() - t0
			yaw += tt * 0.05
			wantFocus = Vector3.new(0, 0, 0)
			targetDistance = 110
		elseif #positions > 0 then
			local minV, maxV = positions[1], positions[1]
			for _, p in positions do
				minV = minV:Min(p)
				maxV = maxV:Max(p)
			end
			local extent = math.max(maxV.X - minV.X, maxV.Z - minV.Z) + Config.Camera.Margin * 2
			local want = math.clamp(Config.Camera.MinDistance + (extent - Config.Camera.Margin * 2) * Config.Camera.DistancePerStud, Config.Camera.MinDistance, Config.Camera.MaxDistance)
			wantFocus = (minV + maxV) / 2
			local tooWide = extent > Config.Camera.MaxDistance * 1.1
			local root = State.Root()
			if tooWide and root then
				wantFocus = root.Position
				want = Config.Camera.MaxDistance
			end
			if math.abs(want - targetDistance) > Config.Camera.ZoomDeadband then
				targetDistance = want
			end
		end
		local alpha = 1 - math.exp(-Config.Camera.FollowSpeed * dt)
		focus = focus:Lerp(Vector3.new(wantFocus.X, math.max(wantFocus.Y - 2, 0), wantFocus.Z), alpha)
		distance += (targetDistance - distance) * (1 - math.exp(-Config.Camera.ZoomSpeed * dt))

		local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(-pitch, 0, 0)
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
