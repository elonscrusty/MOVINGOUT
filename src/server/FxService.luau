--[[
	FxService.luau
	Server -> client presentation events (sounds, particles, toasts, results).
	Gameplay never depends on these; they only describe what already happened.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local FxService = {}

function FxService.All(kind: string, data: any?)
	Net.Fx:FireAllClients(kind, data or {})
end

function FxService.To(player: Player, kind: string, data: any?)
	Net.Fx:FireClient(player, kind, data or {})
end

function FxService.Sound(name: string, pos: Vector3?)
	Net.Fx:FireAllClients("Sound", { Name = name, Pos = pos })
end

function FxService.Toast(player: Player, text: string)
	Net.Fx:FireClient(player, "Toast", { Text = text })
end

return FxService
