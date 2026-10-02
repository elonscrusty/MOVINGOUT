--[[
	look: the LOOK screen (mover style picker) in the lobby, opened with the real button.
]]
local M = lib("menu")
return function(preview)
	M.start({ level = "Depot" })
	M.press("LOOK")
	M.report()
end
