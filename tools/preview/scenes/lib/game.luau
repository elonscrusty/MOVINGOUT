--!nocheck
--[[
	scenes/lib/game.luau - boots MOVING OUT on the mock and drives it like players would.

	G.boot(opts) runs the real server (ServerScriptService.Server = init.server.luau) and
	the real client (StarterPlayerScripts.Client = init.client.luau), then:
	  opts.join    (default true)  the local player presses the real PLAY button
	  opts.movers  (default 1)     extra Players join through the Action remote ("Play")
	  opts.level   (default Depot) a job id: the host selects it on the job board path
	                               (SelectJob -> Briefing); the job is unlocked first
	  opts.phase   "Lobby" | "Briefing" | "Countdown" | "Playing" (StartJob + 3 s)
	Movers get styles 1..N so each wears a different hat. Returns a context table.

	Camera helpers mirror CameraController (Config.Camera + the level's Camera.Yaw /
	Pitch, distance from the spread of the movers) for --set focus / dist overrides.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local G = {}

function G.state()
	return ReplicatedStorage:FindFirstChild("GameState")
end

function G.phase()
	local st = G.state()
	return st and st:GetAttribute("Phase")
end

function G.server(name: string)
	return preview.server(name)
end

function G.levelData(id: string)
	local levels = ReplicatedStorage.Shared:FindFirstChild("Levels")
	local m = levels and levels:FindFirstChild(id)
	if not m then
		local names = {}
		for _, c in levels:GetChildren() do
			table.insert(names, c.Name)
		end
		table.sort(names)
		error("no level " .. tostring(id) .. " (levels: " .. table.concat(names, ", ") .. ")")
	end
	return preview.require(m)
end

local function action(player, name, ...)
	preview.fireServerAs(player, "Action", name, ...)
end
G.action = action

function G.boot(opts)
	opts = opts or {}
	local ctx = { players = {} }
	preview.startServer()
	preview.advance(0.2)
	preview.startClient()
	preview.advance(0.6)
	local me = preview.player()
	ctx.me = me
	if opts.join == false then
		return ctx
	end
	local play = preview.findGui("PLAY")[1]
	if play then
		preview.click(play)
	else
		preview.warn("no PLAY button found; joining through the remote")
		action(me, "Play")
	end
	preview.advance(0.1)
	table.insert(ctx.players, me)
	local n = math.clamp(opts.movers or 1, 1, 4)
	for i = 2, n do
		local p = preview.addPlayer("Mover" .. i, 1000 + i)
		preview.advance(0.05)
		action(p, "Play")
		preview.advance(0.05)
		table.insert(ctx.players, p)
	end
	for i, p in ctx.players do
		if opts.styles ~= false then
			action(p, "SetStyle", opts.styles and opts.styles[i] or i)
		end
	end
	preview.advance(0.2)
	local level = opts.level or "Depot"
	if level ~= "Depot" then
		local Data = G.server("DataService")
		for _, p in ctx.players do
			local profile = Data.Get(p)
			if profile then
				profile.Unlocked[level] = true
			end
		end
		action(me, "SelectJob", level, opts.assists)
		preview.advance(0.3)
		if G.phase() ~= "Briefing" then
			preview.warn("SelectJob " .. level .. " did not reach Briefing (phase " .. tostring(G.phase()) .. ")")
		end
		if opts.phase == "Playing" or opts.phase == "Countdown" then
			action(me, "StartJob")
			preview.advance(opts.phase == "Playing" and 3.3 or 0.4)
		end
	end
	return ctx
end

-- CameraController's framing for these positions: (focus, distance).
function G.frame(positions: { Vector3 })
	local Config = preview.shared("Config")
	local C = Config.Camera
	if #positions == 0 then
		return Vector3.zero, C.MinDistance
	end
	local minV, maxV = positions[1], positions[1]
	for _, p in positions do
		minV = minV:Min(p)
		maxV = maxV:Max(p)
	end
	local extent = math.max(maxV.X - minV.X, maxV.Z - minV.Z) + C.Margin * 2
	local want = math.clamp(C.MinDistance + (extent - C.Margin * 2) * C.DistancePerStud, C.MinDistance, C.MaxDistance)
	local focus = (minV + maxV) / 2
	return Vector3.new(focus.X, math.max(focus.Y - 2, 0), focus.Z), want
end

-- The camera CFrame CameraController builds for a focus / distance / yaw / pitch.
function G.cameraCFrame(focus: Vector3, distance: number, yawDeg: number, pitchDeg: number)
	local rot = CFrame.Angles(0, math.rad(yawDeg), 0) * CFrame.Angles(-math.rad(pitchDeg), 0, 0)
	local camPos = focus + rot * Vector3.new(0, 0, distance)
	return CFrame.lookAt(camPos, focus)
end

function G.yawPitch(data)
	local Config = preview.shared("Config")
	local yaw = data and data.Camera and data.Camera.Yaw or Config.Camera.Yaw
	local pitch = data and data.Camera and data.Camera.Pitch or Config.Camera.Pitch
	return yaw, pitch
end

-- Parses "x,z" or "x,y,z".
function G.vec(text: string?): Vector3?
	if not text then
		return nil
	end
	local nums = {}
	for n in string.gmatch(text, "[-%d%.]+") do
		table.insert(nums, tonumber(n))
	end
	if #nums == 2 then
		return Vector3.new(nums[1], 0, nums[2])
	elseif #nums >= 3 then
		return Vector3.new(nums[1], nums[2], nums[3])
	end
	return nil
end

function G.moverRoots(): { Vector3 }
	local out = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and (p:GetAttribute("Slot") or 0) > 0 then
			table.insert(out, r.Position)
		end
	end
	return out
end

function G.levelFolder()
	return Workspace:FindFirstChild("Level")
end

-- Shows the client's ScreenGuis or not (BillboardGuis / SurfaceGuis stay).
function G.hud(on: boolean)
	preview.render.hideScreenGui = not on
end

return G
