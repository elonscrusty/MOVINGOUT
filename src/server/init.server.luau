--[[
	Server entry point: registers the systems, routes client actions, starts the lobby.
	Every client request is validated here or in the system it reaches; the client only
	ever asks, the server decides.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local S = require(script.Services)

S.Fx = require(script.FxService)
S.Data = require(script.DataService)
S.Players = require(script.PlayerService)
S.Items = require(script.ItemService)
S.Carry = require(script.CarrySystem)
S.Truck = require(script.TruckService)
S.Breakables = require(script.Breakables)
S.Hazards = require(script.Hazards)
S.Jobs = require(script.JobManager)

Net.State():SetAttribute("Phase", "Lobby")
Net.State():SetAttribute("Version", Config.Version)

S.Data.Init()
S.Players.Init()
S.Jobs.Init()

-- simple flood protection: at most 25 actions per second per player
local budget: { [Player]: { number } } = {}
local function allowed(player: Player): boolean
	local b = budget[player]
	local t = os.clock()
	if not b or t - b[1] > 1 then
		budget[player] = { t, 1 }
		return true
	end
	b[2] += 1
	return b[2] <= 25
end
Players.PlayerRemoving:Connect(function(player)
	budget[player] = nil
end)

local function isMover(player: Player): boolean
	return S.Players.Slot(player) > 0
end

local function isLeader(player: Player): boolean
	return S.Players.IsLeader(player)
end

local handlers: { [string]: (Player, any, any) -> () } = {
	Play = function(player)
		S.Players.Join(player)
	end,
	Grab = function(player, id)
		if isMover(player) then
			S.Carry.Grab(player, id)
		end
	end,
	Release = function(player)
		if isMover(player) then
			S.Carry.ReleasePlayer(player, "release")
		end
	end,
	Throw = function(player)
		if isMover(player) then
			S.Carry.Throw(player)
		end
	end,
	Slap = function(player)
		if isMover(player) then
			S.Carry.Slap(player)
		end
	end,
	SetStyle = function(player, style)
		S.Players.SetStyle(player, style)
	end,
	SelectJob = function(player, id, assists)
		if isLeader(player) and S.Jobs.Phase() == "Lobby" then
			S.Jobs.SelectJob(id, assists)
		end
	end,
	StartJob = function(player)
		if isLeader(player) and S.Jobs.Phase() == "Briefing" then
			S.Jobs.StartCountdown()
		end
	end,
	Board = function(player)
		local phase = S.Jobs.Phase()
		if isLeader(player) and (phase == "Briefing" or phase == "Results" or phase == "Playing") then
			S.Jobs.GoLobby()
		end
	end,
	Pause = function(player)
		if isMover(player) then
			S.Jobs.SetPaused(true, player)
		end
	end,
	Resume = function(player)
		if isMover(player) then
			S.Jobs.SetPaused(false, player)
		end
	end,
	Restart = function(player)
		local phase = S.Jobs.Phase()
		if isLeader(player) and (phase == "Playing" or phase == "Results") then
			S.Jobs.Restart()
		end
	end,
	Replay = function(player)
		if isLeader(player) and S.Jobs.Phase() == "Results" then
			S.Jobs.StartCountdown()
		end
	end,
	NextJob = function(player)
		if isLeader(player) then
			S.Jobs.NextJob()
		end
	end,
	SaveSettings = function(player, settings)
		local profile = S.Data.Get(player)
		if profile and type(settings) == "table" then
			local clean = S.Data.Sanitize({ Version = profile.Version, Settings = settings }).Settings
			profile.Settings = clean
			S.Data.MarkDirty(player)
		end
	end,
	SaveBindings = function(player, bindings)
		local profile = S.Data.Get(player)
		if profile and type(bindings) == "table" then
			profile.Bindings = S.Data.Sanitize({ Version = profile.Version, Bindings = bindings }).Bindings
			S.Data.MarkDirty(player)
		end
	end,
	TutorialDone = function(player)
		local profile = S.Data.Get(player)
		if profile then
			profile.TutorialSeen = true
			S.Data.MarkDirty(player)
		end
	end,
}

Net.Action.OnServerEvent:Connect(function(player, name, a, b)
	if type(name) ~= "string" or not allowed(player) then
		return
	end
	local h = handlers[name]
	if h then
		h(player, a, b)
	end
end)

Net.Profile.OnServerInvoke = function(player)
	local t0 = os.clock()
	while not S.Data.Get(player) and os.clock() - t0 < 10 do
		task.wait(0.1)
	end
	return S.Data.Get(player), S.Data.Status(player)
end

Workspace:SetAttribute("ServerStarted", true)
