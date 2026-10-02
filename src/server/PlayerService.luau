--[[
	PlayerService.luau
	Mover slots (P1-P4), spawning, costumes, stuns, respawning and walking speed.

	A player chooses PLAY on the title screen to take a free slot and get a mover; with
	all four slots taken they watch as a spectator until one frees up. The leader (host)
	is the mover with the lowest slot number; only they pick jobs and restart.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Movers = require(ReplicatedStorage.Shared.Movers)
local S = require(script.Parent.Services)
local MoverBuilder = require(script.Parent.MoverBuilder)

local PlayerService = {}

local slots: { [number]: Player } = {}
local frozen = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

function PlayerService.Slot(player: Player): number
	return (player:GetAttribute("Slot") :: number?) or 0
end

function PlayerService.Movers(): { Player }
	local list = {}
	for i = 1, Config.MaxMovers do
		local p = slots[i]
		if p and p.Parent then
			table.insert(list, p)
		end
	end
	return list
end

function PlayerService.MoverCount(): number
	return #PlayerService.Movers()
end

function PlayerService.Leader(): Player?
	return PlayerService.Movers()[1]
end

function PlayerService.IsLeader(player: Player): boolean
	return PlayerService.Leader() == player
end

local function updateLeader()
	local leader = PlayerService.Leader()
	Net.State():SetAttribute("Leader", leader and leader.UserId or 0)
	Net.State():SetAttribute("MoverCount", PlayerService.MoverCount())
end

function PlayerService.Root(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function PlayerService.Humanoid(player: Player): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

function PlayerService.IsStunned(player: Player): boolean
	return (player:GetAttribute("StunUntil") or 0) > now()
end

function PlayerService.IsProtected(player: Player): boolean
	return (player:GetAttribute("ProtectUntil") or 0) > now()
end

-- Walking speed: 0 when frozen / stunned / paused, reduced while carrying.
function PlayerService.UpdateSpeed(player: Player)
	local hum = PlayerService.Humanoid(player)
	if not hum then
		return
	end
	local speed = Config.Movement.WalkSpeed
	local jump = Config.Movement.JumpHeight
	if frozen or S.World.Paused or PlayerService.IsStunned(player) then
		speed = 0
		jump = 0
	else
		local factor = S.Carry and S.Carry.SpeedFactor(player) or 1
		speed *= factor
	end
	hum.WalkSpeed = speed
	hum.JumpHeight = jump
end

function PlayerService.UpdateAllSpeeds()
	for _, p in PlayerService.Movers() do
		PlayerService.UpdateSpeed(p)
	end
end

-- Freeze all movers in place (briefing / countdown / results).
function PlayerService.SetFrozen(value: boolean)
	frozen = value
	PlayerService.UpdateAllSpeeds()
end

function PlayerService.Stun(player: Player, seconds: number, dropItem: boolean)
	if PlayerService.IsProtected(player) then
		return
	end
	player:SetAttribute("StunUntil", now() + seconds)
	if dropItem and S.Carry then
		S.Carry.ReleasePlayer(player, "stun")
	end
	PlayerService.UpdateSpeed(player)
	S.Fx.All("Stun", { UserId = player.UserId, Duration = seconds })
	task.delay(seconds + 0.05, function()
		if player.Parent then
			PlayerService.UpdateSpeed(player)
		end
	end)
end

function PlayerService.Knock(player: Player, velocity: Vector3)
	local root = PlayerService.Root(player)
	if root then
		root.AssemblyLinearVelocity = velocity
	end
end

local function spawnPoint(player: Player): Vector3
	local level = S.World.Level
	local slot = math.max(1, PlayerService.Slot(player))
	if level and #level.Spawns > 0 then
		return level.Spawns[(slot - 1) % #level.Spawns + 1]
	end
	return Vector3.new(0, 5, 0)
end

-- Puts a mover back on their spawn point (new level, restart, fell in water).
function PlayerService.Respawn(player: Player, pos: Vector3?)
	local char = player.Character
	local root = PlayerService.Root(player)
	if not char or not root then
		return
	end
	if S.Carry then
		S.Carry.ReleasePlayer(player, "respawn")
	end
	local p = pos or spawnPoint(player)
	local facing = S.World.Data and S.World.Data.SpawnFacing or 0
	char:PivotTo(CFrame.new(p + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(facing), 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	player:SetAttribute("StunUntil", 0)
	player:SetAttribute("ProtectUntil", now() + Config.Stun.RespawnProtect)
	PlayerService.UpdateSpeed(player)
end

function PlayerService.RespawnAll()
	for _, p in PlayerService.Movers() do
		PlayerService.Respawn(p)
	end
end

local function dress(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local slot = PlayerService.Slot(player)
	local color = Config.Slots[slot] and Config.Slots[slot].Color or Color3.fromRGB(200, 200, 200)
	char:SetAttribute("Slot", slot)
	MoverBuilder.Dress(char, (player:GetAttribute("Style") :: number?) or 1, color)
end

local function setupCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	hum.UseJumpPower = false
	dress(player)
	PlayerService.Respawn(player)
	hum.Died:Connect(function()
		-- should not happen (Dead is disabled) but never leave a player stuck
		task.wait(1)
		if player.Parent and PlayerService.Slot(player) > 0 then
			PlayerService.SpawnCharacter(player)
		end
	end)
end

function PlayerService.SpawnCharacter(player: Player)
	if PlayerService.Slot(player) == 0 then
		return
	end
	local desc = MoverBuilder.Description(Config.Movement)
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescriptionAsync(desc)
	end)
	if not ok then
		warn("PlayerService: spawn failed for " .. player.Name .. ": " .. tostring(err))
	end
end

-- Takes a free slot for the player (from the title screen PLAY button).
function PlayerService.Join(player: Player)
	if PlayerService.Slot(player) > 0 then
		return
	end
	for i = 1, Config.MaxMovers do
		if not slots[i] or not slots[i].Parent then
			slots[i] = player
			player:SetAttribute("Slot", i)
			updateLeader()
			PlayerService.SpawnCharacter(player)
			S.Jobs.OnMoversChanged()
			return
		end
	end
	S.Fx.Toast(player, "All four mover slots are taken - watching for now.")
	player:SetAttribute("Spectator", true)
end

function PlayerService.Leave(player: Player)
	local slot = PlayerService.Slot(player)
	if S.Carry then
		S.Carry.ReleasePlayer(player, "leave")
	end
	if slot > 0 and slots[slot] == player then
		slots[slot] = nil
	end
	player:SetAttribute("Slot", 0)
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end
	updateLeader()
	S.Jobs.OnMoversChanged()
	-- a spectator can take the free slot
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("Spectator") and PlayerService.Slot(p) == 0 then
			p:SetAttribute("Spectator", false)
			PlayerService.Join(p)
			break
		end
	end
end

function PlayerService.SetStyle(player: Player, style: any)
	if type(style) ~= "number" or style ~= style then
		return
	end
	style = math.clamp(math.floor(style), 1, #Movers.Styles)
	player:SetAttribute("Style", style)
	local profile = S.Data.Get(player)
	if profile then
		profile.Style = style
		S.Data.MarkDirty(player)
	end
	dress(player)
end

-- Movers that fell out of the world or into water get a respawn.
function PlayerService.Step()
	local level = S.World.Level
	if not level or S.World.Paused then
		return
	end
	for _, player in PlayerService.Movers() do
		local root = PlayerService.Root(player)
		if root and not player:GetAttribute("Recovering") then
			local pos = root.Position
			local inWater = S.Hazards and S.Hazards.InWater(pos)
			if pos.Y < Config.Recovery.KillY or inWater then
				player:SetAttribute("Recovering", true)
				S.Carry.ReleasePlayer(player, "fall")
				if inWater then
					S.Fx.All("Splash", { Pos = pos })
				end
				task.delay(Config.Recovery.PlayerDelay, function()
					player:SetAttribute("Recovering", false)
					if player.Parent then
						PlayerService.Respawn(player)
						S.Fx.All("Poof", { Pos = (PlayerService.Root(player) or root).Position })
					end
				end)
			end
		end
	end
end

function PlayerService.Init()
	local function onAdded(player: Player)
		player:SetAttribute("Slot", 0)
		player.CharacterAdded:Connect(function(char)
			setupCharacter(player, char)
		end)
		local profile = S.Data.Load(player)
		player:SetAttribute("Style", profile.Style)
		player:SetAttribute("SaveStatus", S.Data.Status(player))
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlayerService.Leave(player)
	end)
end

return PlayerService
