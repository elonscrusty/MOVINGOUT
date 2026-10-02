--[[
	pause: the pause menu during a job (the Pause action through the real remote).
	  --set level=<Id>   Suburb (default)
]]
local G = lib("game")
local M = lib("menu")
return function(preview)
	M.start({ level = preview.args.level or "Suburb", phase = "Playing" })
	G.action(preview.player(), "Pause")
	preview.advance(0.5)
	M.report()
end
