--[[
	DataService.luau
	Versioned player profiles in a DataStore: settings, key bindings, unlocked jobs, best
	times and medals. Studio uses a separate store so tests never touch real saves.

	Every loaded value is validated; anything malformed falls back to safe defaults, so a
	bad save can never stop the game from starting. A slower time never overwrites a
	better one. If DataStores are unavailable (e.g. Studio API access off) profiles live in
	memory for the session and the client is told progress isn't being saved.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Jobs = require(ReplicatedStorage.Shared.Jobs)

local DataService = {}

local VERSION = 1
local STORE_NAME = "MovingOut_Profiles_v1" .. (RunService:IsStudio() and "_Studio" or "")

local store: DataStore? = nil
local profiles: { [Player]: any } = {}
local saving: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local status: { [Player]: string } = {}

local function defaults(): any
	local settings = table.clone(Config.SettingsDefaults)
	return {
		Version = VERSION,
		Settings = settings,
		Bindings = {},
		Style = 1,
		Unlocked = { [Jobs.List[1].Id] = true },
		Best = {},
		Medals = {},
		TutorialSeen = false,
	}
end

local function validNumber(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == v and v >= lo and v <= hi
end

-- Returns a clean profile built from defaults plus every valid saved field.
function DataService.Sanitize(raw: any): any
	local p = defaults()
	if type(raw) ~= "table" or raw.Version ~= VERSION then
		return p
	end
	if type(raw.Settings) == "table" then
		for key, default in Config.SettingsDefaults do
			local v = raw.Settings[key]
			if type(v) == type(default) then
				if type(v) == "number" then
					if validNumber(v, 0, 2) then
						p.Settings[key] = v
					end
				elseif type(v) == "string" then
					if key == "Quality" and (v == "High" or v == "Low") then
						p.Settings[key] = v
					end
				else
					p.Settings[key] = v
				end
			end
		end
	end
	if type(raw.Bindings) == "table" then
		for _, action in Config.Bindings.Remappable do
			local b = raw.Bindings[action]
			if type(b) == "string" and #b <= 32 and (Enum.KeyCode :: any)[b] ~= nil then
				p.Bindings[action] = b
			end
		end
	end
	if validNumber(raw.Style, 1, 64) then
		p.Style = math.floor(raw.Style)
	end
	for id in Jobs.ById do
		if type(raw.Unlocked) == "table" and raw.Unlocked[id] == true then
			p.Unlocked[id] = true
		end
		if type(raw.Best) == "table" and validNumber(raw.Best[id], 1, 36000) then
			p.Best[id] = raw.Best[id]
		end
		if type(raw.Medals) == "table" and Jobs.MedalRank[raw.Medals[id]] then
			p.Medals[id] = raw.Medals[id]
		end
	end
	p.TutorialSeen = raw.TutorialSeen == true
	return p
end

local function keyFor(player: Player): string
	return "u" .. player.UserId
end

function DataService.Load(player: Player): any
	local profile = defaults()
	status[player] = "memory"
	if store then
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok then
			profile = DataService.Sanitize(result)
			status[player] = "ok"
		else
			warn("DataService: load failed for " .. player.Name .. ": " .. tostring(result))
			status[player] = "failing"
		end
	end
	profiles[player] = profile
	return profile
end

function DataService.Get(player: Player): any
	return profiles[player]
end

function DataService.Status(player: Player): string
	return status[player] or "memory"
end

function DataService.Save(player: Player)
	local profile = profiles[player]
	if not profile or not store or saving[player] or status[player] == "failing" then
		return
	end
	saving[player] = true
	dirty[player] = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old: any)
			-- merge so a stale server can never lower a best time or relock a job
			local base = DataService.Sanitize(old)
			for id, t in profile.Best do
				if base.Best[id] == nil or t < base.Best[id] then
					base.Best[id] = t
				end
			end
			for id, m in profile.Medals do
				if (Jobs.MedalRank[base.Medals[id]] or 0) < Jobs.MedalRank[m] then
					base.Medals[id] = m
				end
			end
			for id in profile.Unlocked do
				base.Unlocked[id] = true
			end
			base.Settings = profile.Settings
			base.Bindings = profile.Bindings
			base.Style = profile.Style
			base.TutorialSeen = profile.TutorialSeen
			return base
		end)
	end)
	saving[player] = false
	if not ok then
		warn("DataService: save failed for " .. player.Name .. ": " .. tostring(err))
		dirty[player] = true
	end
end

function DataService.MarkDirty(player: Player)
	dirty[player] = true
end

-- Records a finished job. Returns the previous best and whether this is a new best.
function DataService.RecordJob(player: Player, jobId: string, seconds: number, medal: string): (number?, boolean, string?)
	local p = profiles[player]
	if not p then
		return nil, false, nil
	end
	local prev = p.Best[jobId]
	local isBest = prev == nil or seconds < prev
	if isBest then
		p.Best[jobId] = seconds
	end
	if (Jobs.MedalRank[p.Medals[jobId]] or 0) < Jobs.MedalRank[medal] then
		p.Medals[jobId] = medal
	end
	local nextJob = Jobs.Next(jobId)
	local unlocked: string? = nil
	if nextJob and not p.Unlocked[nextJob.Id] then
		p.Unlocked[nextJob.Id] = true
		unlocked = nextJob.Id
	end
	dirty[player] = true
	task.spawn(DataService.Save, player)
	return prev, isBest, unlocked
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("DataService: DataStores unavailable, progress kept in memory only: " .. tostring(result))
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
		profiles[player] = nil
		status[player] = nil
		dirty[player] = nil
	end)

	-- periodic save of changed settings
	task.spawn(function()
		while true do
			task.wait(30)
			for player, isDirty in dirty do
				if isDirty and player.Parent then
					task.spawn(DataService.Save, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 20 do
			task.wait(0.1)
		end
	end)
end

return DataService
