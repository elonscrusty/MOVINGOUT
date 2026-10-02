--[[
	overview: a whole level from high above (the level fitted to the screen).
	  --set level=<Id>      Suburb (default), Depot, Poolside, Warehouse, Haunted, ...
	  --set pitch=N         degrees down (default 68); --set yaw=N (default the level's)
	  --set ortho=on        straight down, orthographic (a plan view)
	  --set movers=N        movers at their spawns (default 2, 0 = none)
	  --set hud=on          show the HUD (default off)
	Fits everything the level built (walls, props, truck, furniture, hazards) except the
	ground slabs; --set fit=bounds fits the level's Bounds instead. The view is centred
	on the built area (focus on the ground at its centre).
]]
local G = lib("game")

return function(preview)
	local a = preview.args
	local level = a.level or "Suburb"
	local data = G.levelData(level)
	local movers = tonumber(a.movers) or 2
	G.boot({ level = level, movers = math.max(movers, 1), phase = a.phase or "Playing", join = true })
	if movers == 0 then
		for _, p in game:GetService("Players"):GetPlayers() do
			if p.Character then
				p.Character.Parent = nil
			end
		end
	end
	preview.advance(0.5)
	G.hud(a.hud == "on")

	-- what to fit: the corners of everything the level built except the ground slabs
	-- (Base / Ground parts); --set fit=bounds fits the level's Bounds instead
	local corners = {}
	local folder = G.levelFolder()
	local function addBox(lo: Vector3, hi: Vector3)
		for _, x in { lo.X, hi.X } do
			for _, y in { math.max(lo.Y, 0), math.min(hi.Y, 12) } do
				for _, z in { lo.Z, hi.Z } do
					table.insert(corners, Vector3.new(x, y, z))
				end
			end
		end
	end
	local minV, maxV
	if folder and a.fit ~= "bounds" then
		for _, p in folder:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Base" and not p:GetAttribute("Ground") and p.Transparency < 1 then
				local lo, hi = p.Position - p.Size / 2, p.Position + p.Size / 2
				addBox(lo, hi)
				minV = minV and minV:Min(lo) or lo
				maxV = maxV and maxV:Max(hi) or hi
			end
		end
	end
	if not minV then
		minV = Vector3.new(data.Bounds.Min[1], 0, data.Bounds.Min[2])
		maxV = Vector3.new(data.Bounds.Max[1], 8, data.Bounds.Max[2])
		addBox(minV, maxV)
	end
	local centre = Vector3.new((minV.X + maxV.X) / 2, 0, (minV.Z + maxV.Z) / 2)
	local d = preview.device
	local aspect = d.width / d.height
	local yaw = tonumber(a.yaw) or (G.yawPitch(data))
	if a.ortho == "on" then
		local rot = CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(-math.rad(89.9), 0, 0)
		local cf = CFrame.new(centre + rot * Vector3.new(0, 0, 600)) * rot
		local maxW, maxH = 0, 0
		for _, c in corners do
			local l = cf:PointToObjectSpace(c)
			maxW = math.max(maxW, math.abs(l.X))
			maxH = math.max(maxH, math.abs(l.Y))
		end
		local h = math.max(maxH * 2, maxW * 2 / aspect) * 1.06
		preview.camera = { cf = cf, ortho = { height = h }, near = 1, far = 2000 }
		return
	end
	local pitch = tonumber(a.pitch) or 68
	local fov = tonumber(a.fov) or 34
	local t = math.tan(math.rad(fov) / 2)
	local function fits(dist)
		local cf = G.cameraCFrame(centre, dist, yaw, pitch)
		for _, c in corners do
			local l = cf:PointToObjectSpace(c)
			if -l.Z <= 0.1 then
				return false
			end
			if math.abs(l.X) / (-l.Z * t * aspect) > 0.96 or math.abs(l.Y) / (-l.Z * t) > 0.96 then
				return false
			end
		end
		return true
	end
	local lo, hi = 20, 4000
	for _ = 1, 40 do
		local mid = (lo + hi) / 2
		if fits(mid) then
			hi = mid
		else
			lo = mid
		end
	end
	preview.camera = { cf = G.cameraCFrame(centre, hi, yaw, pitch), fov = fov, far = 8000 }
	preview.log("overview", level, string.format("distance %.0f", hi))
end
