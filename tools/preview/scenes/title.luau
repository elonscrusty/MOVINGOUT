--[[
	title: the title screen (before PLAY) over the slowly orbiting depot.
	  --set t=S   seconds of orbit before the picture (default 3)
]]
local M = lib("menu")
return function(preview)
	M.start({ join = false, settle = tonumber(preview.args.t) or 3 })
	M.report()
end
