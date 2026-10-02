--[[
	Services.luau
	A tiny registry so server systems can call each other without circular requires:
	each system registers itself in init.server.luau and looks others up at call time.
	World holds the state every system reads.
]]

local Services = {}

Services.World = {
	Level = nil :: any, -- LevelBuilder Built table of the loaded level
	Data = nil :: any, -- level data table
	IsJob = false, -- false in the lobby yard
	Active = false, -- gameplay systems run (lobby practice or a running job)
	Paused = false,
	SimTime = 0, -- gameplay clock: only advances while Active and not paused
	Assists = {} :: { [string]: any },
}

Services.Data = nil :: any
Services.Players = nil :: any
Services.Items = nil :: any
Services.Carry = nil :: any
Services.Truck = nil :: any
Services.Breakables = nil :: any
Services.Hazards = nil :: any
Services.Jobs = nil :: any
Services.Fx = nil :: any

return Services
