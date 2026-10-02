--[[
	briefing: the job briefing after the host picked a job (SelectJob -> Briefing).
	  --set level=<Id>   Suburb (default), Poolside, Warehouse, Haunted
]]
local M = lib("menu")
return function(preview)
	M.start({ level = preview.args.level or "Suburb", phase = "Briefing" })
	M.report()
end
