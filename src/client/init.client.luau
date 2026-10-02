--[[
	Client entry point. Boot order: loading screen -> systems -> title screen.
	Gameplay authority is the server; the client renders, animates, plays sound and
	sends requests.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local State = require(script.State)
local UI = require(script.UI)
local Audio = require(script.Audio)
local Effects = require(script.Effects)
local Input = require(script.Input)
local Targeting = require(script.Targeting)
local CameraController = require(script.CameraController)
local MoverAnimator = require(script.MoverAnimator)
local Menus = require(script.Menus)
local Hud = require(script.Hud)

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)
for _, t in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(t, false)
	end)
end

-- loading screen until the world and the profile are here
local loadingRoot = UI.Root("Loading", 100)
local cover = Instance.new("Frame")
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundColor3 = Color3.fromRGB(255, 196, 80)
cover.Parent = loadingRoot
local title = UI.Title(cover, "MOVING OUT", UDim2.fromScale(0.7, 0.18), UDim2.fromScale(0.5, 0.42), Color3.new(1, 1, 1))
title.AnchorPoint = Vector2.new(0.5, 0.5)
local sub = UI.Title(cover, "Loading the truck...", UDim2.fromScale(0.5, 0.06), UDim2.fromScale(0.5, 0.58), Color3.new(1, 1, 1))
sub.AnchorPoint = Vector2.new(0.5, 0.5)

UI.Init()
Audio.Init()
Effects.Init()
Input.Init()
Targeting.Init()
Input.SetTargetProvider(Targeting.Current)
CameraController.Init()
MoverAnimator.Init()
Menus.Init()
Hud.Init()

local function applyQuality()
	Lighting.GlobalShadows = State.Settings().Quality ~= "Low"
end
State.SettingsChanged:Connect(applyQuality)

task.spawn(function()
	State.LoadProfile()
	applyQuality()
	local t0 = os.clock()
	while not Workspace:FindFirstChild("Level") and os.clock() - t0 < 15 do
		task.wait(0.1)
	end
	cover:Destroy()
	Menus.FollowPhase()
end)
