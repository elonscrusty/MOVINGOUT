--[[
	UI.luau
	Small UI kit in the game's chunky cartoon style: cream cards with a tan rim and a
	sky-blue ribbon title, big rounded buttons with a soft top-lit gradient, bold white
	FredokaOne text with a dark outline on coloured surfaces. Every button is selectable with a gamepad and
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
	Panel = Color3.fromRGB(253, 244, 222),
	PanelRim = Color3.fromRGB(232, 208, 164),
	PanelDark = Color3.fromRGB(110, 84, 64),
	Ink = Color3.fromRGB(70, 48, 40),
	Cream = Color3.fromRGB(244, 226, 190),
	Sky = Color3.fromRGB(96, 198, 244),
	SkyDark = Color3.fromRGB(28, 96, 160),
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

-- Small screens (phones) shrink the UI so it doesn't cover the playfield.
local function screenFactor(): number
	local cam = workspace.CurrentCamera
	local h = cam and cam.ViewportSize.Y or 720
	return math.clamp(h / 720, 0.62, 1)
end
UI.ScreenFactor = screenFactor

local function applyScale()
	local s = (State.Settings().TextScale or 1) * screenFactor()
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
	UI.Corner(f, 22)
	UI.Stroke(f, 6, C.PanelRim)
	return f
end

-- Vertical top-lit shading for chunky surfaces (multiplies the background colour).
function UI.Shade(obj: GuiObject, amount: number?)
	local g = Instance.new("UIGradient")
	local k = 1 - (amount or 0.14)
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(k, k, k))
	g.Rotation = 90
	g.Parent = obj
	return g
end

-- Bold outlined text (white with a dark contextual stroke), like the HUD numbers.
function UI.Outlined(parent: Instance, text: string, size: UDim2, pos: UDim2, props: any?): TextLabel
	local t = UI.Text(parent, text, size, pos, props)
	if not (props and props.TextColor3) then
		t.TextColor3 = C.White
	end
	local s = Instance.new("UIStroke")
	s.Thickness = props and props.Outline or 3
	s.Color = props and props.OutlineColor or C.Ink
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = t
	return t
end

-- A sky-blue ribbon title tag that straddles the top edge of a card.
function UI.Banner(parent: Instance, text: string, width: number?): TextLabel
	local b = Instance.new("Frame")
	b.Name = "Banner"
	b.Size = UDim2.new(width or 0.46, 0, 0, 60)
	b.Position = UDim2.new(0.5, 0, 0, -4)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Rotation = -1.5
	b.BackgroundColor3 = C.Sky
	b.ZIndex = 5
	b.Parent = parent
	UI.Corner(b, 14)
	UI.Stroke(b, 5, C.White)
	UI.Shade(b, 0.12)
	local lim = Instance.new("UISizeConstraint")
	lim.MinSize = Vector2.new(200, 0)
	lim.MaxSize = Vector2.new(460, 60)
	lim.Parent = b
	-- folded ribbon corner
	local fold = Instance.new("Frame")
	fold.Size = UDim2.fromOffset(22, 22)
	fold.Position = UDim2.new(1, -6, 1, -6)
	fold.AnchorPoint = Vector2.new(0.5, 0.5)
	fold.Rotation = 45
	fold.BackgroundColor3 = C.SkyDark
	fold.ZIndex = 4
	fold.Parent = b
	local t = UI.Outlined(b, text, UDim2.new(1, -24, 1, -12), UDim2.fromOffset(12, 6), { MaxText = 40, OutlineColor = C.SkyDark, Outline = 3.5, ZIndex = 6 })
	t.Name = "BannerText"
	return t
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
			if k ~= "MaxText" and k ~= "Outline" and k ~= "OutlineColor" then
				(t :: any)[k] = v
			end
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
	s.LineJoinMode = Enum.LineJoinMode.Round
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

local function luminance(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

-- Chunky rounded button. The visible text is a child label that mirrors b.Text, so
-- coloured buttons get bold white text with an outline while the button keeps its rim.
function UI.Button(parent: Instance, text: string, size: UDim2, pos: UDim2, onClick: () -> (), color: Color3?): TextButton
	local base = color or C.Yellow
	if base == C.White then
		base = C.Cream -- light buttons are warm cream, like the cards
	end
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.BackgroundColor3 = base
	b.AutoButtonColor = false
	b.Font = UI.Font
	b.Text = text
	b.TextColor3 = C.Ink
	b.TextTransparency = 1
	b.TextScaled = true
	b.Selectable = true
	b.SelectionImageObject = focusRing()
	b.Parent = parent
	UI.Corner(b, 18)
	local stroke = UI.Stroke(b, 3, base:Lerp(C.Ink, 0.45))
	UI.Shade(b)
	local light = luminance(base) > 0.72
	local label = UI.Text(b, text, UDim2.new(1, -20, 1, -12), UDim2.fromOffset(10, 6), { MaxText = 30, TextColor3 = light and C.Ink or C.White })
	label.Name = "Label"
	if not light then
		local ts = Instance.new("UIStroke")
		ts.Thickness = 2.5
		ts.Color = base:Lerp(C.Ink, 0.6)
		ts.LineJoinMode = Enum.LineJoinMode.Round
		ts.Parent = label
	end
	b:GetPropertyChangedSignal("Text"):Connect(function()
		label.Text = b.Text
	end)
	local hovered = false
	local function restyle()
		stroke.Color = hovered and C.White or b.BackgroundColor3:Lerp(C.Ink, 0.45)
		stroke.Thickness = hovered and 5 or 3
	end
	b:GetPropertyChangedSignal("BackgroundColor3"):Connect(restyle)
	local function hover(on: boolean)
		hovered = on
		restyle()
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
	local label = b:FindFirstChild("Label") :: TextLabel?
	if label then
		label.TextTransparency = disabled and 0.5 or 0
	else
		b.TextTransparency = disabled and 0.5 or 0
	end
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
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end
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
