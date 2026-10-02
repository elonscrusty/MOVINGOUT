--[[
	Effects.luau
	Plays the server's Fx events locally: sounds, dust puffs, impact bursts, glass shards,
	splinters, splashes, delivery pops, stun stars, confetti. All effects are short-lived
	local parts that never collide (they can't block a route) and are capped in number;
	the Low quality setting halves them.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Audio = require(script.Parent.Audio)
local CameraController = require(script.Parent.CameraController)
local MoverAnimator = require(script.Parent.MoverAnimator)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Effects = {}

Effects.Toast = State.Signal() -- (text)
Effects.Event = State.Signal() -- (kind, data) for HUD / tutorial
local folder: Folder
local live = 0
local MAX_LIVE = 160
local rng = Random.new()

local function count(n: number): number
	if State.Settings().Quality == "Low" then
		return math.max(1, n // 2)
	end
	return n
end

local function bit(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part?
	if live >= MAX_LIVE then
		return nil
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	live += 1
	p.Destroying:Connect(function()
		live -= 1
	end)
	return p
end

-- Expanding fading balls (dust, splash).
function Effects.Puff(pos: Vector3, color: Color3, n: number, spread: number, size: number?)
	for _ = 1, count(n) do
		local s = (size or 1.2) * rng:NextNumber(0.7, 1.3)
		local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 0.6), rng:NextNumber(-1, 1)) * spread
		local p = bit(Vector3.new(s, s, s), CFrame.new(pos + offset * 0.3), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		if p then
			p.Transparency = 0.15
			local t = rng:NextNumber(0.35, 0.6)
			TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(s, s, s) * 2.2,
				Transparency = 1,
				CFrame = CFrame.new(pos + offset + Vector3.new(0, 1.2, 0)),
			}):Play()
			Debris:AddItem(p, t + 0.05)
		end
	end
end

-- Pieces flying out along an arc (glass, splinters, confetti), simulated by tweens.
function Effects.Burst(pos: Vector3, colors: { Color3 }, n: number, speed: number, size: Vector3, material: Enum.Material?, life: number?)
	for i = 1, count(n) do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 1.2), rng:NextNumber(-1, 1)).Unit
		local p = bit(size, CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), colors[(i - 1) % #colors + 1], material)
		if p then
			local l = life or 0.8
			local peak = pos + dir * speed * 0.5 + Vector3.new(0, speed * 0.25, 0)
			local land = pos + Vector3.new(dir.X, 0, dir.Z) * speed + Vector3.new(0, -2, 0)
			local up = TweenService:Create(p, TweenInfo.new(l * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(peak) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0) })
			up:Play()
			up.Completed:Connect(function()
				TweenService:Create(p, TweenInfo.new(l * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(land), Transparency = 1 }):Play()
			end)
			Debris:AddItem(p, l + 0.1)
		end
	end
end

-- Floating text over the world ("+1", "!").
function Effects.Pop(pos: Vector3, text: string, color: Color3)
	local anchor = bit(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), color)
	if not anchor then
		return
	end
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = UI.Title(gui, text, UDim2.fromScale(1, 1), UDim2.new(), color)
	TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) }):Play()
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.2)
end

local function itemPos(name: string?): Vector3?
	local level = Workspace:FindFirstChild("Level")
	local items = level and level:FindFirstChild("Items")
	local m = items and name and items:FindFirstChild(name)
	if m and m:IsA("Model") and m.PrimaryPart then
		return m.PrimaryPart.Position
	end
	return nil
end

local handlers: { [string]: (data: any) -> () } = {}

handlers.Sound = function(d)
	Audio.PlayAt(d.Name, d.Pos)
end

handlers.Toast = function(d)
	Effects.Toast:Fire(d.Text)
	Audio.Play("Error", 1.3, 0.6)
end

handlers.Grab = function(d)
	Audio.PlayAt("Grab", d.Pos)
	if d.Pos then
		Effects.Puff(d.Pos, Color3.fromRGB(255, 255, 255), 2, 0.6, 0.5)
	end
end

handlers.Windup = function(d)
	Audio.PlayAt("Windup", d.Pos, d.Coop and 0.8 or 1)
end

handlers.Throw = function(d)
	Audio.PlayAt("Throw", d.Pos, d.Coop and 0.8 or 1.4)
	for _, id in d.Throwers or {} do
		local p = Players:GetPlayerByUserId(id)
		if p then
			MoverAnimator.ThrowRelease(p)
		end
	end
	if d.Coop then
		CameraController.Shake(0.4)
	end
end

handlers.Slap = function(d)
	Audio.PlayAt("Slap", d.Pos)
end

handlers.Impact = function(d)
	local speed = d.Speed or 10
	local vol = math.clamp(speed / 30, 0.3, 1)
	Audio.PlayAt(d.Sound or "ImpactWood", d.Pos, nil, vol)
	if speed > 18 then
		Effects.Puff(d.Pos - Vector3.new(0, 1, 0), Color3.fromRGB(240, 230, 210), 3, 1.2, 0.9)
		if speed > 30 then
			CameraController.Shake(0.25)
		end
	end
end

handlers.Break = function(d)
	local cf: CFrame = d.CFrame
	local size: Vector3 = d.Size
	if d.Kind == "Glass" then
		Audio.PlayAt("Glass", cf.Position)
		Audio.PlayAt("GlassTinkle", cf.Position)
		Effects.Burst(cf.Position, { Color3.fromRGB(190, 230, 250), Color3.fromRGB(240, 250, 255) }, 10, 8, Vector3.new(0.5, 0.5, 0.1), Enum.Material.Glass, 1.0)
	else
		Audio.PlayAt("WoodBreak", cf.Position)
		Effects.Burst(cf.Position, { Color3.fromRGB(150, 108, 70), Color3.fromRGB(120, 86, 56) }, 8, 7, Vector3.new(1.2, 0.3, 0.3), Enum.Material.WoodPlanks, 1.0)
	end
	Effects.Puff(cf.Position - Vector3.new(0, size.Y / 3, 0), Color3.fromRGB(240, 236, 226), 4, 2, 1.2)
	CameraController.Shake(0.35)
	Effects.Event:Fire("Break", d)
end

handlers.Crack = function(d)
	Audio.PlayAt("WoodBreak", d.CFrame.Position, 1.4, 0.5)
	Effects.Puff(d.CFrame.Position, Color3.fromRGB(200, 170, 130), 2, 1, 0.8)
end

handlers.Deliver = function(d)
	local pos = d.Pos or itemPos(d.Item)
	if d.Delivered then
		Audio.PlayAt("Deliver", pos)
		if pos then
			Effects.Pop(pos + Vector3.new(0, 3, 0), "+1", UI.Colors.Green)
			Effects.Burst(pos + Vector3.new(0, 2, 0), { UI.Colors.Yellow, UI.Colors.White }, 6, 4, Vector3.new(0.4, 0.4, 0.4), Enum.Material.Neon, 0.7)
		end
	else
		Audio.PlayAt("Undeliver", pos)
		if pos then
			Effects.Pop(pos + Vector3.new(0, 3, 0), "-1", UI.Colors.Red)
		end
	end
	Effects.Event:Fire("Deliver", d)
end

handlers.Splash = function(d)
	Audio.PlayAt("Splash", d.Pos)
	Effects.Puff(Vector3.new(d.Pos.X, -0.6, d.Pos.Z), Color3.fromRGB(150, 210, 250), 7, 2.5, 1.4)
	Effects.Burst(Vector3.new(d.Pos.X, -0.4, d.Pos.Z), { Color3.fromRGB(120, 200, 245), Color3.fromRGB(230, 245, 255) }, 8, 6, Vector3.new(0.5, 0.5, 0.5), Enum.Material.Glass, 0.7)
end

handlers.Poof = function(d)
	if d.Pos then
		Effects.Puff(d.Pos, Color3.fromRGB(255, 255, 255), 6, 2.5, 1.4)
	end
end

handlers.Vanish = function(d)
	if d.Pos then
		Effects.Burst(d.Pos, { UI.Colors.Yellow, UI.Colors.White }, 10, 5, Vector3.new(0.4, 0.4, 0.4), Enum.Material.Neon, 0.6)
	end
end

handlers.Stun = function(d)
	local p = Players:GetPlayerByUserId(d.UserId)
	local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	Audio.PlayAt("Stun", root and root.Position)
	if p == Players.LocalPlayer then
		CameraController.Shake(0.3)
	end
end

handlers.Honk = function(d)
	Audio.PlayAt("Honk", d.Pos)
	Effects.Pop(d.Pos + Vector3.new(0, 4, 0), "! CAR !", UI.Colors.Orange)
end

handlers.Ghost = function(d)
	Audio.PlayAt("Ghost", d.Pos)
	Effects.Pop(d.Pos + Vector3.new(0, 3, 0), "!", UI.Colors.White)
end

handlers.GhostStun = function(d)
	Audio.PlayAt("SlapHit", d.Pos, 0.7)
	Effects.Pop(d.Pos + Vector3.new(0, 3, 0), "zzz", UI.Colors.Blue)
end

handlers.Spook = function(d)
	Audio.PlayAt("Ghost", d.Pos, 0.7)
	Effects.Pop(d.Pos + Vector3.new(0, 4, 0), "BOO!", UI.Colors.White)
end

handlers.Countdown = function(d)
	Audio.Play(d.N == 0 and "Go" or "Countdown")
	Effects.Event:Fire("Countdown", d)
end

handlers.Celebrate = function()
	Audio.Play("Complete")
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Effects.Burst(root.Position + Vector3.new(0, 4, 0), { UI.Colors.Red, UI.Colors.Yellow, UI.Colors.Blue, UI.Colors.Green }, 14, 9, Vector3.new(0.5, 0.1, 0.5), Enum.Material.Neon, 1.2)
		end
	end
	Effects.Event:Fire("Celebrate", {})
end

handlers.Results = function(d)
	Effects.Event:Fire("Results", d)
end

handlers.Profile = function(d)
	if type(d) == "table" and d.Settings then
		local settings = State.Profile.Settings
		State.Profile = d
		State.Profile.Settings = settings -- keep any local unsaved tweaks
		State.ProfileChanged:Fire()
	end
end

function Effects.Init()
	folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = Workspace
	Net.Fx.OnClientEvent:Connect(function(kind, data)
		local h = handlers[kind]
		if h then
			local ok, err = pcall(h, data or {})
			if not ok then
				warn("Effects." .. tostring(kind) .. ": " .. tostring(err))
			end
		end
	end)
	MoverAnimator.Landed:Connect(function(player, pos)
		if pos then
			Effects.Puff(pos, Color3.fromRGB(245, 240, 228), 3, 1.2, 0.8)
			if player == Players.LocalPlayer then
				Audio.Play("Land")
			end
		elseif player == Players.LocalPlayer then
			Audio.Play("Jump")
		end
	end)
	UI.SetSoundHook(function(name)
		Audio.Play(name)
	end)
end

return Effects
