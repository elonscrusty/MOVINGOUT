--[[
	results: the results screen after a job, through the real server path
	(JobManager.OnAllDelivered: timer, award, best time, unlock, the Results Fx).
	  --set level=<Id>   Suburb (default)
	  --set seconds=N    play N simulated seconds first (default 2, at 30 fps)
	  --set movers=N     more movers
]]
local G = lib("game")
local M = lib("menu")
return function(preview)
	M.start({ level = preview.args.level or "Suburb", phase = "Playing", settle = 0.2 })
	preview.advance(tonumber(preview.args.seconds) or 2, 30)
	G.server("JobManager").OnAllDelivered()
	preview.advance(1.0)
	M.report()
end
