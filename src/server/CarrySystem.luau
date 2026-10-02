--[[
	CarrySystem.luau
	Physical grabbing, carrying, cooperative handling, throwing and slapping.

	Carrying is made of real constraints, never teleporting:
	  * per holder: a Grip attachment on the item at the point the mover grabbed (the
	    nearest point of the item's box, so a sofa can be grabbed by its near end), a Carry
	    attachment in front of the mover, an AlignPosition pulling grip -> carry with a
	    limited force, and (once the item is in the hands) a RopeConstraint so a stuck item
	    holds its mover back instead of the mover walking away from it.
	  * per held item: an AlignOrientation that only keeps the item upright (yaw is free,
	    so it swings and catches on door frames) and a weak AngularVelocity damper.
	Lift force per holder is a fraction of the item's weight (Config.Carry.LiftPerHolder):
	one mover can't fully lift a heavy item (it drags), two can. Positions of the two grips
	decide the orientation, so walking around each other turns a sofa.
	In solo play (one mover in the job) heavy items get extra lift so every job can be
	finished alone; they stay big, slow and awkward.

	The first holder simulates the item (network owner) so carrying feels responsive.
	Throws switch the item to server simulation and apply a launch velocity.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local S = require(script.Parent.Services)

local CarrySystem = {}

type Hold = {
	Player: Player,
	Grip: Attachment,
	Carry: Attachment,
	Align: AlignPosition,
	Rope: RopeConstraint?,
	NoCollide: { NoCollisionConstraint },
	Since: number,
}

type ItemHold = {
	Model: Model,
	Body: BasePart,
	Holds: { [Player]: Hold },
	Upright: AlignOrientation?,
	Spin: AngularVelocity?,
	UpAttachment: Attachment?,
	Primed: { [Player]: number },
}

local held: { [Model]: ItemHold } = {}
local holding: { [Player]: Model } = {}
local lastThrow: { [Player]: number } = {}
local lastSlap: { [Player]: number } = {}
local lastRelease: { [Player]: number } = {}
local busy: { [Player]: boolean } = {} -- in a throw wind-up

local function simNow(): number
	return S.World.SimTime
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function bodyOf(model: Model): BasePart?
	return model.PrimaryPart
end

local function countHolders(h: ItemHold): number
	local n = 0
	for _ in h.Holds do
		n += 1
	end
	return n
end

local function classOf(model: Model): string
	return (model:GetAttribute("Class") :: string?) or "Light"
end

local function isSolo(): boolean
	return S.Players.MoverCount() <= 1
end

-- Closest point of an item's collider box to a world position.
function CarrySystem.ClosestPoint(body: BasePart, pos: Vector3): (Vector3, Vector3)
	local half = body.Size / 2
	local lp = body.CFrame:PointToObjectSpace(pos)
	local c = Vector3.new(math.clamp(lp.X, -half.X, half.X), math.clamp(lp.Y, -half.Y, half.Y), math.clamp(lp.Z, -half.Z, half.Z))
	return body.CFrame:PointToWorldSpace(c), c
end

-- How much carrying slows a mover (1 = full speed). Resistance from shared load.
function CarrySystem.SpeedFactor(player: Player): number
	local model = holding[player]
	local h = model and held[model]
	if not h then
		return 1
	end
	local class = classOf(model)
	local supplied = 0
	local solo = isSolo()
	for _ in h.Holds do
		supplied += 1 + (solo and (Config.Carry.SoloBonus[class] or 0) or 0)
	end
	if S.World.Assists.EasyHeavy and class == "Heavy" then
		supplied += 0.6
	end
	local need = Config.Carry.Strength[class] or 1
	local t = math.clamp(supplied / need, 0, 1)
	local m = Config.Movement
	return m.CarrySpeedMin + (m.CarrySpeedMax - m.CarrySpeedMin) * t
end

-- Recomputes every holder's force on an item (depends on holder count, solo, assists).
local function refreshForces(h: ItemHold)
	local class = classOf(h.Model)
	local weight = h.Body.AssemblyMass * Workspace.Gravity
	local lift = Config.Carry.LiftPerHolder[class] or 1
	if isSolo() then
		lift += Config.Carry.SoloBonus[class] or 0
	end
	if S.World.Assists.EasyHeavy and class == "Heavy" then
		lift += 0.5
	end
	for player, hold in h.Holds do
		hold.Align.MaxForce = weight * lift
		S.Players.UpdateSpeed(player)
	end
	h.Model:SetAttribute("Holders", countHolders(h))
end

local function setOwner(body: BasePart, player: Player?)
	if body.Anchored then
		return
	end
	pcall(function()
		if player then
			body:SetNetworkOwner(player)
		else
			body:SetNetworkOwnershipAuto()
		end
	end)
end

local function addUpright(h: ItemHold)
	local body = h.Body
	local mass = body.AssemblyMass
	local up = Instance.new("Attachment")
	up.Name = "UprightAttachment"
	up.Parent = body
	local ao = Instance.new("AlignOrientation")
	ao.Name = "Upright"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = up
	ao.AlignType = Enum.AlignType.PrimaryAxisParallel
	ao.PrimaryAxis = Vector3.yAxis
	up.Axis = Vector3.yAxis
	up.SecondaryAxis = Vector3.xAxis
	ao.MaxTorque = mass * Config.Carry.UprightTorque
	ao.Responsiveness = Config.Carry.UprightResponsiveness
	ao.Parent = body
	local av = Instance.new("AngularVelocity")
	av.Name = "SpinDamper"
	av.Attachment0 = up
	av.AngularVelocity = Vector3.zero
	av.MaxTorque = mass * Config.Carry.SpinDamping
	av.RelativeTo = Enum.ActuatorRelativeTo.World
	av.Parent = body
	h.Upright = ao
	h.Spin = av
	h.UpAttachment = up
end

local function removeUpright(h: ItemHold)
	if h.Upright then
		h.Upright:Destroy()
	end
	if h.Spin then
		h.Spin:Destroy()
	end
	if h.UpAttachment then
		h.UpAttachment:Destroy()
	end
	h.Upright = nil
	h.Spin = nil
	h.UpAttachment = nil
end

local function destroyHold(hold: Hold, keepNoCollide: number?)
	hold.Align:Destroy()
	if hold.Rope then
		hold.Rope:Destroy()
	end
	hold.Grip:Destroy()
	hold.Carry:Destroy()
	if keepNoCollide and keepNoCollide > 0 then
		local list = hold.NoCollide
		task.delay(keepNoCollide, function()
			for _, nc in list do
				nc:Destroy()
			end
		end)
	else
		for _, nc in hold.NoCollide do
			nc:Destroy()
		end
	end
end

-- Detaches one player from whatever they hold. Safe to call any time.
function CarrySystem.ReleasePlayer(player: Player, reason: string?)
	local model = holding[player]
	holding[player] = nil
	busy[player] = nil
	player:SetAttribute("Holding", nil)
	player:SetAttribute("HoldingClass", nil)
	player:SetAttribute("Windup", nil)
	lastRelease[player] = simNow()
	if not model then
		S.Players.UpdateSpeed(player)
		return
	end
	local h = held[model]
	if not h then
		S.Players.UpdateSpeed(player)
		return
	end
	local hold = h.Holds[player]
	if hold then
		h.Holds[player] = nil
		destroyHold(hold, reason == "throw" and 0.3 or 0)
	end
	h.Primed[player] = nil
	model:SetAttribute("Primed", 0)
	local remaining = countHolders(h)
	if remaining == 0 then
		removeUpright(h)
		held[model] = nil
		model:SetAttribute("Holders", 0)
		if reason ~= "throw" then
			setOwner(h.Body, nil)
		end
	else
		-- hand simulation to a remaining holder
		for other in h.Holds do
			setOwner(h.Body, other)
			break
		end
		refreshForces(h)
	end
	S.Players.UpdateSpeed(player)
	if reason == "release" then
		S.Fx.All("Sound", { Name = "Release", Pos = h.Body.Position })
	end
end

-- Detaches every holder from an item (recovery, vanish, throw, level end).
function CarrySystem.ReleaseItem(model: Model, reason: string?)
	local h = held[model]
	if not h then
		return
	end
	local players = {}
	for p in h.Holds do
		table.insert(players, p)
	end
	for _, p in players do
		CarrySystem.ReleasePlayer(p, reason)
	end
end

function CarrySystem.ReleaseAll()
	for player in holding do
		CarrySystem.ReleasePlayer(player, "reset")
	end
	for model, h in held do
		removeUpright(h)
		held[model] = nil
	end
end

-- After a pause (anchoring drops network ownership) give held items back to a holder.
function CarrySystem.RefreshOwners()
	for _, h in held do
		for p in h.Holds do
			setOwner(h.Body, p)
			break
		end
	end
end

-- Mover count changed (solo <-> group): recompute every held item's forces.
function CarrySystem.RefreshAll()
	for _, h in held do
		refreshForces(h)
	end
end

function CarrySystem.Holding(player: Player): Model?
	return holding[player]
end

function CarrySystem.IsHeld(model: Model): boolean
	local h = held[model]
	return h ~= nil and next(h.Holds) ~= nil
end

local function canAct(player: Player): boolean
	if S.World.Paused or not S.World.Active then
		return false
	end
	if S.Jobs.Phase() ~= "Playing" and S.Jobs.Phase() ~= "Lobby" then
		return false
	end
	if S.Players.IsStunned(player) or player:GetAttribute("Recovering") then
		return false
	end
	return S.Players.Root(player) ~= nil
end

local function itemFromId(id: any): Model?
	local level = S.World.Level
	if type(id) ~= "string" or not level then
		return nil
	end
	local m = level.Items[id]
	if m and m.Parent and not m:GetAttribute("Recovering") and not m:GetAttribute("Vanished") then
		return m
	end
	return nil
end

-- Grab request from a client: validates reach, line of sight and free grip space.
function CarrySystem.Grab(player: Player, itemId: any)
	if holding[player] then
		CarrySystem.ReleasePlayer(player, "release")
		return
	end
	if not canAct(player) then
		return
	end
	if lastRelease[player] and simNow() - lastRelease[player] < Config.Carry.DropProtect then
		return
	end
	local model = itemFromId(itemId)
	local root = S.Players.Root(player)
	if not model or not root then
		return
	end
	local body = bodyOf(model)
	if not body or body.Anchored then
		return
	end
	local h = held[model]
	local max = model:GetAttribute("MaxHolders") or 1
	if h and countHolders(h) >= max then
		S.Fx.Toast(player, "No room to grab that")
		return
	end

	local point, localPoint = CarrySystem.ClosestPoint(body, root.Position)
	local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	if flat.Magnitude > Config.Carry.Reach + Config.Carry.ServerReachSlack then
		return
	end

	-- line of sight: nothing solid between the mover and the grab point
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { model }
	for _, p in S.Players.Movers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local origin = root.Position
	local toPoint = point - origin
	if toPoint.Magnitude > 0.5 then
		local hit = Workspace:Raycast(origin, toPoint.Unit * (toPoint.Magnitude - 0.3), params)
		if hit and hit.Instance.CanCollide and not hit.Instance:GetAttribute("Ground") then
			S.Fx.Toast(player, "Can't reach - something is in the way")
			return
		end
	end

	-- grip height: around the mover's waist, inside the item's box
	local half = body.Size / 2
	local rootLocalY = body.CFrame:PointToObjectSpace(root.Position).Y
	local gy = math.clamp(rootLocalY, -half.Y + math.min(0.6, half.Y * 0.5), half.Y - math.min(0.3, half.Y * 0.3))
	local gripLocal = Vector3.new(localPoint.X, gy, localPoint.Z)

	-- don't let two movers grab the same spot
	if h then
		for _, other in h.Holds do
			if (other.Grip.Position - gripLocal).Magnitude < Config.Carry.GripSpacing then
				S.Fx.Toast(player, "Spot taken - grab the other end")
				return
			end
		end
	end

	if not h then
		h = { Model = model, Body = body, Holds = {}, Primed = {} } :: ItemHold
		held[model] = h
		addUpright(h :: ItemHold)
	end
	local hh = h :: ItemHold

	local grip = Instance.new("Attachment")
	grip.Name = "Grip_" .. player.UserId
	grip.Position = gripLocal
	grip.Parent = body

	local class = classOf(model)
	local liftHeight = class == "Light" and 1.4 or (class == "Medium" and 0.8 or 0.55)
	local gripWorld = body.CFrame:PointToWorldSpace(gripLocal)
	local carryY = math.clamp(gripWorld.Y - root.Position.Y + liftHeight, -2.4, 1.6)
	local carry = Instance.new("Attachment")
	carry.Name = "Carry_" .. model.Name
	carry.Position = Vector3.new(Config.Carry.HoldOffset.X, carryY, Config.Carry.HoldOffset.Z)
	carry.Parent = root

	local align = Instance.new("AlignPosition")
	align.Name = "CarryAlign"
	align.Mode = Enum.PositionAlignmentMode.TwoAttachment
	align.Attachment0 = grip
	align.Attachment1 = carry
	align.ReactionForceEnabled = false
	align.ApplyAtCenterOfMass = false
	align.Responsiveness = Config.Carry.Responsiveness
	align.MaxVelocity = Config.Carry.MaxVelocity
	align.Parent = body

	local noCollide = {}
	for _, d in (player.Character :: Model):GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			local nc = Instance.new("NoCollisionConstraint")
			nc.Part0 = body
			nc.Part1 = d
			nc.Parent = body
			table.insert(noCollide, nc)
		end
	end

	hh.Holds[player] = {
		Player = player,
		Grip = grip,
		Carry = carry,
		Align = align,
		Rope = nil,
		NoCollide = noCollide,
		Since = simNow(),
	}
	holding[player] = model
	player:SetAttribute("Holding", model.Name)
	player:SetAttribute("HoldingClass", class)
	if countHolders(hh) == 1 then
		setOwner(body, player)
	end
	refreshForces(hh)
	S.Fx.All("Grab", { UserId = player.UserId, Item = model.Name, Pos = gripWorld })
end

-- Per-frame upkeep: ropes engage once the item is in the hands, broken holds release.
function CarrySystem.Step()
	for model, h in held do
		if not model.Parent or model:GetAttribute("Recovering") then
			CarrySystem.ReleaseItem(model, "reset")
			continue
		end
		for player, hold in h.Holds do
			local root = S.Players.Root(player)
			if not root or not player.Parent then
				CarrySystem.ReleasePlayer(player, "lost")
				continue
			end
			local d = (hold.Grip.WorldPosition - hold.Carry.WorldPosition).Magnitude
			if not hold.Rope and d < 3.4 then
				local rope = Instance.new("RopeConstraint")
				rope.Name = "CarryRope"
				rope.Attachment0 = hold.Grip
				rope.Attachment1 = hold.Carry
				rope.Length = 3.6
				rope.Restitution = 0
				rope.Visible = false
				rope.Parent = h.Body
				hold.Rope = rope
			elseif d > 11 then
				CarrySystem.ReleasePlayer(player, "lost")
				S.Fx.Toast(player, "Lost your grip!")
			elseif not hold.Rope and simNow() - hold.Since > 2.5 and d > 6 then
				-- never pulled into the hands (wedged): let go rather than strain forever
				CarrySystem.ReleasePlayer(player, "lost")
				S.Fx.Toast(player, "It's stuck - try another angle")
			end
		end
	end
end

----------------------------------------------------------------------------------------
-- Throwing

local function launch(model: Model, direction: Vector3, class: string, strength: number, throwers: { Player })
	local body = bodyOf(model)
	if not body or not model.Parent then
		return
	end
	for _, p in throwers do
		CarrySystem.ReleasePlayer(p, "throw")
		lastThrow[p] = simNow()
	end
	CarrySystem.ReleaseItem(model, "throw")
	pcall(function()
		body:SetNetworkOwner(nil)
	end)
	local v = Config.Throw.Velocity[class] or Config.Throw.Velocity.Light
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit
	body.AssemblyLinearVelocity = flat * v.Forward * strength + Vector3.new(0, v.Up * strength, 0)
	if class == "Light" then
		body.AssemblyAngularVelocity = Vector3.new(flat.Z, 0, -flat.X) * 6
	end
	model:SetAttribute("Thrown", serverNow())
	local ids = {}
	for _, p in throwers do
		table.insert(ids, p.UserId)
	end
	S.Fx.All("Throw", { Item = model.Name, Pos = body.Position, Coop = #throwers > 1, Throwers = ids })
	task.delay(Config.Throw.ServerOwnSeconds, function()
		if model.Parent and not CarrySystem.IsHeld(model) and not body.Anchored then
			pcall(function()
				body:SetNetworkOwnershipAuto()
			end)
		end
	end)
end

function CarrySystem.Throw(player: Player)
	local model = holding[player]
	if not model or busy[player] or not canAct(player) then
		return
	end
	if lastThrow[player] and simNow() - lastThrow[player] < Config.Throw.Cooldown then
		return
	end
	local h = held[model]
	local root = S.Players.Root(player)
	if not h or not root then
		return
	end
	local class = classOf(model)
	local n = countHolders(h)

	if n == 1 then
		if class == "Heavy" then
			S.Fx.Toast(player, "Too heavy to throw alone - get a partner on the other end!")
			S.Fx.To(player, "Sound", { Name = "Error" })
			return
		end
		busy[player] = true
		player:SetAttribute("Windup", serverNow())
		S.Fx.All("Windup", { UserId = player.UserId, Pos = root.Position })
		task.delay(Config.Throw.Windup, function()
			busy[player] = nil
			player:SetAttribute("Windup", nil)
			if holding[player] ~= model or S.World.Paused then
				return
			end
			local r = S.Players.Root(player)
			if r then
				launch(model, r.CFrame.LookVector, class, 1, { player })
			end
		end)
		return
	end

	-- cooperative throw: every holder presses within the window
	h.Primed[player] = simNow()
	local primed = 0
	for p, t in h.Primed do
		if h.Holds[p] and simNow() - t <= Config.Throw.CoopWindow then
			primed += 1
		end
	end
	model:SetAttribute("Primed", primed)
	model:SetAttribute("PrimedAt", serverNow())
	S.Fx.All("Windup", { UserId = player.UserId, Pos = root.Position, Coop = true })
	if primed >= n then
		local throwers = {}
		local dir = Vector3.zero
		for p in h.Holds do
			table.insert(throwers, p)
			local r = S.Players.Root(p)
			if r then
				dir += r.CFrame.LookVector
			end
			busy[p] = true
			p:SetAttribute("Windup", serverNow())
		end
		if Vector3.new(dir.X, 0, dir.Z).Magnitude < 0.3 then
			dir = root.CFrame.LookVector -- facing each other: the last presser decides
		end
		local strength = class == "Heavy" and 1 or 1.15
		task.delay(Config.Throw.CoopWindup, function()
			for _, p in throwers do
				busy[p] = nil
				p:SetAttribute("Windup", nil)
			end
			if S.World.Paused or not held[model] then
				return
			end
			launch(model, dir, class, strength, throwers)
		end)
	else
		local stamp = h.Primed[player]
		task.delay(Config.Throw.CoopWindow + 0.05, function()
			local hh = held[model]
			if hh and hh.Primed[player] == stamp then
				hh.Primed[player] = nil
				model:SetAttribute("Primed", 0)
				for p in hh.Holds do
					S.Fx.Toast(p, "Throw together! Both press throw at the same time.")
				end
			end
		end)
	end
end

----------------------------------------------------------------------------------------
-- Slapping

function CarrySystem.Slap(player: Player)
	if not canAct(player) or busy[player] then
		return
	end
	if lastSlap[player] and simNow() - lastSlap[player] < Config.Slap.Cooldown then
		return
	end
	lastSlap[player] = simNow()
	local root = S.Players.Root(player)
	if not root then
		return
	end
	player:SetAttribute("SlapAt", serverNow())
	S.Fx.All("Slap", { UserId = player.UserId, Pos = root.Position })
	task.delay(0.1, function()
		local r = S.Players.Root(player)
		if not r or S.World.Paused then
			return
		end
		local cf = r.CFrame * CFrame.new(0, 0, -Config.Slap.Range / 2)
		local size = Vector3.new(Config.Slap.Radius * 2, 6, Config.Slap.Range)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Model }
		local parts = Workspace:GetPartBoundsInBox(cf, size, params)
		local hitPlayers: { [Player]: boolean } = {}
		local hitItems: { [Model]: boolean } = {}
		local landed = false
		for _, part in parts do
			local char = part:FindFirstAncestorOfClass("Model")
			local other = char and game:GetService("Players"):GetPlayerFromCharacter(char)
			if other and other ~= player and not hitPlayers[other] then
				hitPlayers[other] = true
				local away = (part.Position - r.Position) * Vector3.new(1, 0, 1)
				away = away.Magnitude > 0.01 and away.Unit or r.CFrame.LookVector
				S.Players.Knock(other, away * Config.Slap.PlayerKnock + Vector3.new(0, 12, 0))
				S.Players.Stun(other, Config.Slap.PlayerStun, false)
				landed = true
			elseif part:GetAttribute("Ghost") or (part.Parent and part.Parent:GetAttribute("Ghost")) then
				S.Hazards.StunGhost(part.Parent :: Instance)
				landed = true
			elseif part:GetAttribute("Breakable") then
				S.Breakables.Hit(part, "Slap", r.Position)
				landed = true
			elseif part.Name == "Body" and part.Parent and part.Parent:GetAttribute("ItemId") then
				local m = part.Parent :: Model
				if not hitItems[m] and not CarrySystem.IsHeld(m) and not part.Anchored then
					hitItems[m] = true
					pcall(function()
						part:SetNetworkOwner(nil)
					end)
					local push = Config.Slap.ItemPush / math.max(1, part.AssemblyMass / 8)
					part.AssemblyLinearVelocity += r.CFrame.LookVector * push + Vector3.new(0, push * 0.3, 0)
					task.delay(1, function()
						if part.Parent and not CarrySystem.IsHeld(m) and not part.Anchored then
							pcall(function()
								part:SetNetworkOwnershipAuto()
							end)
						end
					end)
					landed = true
				end
			end
		end
		if landed then
			S.Fx.All("Sound", { Name = "SlapHit", Pos = r.Position + r.CFrame.LookVector * 2 })
		end
	end)
end

return CarrySystem
