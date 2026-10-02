--[[
	Hazards.luau
	Environmental hazards and moving surfaces, built from a level's Hazards list:

	  Water     { Kind="Water", Min={x,z}, Max={x,z}, Depth? }  pool / river basin. Movers
	            respawn, furniture is recovered (same item) after a splash.
	  Conveyor  { Kind="Conveyor", Min, Max, Dir={x,z}, Speed }  an anchored belt whose
	            surface velocity physically carries movers and furniture.
	  Platform  { Kind="Platform", Path={{x,y,z},...}, Size={x,y,z}, Speed, Wait }  a raft /
	            lift that ping-pongs along a path; moved kinematically with a matching
	            surface velocity so things standing on it ride along.
	  Traffic   { Kind="Traffic", A={x,z}, B={x,z}, Interval={min,max}, Width? }  cars drive
	            down a visible lane after a flashing, honking warning. A hit knocks and
	            briefly stuns movers and knocks furniture; nothing is ever deleted.
	  Ghost     { Kind="Ghost", Patrol={{x,z},...} }  wanders a patrol loop, rears up when
	            it notices a mover, chases briefly, spooks (stun + drop) and then backs
	            off. A slap stuns it.
	"Reduced hazards" assist: longer gaps between cars, slower ghosts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local S = require(script.Parent.Services)

local Hazards = {}

local V = Vector3.new
local CF = CFrame.new

type Water = { Min: Vector3, Max: Vector3, Surface: number }
local waters: { Water } = {}
local platforms: { any } = {}
local lanes: { any } = {}
local ghosts: { any } = {}
local folder: Folder? = nil
local rng = Random.new()

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Hazard"
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function v2(t: any): Vector2
	return Vector2.new(t[1], t[2])
end

local function scale(): (number, number)
	if S.World.Assists.ReducedHazards then
		return Config.Hazards.ReducedIntervalScale, Config.Hazards.ReducedSpeedScale
	end
	return 1, 1
end

----------------------------------------------------------------------------------------
-- Water

local function buildWater(h: any, parent: Instance)
	local min, max = v2(h.Min), v2(h.Max)
	local depth = h.Depth or 5
	local size = max - min
	local centre = (min + max) / 2
	local tile = h.EdgeColor or Color3.fromRGB(236, 240, 244)
	-- basin floor and walls
	part(parent, V(size.X, 1, size.Y), CF(centre.X, -depth - 0.5, centre.Y), h.FloorColor or Color3.fromRGB(80, 170, 210), Enum.Material.CeramicTiles, "PoolFloor")
	for _, side in { { V(size.X, depth, 0.6), V(0, 0, -size.Y / 2 - 0.3) }, { V(size.X, depth, 0.6), V(0, 0, size.Y / 2 + 0.3) }, { V(0.6, depth, size.Y + 1.2), V(-size.X / 2 - 0.3, 0, 0) }, { V(0.6, depth, size.Y + 1.2), V(size.X / 2 + 0.3, 0, 0) } } do
		part(parent, side[1], CF(centre.X, -depth / 2, centre.Y) + side[2], tile, Enum.Material.CeramicTiles, "PoolWall")
	end
	-- coping (rim) so the edge reads clearly
	if h.Coping ~= false then
		for _, side in { { V(size.X + 2.4, 0.3, 1.2), V(0, 0, -size.Y / 2 - 0.6) }, { V(size.X + 2.4, 0.3, 1.2), V(0, 0, size.Y / 2 + 0.6) }, { V(1.2, 0.3, size.Y), V(-size.X / 2 - 0.6, 0, 0) }, { V(1.2, 0.3, size.Y), V(size.X / 2 + 0.6, 0, 0) } } do
			local c = part(parent, side[1], CF(centre.X, 0.1, centre.Y) + side[2], tile, Enum.Material.SmoothPlastic, "Coping")
			c:SetAttribute("Ground", true)
		end
	end
	local surfaceY = -(h.SurfaceDrop or 0.9)
	local water = part(parent, V(size.X, 0.4, size.Y), CF(centre.X, surfaceY, centre.Y), h.Color or Color3.fromRGB(70, 180, 235), Enum.Material.Glass, "Water")
	water.Transparency = 0.35
	water.CanCollide = false
	water.CanQuery = false
	water.CanTouch = false
	water:SetAttribute("Water", true)
	table.insert(waters, { Min = V(min.X, 0, min.Y), Max = V(max.X, 0, max.Y), Surface = surfaceY })
end

-- True when a position is under a water surface (movers / items get recovered).
function Hazards.InWater(pos: Vector3): boolean
	for _, w in waters do
		if pos.X > w.Min.X and pos.X < w.Max.X and pos.Z > w.Min.Z and pos.Z < w.Max.Z and pos.Y < w.Surface - 0.2 then
			return true
		end
	end
	return false
end

-- Rectangles of water, so LevelBuilder can leave holes in the ground for them.
function Hazards.WaterRects(level: any): { { Min: Vector2, Max: Vector2 } }
	local list = {}
	for _, h in level.Hazards or {} do
		if h.Kind == "Water" then
			table.insert(list, { Min = v2(h.Min), Max = v2(h.Max) })
		end
	end
	return list
end

----------------------------------------------------------------------------------------
-- Conveyors

local function buildConveyor(h: any, parent: Instance)
	local min, max = v2(h.Min), v2(h.Max)
	local size = max - min
	local centre = (min + max) / 2
	local dir = Vector3.new(h.Dir[1], 0, h.Dir[2]).Unit
	local belt = part(parent, V(size.X, 0.5, size.Y), CF(centre.X, -0.13, centre.Y), Color3.fromRGB(60, 62, 70), Enum.Material.Fabric, "Conveyor")
	belt.CustomPhysicalProperties = PhysicalProperties.new(1, 1.2, 0, 1, 1)
	belt.AssemblyLinearVelocity = dir * (h.Speed or 8)
	belt:SetAttribute("BeltVelocity", dir * (h.Speed or 8))
	belt:SetAttribute("Ground", true)
	belt:SetAttribute("Conveyor", true)
	-- yellow side rails (low, decorative edges) and chevrons showing the direction
	local alongX = math.abs(dir.X) > 0.5
	local len = alongX and size.X or size.Y
	local n = math.max(1, math.floor(len / 4))
	local yaw = math.atan2(-dir.X, -dir.Z)
	for i = 0, n - 1 do
		local t = (i + 0.5) / n - 0.5
		local pos = alongX and V(centre.X + t * size.X, 0.14, centre.Y) or V(centre.X, 0.14, centre.Y + t * size.Y)
		for _, s in { -1, 1 } do
			local arm = part(parent, V(0.35, 0.05, 1.6), CF(pos) * CFrame.Angles(0, yaw, 0) * CF(s * 0.5, 0, 0) * CFrame.Angles(0, math.rad(s * 40), 0), Color3.fromRGB(250, 210, 60), Enum.Material.Neon, "Chevron")
			arm.CanCollide = false
			arm.CanQuery = false
			arm.CanTouch = false
		end
	end
	for _, s in { -1, 1 } do
		local railPos = alongX and V(centre.X, 0.05, centre.Y + s * (size.Y / 2 + 0.25)) or V(centre.X + s * (size.X / 2 + 0.25), 0.05, centre.Y)
		local railSize = alongX and V(size.X, 0.35, 0.5) or V(0.5, 0.35, size.Y)
		local rail = part(parent, railSize, CF(railPos), Color3.fromRGB(250, 200, 50), Enum.Material.SmoothPlastic, "ConveyorRail")
		rail.CanCollide = false
	end
end

----------------------------------------------------------------------------------------
-- Moving platforms

local function buildPlatform(h: any, parent: Instance)
	local s = h.Size or { 8, 1, 8 }
	local size = V(s[1], s[2], s[3])
	local path = {}
	for _, p in h.Path do
		table.insert(path, V(p[1], p[2], p[3]))
	end
	local p = part(parent, size, CF(path[1]), h.Color or Color3.fromRGB(250, 140, 170), Enum.Material.SmoothPlastic, "Platform")
	p.CustomPhysicalProperties = PhysicalProperties.new(1, 1.5, 0, 1, 1)
	p:SetAttribute("Ground", true)
	-- inflatable ring look
	for _, side in { { V(size.X, 1, 1), V(0, 0.6, size.Z / 2 - 0.5) }, { V(size.X, 1, 1), V(0, 0.6, -size.Z / 2 + 0.5) }, { V(1, 1, size.Z), V(size.X / 2 - 0.5, 0.6, 0) }, { V(1, 1, size.Z), V(-size.X / 2 + 0.5, 0.6, 0) } } do
		local rim = part(parent, side[1], p.CFrame + side[2], Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, "PlatformRim")
		rim.CanCollide = false
		rim.CanQuery = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = p
		w.Part1 = rim
		w.Parent = rim
		rim.Anchored = false
		rim.Massless = true
	end
	table.insert(platforms, { Part = p, Path = path, Speed = h.Speed or 6, Wait = h.Wait or 1.5, Index = 1, Dir = 1, WaitLeft = h.Wait or 1.5 })
end

local function stepPlatforms(dt: number)
	for _, pl in platforms do
		local p: Part = pl.Part
		if pl.WaitLeft > 0 then
			pl.WaitLeft -= dt
			p.AssemblyLinearVelocity = Vector3.zero
			continue
		end
		local nextIndex = pl.Index + pl.Dir
		if nextIndex < 1 or nextIndex > #pl.Path then
			pl.Dir = -pl.Dir
			nextIndex = pl.Index + pl.Dir
		end
		local target = pl.Path[nextIndex]
		local pos = p.Position
		local delta = target - pos
		local stepLen = pl.Speed * dt
		if delta.Magnitude <= stepLen then
			p.CFrame = CF(target)
			p.AssemblyLinearVelocity = Vector3.zero
			pl.Index = nextIndex
			pl.WaitLeft = pl.Wait
		else
			local v = delta.Unit * pl.Speed
			p.CFrame = CF(pos + delta.Unit * stepLen)
			p.AssemblyLinearVelocity = v
		end
	end
end

----------------------------------------------------------------------------------------
-- Traffic

local function buildCar(parent: Instance, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "Car"
	local body = part(m, V(5.6, 2.4, 9), CF(0, 1.9, 0), color, Enum.Material.SmoothPlastic, "CarBody")
	body.CanCollide = false
	m.PrimaryPart = body
	local cab = part(m, V(5, 2, 5), CF(0, 4, 0.5), color:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.SmoothPlastic, "CarCab")
	cab.CanCollide = false
	local glass = part(m, V(4.6, 1.6, 5.1), CF(0, 4.05, 0.5), Color3.fromRGB(150, 200, 230), Enum.Material.Glass, "CarGlass")
	glass.Transparency = 0.3
	glass.CanCollide = false
	for _, x in { -2.6, 2.6 } do
		for _, z in { -3, 3 } do
			local w = part(m, V(1, 2, 2), CF(x, 1, z), Color3.fromRGB(30, 30, 34), Enum.Material.SmoothPlastic, "Wheel")
			w.Shape = Enum.PartType.Cylinder
			w.CanCollide = false
		end
	end
	for _, x in { -1.8, 1.8 } do
		local light = part(m, V(1, 0.6, 0.2), CF(x, 2.3, -4.5), Color3.fromRGB(255, 250, 200), Enum.Material.Neon, "Headlight")
		light.CanCollide = false
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	m.Parent = parent
	return m
end

local CAR_COLORS = {
	Color3.fromRGB(80, 140, 230),
	Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(120, 200, 120),
	Color3.fromRGB(230, 120, 60),
	Color3.fromRGB(180, 110, 210),
}

local function buildLane(h: any, parent: Instance)
	local a = V(h.A[1], 0, h.A[2])
	local b = V(h.B[1], 0, h.B[2])
	local dir = (b - a).Unit
	local width = h.Width or 7
	local lights = {}
	-- warning lamps along both kerbs
	local len = (b - a).Magnitude
	local n = math.max(2, math.floor(len / 12))
	local side = Vector3.new(-dir.Z, 0, dir.X)
	for i = 0, n do
		local p = a + dir * (i / n * len)
		for _, s in { -1, 1 } do
			local lamp = part(parent, V(0.8, 0.5, 0.8), CF(p + side * s * (width / 2 + 0.6) + V(0, 0.25, 0)), Color3.fromRGB(120, 60, 40), Enum.Material.SmoothPlastic, "WarnLamp")
			lamp.CanCollide = false
			table.insert(lights, lamp)
		end
	end
	local interval = h.Interval or { 6, 10 }
	table.insert(lanes, {
		A = a,
		B = b,
		Dir = dir,
		Width = width,
		Lights = lights,
		Interval = interval,
		Next = rng:NextNumber(interval[1], interval[2]),
		State = "Idle",
		Timer = 0,
		Car = nil :: Model?,
		Parent = parent,
		Hit = {} :: { [Instance]: boolean },
	})
end

local function setLights(lane: any, on: boolean)
	for _, l in lane.Lights do
		l.Color = on and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(120, 60, 40)
		l.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
end

local function carHits(lane: any, car: Model)
	local body = car.PrimaryPart :: BasePart
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car }
	local hits = Workspace:GetPartBoundsInBox(body.CFrame + V(0, 0.8, 0), V(6, 5, 9.5), params)
	for _, p in hits do
		local m = p:FindFirstAncestorOfClass("Model")
		if not m then
			continue
		end
		local player = Players:GetPlayerFromCharacter(m)
		if player and not lane.Hit[player] and not S.Players.IsProtected(player) then
			lane.Hit[player] = true
			local away = (p.Position - body.Position) * V(1, 0, 1)
			local push = lane.Dir * Config.Hazards.CarKnock + (away.Magnitude > 0.1 and away.Unit * 20 or Vector3.zero) + V(0, 30, 0)
			S.Players.Stun(player, Config.Stun.CarHit, true)
			S.Players.Knock(player, push)
			S.Fx.All("Sound", { Name = "CarHit", Pos = p.Position })
		elseif m:GetAttribute("ItemId") and p.Name == "Body" and not lane.Hit[m] then
			lane.Hit[m] = true
			S.Carry.ReleaseItem(m, "knock")
			pcall(function()
				p:SetNetworkOwner(nil)
			end)
			local push = Config.Hazards.ItemKnock / math.max(1, p.AssemblyMass / 10)
			p.AssemblyLinearVelocity = lane.Dir * push + V(0, push * 0.5, 0)
			S.Fx.All("Sound", { Name = "CarHit", Pos = p.Position })
			task.delay(1.5, function()
				if p.Parent and not S.Carry.IsHeld(m) and not p.Anchored then
					pcall(function()
						p:SetNetworkOwnershipAuto()
					end)
				end
			end)
		end
	end
end

local function stepLanes(dt: number)
	local intervalScale, speedScale = scale()
	for _, lane in lanes do
		if lane.State == "Idle" then
			lane.Next -= dt
			if lane.Next <= 0 then
				lane.State = "Warn"
				lane.Timer = Config.Hazards.CarWarnTime
				S.Fx.All("Honk", { Pos = lane.A + V(0, 2, 0) })
			end
		elseif lane.State == "Warn" then
			lane.Timer -= dt
			setLights(lane, math.floor(lane.Timer * 6) % 2 == 0)
			if lane.Timer <= 0 then
				setLights(lane, true)
				local car = buildCar(lane.Parent, CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)])
				local yaw = math.atan2(-lane.Dir.X, -lane.Dir.Z)
				car:PivotTo(CF(lane.A) * CFrame.Angles(0, yaw, 0))
				lane.Car = car
				lane.Dist = 0
				lane.State = "Drive"
				table.clear(lane.Hit)
			end
		elseif lane.State == "Drive" then
			local car = lane.Car :: Model
			local total = (lane.B - lane.A).Magnitude
			lane.Dist += Config.Hazards.CarSpeed * speedScale * dt
			local yaw = math.atan2(-lane.Dir.X, -lane.Dir.Z)
			car:PivotTo(CF(lane.A + lane.Dir * lane.Dist) * CFrame.Angles(0, yaw, 0))
			carHits(lane, car)
			if lane.Dist >= total then
				car:Destroy()
				lane.Car = nil
				lane.State = "Idle"
				setLights(lane, false)
				lane.Next = rng:NextNumber(lane.Interval[1], lane.Interval[2]) * intervalScale
			end
		end
	end
end

----------------------------------------------------------------------------------------
-- Ghosts

local function buildGhost(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Ghost"
	m:SetAttribute("Ghost", true)
	local body = part(m, V(3.4, 4, 3.4), CF(0, 0, 0), Color3.fromRGB(236, 240, 255), Enum.Material.SmoothPlastic, "GhostBody")
	body.Shape = Enum.PartType.Ball
	body.Transparency = 0.2
	body.CanCollide = false
	body:SetAttribute("Ghost", true)
	m.PrimaryPart = body
	local tail = part(m, V(2.6, 2.2, 2.6), CF(0, -2, 0), Color3.fromRGB(236, 240, 255), Enum.Material.SmoothPlastic, "GhostTail")
	tail.Shape = Enum.PartType.Ball
	tail.Transparency = 0.35
	tail.CanCollide = false
	for _, x in { -0.65, 0.65 } do
		local eye = part(m, V(0.6, 0.9, 0.3), CF(x, 0.4, -1.55), Color3.fromRGB(30, 30, 50), Enum.Material.SmoothPlastic, "GhostEye")
		eye.Shape = Enum.PartType.Ball
		eye.CanCollide = false
	end
	local mouth = part(m, V(0.8, 0.6, 0.3), CF(0, -0.5, -1.55), Color3.fromRGB(30, 30, 50), Enum.Material.SmoothPlastic, "GhostMouth")
	mouth.Shape = Enum.PartType.Ball
	mouth.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 200, 255)
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = body
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanTouch = false
		end
	end
	m.Parent = parent
	return m
end

local function buildGhostHazard(h: any, parent: Instance)
	local patrol = {}
	for _, p in h.Patrol do
		table.insert(patrol, V(p[1], 4.2, p[2]))
	end
	local m = buildGhost(parent)
	m:PivotTo(CF(patrol[1]))
	table.insert(ghosts, { Model = m, Patrol = patrol, Index = 1, State = "Wander", Timer = 0, Target = nil :: Player?, Pos = patrol[1] })
end

function Hazards.StunGhost(model: Instance)
	for _, g in ghosts do
		if g.Model == model and g.State ~= "Stunned" then
			g.State = "Stunned"
			g.Timer = Config.Slap.GhostStun
			g.Model:SetAttribute("State", "Stunned")
			S.Fx.All("GhostStun", { Pos = g.Pos })
		end
	end
end

local function nearestMover(pos: Vector3, range: number): (Player?, number)
	local best, bestD = nil, range
	for _, p in S.Players.Movers() do
		local r = S.Players.Root(p)
		if r and not S.Players.IsStunned(p) and not S.Players.IsProtected(p) then
			local d = ((r.Position - pos) * V(1, 0, 1)).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best, bestD
end

local function stepGhosts(dt: number)
	local _, speedScale = scale()
	local t = S.World.SimTime
	for _, g in ghosts do
		local pos: Vector3 = g.Pos
		local moveTo: Vector3? = nil
		local speed = Config.Hazards.GhostSpeed * speedScale
		if g.State == "Stunned" or g.State == "Cooldown" then
			g.Timer -= dt
			if g.State == "Cooldown" then
				moveTo = g.Patrol[g.Index]
			end
			if g.Timer <= 0 then
				g.State = "Wander"
			end
		elseif g.State == "Wander" then
			moveTo = g.Patrol[g.Index]
			local target = nearestMover(pos, Config.Hazards.GhostNotice)
			if target then
				g.State = "Notice"
				g.Timer = 0.7 -- anticipation: it rears up before chasing
				g.Target = target
				S.Fx.All("Ghost", { Pos = pos })
			end
		elseif g.State == "Notice" then
			g.Timer -= dt
			if g.Timer <= 0 then
				g.State = "Chase"
				g.Timer = 3
			end
		elseif g.State == "Chase" then
			g.Timer -= dt
			local target = g.Target
			local r = target and S.Players.Root(target)
			if not r or g.Timer <= 0 or S.Players.IsStunned(target :: Player) then
				g.State = "Cooldown"
				g.Timer = Config.Hazards.GhostCooldown * 0.5
			else
				moveTo = V(r.Position.X, 4.2, r.Position.Z)
				speed = Config.Hazards.GhostChaseSpeed * speedScale
				if ((r.Position - pos) * V(1, 0, 1)).Magnitude < 2.8 then
					S.Players.Stun(target :: Player, Config.Stun.GhostSpook, true)
					S.Players.Knock(target :: Player, ((r.Position - pos) * V(1, 0, 1)).Unit * 20 + V(0, 18, 0))
					S.Fx.All("Spook", { Pos = r.Position, UserId = (target :: Player).UserId })
					g.State = "Cooldown"
					g.Timer = Config.Hazards.GhostCooldown
				end
			end
		end
		if moveTo then
			local delta = (moveTo - pos) * V(1, 0, 1)
			if delta.Magnitude < 0.6 and g.State == "Wander" then
				g.Index = g.Index % #g.Patrol + 1
			elseif delta.Magnitude > 0.01 then
				pos += delta.Unit * math.min(delta.Magnitude, speed * dt)
			end
		end
		g.Pos = pos
		local bob = math.sin(t * 2.4 + g.Index) * 0.35
		local rear = g.State == "Notice" and 1.4 or 0
		local look = moveTo and ((moveTo - pos) * V(1, 0, 1)) or Vector3.zero
		local facing = look.Magnitude > 0.1 and CFrame.lookAt(pos, pos + look) or (g.Model.PrimaryPart :: BasePart).CFrame.Rotation + pos
		g.Model:PivotTo(facing.Rotation + pos + V(0, bob + rear, 0))
		g.Model:SetAttribute("State", g.State)
		local body = g.Model.PrimaryPart :: BasePart
		body.Transparency = (g.State == "Stunned" or g.State == "Cooldown") and 0.65 or 0.2
	end
end

----------------------------------------------------------------------------------------

function Hazards.Build(level: any, parent: Instance)
	Hazards.Clear()
	local f = Instance.new("Folder")
	f.Name = "Hazards"
	f.Parent = parent
	folder = f
	for _, h in level.Hazards or {} do
		if h.Kind == "Water" then
			buildWater(h, f)
		elseif h.Kind == "Conveyor" then
			buildConveyor(h, f)
		elseif h.Kind == "Platform" then
			buildPlatform(h, f)
		elseif h.Kind == "Traffic" then
			buildLane(h, f)
		elseif h.Kind == "Ghost" then
			buildGhostHazard(h, f)
		else
			warn("Hazards: unknown kind " .. tostring(h.Kind))
		end
	end
end

function Hazards.Clear()
	table.clear(waters)
	table.clear(platforms)
	table.clear(lanes)
	table.clear(ghosts)
	if folder then
		folder:Destroy()
	end
	folder = nil
end

-- Only runs while gameplay is active and not paused (simulation time).
function Hazards.Step(dt: number)
	stepPlatforms(dt)
	stepLanes(dt)
	stepGhosts(dt)
end

-- Stop moving surfaces while paused (conveyors keep their belt velocity but everything
-- on them is anchored, so nothing moves).
function Hazards.SetFrozen(frozen: boolean)
	for _, pl in platforms do
		pl.Part.AssemblyLinearVelocity = Vector3.zero
	end
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Conveyor") then
				d.AssemblyLinearVelocity = frozen and Vector3.zero or d:GetAttribute("BeltVelocity") or d.AssemblyLinearVelocity
			end
		end
	end
end

return Hazards
