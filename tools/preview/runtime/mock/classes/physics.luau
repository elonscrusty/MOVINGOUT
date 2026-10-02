--!nocheck
--[[
	classes/physics.luau - the little "physics" the preview fakes.

	* Workspace:Raycast and spatial queries: rays hit parts as oriented boxes (Ball parts
	  as ellipsoids, or spheres with --set balls=uniform; everything else, cylinders and
	  wedges included, as its box), honouring CanQuery, RaycastParams (Include / Exclude lists,
	  RespectCanCollide). GetPartBoundsInBox / InRadius / GetPartsInPart test world AABBs.
	* Ground snap: every frame, each Humanoid character whose root part is not anchored
	  stands on whatever is under it (root part at floor + HipHeight + half its height).
	  There is no falling, sliding or collision: a stand-in for gravity so characters the
	  game spawns in the air land like they would.
	* AlignPosition / AlignOrientation (enabled, Attachment0 on an unanchored part) snap
	  their part to the goal each frame, so carried things sit where the game holds them.
	Everything else stays where code puts it.
]]

local roblox = require("@lune/roblox")
local R = require("../R")
local S = require("../scheduler")

local states = R.states
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Enum = roblox.Enum
local getProp = R.getProp

local Physics = {}

-- Every BasePart under Workspace, cached per simulated frame (parts created and queried
-- in the same frame are found from the next frame on).
local cache = { frame = -1, parts = {} }
local function allParts()
	if cache.frame == S.frame and S.frame > 0 then
		return cache.parts
	end
	local out = {}
	local function scan(inst)
		local st = states[inst]
		if st.info.isA.BasePart and not st.info.isA.Terrain then
			table.insert(out, inst)
		end
		for _, c in ipairs(st.children) do
			scan(c)
		end
	end
	scan(R.services.Workspace)
	cache.frame = S.frame
	cache.parts = out
	return out
end

-- Candidate parts under Workspace for a query (CanQuery, filter list).
local function candidates(params, needCollide: boolean?)
	local list = params and params.FilterDescendantsInstances or {}
	local include = params and params.FilterType == Enum.RaycastFilterType.Include
	local respect = needCollide or (params and params.RespectCanCollide)
	local set = {}
	local any = false
	for _, x in ipairs(list) do
		set[x] = true
		any = true
	end
	local ws = R.services.Workspace
	local out = {}
	for _, inst in ipairs(allParts()) do
		local st = states[inst]
		if not st.destroyed and getProp(st, "CanQuery") ~= false and (not respect or getProp(st, "CanCollide")) then
			local inside = false
			if any then
				local p = inst
				while p and p ~= ws do
					if set[p] then
						inside = true
						break
					end
					p = states[p].parent
				end
				if p == nil then
					continue -- no longer in Workspace
				end
			end
			if (include and inside) or (not include and not inside) then
				table.insert(out, inst)
			end
		end
	end
	return out
end
Physics.candidates = candidates

-- Ray vs one part. Returns distance t (0..1 along dir), local normal.
local function hitPart(st, origin: Vector3, dir: Vector3)
	local cf = getProp(st, "CFrame")
	local size = getProp(st, "Size")
	local o = cf:PointToObjectSpace(origin)
	local d = cf:VectorToObjectSpace(dir)
	local info = st.info
	local shape = info.isA.Part and getProp(st, "Shape") or nil
	if shape == Enum.PartType.Ball then
		local r = math.min(size.X, size.Y, size.Z) / 2
		if not (R.api and R.api.render.balls == "uniform") then
			-- ellipsoid: scale to a unit sphere
			o = o / (size / 2)
			d = d / (size / 2)
			r = 1
		end
		local a = d:Dot(d)
		local b = 2 * o:Dot(d)
		local c = o:Dot(o) - r * r
		local disc = b * b - 4 * a * c
		if disc < 0 or a < 1e-12 then
			return nil
		end
		local sq = math.sqrt(disc)
		local t = (-b - sq) / (2 * a)
		if t < 0 then
			t = (-b + sq) / (2 * a)
			if t < 0 then
				return nil
			end
			return nil -- origin inside: Roblox does not report the exit
		end
		if t > 1 then
			return nil
		end
		local p = o + d * t
		if r == 1 and not (R.api and R.api.render.balls == "uniform") then
			p = p / (size / 2) -- ellipsoid normal ~ gradient
		end
		return t, p.Unit
	end
	local h = size / 2
	local tmin, tmax = -math.huge, math.huge
	local nmin = Vector3.zero
	for _, axis in ipairs({ "X", "Y", "Z" }) do
		local oa, da, ha = o[axis], d[axis], h[axis]
		if math.abs(da) < 1e-12 then
			if oa < -ha or oa > ha then
				return nil
			end
		else
			local t1 = (-ha - oa) / da
			local t2 = (ha - oa) / da
			local n1 = -1
			if t1 > t2 then
				t1, t2 = t2, t1
				n1 = 1
			end
			if t1 > tmin then
				tmin = t1
				nmin = (axis == "X" and Vector3.new(n1, 0, 0)) or (axis == "Y" and Vector3.new(0, n1, 0)) or Vector3.new(0, 0, n1)
			end
			if t2 < tmax then
				tmax = t2
			end
			if tmin > tmax then
				return nil
			end
		end
	end
	if tmin < 0 or tmin > 1 then
		return nil -- behind, inside (no exit hits, like Roblox) or beyond the ray
	end
	return tmin, nmin
end

local function makeResult(part, st, pos, normal, dist)
	return setmetatable({
		Instance = part,
		Position = pos,
		Normal = normal,
		Material = getProp(st, "Material"),
		Distance = dist,
	}, { __type = "RaycastResult", __tostring = function()
		return "RaycastResult{" .. tostring(part) .. "}"
	end })
end

function Physics.raycast(origin: Vector3, dir: Vector3, params)
	local best, bestT, bestN = nil, math.huge, nil
	for _, p in ipairs(candidates(params)) do
		local st = states[p]
		local t, n = hitPart(st, origin, dir)
		if t and t < bestT then
			best, bestT, bestN = p, t, n
		end
	end
	if not best then
		return nil
	end
	local st = states[best]
	local cf = getProp(st, "CFrame")
	local pos = origin + dir * bestT
	return makeResult(best, st, pos, cf:VectorToWorldSpace(bestN).Unit, dir.Magnitude * bestT)
end

-- World AABB of a part.
local function aabb(st)
	local cf = getProp(st, "CFrame")
	local s = getProp(st, "Size") / 2
	local r = cf.Rotation
	local ex = Vector3.new(
		math.abs(r.RightVector.X) * s.X + math.abs(r.UpVector.X) * s.Y + math.abs(r.LookVector.X) * s.Z,
		math.abs(r.RightVector.Y) * s.X + math.abs(r.UpVector.Y) * s.Y + math.abs(r.LookVector.Y) * s.Z,
		math.abs(r.RightVector.Z) * s.X + math.abs(r.UpVector.Z) * s.Y + math.abs(r.LookVector.Z) * s.Z
	)
	return cf.Position - ex, cf.Position + ex
end
Physics.aabb = aabb

local function boxQuery(minQ: Vector3, maxQ: Vector3, params, exclude)
	local out = {}
	local maxParts = params and params.MaxParts or 0
	for _, p in ipairs(candidates(params)) do
		if p ~= exclude then
			local mn, mx = aabb(states[p])
			if mn.X <= maxQ.X and mx.X >= minQ.X and mn.Y <= maxQ.Y and mx.Y >= minQ.Y and mn.Z <= maxQ.Z and mx.Z >= minQ.Z then
				table.insert(out, p)
				if maxParts > 0 and #out >= maxParts then
					break
				end
			end
		end
	end
	return out
end

local function obbBounds(cf: CFrame, size: Vector3)
	local s = size / 2
	local ex = Vector3.new(
		math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
		math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
		math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
	)
	return cf.Position - ex, cf.Position + ex
end

R.defineClass("Workspace", {
	methods = {
		Raycast = function(_, origin, dir, params)
			return Physics.raycast(origin, dir, params)
		end,
		GetPartBoundsInBox = function(_, cf, size, params)
			local mn, mx = obbBounds(cf, size)
			return boxQuery(mn, mx, params)
		end,
		GetPartBoundsInRadius = function(_, pos, radius, params)
			local out = {}
			for _, p in ipairs(boxQuery(pos - Vector3.one * radius, pos + Vector3.one * radius, params)) do
				local mn, mx = aabb(states[p])
				local closest = Vector3.new(math.clamp(pos.X, mn.X, mx.X), math.clamp(pos.Y, mn.Y, mx.Y), math.clamp(pos.Z, mn.Z, mx.Z))
				if (closest - pos).Magnitude <= radius then
					table.insert(out, p)
				end
			end
			return out
		end,
		GetPartsInPart = function(_, part, params)
			local mn, mx = aabb(states[part])
			return boxQuery(mn, mx, params, part)
		end,
	},
})

------------------------------------------------------------------------------------------
-- Per-frame: ground snap for characters, Align constraints
------------------------------------------------------------------------------------------

local function groundSnap(model, mst)
	local root = R.findChild(mst, "HumanoidRootPart")
	local hum = nil
	for _, c in ipairs(mst.children) do
		if states[c].info.isA.Humanoid then
			hum = c
			break
		end
	end
	if not root or not hum then
		return
	end
	local rst = states[root]
	if getProp(rst, "Anchored") then
		return
	end
	local cf = getProp(rst, "CFrame")
	local size = getProp(rst, "Size")
	local params = R.D.RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true
	local origin = cf.Position + Vector3.new(0, size.Y, 0)
	local hit = Physics.raycast(origin, Vector3.new(0, -200, 0), params)
	if not hit then
		return
	end
	local hip = getProp(states[hum], "HipHeight") or 2
	local want = hit.Position.Y + hip + size.Y / 2
	if math.abs(cf.Position.Y - want) > 0.005 then
		root.CFrame = cf + Vector3.new(0, want - cf.Position.Y, 0)
	end
end

local function attachmentWorld(a)
	return a and states[a] and a.WorldCFrame or nil
end

local function alignStep(c, cst)
	if getProp(cst, "Enabled") == false then
		return
	end
	local a0 = getProp(cst, "Attachment0")
	if not a0 or not states[a0] then
		return
	end
	local part = states[a0].parent
	if not part or not states[part].info.isA.BasePart or getProp(states[part], "Anchored") then
		return
	end
	local pst = states[part]
	local partCF = getProp(pst, "CFrame")
	local aLocal = getProp(states[a0], "CFrame")
	local oneAtt = getProp(cst, "Mode") == Enum.PositionAlignmentMode.OneAttachment
	if cst.info.isA.AlignPosition then
		local goal
		if oneAtt then
			goal = getProp(cst, "Position")
		else
			local w = attachmentWorld(getProp(cst, "Attachment1"))
			goal = w and w.Position
		end
		if goal then
			local cur = (partCF * aLocal).Position
			part.CFrame = partCF + (goal - cur)
		end
	elseif cst.info.isA.AlignOrientation then
		local goalRot
		if getProp(cst, "Mode") == Enum.OrientationAlignmentMode.OneAttachment then
			goalRot = getProp(cst, "CFrame").Rotation
		else
			local w = attachmentWorld(getProp(cst, "Attachment1"))
			goalRot = w and w.Rotation
		end
		if goalRot then
			-- part rotation such that (part * aLocal).Rotation == goalRot
			local rot = goalRot * aLocal.Rotation:Inverse()
			local pivot = (partCF * aLocal).Position
			local newCF = CFrame.new(pivot) * rot * CFrame.new(aLocal.Position):Inverse()
			part.CFrame = newCF
		end
	end
end

function Physics.step()
	local ws = R.services.Workspace
	if not ws then
		return
	end
	local aligns = {}
	local chars = {}
	R.walk(ws, function(d)
		local st = states[d]
		local info = st.info
		if info.isA.AlignOrientation or info.isA.AlignPosition then
			table.insert(aligns, d)
		elseif info.isA.Model and R.findChild(st, "HumanoidRootPart") then
			table.insert(chars, d)
		end
	end)
	-- orientation first, then position (position uses the rotated attachment)
	for _, c in ipairs(aligns) do
		if states[c].info.isA.AlignOrientation then
			alignStep(c, states[c])
		end
	end
	for _, c in ipairs(aligns) do
		if states[c].info.isA.AlignPosition then
			alignStep(c, states[c])
		end
	end
	for _, m in ipairs(chars) do
		groundSnap(m, states[m])
	end
end

S.frameHooks.physics = function()
	if R.options.physics ~= false then
		Physics.step()
	end
end

R.physics = Physics
return Physics
