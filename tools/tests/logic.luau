--[[
	Logic tests that run outside Roblox with Lune (no physics, no rendering):
	  lune run tools/tests/logic.luau
	They load the REAL game modules with a tiny require shim and stubbed services, and
	check delivery geometry, save validation / merging rules, award thresholds and the
	level item counts. Physics handling still needs a Studio playtest.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.cwd
local passed, failed = 0, 0

local function check(name: string, cond: boolean, detail: string?)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. (detail and ("  (" .. detail .. ")") or ""))
	end
end

-- path proxies standing in for Roblox instances (script, script.Parent, Shared...)
local Proxy = {}
local cache: { [string]: any } = {}
local overrides: { [string]: any } = {}

local function proxy(path: string): any
	return setmetatable({ __path = path }, Proxy)
end
Proxy.__index = function(self, key)
	if key == "Parent" then
		return proxy((self.__path :: string):match("^(.*)/[^/]+$") or "")
	elseif key == "WaitForChild" or key == "FindFirstChild" then
		return function(s, name)
			return proxy(s.__path .. "/" .. name)
		end
	end
	return proxy(self.__path .. "/" .. key)
end

local services: { [string]: any }
local loadModule: (string) -> any

local function env(path: string): any
	return setmetatable({
		script = proxy(path),
		game = { GetService = function(_, name)
			return services[name]
		end },
		require = function(p: any)
			return loadModule(p.__path)
		end,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		UDim2 = roblox.UDim2,
		PhysicalProperties = roblox.PhysicalProperties,
		warn = function() end,
		typeof = typeof,
		task = { spawn = function() end, delay = function() end, wait = function() end },
	}, { __index = _G })
end

loadModule = function(path: string): any
	if overrides[path] then
		return overrides[path]
	end
	if cache[path] then
		return cache[path]
	end
	local file = path .. ".luau"
	if not fs.isFile(ROOT .. "/" .. file) then
		file = path .. "/init.luau"
	end
	local chunk = luau.load(fs.readFile(ROOT .. "/" .. file), { debugName = file, environment = env(path) })
	local result = chunk()
	cache[path] = result
	return result
end

local SHARED = "src/shared"
local signal = { Connect = function() end }
services = {
	ReplicatedStorage = { Shared = proxy(SHARED) },
	RunService = { IsStudio = function()
		return true
	end, IsServer = function()
		return true
	end },
	DataStoreService = { GetDataStore = function()
		error("no datastores in tests")
	end },
	Players = { PlayerRemoving = signal, PlayerAdded = signal, GetPlayers = function()
		return {}
	end },
	Workspace = { GetServerTimeNow = function()
		return os.clock()
	end, Gravity = 140 },
}
-- ReplicatedStorage.Shared.X resolves to src/shared/X
setmetatable(services.ReplicatedStorage, { __index = function(_, k)
	return proxy(SHARED .. "/" .. k)
end })

-- stubs for modules that touch Roblox instances
overrides[SHARED .. "/Net"] = { State = function()
	return { SetAttribute = function() end }
end }

local Config = loadModule(SHARED .. "/Config")
local Jobs = loadModule(SHARED .. "/Jobs")
local FurnitureData = loadModule(SHARED .. "/FurnitureData")

----------------------------------------------------------------------------------------
-- Delivery geometry (TruckService.InsideFraction)

local Truck = loadModule("src/server/TruckService")
local cargoSize = roblox.Vector3.new(11, 6, 18)
local cargo = roblox.CFrame.new(10, 5, 20) * roblox.CFrame.Angles(0, math.rad(180), 0)
local function body(cf, size)
	return { CFrame = cf, Size = size }
end
local box = roblox.Vector3.new(2.3, 2.3, 2.3)
local floorY = 5 - 3 -- cargo floor
local inside = body(roblox.CFrame.new(10, floorY + 1.2, 20), box)
check("box resting in the cargo counts fully", Truck.InsideFraction(inside, cargo, cargoSize) == 1)
local outside = body(roblox.CFrame.new(40, floorY + 1.2, 20), box)
check("box far away counts zero", Truck.InsideFraction(outside, cargo, cargoSize) == 0)
-- half way out of the open rear (cargo spans z 11..29 after the 180 turn)
local half = body(roblox.CFrame.new(10, floorY + 1.2, 11), box)
local f = Truck.InsideFraction(half, cargo, cargoSize)
check("box straddling the cargo edge is partial", f > 0 and f < Config.Delivery.InFraction, tostring(f))
local sofa = roblox.Vector3.new(9, 4, 3.6)
local rotated = body(roblox.CFrame.new(10, floorY + 2, 24) * roblox.CFrame.Angles(0, math.rad(90), 0), sofa)
check("sofa turned lengthwise inside fits", Truck.InsideFraction(rotated, cargo, cargoSize) == 1)
local across = body(roblox.CFrame.new(10, floorY + 2, 24) * roblox.CFrame.Angles(0, math.rad(0), 0), roblox.Vector3.new(14, 4, 3.6))
check("item wider than the truck is not fully inside", Truck.InsideFraction(across, cargo, cargoSize) < 1)
local stacked = body(roblox.CFrame.new(10, floorY + 6.5, 20), box)
check("box stacked high (open top) still counts", Truck.InsideFraction(stacked, cargo, cargoSize) == 1)
local below = body(roblox.CFrame.new(10, floorY - 3, 20), box)
check("box under the truck does not count", Truck.InsideFraction(below, cargo, cargoSize) == 0)
check("hysteresis: out threshold below in threshold", Config.Delivery.OutFraction < Config.Delivery.InFraction)

----------------------------------------------------------------------------------------
-- Saves (DataService.Sanitize / RecordJob)

local Data = loadModule("src/server/DataService")
local clean = Data.Sanitize(nil)
check("nil save -> defaults", clean.Version == 1 and clean.Unlocked[Jobs.List[1].Id] == true)
local wrong = Data.Sanitize({ Version = 99, Best = { Suburb = 10 } })
check("wrong version -> defaults", wrong.Best.Suburb == nil)
local junk = Data.Sanitize({
	Version = 1,
	Settings = { Master = "loud", Music = 5, Effects = 0.4, Mute = "yes", Quality = "Ultra", GrabToggle = false },
	Bindings = { Grab = "NotAKey", Throw = 42, Slap = "G" },
	Best = { Suburb = -5, Poolside = 120, Nope = 3 },
	Medals = { Suburb = "Platinum", Poolside = "Gold" },
	Unlocked = { Warehouse = true, Fake = true },
	Style = 3.7,
})
check("bad volume type ignored", junk.Settings.Master == Config.SettingsDefaults.Master)
check("volume out of range ignored", junk.Settings.Music == Config.SettingsDefaults.Music)
check("valid volume kept", junk.Settings.Effects == 0.4)
check("bad bool ignored", junk.Settings.Mute == false)
check("unknown quality ignored", junk.Settings.Quality == "High")
check("valid bool kept", junk.Settings.GrabToggle == false)
check("negative best time dropped", junk.Best.Suburb == nil)
check("valid best kept", junk.Best.Poolside == 120)
check("unknown job dropped", junk.Best.Nope == nil and junk.Unlocked.Fake == nil)
check("unknown medal dropped", junk.Medals.Suburb == nil and junk.Medals.Poolside == "Gold")
check("style floored", junk.Style == 3)
check("non-string binding dropped", junk.Bindings.Throw == nil)
check("valid binding kept", junk.Bindings.Slap == "G")

local fake = { UserId = 1, Name = "Tester" }
Data.Load(fake)
local prev, isBest, unlocked = Data.RecordJob(fake, "Suburb", 200, "Silver")
check("first clear is a best and unlocks job 2", isBest and prev == nil and unlocked == Jobs.List[2].Id)
prev, isBest = Data.RecordJob(fake, "Suburb", 250, "Bronze")
check("slower time does not overwrite", not isBest and Data.Get(fake).Best.Suburb == 200 and Data.Get(fake).Medals.Suburb == "Silver")
prev, isBest = Data.RecordJob(fake, "Suburb", 150, "Gold")
check("faster time overwrites", isBest and prev == 200 and Data.Get(fake).Best.Suburb == 150 and Data.Get(fake).Medals.Suburb == "Gold")

----------------------------------------------------------------------------------------
-- Jobs and levels

check("four jobs", #Jobs.List == 4)
for _, job in Jobs.List do
	local a = job.Awards
	check(job.Id .. ": award order", a.Gold < a.Silver and a.Silver < a.Bronze)
	check(job.Id .. ": medal gold", Jobs.Medal(job, a.Gold - 1) == "Gold")
	check(job.Id .. ": medal none after bronze", Jobs.Medal(job, a.Bronze + 1) == "None")
	check(job.Id .. ": assist scale widens", Jobs.Medal(job, a.Gold * 1.4, 1.5) == "Gold")
	local n = Jobs.RequiredCount(job)
	check(job.Id .. ": 10-28 required items", n >= 10 and n <= 28, tostring(n))
	local ids = {}
	for i, item in job.Items do
		check(job.Id .. ": known kind " .. tostring(item.Kind), FurnitureData.Kinds[item.Kind] ~= nil)
		local id = item.Id or (item.Kind .. "_" .. i)
		check(job.Id .. ": unique id " .. id, ids[id] == nil)
		ids[id] = true
	end
	check(job.Id .. ": four spawns", #job.Spawns >= 4)
end

print(string.format("logic tests: %d passed, %d failed", passed, failed))
process.exit(failed == 0 and 0 or 1)
