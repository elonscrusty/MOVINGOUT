--[[
	board: the JOB BOARD in the lobby (the host's view), opened with the real button.
	  --set unlocked=all     every job unlocked in the profile (default: the first only)
	  --set movers=N         more movers (the board shows the host note)
]]
local G = lib("game")
local M = lib("menu")
return function(preview)
	M.start({ level = "Depot" })
	if preview.args.unlocked == "all" then
		local Data = G.server("DataService")
		local Jobs = preview.shared("Jobs")
		local profile = Data.Get(preview.player())
		for _, job in Jobs.List do
			profile.Unlocked[job.Id] = true
		end
		-- the client reads its profile from the server (Profile remote), as on join
		preview.client("State").LoadProfile()
		preview.advance(0.2)
	end
	M.press("JOB BOARD")
	M.report()
end
