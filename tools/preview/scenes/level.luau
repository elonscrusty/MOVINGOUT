--[[
	level: a level in play from the game's camera.
	  --set level=<Id>     Suburb (default), Depot (the lobby yard), Poolside, Warehouse, ...
	  --set movers=N       1-4 movers (default 2), each with its slot colour and a style
	  --set hud=on         show the client's HUD (default off: world, tags and rings only)
	  --set phase=Briefing|Playing   (default Playing; Depot is always the lobby)
	  --set focus=x,z      camera focus (default: CameraController framing the movers)
	  --set dist=N         camera distance (default: CameraController's)
	  --set t=S            simulated seconds to run after the start (default 1.5)
]]
local G = lib("game")

return function(preview)
	local a = preview.args
	local level = a.level or "Suburb"
	local data = G.levelData(level)
	G.boot({
		level = level,
		movers = tonumber(a.movers) or 2,
		phase = a.phase or "Playing",
	})
	preview.advance(tonumber(a.t) or 1.5)
	G.hud(a.hud == "on")
	-- the real CameraController has framed the movers; overrides recompute the same way
	local focusOverride = G.vec(a.focus)
	local distOverride = tonumber(a.dist)
	if focusOverride or distOverride then
		local yaw, pitch = G.yawPitch(data)
		local focus, dist = G.frame(G.moverRoots())
		focus = focusOverride or focus
		dist = distOverride or dist
		preview.camera = { cf = G.cameraCFrame(focus, dist, yaw, pitch), fov = preview.shared("Config").Camera.FieldOfView }
	end
	preview.log("level", level, "phase", G.phase(), "movers", #G.moverRoots())
end
