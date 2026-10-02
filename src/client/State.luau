--[[
	State.luau
	Client-side shared state: the saved profile (settings, bindings, records), the
	current menu screen, and a tiny signal helper. Settings changes are saved through
	the server (the profile lives in a DataStore).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local State = {}

export type Signal = { Connect: (self: Signal, fn: (...any) -> ()) -> (), Fire: (self: Signal, ...any) -> () }

function State.Signal(): Signal
	local listeners: { (...any) -> () } = {}
	local s = {}
	function s.Connect(_self, fn)
		table.insert(listeners, fn)
	end
	function s.Fire(_self, ...)
		for _, fn in listeners do
			task.spawn(fn, ...)
		end
	end
	return s :: any
end

State.Player = Players.LocalPlayer
State.Profile = {
	Settings = table.clone(Config.SettingsDefaults),
	Bindings = {},
	Unlocked = {},
	Best = {},
	Medals = {},
	Style = 1,
	TutorialSeen = false,
} :: any
State.SaveStatus = "memory"
State.Joined = false -- pressed PLAY and owns a mover slot (or spectates)
State.MenuOpen = false -- a modal menu is open (movement keys drive the menu)
State.ProfileChanged = State.Signal()
State.SettingsChanged = State.Signal()

function State.Settings(): any
	return State.Profile.Settings
end

function State.SetSetting(key: string, value: any)
	State.Profile.Settings[key] = value
	State.SettingsChanged:Fire(key, value)
	Net.Action:FireServer("SaveSettings", State.Profile.Settings)
end

function State.LoadProfile()
	local ok, profile, status = pcall(function()
		return Net.Profile:InvokeServer()
	end)
	if ok and type(profile) == "table" then
		State.Profile = profile
		State.SaveStatus = status or "memory"
	end
	State.ProfileChanged:Fire()
	State.SettingsChanged:Fire()
end

function State.Game(): Folder
	return Net.State()
end

function State.Phase(): string
	return (State.Game():GetAttribute("Phase") :: string?) or "Lobby"
end

function State.MySlot(): number
	return (State.Player:GetAttribute("Slot") :: number?) or 0
end

function State.IsLeader(): boolean
	return State.Game():GetAttribute("Leader") == State.Player.UserId
end

function State.Character(): Model?
	return State.Player.Character
end

function State.Root(): BasePart?
	local c = State.Player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

return State
