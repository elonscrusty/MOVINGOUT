--!nocheck
--[[
	classes/character.luau - player characters for the preview.

	Player:LoadCharacter / LoadCharacterWithHumanoidDescription(Async) build a plain R15
	block rig (HumanoidRootPart, LowerTorso, UpperTorso, Head, arms, legs, hands, feet)
	joined by Motor6Ds with the standard R15 joint names (Root, Waist, Neck, Shoulders,
	Elbows, Wrists, Hips, Knees, Ankles) and rig attachments. Sizes follow Roblox's blocky
	R15 proportions; HumanoidDescription HeightScale / WidthScale / DepthScale / HeadScale
	scale them like Roblox's automatic scaling (heights by HeightScale, the head by
	HeadScale), and Humanoid.HipHeight is set to match. The rig appears at the origin; the
	game positions it (PivotTo) and the mock's ground snap (physics.luau) stands it on the
	floor. No avatar meshes, clothes or accessories.
]]

local roblox = require("@lune/roblox")
local R = require("../R")
local S = require("../scheduler")

local states = R.states
local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local Enum = roblox.Enum

local Character = {}

-- Blocky R15 at scale 1: name -> { size, centre y, centre x } with the ground at y = 0
-- and HipHeight 2 (the root part's bottom). Arms hang beside the torso.
local PARTS = {
	{ "LowerTorso", Vector3.new(2, 0.4, 1), 2.2, 0 },
	{ "UpperTorso", Vector3.new(2, 1.6, 1), 3.2, 0 },
	{ "Head", Vector3.new(1.2, 1.2, 1.2), 4.6, 0 },
	{ "LeftUpperArm", Vector3.new(1, 1, 1), 3.5, -1.5 },
	{ "LeftLowerArm", Vector3.new(1, 0.9, 1), 2.55, -1.5 },
	{ "LeftHand", Vector3.new(1, 0.3, 1), 1.95, -1.5 },
	{ "RightUpperArm", Vector3.new(1, 1, 1), 3.5, 1.5 },
	{ "RightLowerArm", Vector3.new(1, 0.9, 1), 2.55, 1.5 },
	{ "RightHand", Vector3.new(1, 0.3, 1), 1.95, 1.5 },
	{ "LeftUpperLeg", Vector3.new(1, 0.85, 1), 1.575, -0.5 },
	{ "LeftLowerLeg", Vector3.new(1, 0.85, 1), 0.725, -0.5 },
	{ "LeftFoot", Vector3.new(1, 0.3, 1), 0.15, -0.5 },
	{ "RightUpperLeg", Vector3.new(1, 0.85, 1), 1.575, 0.5 },
	{ "RightLowerLeg", Vector3.new(1, 0.85, 1), 0.725, 0.5 },
	{ "RightFoot", Vector3.new(1, 0.3, 1), 0.15, 0.5 },
}

-- joint name, part0, part1, joint position (y, x) at scale 1
local JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", 2.0, 0, "Root" },
	{ "Waist", "LowerTorso", "UpperTorso", 2.4, 0, "Waist" },
	{ "Neck", "UpperTorso", "Head", 4.0, 0, "Neck" },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", 3.9, -1.25, "LeftShoulder" },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", 3.0, -1.5, "LeftElbow" },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", 2.1, -1.5, "LeftWrist" },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", 3.9, 1.25, "RightShoulder" },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", 3.0, 1.5, "RightElbow" },
	{ "RightWrist", "RightLowerArm", "RightHand", 2.1, 1.5, "RightWrist" },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", 2.0, -0.5, "LeftHip" },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", 1.15, -0.5, "LeftKnee" },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", 0.3, -0.5, "LeftAnkle" },
	{ "RightHip", "LowerTorso", "RightUpperLeg", 2.0, 0.5, "RightHip" },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", 1.15, 0.5, "RightKnee" },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", 0.3, 0.5, "RightAnkle" },
}

local function new(className: string, name: string, parent)
	local inst = R.create(className)
	inst.Name = name
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Builds an R15 rig (Model) for `player` with the description's scales.
function Character.build(player, desc)
	local hs = desc and desc.HeightScale or 1
	local ws = desc and desc.WidthScale or 1
	local ds = desc and desc.DepthScale or 1
	local heads = desc and desc.HeadScale or 1
	local model = new("Model", player and player.Name or "Character", nil)
	local hipHeight = 2 * hs
	local rootSize = Vector3.new(2 * ws, 2 * hs, 1 * ds)
	local root = new("Part", "HumanoidRootPart", model)
	root.Size = rootSize
	root.CFrame = CFrame.new(0, hipHeight + rootSize.Y / 2, 0)
	root.Transparency = 1
	root.CanCollide = false
	root.CastShadow = false
	model.PrimaryPart = root
	local parts = { HumanoidRootPart = root }
	local skin = Color3.fromRGB(234, 184, 146)
	for _, def in ipairs(PARTS) do
		local name, size, y, x = def[1], def[2], def[3], def[4]
		local p = new("Part", name, model)
		local isHead = name == "Head"
		if isHead then
			p.Size = size * heads
		else
			p.Size = Vector3.new(size.X * ws, size.Y * hs, size.Z * ds)
		end
		local cy = y * hs
		if isHead then
			cy = 4.0 * hs + p.Size.Y / 2
		end
		p.CFrame = CFrame.new(x * ws, cy, 0)
		p.Color = (string.find(name, "Torso") and Color3.fromRGB(80, 120, 200)) or (string.find(name, "Leg") or string.find(name, "Foot")) and Color3.fromRGB(60, 70, 90) or skin
		p.CanCollide = false
		parts[name] = p
	end
	local face = new("Decal", "face", parts.Head)
	face.Face = Enum.NormalId.Front
	for _, j in ipairs(JOINTS) do
		local name, p0, p1, y, x, att = j[1], parts[j[2]], parts[j[3]], j[4], j[5], j[6]
		local at = CFrame.new(x * ws, y * hs, 0)
		local c0 = p0.CFrame:ToObjectSpace(at)
		local c1 = p1.CFrame:ToObjectSpace(at)
		local a0 = new("Attachment", att .. "RigAttachment", p0)
		a0.CFrame = c0
		local a1 = new("Attachment", att .. "RigAttachment", p1)
		a1.CFrame = c1
		local m = new("Motor6D", name, nil)
		m.C0 = c0
		m.C1 = c1
		m.Part0 = p0
		m.Part1 = p1
		m.Parent = p1
	end
	local hum = new("Humanoid", "Humanoid", nil)
	hum.HipHeight = hipHeight
	hum.RigType = Enum.HumanoidRigType.R15
	local animator = new("Animator", "Animator", hum)
	local _ = animator
	hum.Parent = model
	local scaleNames = { BodyHeightScale = hs, BodyWidthScale = ws, BodyDepthScale = ds, HeadScale = heads }
	for n, v in pairs(scaleNames) do
		local nv = new("NumberValue", n, hum)
		nv.Value = v
	end
	if desc then
		local copy = desc:Clone()
		copy.Parent = hum
	end
	return model
end

-- Spawns a new character for the player like Roblox: the old one is removed, the new
-- one is parented to Workspace and assigned to player.Character (CharacterAdded).
function Character.load(player, desc)
	local old = player.Character
	if old then
		player.Character = nil
		old:Destroy()
	end
	local model = Character.build(player, desc)
	model.Name = player.Name
	-- StarterCharacterScripts are not run (the game's own scripts handle movers)
	model.Parent = R.services.Workspace
	player.Character = model
	R.fire(states[player], "CharacterAppearanceLoaded", model)
	return model
end

local function loadWith(player, desc)
	if desc ~= nil and not (R.isInstance(desc) and states[desc].info.isA.HumanoidDescription) then
		error("Unable to cast value to Object (HumanoidDescription expected)", 3)
	end
	Character.load(player, desc)
end

R.defineClass("Player", {
	methods = {
		LoadCharacter = function(player)
			Character.load(player, nil)
		end,
		LoadCharacterAsync = function(player)
			Character.load(player, nil)
		end,
		LoadCharacterWithHumanoidDescription = function(player, desc)
			loadWith(player, desc)
		end,
		LoadCharacterWithHumanoidDescriptionAsync = function(player, desc)
			loadWith(player, desc)
		end,
	},
})

local _ = S
R.character = Character
return Character
