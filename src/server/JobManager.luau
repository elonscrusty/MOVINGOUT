--[[
	JobManager.luau
	The shared game state machine (one per server, all movers play together):

	  Lobby      the depot yard: practice grabbing / throwing; the host picks a job
	  Briefing   the job is loaded, movers wait at their spawns, objective + controls shown
	  Countdown  3-2-1, then the timer starts
	  Playing    the timer runs; every required item must be in the truck
	  Results    time, award, best time; host chooses replay / next job / job board
	  (Paused is a flag on top of Playing: simulation, timer and hazards freeze)

	Loading a level always destroys the previous one first, so restarts can't duplicate
	parts, constraints or listeners. Gameplay time (SimTime) only advances while active
	and unpaused; the job timer only while Playing.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Jobs = require(ReplicatedStorage.Shared.Jobs)
local Net = require(ReplicatedStorage.Shared.Net)
local S = require(script.Parent.Services)
local LevelBuilder = require(script.Parent.LevelBuilder)

local JobManager = {}

local phase: string = "Lobby"
local job: any = nil
local timerAccum = 0
local timerRunning = false
local token = 0 -- bumps on every load so stale delayed callbacks do nothing
local lightingDefaults: { [string]: any } = {}
local savedRoots: { [BasePart]: Vector3 } = {}

local function state(): Folder
	return Net.State()
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

function JobManager.Phase(): string
	return phase
end

function JobManager.Job(): any
	return job
end

local function setPhase(p: string)
	phase = p
	state():SetAttribute("Phase", p)
end

local function publishTimer()
	local st = state()
	st:SetAttribute("TimerRunning", timerRunning)
	st:SetAttribute("TimerValue", timerAccum)
	st:SetAttribute("TimerOrigin", serverNow() - timerAccum)
end

local function applyLighting(data: any)
	for key, value in lightingDefaults do
		(Lighting :: any)[key] = value
	end
	for key, value in data.Lighting or {} do
		pcall(function()
			(Lighting :: any)[key] = value
		end)
	end
end

local function unload()
	token += 1
	S.Carry.ReleaseAll()
	S.Items.Detach()
	S.Hazards.Clear()
	if S.World.Level then
		S.World.Level.Folder:Destroy()
	end
	S.World.Level = nil
	S.World.Paused = false
	state():SetAttribute("Paused", false)
	for root in savedRoots do
		if root.Parent then
			root.Anchored = false
		end
	end
	table.clear(savedRoots)
end

local function load(data: any, isJob: boolean)
	unload()
	S.World.Data = data
	S.World.IsJob = isJob
	applyLighting(data)
	local built = LevelBuilder.Build(data, Workspace)
	S.Hazards.Build(data, built.Folder)
	S.World.Level = built
	S.Items.Attach()
	S.Truck.Reset()
	local st = state()
	st:SetAttribute("JobId", isJob and data.Id or "")
	st:SetAttribute("JobName", data.Name)
	st:SetAttribute("CameraYaw", data.Camera and data.Camera.Yaw or Config.Camera.Yaw)
	st:SetAttribute("CameraPitch", data.Camera and data.Camera.Pitch or Config.Camera.Pitch)
	timerAccum = 0
	timerRunning = false
	publishTimer()
	S.Players.RespawnAll()
end

local function publishAssists()
	local a = S.World.Assists
	local st = state()
	st:SetAttribute("AssistTimeScale", a.TimeScale)
	st:SetAttribute("AssistReducedHazards", a.ReducedHazards)
	st:SetAttribute("AssistEasyHeavy", a.EasyHeavy)
	st:SetAttribute("AssistVanish", a.VanishDelivered)
end

function JobManager.GoLobby()
	load(Jobs.Lobby, false)
	job = nil
	S.World.Active = true
	S.Players.SetFrozen(false)
	setPhase("Lobby")
end

local function unlockedForGroup(id: string): boolean
	if Jobs.List[1].Id == id then
		return true
	end
	for _, p in S.Players.Movers() do
		local profile = S.Data.Get(p)
		if profile and profile.Unlocked[id] then
			return true
		end
	end
	return false
end

local function sanitizeAssists(a: any): { [string]: any }
	local out = table.clone(Config.Assists.Defaults)
	if type(a) ~= "table" then
		return out
	end
	if table.find(Config.Assists.TimeTargetScale, a.TimeScale) then
		out.TimeScale = a.TimeScale
	end
	out.ReducedHazards = a.ReducedHazards == true
	out.EasyHeavy = a.EasyHeavy == true
	out.VanishDelivered = a.VanishDelivered == true
	return out
end

-- Host picked a job on the board: load it and show the briefing.
function JobManager.SelectJob(id: any, assists: any)
	if type(id) ~= "string" or not Jobs.ById[id] or not unlockedForGroup(id) then
		return
	end
	S.World.Assists = sanitizeAssists(assists)
	publishAssists()
	job = Jobs.ById[id]
	S.World.Active = false
	load(job, true)
	S.Players.SetFrozen(true)
	setPhase("Briefing")
end

function JobManager.StartCountdown()
	if not job or (phase ~= "Briefing" and phase ~= "Results") then
		return
	end
	if phase == "Results" then
		-- replay: rebuild the level from scratch
		S.World.Active = false
		load(job, true)
	end
	S.Players.SetFrozen(true)
	setPhase("Countdown")
	local myToken = token
	local ends = serverNow() + Config.Countdown
	state():SetAttribute("CountdownEnd", ends)
	for i = Config.Countdown, 1, -1 do
		task.delay(Config.Countdown - i, function()
			if token == myToken and JobManager.Phase() == "Countdown" then
				S.Fx.All("Countdown", { N = i })
			end
		end)
	end
	task.delay(Config.Countdown, function()
		if token ~= myToken or JobManager.Phase() ~= "Countdown" then
			return
		end
		S.Fx.All("Countdown", { N = 0 })
		setPhase("Playing")
		S.World.Active = true
		S.Players.SetFrozen(false)
		timerAccum = 0
		timerRunning = true
		publishTimer()
	end)
end

function JobManager.Restart()
	if not job then
		return
	end
	S.World.Active = false
	load(job, true)
	setPhase("Briefing") -- StartCountdown requires Briefing
	JobManager.StartCountdown()
end

function JobManager.SetPaused(paused: boolean, by: Player?)
	if paused == S.World.Paused then
		return
	end
	if paused and phase ~= "Playing" then
		return
	end
	S.World.Paused = paused
	local st = state()
	st:SetAttribute("Paused", paused)
	st:SetAttribute("PausedBy", by and by:GetAttribute("Slot") or 0)
	S.Items.SetFrozen(paused)
	S.Hazards.SetFrozen(paused)
	for _, p in S.Players.Movers() do
		local root = S.Players.Root(p)
		if root then
			if paused then
				savedRoots[root] = root.AssemblyLinearVelocity
				root.Anchored = true
			else
				root.Anchored = false
				root.AssemblyLinearVelocity = savedRoots[root] or Vector3.zero
			end
		end
	end
	if not paused then
		table.clear(savedRoots)
		S.Carry.RefreshOwners()
	end
	S.Players.UpdateAllSpeeds()
	if phase == "Playing" then
		timerRunning = not paused
		publishTimer()
	end
end

-- TruckService calls this once every required item is securely delivered.
function JobManager.OnAllDelivered()
	if phase ~= "Playing" or not job then
		return
	end
	timerRunning = false
	publishTimer()
	setPhase("Results")
	S.World.Active = false
	S.Players.SetFrozen(true)
	local seconds = math.floor(timerAccum * 100 + 0.5) / 100
	local scale = S.World.Assists.TimeScale or 1
	local medal = Jobs.Medal(job, seconds, scale)
	S.Fx.All("Celebrate", {})
	for _, p in S.Players.Movers() do
		local prev, isBest, unlocked = S.Data.RecordJob(p, job.Id, seconds, medal)
		S.Fx.To(p, "Results", {
			JobId = job.Id,
			Time = seconds,
			Medal = medal,
			PrevBest = prev,
			NewBest = isBest,
			Unlocked = unlocked,
			Scale = scale,
			Assisted = scale ~= 1 or S.World.Assists.ReducedHazards or S.World.Assists.EasyHeavy or S.World.Assists.VanishDelivered,
		})
		S.Fx.To(p, "Profile", S.Data.Get(p))
	end
end

function JobManager.NextJob()
	if phase ~= "Results" or not job then
		return
	end
	local nextJob = Jobs.Next(job.Id)
	if nextJob and unlockedForGroup(nextJob.Id) then
		JobManager.SelectJob(nextJob.Id, S.World.Assists)
	else
		JobManager.GoLobby()
	end
end

function JobManager.OnMoversChanged()
	if S.Players.MoverCount() == 0 and phase ~= "Lobby" then
		JobManager.GoLobby()
		return
	end
	S.Carry.RefreshAll()
	local p = JobManager.Phase()
	if p == "Briefing" or p == "Countdown" or p == "Results" then
		S.Players.SetFrozen(true)
	end
end

-- Fixed-rate gameplay tick (Config.Tick.Rate), with a cap on catch-up after a stall.
local function tick(dt: number)
	if not S.World.Level then
		return
	end
	if S.World.Active and not S.World.Paused then
		S.World.SimTime += dt
		S.Carry.Step()
		S.Items.Step()
		S.Players.Step()
		S.Hazards.Step(dt)
		S.Truck.Step(dt)
		if phase == "Playing" and timerRunning then
			timerAccum += dt
		end
	elseif S.World.Level and not S.World.Paused then
		-- briefing / results: still recover things that fall out of the world
		S.Items.Step()
		S.Players.Step()
	end
end

function JobManager.Init()
	for _, key in { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogEnd", "FogStart", "FogColor", "ShadowSoftness", "ExposureCompensation" } do
		lightingDefaults[key] = (Lighting :: any)[key]
	end
	local acc = 0
	local publishAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += math.min(dt, 0.5)
		local steps = 0
		while acc >= Config.Tick.Rate and steps < Config.Tick.MaxCatchUp do
			tick(Config.Tick.Rate)
			acc -= Config.Tick.Rate
			steps += 1
		end
		if steps >= Config.Tick.MaxCatchUp then
			acc = 0
		end
		publishAcc += dt
		if publishAcc > 1 and timerRunning then
			publishAcc = 0
			publishTimer() -- re-anchor the client clock now and then
		end
	end)
	JobManager.GoLobby()
end

return JobManager
