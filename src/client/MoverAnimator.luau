--[[
	MoverAnimator.luau
	Everything that makes movers readable and expressive, for every mover (local only):
	  * a numbered ground ring in the slot colour that sits on the floor under the mover
	    (raycast; hidden while falling / recovering, never z-fights: it floats 0.06 up),
	  * an overhead tag "P1 ▲" (number + symbol, not just colour),
	  * procedural poses layered over Roblox's walk / idle / jump animations:
	    carrying (arms out to the load, heavier = lower arms and a lean), throw wind-up
	    and release, slap, stunned flailing with stars, celebrating.
	Poses write Motor6D.Transform in PreSimulation, after the Animator has run.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local MoverAnimator = {}

type Rig = {
	Player: Player,
	Char: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	LS: Motor6D?,
	RS: Motor6D?,
	LE: Motor6D?,
	RE: Motor6D?,
	Waist: Motor6D?,
	Neck: Motor6D?,
	Ring: Part,
	RingLabel: TextLabel,
	RingStroke: UIStroke,
	Tag: BillboardGui,
	Stars: BillboardGui,
	ThrowAt: number,
}

local rigs: { [Player]: Rig } = {}
local folder: Folder
local rad = math.rad
local Angles = CFrame.Angles

MoverAnimator.Landed = State.Signal()

local function motor(char: Model, part: string, name: string): Motor6D?
	local p = char:FindFirstChild(part)
	return p and p:FindFirstChild(name) :: Motor6D?
end

local function makeRing(slot: number): (Part, TextLabel, UIStroke)
	local info = Config.Slots[slot] or Config.Slots[1]
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Transparency = 1
	ring.Size = Vector3.new(4.6, 0.1, 4.6)
	ring.Parent = folder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = ring
	local circle = Instance.new("Frame")
	circle.Size = UDim2.fromScale(0.92, 0.92)
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.BackgroundTransparency = 1
	circle.Parent = gui
	UI.Corner(circle, 999)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 14
	stroke.Color = info.Color
	stroke.Parent = circle
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.3, 0.3)
	label.Position = UDim2.fromScale(0.5, 0.96)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundColor3 = info.Color
	label.Font = UI.Font
	label.Text = tostring(slot)
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
	UI.Corner(label, 999)
	return ring, label, stroke
end

local function makeTag(player: Player, slot: number, head: BasePart): (BillboardGui, BillboardGui)
	local info = Config.Slots[slot] or Config.Slots[1]
	local tag = Instance.new("BillboardGui")
	tag.Name = "MoverTag"
	tag.Size = UDim2.fromOffset(64, 22)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.3, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.MaxDistance = 400
	tag.Adornee = head
	tag.Parent = folder
	-- small and quiet: the ring and shirt number do most of the work; your own tag
	-- gets a white outline so you can find yourself in a crowd
	local t = UI.Text(tag, info.Name .. info.Symbol, UDim2.fromScale(1, 1), UDim2.new(), { TextColor3 = info.Color, MaxText = 18 })
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = player == Players.LocalPlayer and Color3.new(1, 1, 1) or Color3.fromRGB(30, 24, 36)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = t
	local stars = Instance.new("BillboardGui")
	stars.Name = "Stars"
	stars.Size = UDim2.fromOffset(90, 40)
	stars.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	stars.AlwaysOnTop = true
	stars.Enabled = false
	stars.Adornee = head
	stars.Parent = folder
	UI.Text(stars, "★ ✦ ★", UDim2.fromScale(1, 1), UDim2.new(), { TextColor3 = Color3.fromRGB(255, 220, 80), MaxText = 30 })
	return tag, stars
end

local function removeRig(player: Player)
	local r = rigs[player]
	if r then
		r.Ring:Destroy()
		r.Tag:Destroy()
		r.Stars:Destroy()
		rigs[player] = nil
	end
end

local function buildRig(player: Player, char: Model)
	removeRig(player)
	local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	local head = char:WaitForChild("Head", 10) :: BasePart?
	if not root or not hum or not head then
		return
	end
	local slot = (player:GetAttribute("Slot") :: number?) or 1
	local ring, label, stroke = makeRing(slot)
	local tag, stars = makeTag(player, slot, head)
	local rig: Rig = {
		Player = player,
		Char = char,
		Root = root,
		Humanoid = hum,
		LS = motor(char, "LeftUpperArm", "LeftShoulder"),
		RS = motor(char, "RightUpperArm", "RightShoulder"),
		LE = motor(char, "LeftLowerArm", "LeftElbow"),
		RE = motor(char, "RightLowerArm", "RightElbow"),
		Waist = motor(char, "UpperTorso", "Waist"),
		Neck = motor(char, "Head", "Neck"),
		Ring = ring,
		RingLabel = label,
		RingStroke = stroke,
		Tag = tag,
		Stars = stars,
		ThrowAt = 0,
	}
	rigs[player] = rig
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			MoverAnimator.Landed:Fire(player, root.Position - Vector3.new(0, 2.6, 0))
		elseif new == Enum.HumanoidStateType.Jumping and player == Players.LocalPlayer then
			MoverAnimator.Landed:Fire(player, nil)
		end
	end)
end

-- Marks a throw release so the arms snap forward (called from Effects).
function MoverAnimator.ThrowRelease(player: Player)
	local r = rigs[player]
	if r then
		r.ThrowAt = os.clock()
	end
end

local function track(player: Player)
	local function onChar(char: Model)
		task.spawn(buildRig, player, char)
	end
	if player.Character then
		onChar(player.Character)
	end
	player.CharacterAdded:Connect(onChar)
	player.CharacterRemoving:Connect(function()
		removeRig(player)
	end)
	player:GetAttributeChangedSignal("Slot"):Connect(function()
		if player.Character then
			onChar(player.Character)
		end
	end)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateRings()
	local exclude: { Instance } = { folder }
	for _, r in rigs do
		table.insert(exclude, r.Char)
	end
	local level = Workspace:FindFirstChild("Level")
	if level and level:FindFirstChild("Items") then
		table.insert(exclude, (level :: any).Items)
	end
	rayParams.FilterDescendantsInstances = exclude
	for player, r in rigs do
		if not r.Root.Parent then
			continue
		end
		local hit = Workspace:Raycast(r.Root.Position, Vector3.new(0, -14, 0), rayParams)
		local visible = hit ~= nil and not player:GetAttribute("Recovering") and r.Root.Position.Y > -10
		if hit then
			r.Ring.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.06, 0))
		end
		local gui = r.Ring:FindFirstChildOfClass("SurfaceGui")
		if gui then
			gui.Enabled = visible
		end
		-- the ring shrinks a little while airborne so jumps read clearly
		local air = hit and (r.Root.Position.Y - hit.Position.Y) or 0
		local s = math.clamp(1 - (air - 2.6) / 10, 0.6, 1)
		r.Ring.Size = Vector3.new(4.6 * s, 0.1, 4.6 * s)
	end
end

local function pose(r: Rig, t: number)
	local p = r.Player
	local now = Workspace:GetServerTimeNow()
	local stunned = ((p:GetAttribute("StunUntil") :: number?) or 0) > now
	local holding = p:GetAttribute("Holding")
	local class = p:GetAttribute("HoldingClass")
	local windup = p:GetAttribute("Windup")
	local slapAt = (p:GetAttribute("SlapAt") :: number?) or 0
	local celebrating = State.Phase() == "Results"
	r.Stars.Enabled = stunned

	local ls, rs, le, re, waist, neck
	if stunned then
		local w = math.sin(t * 18)
		ls = Angles(rad(150 + w * 20), 0, rad(-25))
		rs = Angles(rad(150 - w * 20), 0, rad(25))
		waist = Angles(0, rad(w * 15), rad(w * 6))
		neck = Angles(0, rad(-w * 20), 0)
	elseif celebrating then
		local w = math.sin(t * 10)
		ls = Angles(rad(165), 0, rad(-20 + w * 15))
		rs = Angles(rad(165), 0, rad(20 - w * 15))
		waist = Angles(0, rad(w * 8), 0)
	elseif windup then
		ls = Angles(rad(165), 0, rad(-10))
		rs = Angles(rad(165), 0, rad(10))
		waist = Angles(rad(-14), 0, 0)
	elseif os.clock() - r.ThrowAt < 0.25 then
		ls = Angles(rad(70), 0, 0)
		rs = Angles(rad(70), 0, 0)
		waist = Angles(rad(14), 0, 0)
	elseif holding then
		local heavy = class == "Heavy"
		local medium = class == "Medium"
		local lift = heavy and 62 or (medium and 72 or 85)
		local bob = math.sin(t * 9) * (heavy and 3 or 1.5) * math.clamp(r.Root.AssemblyLinearVelocity.Magnitude / 10, 0, 1)
		ls = Angles(rad(lift + bob), 0, rad(-12))
		rs = Angles(rad(lift - bob), 0, rad(12))
		le = Angles(rad(15), 0, 0)
		re = Angles(rad(15), 0, 0)
		waist = Angles(rad(heavy and 10 or (medium and 5 or -3)), 0, 0)
	end
	if now - slapAt < 0.3 then
		local k = (now - slapAt) / 0.3
		rs = Angles(rad(95), rad(-70 + 140 * k), 0)
		waist = Angles(0, rad(-25 + 50 * k), 0)
	end
	if ls and r.LS then
		r.LS.Transform = ls
	end
	if rs and r.RS then
		r.RS.Transform = rs
	end
	if le and r.LE then
		r.LE.Transform = le
	end
	if re and r.RE then
		r.RE.Transform = re
	end
	if waist and r.Waist then
		r.Waist.Transform = waist
	end
	if neck and r.Neck then
		r.Neck.Transform = neck
	end
end

function MoverAnimator.Init()
	folder = Instance.new("Folder")
	folder.Name = "MoverFx"
	folder.Parent = Workspace
	for _, p in Players:GetPlayers() do
		track(p)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(removeRig)
	RunService.PreSimulation:Connect(function()
		local t = os.clock()
		for _, r in rigs do
			if r.Char.Parent then
				pose(r, t)
			end
		end
	end)
	RunService.RenderStepped:Connect(updateRings)
end

return MoverAnimator
