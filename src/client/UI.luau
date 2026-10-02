--[[
	UI.luau
	Small UI kit in the game's chunky cartoon style: cream panels with dark outlines,
	big rounded buttons, FredokaOne text. Every button is selectable with a gamepad and
	navigable with the keyboard (arrows / WASD + Enter) through UI.SetNav, and shows a
	clear focus ring. Text and HUD scale with the TextScale setting.
]]

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local State = require(script.Parent.State)

local UI = {}

UI.Font = Enum.Font.FredokaOne
UI.Colors = {
	Panel = Color3.fromRGB(255, 248, 234),
	PanelDark = Color3.fromRGB(64, 52, 78),
	Ink = Color3.fromRGB(52, 40, 60),
	Yellow = Color3.fromRGB(255, 204, 64),
	Orange = Color3.fromRGB(255, 140, 70),
	Red = Color3.fromRGB(236, 84, 80),
	Green = Color3.fromRGB(96, 200, 110),
	Blue = Color3.fromRGB(90, 160, 240),
	White = Color3.fromRGB(255, 255, 255),
	Grey = Color3.fromRGB(190, 186, 196),
	Gold = Color3.fromRGB(255, 200, 50),
	Silver = Color3.fromRGB(200, 210, 222),
	Bronze = Color3.fromRGB(214, 140, 80),
}
local C = UI.Colors

local roots: { ScreenGui } = {}
local scales: { UIScale } = {}

local function applyScale()
	local s = State.Settings().TextScale or 1
	for _, sc in scales do
		sc.Scale = s
	end
end

function UI.Root(name: string, order: number): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = order
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(roots, g)
	return g
end

-- A full-screen container that scales with the TextScale setting.
function UI.Layer(root: ScreenGui, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.Parent = root
	return f
end

-- Scales a frame's contents by the TextScale setting (pinned at the given anchor).
function UI.Scaled(frame: GuiObject)
	local s = Instance.new("UIScale")
	s.Parent = frame
	table.insert(scales, s)
	applyScale()
end

function UI.Corner(obj: GuiObject, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 16)
	c.Parent = obj
	return c
end

function UI.Stroke(obj: GuiObject, thickness: number?, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or C.Ink
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

function UI.Panel(parent: Instance, size: UDim2, pos: UDim2, anchor: Vector2?, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = color or C.Panel
	f.BorderSizePixel = 0
	f.Parent = parent
	UI.Corner(f, 20)
	UI.Stroke(f, 4)
	return f
end

function UI.Text(parent: Instance, text: string, size: UDim2, pos: UDim2, props: any?): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = size
	t.Position = pos
	t.BackgroundTransparency = 1
	t.Font = UI.Font
	t.Text = text
	t.TextColor3 = C.Ink
	t.TextScaled = true
	t.TextWrapped = true
	t.RichText = true
	if props then
		for k, v in props do
			(t :: any)[k] = v
		end
	end
	t.Parent = parent
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = props and props.MaxText or 40
	lim.MinTextSize = 9
	lim.Parent = t
	return t
end

-- Outlined title text (white with a dark stroke) for over-the-world labels.
function UI.Title(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3?): TextLabel
	local t = UI.Text(parent, text, size, pos, { TextColor3 = color or C.White, MaxText = 96 })
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = C.Ink
	s.Parent = t
	return t
end

local function focusRing(): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 12, 1, 12)
	f.Position = UDim2.fromOffset(-6, -6)
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = C.White
	s.Parent = f
	local s2 = Instance.new("UICorner")
	s2.CornerRadius = UDim.new(0, 20)
	s2.Parent = f
	return f
end

local clickSound: ((string) -> ())? = nil
function UI.SetSoundHook(fn: (string) -> ())
	clickSound = fn
end

export type Button = TextButton

function UI.Button(parent: Instance, text: string, size: UDim2, pos: UDim2, onClick: () -> (), color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.BackgroundColor3 = color or C.Yellow
	b.AutoButtonColor = false
	b.Font = UI.Font
	b.Text = text
	b.TextColor3 = C.Ink
	b.TextScaled = true
	b.Selectable = true
	b.SelectionImageObject = focusRing()
	b.Parent = parent
	UI.Corner(b, 16)
	local stroke = UI.Stroke(b, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = b
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = 30
	lim.Parent = b
	local base = color or C.Yellow
	local function hover(on: boolean)
		b.BackgroundColor3 = on and base:Lerp(C.White, 0.25) or base
		stroke.Thickness = on and 4 or 3
	end
	b.MouseEnter:Connect(function()
		hover(true)
		if clickSound then
			clickSound("Focus")
		end
	end)
	b.MouseLeave:Connect(function()
		hover(false)
	end)
	b.SelectionGained:Connect(function()
		hover(true)
		if clickSound then
			clickSound("Focus")
		end
	end)
	b.SelectionLost:Connect(function()
		hover(false)
	end)
	b.Activated:Connect(function()
		if b:GetAttribute("Disabled") then
			if clickSound then
				clickSound("Error")
			end
			return
		end
		if clickSound then
			clickSound("Click")
		end
		local sc = b:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		sc.Parent = b
		sc.Scale = 0.92
		TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onClick()
	end)
	return b
end

function UI.SetDisabled(b: TextButton, disabled: boolean)
	b:SetAttribute("Disabled", disabled)
	b.TextTransparency = disabled and 0.5 or 0
	b.BackgroundTransparency = disabled and 0.35 or 0
end

----------------------------------------------------------------------------------------
-- Keyboard / gamepad menu navigation

local navList: { GuiObject } = {}
local navIndex = 0

-- Makes these buttons the active menu: arrows / WASD move, Enter activates.
function UI.SetNav(list: { GuiObject }, focusFirst: boolean?)
	navList = list
	navIndex = 0
	State.MenuOpen = #list > 0
	if #list > 0 and (focusFirst ~= false) then
		navIndex = 1
		GuiService.SelectedObject = list[1]
	elseif #list == 0 then
		GuiService.SelectedObject = nil
	end
end

function UI.NavActive(): boolean
	return #navList > 0
end

function UI.NavMove(delta: number)
	if #navList == 0 then
		return
	end
	local current = GuiService.SelectedObject
	local idx = current and table.find(navList, current) or navIndex
	local n = #navList
	for _ = 1, n do
		idx = ((idx or 0) - 1 + delta) % n + 1
		local candidate = navList[idx]
		if candidate.Visible and not candidate:GetAttribute("Disabled") then
			break
		end
	end
	navIndex = idx or 1
	GuiService.SelectedObject = navList[navIndex]
end

function UI.NavActivate()
	local current = GuiService.SelectedObject
	if current and table.find(navList, current) and current:IsA("GuiButton") then
		-- Activated can't be fired from code; buttons store their handler for this
		local fire = current:FindFirstChild("Fire") :: BindableEvent?
		if fire then
			fire:Fire()
		end
	end
end

-- Lets keyboard Enter trigger a button (Activated only fires from real input).
function UI.Bindable(b: TextButton, fn: () -> ())
	local ev = Instance.new("BindableEvent")
	ev.Name = "Fire"
	ev.Event:Connect(function()
		if b:GetAttribute("Disabled") then
			return
		end
		if clickSound then
			clickSound("Click")
		end
		fn()
	end)
	ev.Parent = b
end

-- Button + keyboard binding in one call.
function UI.NavButton(parent: Instance, text: string, size: UDim2, pos: UDim2, onClick: () -> (), color: Color3?): TextButton
	local b = UI.Button(parent, text, size, pos, onClick, color)
	UI.Bindable(b, onClick)
	return b
end

function UI.Init()
	State.SettingsChanged:Connect(applyScale)
end

-- Short pop-in animation for panels (respects Reduced Motion via ReducedShake setting).
function UI.PopIn(obj: GuiObject)
	local sc = obj:FindFirstChild("PopScale") :: UIScale?
	if not sc then
		local s = Instance.new("UIScale")
		s.Name = "PopScale"
		s.Parent = obj
		sc = s
	end
	local scale = sc :: UIScale
	if State.Settings().ReducedShake then
		scale.Scale = 1
		return
	end
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function UI.FormatTime(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = seconds - m * 60
	return string.format("%d:%05.2f", m, s)
end

return UI
