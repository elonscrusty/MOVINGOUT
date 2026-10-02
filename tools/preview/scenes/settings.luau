--[[
	settings: the SETTINGS screen, opened with the real button.
	  --set from=title   from the title screen (default: the lobby HUD button)
]]
local M = lib("menu")
return function(preview)
	if preview.args.from == "title" then
		M.start({ join = false })
	else
		M.start({ level = "Depot" })
	end
	M.press("SETTINGS")
	M.report()
end
