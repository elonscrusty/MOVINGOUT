--[[
	ItemService.luau
	Owns the furniture of the loaded level after LevelBuilder creates it: recovery when an
	item falls in water or out of the world (same model, same id, never a duplicate),
	impact sounds, and the "delivered furniture disappears" assist.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local FurnitureData = require(ReplicatedStorage.Shared.FurnitureData)
local S = require(script.Parent.Services)

local ItemService = {}

local connections: { RBXScriptConnection } = {}
local lastImpact: { [Model]: number } = {}
local lastGlobalImpact = 0

local function level()
	return S.World.Level
end

-- Finds a free spot for an item near its home: tries the home, then raised and offset.
local function clearSpot(model: Model, home: CFrame): CFrame
	local body = model.PrimaryPart :: BasePart
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local size = body.Size - Vector3.new(0.3, 0.3, 0.3)
	local offsets = {
		Vector3.zero,
		Vector3.new(0, 1, 0),
		Vector3.new(body.Size.X + 1, 0, 0),
		Vector3.new(-body.Size.X - 1, 0, 0),
		Vector3.new(0, 0, body.Size.Z + 1),
		Vector3.new(0, 0, -body.Size.Z - 1),
	}
	for i = 1, math.min(#offsets, Config.Recovery.ClearanceTries) do
		local cf = home + offsets[i]
		local hits = Workspace:GetPartBoundsInBox(cf, size, params)
		local blocked = false
		for _, h in hits do
			if h.CanCollide and not h:GetAttribute("Ground") then
				blocked = true
				break
			end
		end
		if not blocked then
			return cf
		end
	end
	-- last resort: drop it from above its home
	return home + Vector3.new(0, body.Size.Y + 4, 0)
end

function ItemService.Recover(model: Model, splash: boolean)
	if model:GetAttribute("Recovering") then
		return
	end
	local body = model.PrimaryPart
	local lvl = level()
	if not body or not lvl then
		return
	end
	model:SetAttribute("Recovering", true)
	S.Carry.ReleaseItem(model, "recover")
	S.Fx.All(splash and "Splash" or "Poof", { Pos = body.Position, Item = model.Name })
	body.Anchored = true
	task.delay(Config.Recovery.ItemDelay, function()
		if not model.Parent or level() ~= lvl then
			return
		end
		local home = lvl.ItemHomes[model.Name] or body.CFrame
		local cf = clearSpot(model, home)
		model:PivotTo(cf)
		body.AssemblyLinearVelocity = Vector3.zero
		body.AssemblyAngularVelocity = Vector3.zero
		if not S.World.Paused then
			body.Anchored = false
		end
		model:SetAttribute("Recovering", false)
		S.Fx.All("Poof", { Pos = cf.Position, Item = model.Name })
	end)
end

-- Delivered + assist on: the item fades out and stays counted.
function ItemService.Vanish(model: Model)
	if model:GetAttribute("Vanished") then
		return
	end
	model:SetAttribute("Vanished", true)
	S.Carry.ReleaseItem(model, "vanish")
	local body = model.PrimaryPart
	S.Fx.All("Vanish", { Item = model.Name, Pos = body and body.Position })
	task.delay(0.4, function()
		if model:GetAttribute("Vanished") then
			model.Parent = nil
		end
	end)
end

function ItemService.Step()
	local lvl = level()
	if not lvl or S.World.Paused then
		return
	end
	local bmin, bmax = lvl.Bounds.Min, lvl.Bounds.Max
	for _, model in lvl.Items do
		local body = model.PrimaryPart
		if not body or not model.Parent or model:GetAttribute("Recovering") then
			continue
		end
		local p = body.Position
		local out = p.Y < Config.Recovery.KillY or p.X < bmin.X or p.X > bmax.X or p.Z < bmin.Z or p.Z > bmax.Z
		local wet = S.Hazards.InWater(p)
		if out or wet then
			ItemService.Recover(model, wet)
		end
	end
end

local function hookImpacts(model: Model)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local data = FurnitureData.Kinds[model:GetAttribute("Kind") or ""]
	local soundFamily = data and data.Sound or "Wood"
	local soundName = ({ Wood = "ImpactWood", Soft = "ImpactSoft", Metal = "ImpactMetal", Glass = "ImpactWood" })[soundFamily]
	if data and data.Class == "Heavy" then
		soundName = "ImpactHeavy"
	end
	table.insert(
		connections,
		body.Touched:Connect(function(other)
			if not other.CanCollide then
				return
			end
			local speed = body.AssemblyLinearVelocity.Magnitude
			if speed < Config.SoundRules.ImpactMinSpeed then
				return
			end
			local t = os.clock()
			if (lastImpact[model] and t - lastImpact[model] < Config.SoundRules.ImpactGap) or t - lastGlobalImpact < Config.SoundRules.GlobalImpactGap then
				return
			end
			lastImpact[model] = t
			lastGlobalImpact = t
			S.Fx.All("Impact", { Pos = body.Position, Sound = soundName, Speed = speed })
			if other:GetAttribute("Breakable") then
				S.Breakables.Hit(other, "Impact", body.Position, speed)
			end
		end)
	)
end

-- Called once per loaded level, after LevelBuilder.Build.
function ItemService.Attach()
	ItemService.Detach()
	local lvl = level()
	if not lvl then
		return
	end
	for _, model in lvl.Items do
		hookImpacts(model)
	end
end

function ItemService.Detach()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(lastImpact)
end

-- Anchors / unanchors every item for pause, keeping their velocities.
local savedVel: { [BasePart]: { Vector3 } } = {}
function ItemService.SetFrozen(frozen: boolean)
	local lvl = level()
	if not lvl then
		return
	end
	for _, model in lvl.Items do
		local body = model.PrimaryPart
		if body and model.Parent and not model:GetAttribute("Recovering") then
			if frozen then
				savedVel[body] = { body.AssemblyLinearVelocity, body.AssemblyAngularVelocity }
				body.Anchored = true
			else
				body.Anchored = false
				local v = savedVel[body]
				if v then
					body.AssemblyLinearVelocity = v[1]
					body.AssemblyAngularVelocity = v[2]
				end
			end
		end
	end
	if not frozen then
		table.clear(savedVel)
	end
end

return ItemService
