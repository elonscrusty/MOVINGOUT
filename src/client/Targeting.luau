--[[
	Targeting.luau
	Picks the furniture the local mover would grab and outlines it.

	Score = distance to the nearest point of the item's box (not its centre: a long
	sofa's near end counts) + a penalty for items behind the mover. Items behind walls
	are skipped (raycast), full items (no free grip) are skipped, and a new target must
	beat the current one by Config.Carry.TargetHysteresis so the outline doesn't flicker
	between two items when standing between them. The server re-validates every grab.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Targeting = {}

local current: Model? = nil
local highlight: Highlight
Targeting.Changed = State.Signal()

local function closestPoint(body: BasePart, pos: Vector3): Vector3
	local half = body.Size / 2
	local lp = body.CFrame:PointToObjectSpace(pos)
	local c = Vector3.new(math.clamp(lp.X, -half.X, half.X), math.clamp(lp.Y, -half.Y, half.Y), math.clamp(lp.Z, -half.Z, half.Z))
	return body.CFrame:PointToWorldSpace(c)
end

local function blocked(origin: Vector3, point: Vector3, model: Model): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex: { Instance } = { model }
	local char = State.Character()
	if char then
		table.insert(ex, char)
	end
	params.FilterDescendantsInstances = ex
	local d = point - origin
	if d.Magnitude < 0.5 then
		return false
	end
	local hit = Workspace:Raycast(origin, d.Unit * (d.Magnitude - 0.3), params)
	return hit ~= nil and hit.Instance.CanCollide and not hit.Instance:GetAttribute("Ground") and hit.Instance.Name ~= "Body"
end

function Targeting.Current(): Model?
	if current and current.Parent then
		return current
	end
	return nil
end

local function score(model: Model, root: BasePart): number?
	local body = model.PrimaryPart
	if not body or model:GetAttribute("Recovering") or model:GetAttribute("Vanished") then
		return nil
	end
	local holders = (model:GetAttribute("Holders") :: number?) or 0
	local max = (model:GetAttribute("MaxHolders") :: number?) or 1
	if holders >= max then
		return nil
	end
	local point = closestPoint(body, root.Position)
	local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	local dist = flat.Magnitude
	if dist > Config.Carry.Reach then
		return nil
	end
	local look = root.CFrame.LookVector
	local dot = dist > 0.1 and look:Dot(flat.Unit) or 1
	if blocked(root.Position, point, model) then
		return nil
	end
	return dist + (1 - dot) * Config.Carry.FacingWeight
end

local function setCurrent(m: Model?)
	if m == current then
		return
	end
	current = m
	highlight.Adornee = m
	highlight.Enabled = m ~= nil
	Targeting.Changed:Fire(m)
end

local function update()
	local root = State.Root()
	local level = Workspace:FindFirstChild("Level")
	local items = level and level:FindFirstChild("Items")
	if not root or not items or State.Player:GetAttribute("Holding") or State.MySlot() == 0 then
		setCurrent(nil)
		return
	end
	local slot = Config.Slots[State.MySlot()]
	if slot then
		highlight.OutlineColor = slot.Color
	end
	local best, bestScore = nil, math.huge
	local currentScore: number? = nil
	for _, m in items:GetChildren() do
		if m:IsA("Model") then
			local s = score(m, root)
			if s then
				if m == current then
					currentScore = s
				end
				if s < bestScore then
					best, bestScore = m, s
				end
			end
		end
	end
	if currentScore and best ~= current and bestScore > currentScore - Config.Carry.TargetHysteresis then
		return -- keep the current target (hysteresis)
	end
	setCurrent(best)
end

function Targeting.Init()
	highlight = Instance.new("Highlight")
	highlight.Name = "GrabTarget"
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.82
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = Workspace
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 / 20 then
			acc = 0
			update()
		end
	end)
end

return Targeting
