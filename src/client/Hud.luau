--[[
	Hud.luau
	In-play interface, kept to the screen edges so the playfield stays clear:
	  top left     cardboard-box icon + delivered / required pill, job name, pause button
	  top right    stopwatch medal with the current award target (gold, then silver,
	               then bronze as time passes) + the elapsed time pill with a bar that
	               runs down toward that target (freezes while paused); mover chips below
	  bottom       contextual hint ("[E] Grab Sofa", "[Q] Throw", ...)
	  centre       countdown, toasts (feedback such as "Spot taken")
	  lobby bar    JOB BOARD / LOOK / SETTINGS buttons in the depot yard
	  touch        GRAB / THROW / SLAP buttons on phones and tablets
	  tutorial     a small step card in the yard and the first job
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Jobs = require(ReplicatedStorage.Shared.Jobs)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local Input = require(script.Parent.Input)
local Effects = require(script.Parent.Effects)
local Targeting = require(script.Parent.Targeting)
local Menus = require(script.Parent.Menus)

local Hud = {}

local C = UI.Colors
local root: ScreenGui
local timerLabel: TextLabel
local timerPill: Frame
local medal: Frame
local medalInner: Frame
local medalLabel: TextLabel
local barFill: Frame
local jobLabel: TextLabel
local countLabel: TextLabel
local countFrame: Frame
local requiredLabel: TextLabel
local hintLabel: TextLabel
local hintFrame: Frame
local chips: Frame
local toastLabel: TextLabel
local countdownLabel: TextLabel
local lobbyBar: Frame
local touchFrame: Frame
local tutorialCard: Frame
local tutorialText: TextLabel
local topLeft: Frame
local pauseButton: TextButton
local saveNote: TextLabel

local function U(xs: number, xo: number, ys: number, yo: number): UDim2
	return UDim2.new(xs, xo, ys, yo)
end

----------------------------------------------------------------------------------------
-- Toasts

local toastToken = 0
function Hud.Toast(text: string)
	toastToken += 1
	local my = toastToken
	toastLabel.Text = text
	toastLabel.Visible = true
	toastLabel.TextTransparency = 0
	task.delay(2.2, function()
		if my == toastToken then
			toastLabel.Visible = false
		end
	end)
end

----------------------------------------------------------------------------------------
-- Tutorial: short step lists that advance on real actions.

local steps: { { Text: string, Done: string } } = {}
local stepIndex = 0
local tutorialActive = false

local LOBBY_STEPS = {
	{ Text = "Walk with %MOVE%.", Done = "Move" },
	{ Text = "Walk up to a box and press %GRAB% to grab it.", Done = "Grab" },
	{ Text = "Press %THROW% to throw it. Light things fly far!", Done = "Throw" },
	{ Text = "Grab it again and drop it with %GRAB%.", Done = "Release" },
	{ Text = "Put a box in the truck: it counts when it rests fully inside.", Done = "Deliver" },
	{ Text = "Ready! %BOARD% to pick a job.", Done = "Never" },
}
local JOB_STEPS = {
	{ Text = "Everything with a highlight can be moved. Grab with %GRAB%.", Done = "Grab" },
	{ Text = "Big things (sofa, bed) are heavy and long: grab an end and walk around to turn them through doors.", Done = "HeavyMoved" },
	{ Text = "Glass with a white cross breaks: throw or slam furniture through it for a shortcut (%SLAP% to slap it).", Done = "Break" },
	{ Text = "Pack the truck: big things first, at the back. Boxes stack on top.", Done = "Deliver" },
}

local function stepText(t: string): string
	local move = Input.Device == "Gamepad" and "the left stick" or Input.Device == "Touch" and "the thumbstick" or "WASD / arrows"
	local board = Input.Device == "Touch" and "Tap JOB BOARD" or "Press P"
	t = t:gsub("%%MOVE%%", move)
	t = t:gsub("%%GRAB%%", "[" .. Input.Label("Grab") .. "]")
	t = t:gsub("%%THROW%%", "[" .. Input.Label("Throw") .. "]")
	t = t:gsub("%%SLAP%%", "[" .. Input.Label("Slap") .. "]")
	t = t:gsub("%%BOARD%%", board)
	return t
end

local function showStep()
	local s = steps[stepIndex]
	if not s or not State.Settings().ShowTutorialHints then
		tutorialCard.Visible = false
		return
	end
	tutorialCard.Visible = true
	tutorialText.Text = string.format("<b>%d/%d</b>  %s", stepIndex, #steps, stepText(s.Text))
	UI.PopIn(tutorialCard)
end

local function startTutorial(list: { any })
	steps = list
	stepIndex = 1
	tutorialActive = true
	showStep()
end

local function stopTutorial()
	tutorialActive = false
	tutorialCard.Visible = false
end

local function advance(event: string)
	if not tutorialActive then
		return
	end
	local s = steps[stepIndex]
	if s and s.Done == event then
		stepIndex += 1
		if stepIndex > #steps then
			stopTutorial()
			Net.Action:FireServer("TutorialDone")
		else
			showStep()
		end
	end
end

----------------------------------------------------------------------------------------

-- Bold white numbers with a dark outline (the HUD's main type).
local function hudText(parent: Instance, text: string, size: UDim2, pos: UDim2, maxText: number, align: Enum.TextXAlignment?, outline: Color3?): TextLabel
	local t = UI.Outlined(parent, text, size, pos, { MaxText = maxText, TextXAlignment = align or Enum.TextXAlignment.Center, OutlineColor = outline or C.Ink, Outline = 3.5 })
	return t
end

-- A little cardboard box drawn with frames (taped lid, shipping label).
local function boxIcon(parent: Instance, size: number, pos: UDim2): Frame
	local box = Instance.new("Frame")
	box.Name = "BoxIcon"
	box.Size = UDim2.fromOffset(size, size)
	box.Position = pos
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Rotation = -6
	box.BackgroundColor3 = Color3.fromRGB(214, 150, 86)
	box.ZIndex = 3
	box.Parent = parent
	UI.Corner(box, 10)
	UI.Stroke(box, 4, C.White)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 240, 220), Color3.fromRGB(205, 175, 150))
	g.Rotation = 90
	g.Parent = box
	local lid = Instance.new("Frame")
	lid.Size = UDim2.new(1, 0, 0.3, 0)
	lid.BackgroundColor3 = Color3.fromRGB(236, 178, 112)
	lid.BorderSizePixel = 0
	lid.ZIndex = 3
	lid.Parent = box
	UI.Corner(lid, 10)
	local tape = Instance.new("Frame")
	tape.Size = UDim2.new(0.22, 0, 0.42, 0)
	tape.Position = UDim2.fromScale(0.39, 0)
	tape.BackgroundColor3 = Color3.fromRGB(250, 226, 180)
	tape.BorderSizePixel = 0
	tape.ZIndex = 4
	tape.Parent = box
	local label = Instance.new("Frame")
	label.Size = UDim2.fromScale(0.34, 0.2)
	label.Position = UDim2.fromScale(0.14, 0.62)
	label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	label.ZIndex = 4
	label.Parent = box
	UI.Corner(label, 3)
	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.fromScale(0.6, 0.5)
	stripe.Position = UDim2.fromScale(0.2, 0.25)
	stripe.BackgroundColor3 = Color3.fromRGB(70, 170, 230)
	stripe.BorderSizePixel = 0
	stripe.ZIndex = 4
	stripe.Parent = label
	return box
end

local function buildTop()
	-- top right: stopwatch medal + elapsed time pill
	timerPill = Instance.new("Frame")
	timerPill.Name = "Stopwatch"
	timerPill.BackgroundTransparency = 1
	timerPill.Size = UDim2.fromOffset(290, 100)
	timerPill.Position = U(1, -12, 0, 10)
	timerPill.AnchorPoint = Vector2.new(1, 0)
	timerPill.Parent = root
	UI.Scaled(timerPill)
	local pill = Instance.new("Frame")
	pill.Name = "Elapsed"
	pill.Size = UDim2.fromOffset(212, 62)
	pill.Position = UDim2.fromOffset(74, 10)
	pill.BackgroundColor3 = C.Sky
	pill.ZIndex = 1
	pill.Parent = timerPill
	UI.Corner(pill, 16)
	UI.Stroke(pill, 4, C.White)
	UI.Shade(pill, 0.18)
	timerLabel = hudText(pill, "0:00", U(1, -56, 1, -8), U(0, 44, 0, 4), 46, Enum.TextXAlignment.Center, C.SkyDark)
	timerLabel.ZIndex = 2
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromOffset(180, 14)
	bar.Position = UDim2.fromOffset(100, 78)
	bar.BackgroundColor3 = Color3.fromRGB(120, 66, 40)
	bar.Parent = timerPill
	UI.Corner(bar, 7)
	UI.Stroke(bar, 3, C.White)
	barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = C.Gold
	barFill.BorderSizePixel = 0
	barFill.Parent = bar
	UI.Corner(barFill, 7)
	for i = 1, 3 do
		local tick = Instance.new("Frame")
		tick.Size = UDim2.new(0, 3, 1, 0)
		tick.Position = UDim2.fromScale(i / 4, 0)
		tick.BackgroundColor3 = Color3.fromRGB(90, 48, 30)
		tick.BackgroundTransparency = 0.3
		tick.BorderSizePixel = 0
		tick.ZIndex = 2
		tick.Parent = bar
	end
	-- the stopwatch: a knob, a gold rim and an inner face with the target time
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(22, 16)
	knob.Position = UDim2.fromOffset(44, 2)
	knob.AnchorPoint = Vector2.new(0.5, 0)
	knob.BackgroundColor3 = C.Gold
	knob.ZIndex = 2
	knob.Parent = timerPill
	UI.Corner(knob, 5)
	UI.Stroke(knob, 3, C.White)
	medal = Instance.new("Frame")
	medal.Name = "Medal"
	medal.Size = UDim2.fromOffset(84, 84)
	medal.Position = UDim2.fromOffset(44, 54)
	medal.AnchorPoint = Vector2.new(0.5, 0.5)
	medal.BackgroundColor3 = C.Gold
	medal.ZIndex = 3
	medal.Parent = timerPill
	UI.Corner(medal, 999)
	UI.Stroke(medal, 4, C.White)
	UI.Shade(medal, 0.12)
	medalInner = Instance.new("Frame")
	medalInner.Size = UDim2.fromScale(0.76, 0.76)
	medalInner.Position = UDim2.fromScale(0.5, 0.5)
	medalInner.AnchorPoint = Vector2.new(0.5, 0.5)
	medalInner.BackgroundColor3 = Color3.fromRGB(226, 144, 24)
	medalInner.ZIndex = 4
	medalInner.Parent = medal
	UI.Corner(medalInner, 999)
	local star = UI.Text(medalInner, "★", UDim2.fromScale(1.05, 1.05), UDim2.fromScale(-0.025, -0.06), { MaxText = 80, TextColor3 = Color3.fromRGB(255, 255, 255), TextTransparency = 0.72, ZIndex = 5 })
	star.Name = "Star"
	medalLabel = hudText(medalInner, "", U(1, 4, 0.6, 0), U(0, -2, 0.2, 0), 26, Enum.TextXAlignment.Center, Color3.fromRGB(110, 60, 10))
	medalLabel.ZIndex = 6

	-- top left: box counter pill, job name, pause button
	topLeft = Instance.new("Frame")
	topLeft.BackgroundTransparency = 1
	topLeft.Size = UDim2.fromOffset(330, 112)
	topLeft.Position = U(0, 10, 0, 62) -- below Roblox's top bar buttons
	topLeft.Parent = root
	UI.Scaled(topLeft)
	countFrame = Instance.new("Frame")
	countFrame.Name = "Counter"
	countFrame.Size = UDim2.fromOffset(176, 60)
	countFrame.Position = UDim2.fromOffset(52, 10)
	countFrame.BackgroundColor3 = Color3.fromRGB(255, 140, 96)
	countFrame.Parent = topLeft
	UI.Corner(countFrame, 16)
	UI.Stroke(countFrame, 4, C.White)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 200, 190))
	g.Rotation = 0
	g.Parent = countFrame
	countLabel = hudText(countFrame, "", U(0.5, -14, 1, -6), U(0, 40, 0, 3), 46, Enum.TextXAlignment.Right, Color3.fromRGB(120, 50, 30))
	requiredLabel = hudText(countFrame, "", U(0.5, -14, 0.62, 0), U(0.5, 26, 0.34, 0), 28, Enum.TextXAlignment.Left, Color3.fromRGB(120, 50, 30))
	boxIcon(topLeft, 72, UDim2.fromOffset(42, 40))
	jobLabel = hudText(topLeft, "", UDim2.fromOffset(250, 26), UDim2.fromOffset(10, 78), 20, Enum.TextXAlignment.Left)
	pauseButton = UI.Button(topLeft, "II", UDim2.fromOffset(54, 54), UDim2.fromOffset(268, 40), function()
		if State.Phase() == "Playing" then
			Net.Action:FireServer("Pause")
		elseif State.Phase() == "Lobby" then
			Menus.Open("Settings")
		end
	end, C.White)

	chips = Instance.new("Frame")
	chips.BackgroundTransparency = 1
	chips.Size = UDim2.fromOffset(200, 200)
	chips.Position = U(1, -10, 0, 118)
	chips.AnchorPoint = Vector2.new(1, 0)
	chips.Parent = root
	UI.Scaled(chips)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.Name
	layout.Parent = chips
end

local MEDALS = {
	{ Name = "Gold", Rim = Color3.fromRGB(255, 200, 50), Face = Color3.fromRGB(226, 144, 24), Ink = Color3.fromRGB(110, 60, 10) },
	{ Name = "Silver", Rim = Color3.fromRGB(214, 224, 236), Face = Color3.fromRGB(150, 166, 188), Ink = Color3.fromRGB(60, 70, 90) },
	{ Name = "Bronze", Rim = Color3.fromRGB(232, 156, 96), Face = Color3.fromRGB(176, 98, 52), Ink = Color3.fromRGB(80, 40, 20) },
}

local function clockText(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Medal shows the next award still reachable; the bar runs down toward it.
local function updateStopwatch(t: number, job: any)
	if not job or not job.Awards then
		medal.Visible = false
		local bar = barFill.Parent :: Frame
		bar.Visible = false
		return
	end
	medal.Visible = true
	local bar = barFill.Parent :: Frame
	bar.Visible = true
	local scale = (State.Game():GetAttribute("AssistTimeScale") :: number?) or 1
	local prev = 0
	for _, m in MEDALS do
		local target = (job.Awards[m.Name] or 0) * scale
		if t <= target then
			medal.BackgroundColor3 = m.Rim
			medalInner.BackgroundColor3 = m.Face
			barFill.BackgroundColor3 = m.Rim
			local stroke = medalLabel:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = m.Ink
			end
			medalLabel.Text = clockText(target)
			barFill.Size = UDim2.fromScale(math.clamp(1 - (t - prev) / math.max(target - prev, 1), 0, 1), 1)
			return
		end
		prev = target
	end
	medal.BackgroundColor3 = C.Grey
	medalInner.BackgroundColor3 = Color3.fromRGB(150, 146, 156)
	medalLabel.Text = "--"
	barFill.Size = UDim2.fromScale(0, 1)
end

local function refreshChips()
	for _, c in chips:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for _, p in Players:GetPlayers() do
		local slot = (p:GetAttribute("Slot") :: number?) or 0
		if slot > 0 then
			local info = Config.Slots[slot]
			local f = Instance.new("Frame")
			f.Name = "Chip" .. slot
			f.Size = UDim2.fromOffset(190, 36)
			f.BackgroundColor3 = info.Color
			f.Parent = chips
			UI.Corner(f, 18)
			UI.Stroke(f, 3, C.White)
			UI.Shade(f, 0.15)
			local leader = State.Game():GetAttribute("Leader") == p.UserId
			UI.Outlined(f, string.format("%s %s  %s%s", info.Name, info.Symbol, p.DisplayName, leader and "  ★" or ""), U(1, -16, 1, -6), U(0, 8, 0, 3), { TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, Outline = 2, OutlineColor = info.Color:Lerp(C.Ink, 0.6) })
		end
	end
end

local function buildBottom()
	hintFrame = Instance.new("Frame")
	hintFrame.Size = UDim2.fromOffset(460, 48)
	hintFrame.Position = U(0.5, 0, 1, -16)
	hintFrame.AnchorPoint = Vector2.new(0.5, 1)
	hintFrame.BackgroundColor3 = C.PanelDark
	hintFrame.BackgroundTransparency = 0.15
	hintFrame.Parent = root
	UI.Corner(hintFrame, 24)
	UI.Scaled(hintFrame)
	hintLabel = UI.Text(hintFrame, "", U(1, -24, 1, -10), U(0, 12, 0, 5), { TextColor3 = C.White, MaxText = 24 })

	toastLabel = UI.Title(root, "", U(0.7, 0, 0, 40), U(0.5, 0, 0, 84), C.White)
	toastLabel.AnchorPoint = Vector2.new(0.5, 0)
	toastLabel.Visible = false

	countdownLabel = UI.Title(root, "", U(0.4, 0, 0.25, 0), U(0.5, 0, 0.42, 0), C.Yellow)
	countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownLabel.Visible = false
	local lim = countdownLabel:FindFirstChildOfClass("UITextSizeConstraint")
	if lim then
		lim.MaxTextSize = 140
	end

	saveNote = UI.Text(root, "", U(0.5, 0, 0, 22), U(0.5, 0, 1, -70), { TextColor3 = C.White, MaxText = 16, TextStrokeTransparency = 0.3 })
	saveNote.AnchorPoint = Vector2.new(0.5, 1)
end

local function buildLobbyBar()
	lobbyBar = Instance.new("Frame")
	lobbyBar.BackgroundTransparency = 1
	lobbyBar.Size = UDim2.fromOffset(470, 64)
	lobbyBar.Position = U(0.5, 0, 0, 10)
	lobbyBar.AnchorPoint = Vector2.new(0.5, 0)
	lobbyBar.Parent = root
	UI.Scaled(lobbyBar)
	UI.Button(lobbyBar, "JOB BOARD", UDim2.fromOffset(170, 56), UDim2.fromOffset(85, 32), function()
		Menus.OpenBoard()
	end, C.Yellow)
	UI.Button(lobbyBar, "LOOK", UDim2.fromOffset(130, 56), UDim2.fromOffset(245, 32), function()
		Menus.OpenLook()
	end, C.White)
	UI.Button(lobbyBar, "SETTINGS", UDim2.fromOffset(150, 56), UDim2.fromOffset(395, 32), function()
		Menus.Open("Settings")
	end, C.White)
end

local function buildTouch()
	touchFrame = Instance.new("Frame")
	touchFrame.BackgroundTransparency = 1
	touchFrame.Size = UDim2.fromOffset(250, 170)
	touchFrame.Position = U(1, -96, 1, -8) -- left of Roblox's jump button
	touchFrame.AnchorPoint = Vector2.new(1, 1)
	touchFrame.Parent = root
	local function tb(text: string, action: string, size: number, x: number, y: number, color: Color3)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(size, size)
		b.Position = UDim2.fromOffset(x, y)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.BackgroundColor3 = color
		b.BackgroundTransparency = 0.1
		b.Font = UI.Font
		b.Text = text
		b.TextScaled = true
		b.TextColor3 = C.Ink
		b.AutoButtonColor = true
		b.Parent = touchFrame
		UI.Corner(b, 999)
		UI.Stroke(b, 3)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.15, 0)
		pad.PaddingRight = UDim.new(0.15, 0)
		pad.Parent = b
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				Input.Press(action)
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				Input.ReleasePress(action)
			end
		end)
		return b
	end
	local grab = tb("GRAB", "Grab", 96, 196, 112, C.Yellow)
	grab.Name = "GrabButton"
	tb("THROW", "Throw", 74, 96, 128, C.Orange)
	tb("SLAP", "Slap", 62, 130, 42, C.White)
end

----------------------------------------------------------------------------------------

local function currentHint(): string
	local phase = State.Phase()
	if State.MySlot() == 0 then
		return State.Joined and "All four mover slots are taken - you're watching." or ""
	end
	if phase ~= "Playing" and phase ~= "Lobby" then
		return ""
	end
	local holding = State.Player:GetAttribute("Holding")
	if holding then
		local class = State.Player:GetAttribute("HoldingClass")
		local level = Workspace:FindFirstChild("Level")
		local item = level and level:FindFirstChild("Items") and (level :: any).Items:FindFirstChild(holding)
		local name = item and item:GetAttribute("DisplayName") or "it"
		local holders = item and item:GetAttribute("Holders") or 1
		if class == "Heavy" and holders < 2 then
			local movers = (State.Game():GetAttribute("MoverCount") :: number?) or 1
			if movers > 1 then
				return string.format("[%s] Drop  ·  Heavy %s: a partner can grab the other end", Input.Label("Grab"), name)
			end
			return string.format("[%s] Drop  ·  Heavy %s: drag it, turn it to fit doors", Input.Label("Grab"), name)
		end
		if holders >= 2 then
			local primed = item and item:GetAttribute("Primed") or 0
			if primed > 0 then
				return string.format("THROW TOGETHER!  [%s]  (%d/%d ready)", Input.Label("Throw"), primed, holders)
			end
			return string.format("[%s] Drop  ·  [%s] Throw together", Input.Label("Grab"), Input.Label("Throw"))
		end
		return string.format("[%s] Drop  ·  [%s] Throw %s", Input.Label("Grab"), Input.Label("Throw"), name)
	end
	local target = Targeting.Current()
	if target then
		local name = target:GetAttribute("DisplayName") or target.Name
		local delivered = target:GetAttribute("Delivered") and "  (in truck)" or ""
		return string.format("[%s] Grab %s%s", Input.Label("Grab"), name, delivered)
	end
	if phase == "Lobby" then
		if State.IsLeader() then
			return "Practice in the yard, then open the JOB BOARD"
		end
		return "Practice in the yard - the host picks the job"
	end
	return ""
end

local function update()
	local game_ = State.Game()
	local phase = State.Phase()
	local joined = State.Joined
	local menu = Menus.Current()
	local inJob = phase == "Playing" or phase == "Countdown"
	local visibleHud = joined and (menu == nil or menu == "Pause")

	-- timer
	timerPill.Visible = visibleHud and (inJob or phase == "Results")
	local running = game_:GetAttribute("TimerRunning")
	local t = running and (Workspace:GetServerTimeNow() - ((game_:GetAttribute("TimerOrigin") :: number?) or 0)) or ((game_:GetAttribute("TimerValue") :: number?) or 0)
	t = math.max(0, t)
	timerLabel.Text = clockText(t)

	-- job info
	topLeft.Visible = joined and menu == nil
	local jobId = game_:GetAttribute("JobId")
	local job = Jobs.ById[jobId or ""]
	updateStopwatch(t, job)
	jobLabel.Text = job and job.Name or "The Depot (practice)"
	local d = (game_:GetAttribute("Delivered") :: number?) or 0
	local r = (game_:GetAttribute("Required") :: number?) or 0
	if job then
		countLabel.Size = U(0.5, -14, 1, -6)
		countLabel.Text = tostring(d)
		requiredLabel.Text = "/" .. tostring(r)
	else
		countLabel.Size = U(1, -48, 0.7, 0)
		countLabel.Text = "Practice!"
		requiredLabel.Text = ""
	end
	if job and r > 0 and d >= r then
		countFrame.BackgroundColor3 = Color3.fromRGB(110, 210, 110)
	else
		countFrame.BackgroundColor3 = Color3.fromRGB(255, 140, 96)
	end
	pauseButton.Text = phase == "Playing" and "II" or "⚙"

	chips.Visible = joined and menu == nil

	-- hint
	local hint = visibleHud and menu == nil and currentHint() or ""
	if Input.Device == "Touch" then
		-- keep the bottom right free for the touch buttons
		hintFrame.AnchorPoint = Vector2.new(0.5, 0)
		hintFrame.Position = U(0.5, 0, 0, phase == "Lobby" and 58 or 62)
	else
		hintFrame.AnchorPoint = Vector2.new(0.5, 1)
		hintFrame.Position = U(0.5, 0, 1, -16)
	end
	hintLabel.Text = hint
	hintFrame.Visible = hint ~= ""
	lobbyBar.Visible = joined and menu == nil and phase == "Lobby" and State.MySlot() > 0
	touchFrame.Visible = joined and menu == nil and Input.Device == "Touch" and State.MySlot() > 0 and (phase == "Lobby" or phase == "Playing")

	-- countdown
	if phase == "Countdown" then
		local left = ((game_:GetAttribute("CountdownEnd") :: number?) or 0) - Workspace:GetServerTimeNow()
		countdownLabel.Visible = true
		countdownLabel.Text = left > 0 and tostring(math.ceil(left)) or "GO!"
	elseif countdownLabel.Text ~= "GO!" then
		countdownLabel.Visible = false
	end

	if menu ~= nil then
		tutorialCard.Visible = false
	elseif tutorialActive and State.Settings().ShowTutorialHints then
		tutorialCard.Visible = true
	end

	local status = State.SaveStatus
	saveNote.Text = (joined and phase == "Lobby" and menu == nil and status ~= "ok") and "Progress isn't being saved this session (data storage unavailable)." or ""
end

function Hud.Init()
	root = UI.Root("Hud", 10)
	buildTop()
	buildBottom()
	buildLobbyBar()
	buildTouch()

	tutorialCard = UI.Panel(root, UDim2.fromOffset(300, 92), U(0, 10, 0, 182), Vector2.new(0, 0))
	UI.Scaled(tutorialCard)
	tutorialText = UI.Text(tutorialCard, "", U(1, -20, 1, -14), U(0, 10, 0, 7), { TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18 })
	tutorialCard.Visible = false

	Effects.Toast:Connect(Hud.Toast)
	Effects.Event:Connect(function(kind, data)
		if kind == "Countdown" and data.N == 0 then
			countdownLabel.Text = "GO!"
			countdownLabel.Visible = true
			task.delay(0.8, function()
				if countdownLabel.Text == "GO!" then
					countdownLabel.Visible = false
					countdownLabel.Text = ""
				end
			end)
		elseif kind == "Deliver" and data.Delivered then
			advance("Deliver")
			local sc = countFrame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			sc.Parent = countFrame
			sc.Scale = 1.3
			TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		elseif kind == "Break" then
			advance("Break")
		end
	end)
	Input.ActionFired:Connect(function(action)
		if action == "GrabMiss" then
			Hud.Toast("Nothing in reach - walk up to something first")
		elseif action == "GamepadLost" then
			Hud.Toast("Controller disconnected - reconnect it to keep playing")
		else
			advance(action)
		end
	end)

	-- tutorial triggers: the yard on first visits, the first job
	local heavyTimer = 0
	local moved = 0
	local lastPos: Vector3? = nil
	local function phaseTutorial()
		local phase = State.Phase()
		local jobId = State.Game():GetAttribute("JobId")
		if phase == "Lobby" and State.Joined and not State.Profile.TutorialSeen and not tutorialActive then
			startTutorial(LOBBY_STEPS)
		elseif phase == "Playing" and jobId == Jobs.List[1].Id then
			startTutorial(JOB_STEPS)
		elseif phase ~= "Lobby" and phase ~= "Playing" then
			stopTutorial()
		end
	end
	State.Game():GetAttributeChangedSignal("Phase"):Connect(phaseTutorial)
	Menus.Changed:Connect(function(name)
		if name == nil then
			phaseTutorial()
		end
	end)

	local game_ = State.Game()
	for _, attr in { "Leader", "MoverCount" } do
		game_:GetAttributeChangedSignal(attr):Connect(refreshChips)
	end
	Players.PlayerAdded:Connect(function(p)
		p:GetAttributeChangedSignal("Slot"):Connect(refreshChips)
		refreshChips()
	end)
	for _, p in Players:GetPlayers() do
		p:GetAttributeChangedSignal("Slot"):Connect(refreshChips)
	end
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshChips)
	end)
	refreshChips()

	RunService.RenderStepped:Connect(function(dt)
		update()
		-- tutorial progress that isn't a button press
		local rootPart = State.Root()
		if tutorialActive and rootPart then
			if lastPos then
				moved += (rootPart.Position - lastPos).Magnitude
				if moved > 12 then
					advance("Move")
				end
			end
			lastPos = rootPart.Position
			if State.Player:GetAttribute("HoldingClass") == "Heavy" and rootPart.AssemblyLinearVelocity.Magnitude > 2 then
				heavyTimer += dt
				if heavyTimer > 2.5 then
					advance("HeavyMoved")
				end
			end
		end
	end)
end

return Hud
