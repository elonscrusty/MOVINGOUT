--[[
	Breakables.luau
	Designated shortcuts: breakable glass (a hard furniture hit or a slap) and boarded
	doors (several slaps or a very hard hit). Breaking removes the blocking collider and
	hides the linked decoration; clients play shards / splinters locally (short-lived, never
	physical debris, so nothing can block a route). A level rebuild restores them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local S = require(script.Parent.Services)

local Breakables = {}

local function hideLinked(part: BasePart)
	for _, v in part:GetChildren() do
		if v:IsA("ObjectValue") and v.Name == "Linked" and v.Value and v.Value:IsA("BasePart") then
			(v.Value :: BasePart).Transparency = 1
		end
	end
end

function Breakables.Break(part: BasePart, from: Vector3?)
	if part:GetAttribute("Broken") then
		return
	end
	part:SetAttribute("Broken", true)
	local kind = part:GetAttribute("Breakable")
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	hideLinked(part)
	S.Fx.All("Break", { Kind = kind, CFrame = part.CFrame, Size = part.Size, From = from })
end

-- A hit on a breakable part: "Slap" from a mover, or "Impact" from furniture at speed.
function Breakables.Hit(part: BasePart, how: string, from: Vector3?, speed: number?)
	if part:GetAttribute("Broken") or not S.World.Active or S.World.Paused then
		return
	end
	local kind = part:GetAttribute("Breakable")
	if kind == "Glass" then
		if how == "Slap" or (speed or 0) >= Config.Breakable.ImpactSpeed then
			Breakables.Break(part, from)
		end
	elseif kind == "Boards" then
		if how == "Impact" then
			if (speed or 0) >= Config.Breakable.DoorImpactSpeed then
				Breakables.Break(part, from)
			end
			return
		end
		local hits = ((part:GetAttribute("Hits") :: number?) or 0) + 1
		part:SetAttribute("Hits", hits)
		if hits >= Config.Breakable.DoorSlaps then
			Breakables.Break(part, from)
		else
			S.Fx.All("Crack", { CFrame = part.CFrame, Size = part.Size, Hits = hits })
		end
	end
end

return Breakables
