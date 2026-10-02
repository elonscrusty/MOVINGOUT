--[[
	controls: the CONTROLS screen, opened from the title screen with the real button.
]]
local M = lib("menu")
return function(preview)
	M.start({ join = false })
	M.press("CONTROLS")
	M.report()
end
