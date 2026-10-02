--[[
	Net.luau
	The three remotes. The server creates them; clients wait for them.
	  Action  (client -> server)  Action:FireServer(name, a?, b?)
	  Fx      (server -> clients) Fx:FireAllClients(kind, data) / FireClient
	  Profile (client -> server)  Profile:InvokeServer() -> the player's saved profile
	Shared game state lives in attributes on ReplicatedStorage.GameState.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local function get(className: string, name: string): Instance
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if RunService:IsServer() then
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		local r = (folder :: Folder):FindFirstChild(name)
		if not r then
			r = Instance.new(className)
			r.Name = name
			r.Parent = folder
		end
		return r :: Instance
	end
	folder = ReplicatedStorage:WaitForChild("Remotes")
	return (folder :: Folder):WaitForChild(name)
end

Net.Action = get("RemoteEvent", "Action") :: RemoteEvent
Net.Fx = get("RemoteEvent", "Fx") :: RemoteEvent
Net.Profile = get("RemoteFunction", "Profile") :: RemoteFunction

function Net.State(): Folder
	if RunService:IsServer() then
		local s = ReplicatedStorage:FindFirstChild("GameState")
		if not s then
			s = Instance.new("Folder")
			s.Name = "GameState"
			s.Parent = ReplicatedStorage
		end
		return s :: Folder
	end
	return ReplicatedStorage:WaitForChild("GameState") :: Folder
end

return Net
