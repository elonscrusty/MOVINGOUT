--[[
	Hud.luau
	In-play interface, kept to the screen edges so the playfield stays clear:
	  top centre   job timer (freezes while paused)
	  top left     job name, delivered / required, pause button
	  top right    mover chips (number + symbol + colour + name)
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
local jobLabel: TextLabel
local countLabel: TextLabel
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

local function buildTop()
	timerPill = Instance.new("Frame")
	timerPill.Size = UDim2.fromOffset(190, 62)
	timerPill.Position = U(0.5, 0, 0, 10)
	timerPill.AnchorPoint = Vector2.new(0.5, 0)
	timerPill.BackgroundColor3 = C.Panel
	timerPill.Parent = root
	UI.Corner(timerPill, 30)
	UI.Stroke(timerPill, 4)
	UI.Scaled(timerPill)
	timerLabel = UI.Text(timerPill, "0:00.00", U(1, -20, 1, -10), U(0, 10, 0, 5), { MaxText = 40 })

	topLeft = Instance.new("Frame")
	topLeft.BackgroundTransparency = 1
	topLeft.Size = UDim2.fromOffset(300, 110)
	topLeft.Position = U(0, 10, 0, 10)
	topLeft.Parent = root
	UI.Scaled(topLeft)
	pauseButton = UI.Button(topLeft, "II", UDim2.fromOffset(56, 56), UDim2.fromOffset(30, 30), function()
		if State.Phase() == "Playing" then
			Net.Action:FireServer("Pause")
		elseif State.Phase() == "Lobby" then
			Menus.Open("Settings")
		end
	end, C.White)
	local info = Instance.new("Frame")
	info.Size = UDim2.fromOffset(230, 92)
	info.Position = UDim2.fromOffset(66, 0)
	info.BackgroundColor3 = C.Panel
	info.Parent = topLeft
	UI.Corner(info, 16)
	UI.Stroke(info, 3)
	jobLabel = UI.Text(info, "", U(1, -16, 0.4, 0), U(0, 8, 0, 4), { TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22 })
	countLabel = UI.Text(info, "", U(1, -16, 0.5, 0), U(0, 8, 0.44, 0), { TextXAlignment = Enum.TextXAlignment.Left, MaxText = 32, TextColor3 = C.Orange })

	chips = Instance.new("Frame")
	chips.BackgroundTransparency = 1
	chips.Size = UDim2.fromOffset(200, 200)
	chips.Position = U(1, -10, 0, 10)
	chips.AnchorPoint = Vector2.new(1, 0)
	chips.Parent = root
	UI.Scaled(chips)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.Name
	layout.Parent = chips
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
			UI.Stroke(f, 3)
			local leader = State.Game():GetAttribute("Leader") == p.UserId
			UI.Text(f, string.format("%s %s  %s%s", info.Name, info.Symbol, p.DisplayName, leader and "  ★" or ""), U(1, -16, 1, -6), U(0, 8, 0, 3), { TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20, TextStrokeTransparency = 0.4 })
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
	lobbyBar.Position = U(0.5, 0, 1, -76)
	lobbyBar.AnchorPoint = Vector2.new(0.5, 1)
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
	touchFrame.Size = UDim2.fromOffset(300, 260)
	touchFrame.Position = U(1, -100, 1, -110)
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
	local grab = tb("GRAB", "Grab", 104, 230, 150, C.Yellow)
	grab.Name = "GrabButton"
	tb("THROW", "Throw", 80, 120, 200, C.Orange)
	tb("SLAP", "Slap", 70, 150, 90, C.White)
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
	timerLabel.Text = UI.FormatTime(math.max(0, t))

	-- job info
	topLeft.Visible = joined and menu == nil
	local jobId = game_:GetAttribute("JobId")
	local job = Jobs.ById[jobId or ""]
	jobLabel.Text = job and job.Name or "The Depot (practice)"
	local d = (game_:GetAttribute("Delivered") :: number?) or 0
	local r = (game_:GetAttribute("Required") :: number?) or 0
	countLabel.Text = job and string.format("In truck: %d / %d", d, r) or "Try the truck!"
	pauseButton.Text = phase == "Playing" and "II" or "⚙"

	chips.Visible = joined and menu == nil

	-- hint
	local hint = visibleHud and menu == nil and currentHint() or ""
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

	local status = State.SaveStatus
	saveNote.Text = (joined and phase == "Lobby" and menu == nil and status ~= "ok") and "Progress isn't being saved this session (data storage unavailable)." or ""
end

function Hud.Init()
	root = UI.Root("Hud", 10)
	buildTop()
	buildBottom()
	buildLobbyBar()
	buildTouch()

	tutorialCard = UI.Panel(root, UDim2.fromOffset(300, 92), U(0, 10, 0, 130), Vector2.new(0, 0))
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
			local sc = countLabel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			sc.Parent = countLabel
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
