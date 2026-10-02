--[[
	Input.luau
	Turns keyboard, gamepad and touch input into mover actions (Grab / Throw / Slap /
	Pause) and drives menu navigation. Movement and jumping are Roblox's own controls;
	our fixed overhead camera makes them camera-relative (up = up the screen).

	* Each player plays on their own device (Roblox co-op is online, one mover per
	  player), so "multiple local players" maps to multiple Roblox players in a server.
	* Grab is a toggle by default (press to grab, press to drop); the Grab Toggle setting
	  off makes it hold-to-carry.
	* The three actions can be remapped (Settings); a fixed alternate set always works.
	* When the window loses focus or a controller disconnects, held input is cleared, the
	  held item is let go and a solo job pauses.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Input = {}

Input.Device = "Keyboard" -- Keyboard | Gamepad | Touch
Input.DeviceChanged = State.Signal()
Input.ActionFired = State.Signal() -- (action) for the tutorial / HUD
Input.PauseRequested = State.Signal()
Input.BackRequested = State.Signal()

local targetProvider: (() -> Model?)? = nil
local controls: any = nil
local grabHeld = false
local capturing: ((Enum.KeyCode) -> ())? = nil

function Input.SetTargetProvider(fn: () -> Model?)
	targetProvider = fn
end

local function keyFor(action: string): string
	local custom = State.Profile.Bindings and State.Profile.Bindings[action]
	return custom or Config.Bindings.Keyboard[action]
end

-- Human-readable label for an action on the current device.
function Input.Label(action: string): string
	if Input.Device == "Gamepad" then
		local b = Config.Bindings.Gamepad[action] or ""
		local names = { ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y", ButtonR1 = "RB", ButtonL1 = "LB", ButtonR2 = "RT", ButtonL2 = "LT", ButtonStart = "Menu" }
		return names[b] or b
	elseif Input.Device == "Touch" then
		return string.upper(action)
	end
	local k = keyFor(action)
	local pretty = { Space = "Space", Escape = "Esc", LeftShift = "L-Shift", Return = "Enter" }
	return pretty[k] or k
end

local function inGameplay(): boolean
	local phase = State.Phase()
	return State.Joined and State.MySlot() > 0 and (phase == "Lobby" or phase == "Playing") and not State.Game():GetAttribute("Paused") and not State.MenuOpen
end

local function fire(action: string)
	if action == "Grab" then
		local char = State.Character()
		local holding = State.Player:GetAttribute("Holding")
		if holding then
			Net.Action:FireServer("Release")
			Input.ActionFired:Fire("Release")
		else
			local target = targetProvider and targetProvider()
			if target then
				Net.Action:FireServer("Grab", target.Name)
				Input.ActionFired:Fire("Grab")
			elseif char then
				Input.ActionFired:Fire("GrabMiss")
			end
		end
	elseif action == "Throw" then
		if State.Player:GetAttribute("Holding") then
			Net.Action:FireServer("Throw")
			Input.ActionFired:Fire("Throw")
		end
	elseif action == "Slap" then
		Net.Action:FireServer("Slap")
		Input.ActionFired:Fire("Slap")
	end
end

-- Public so touch buttons can press actions.
function Input.Press(action: string)
	if action == "Pause" then
		Input.PauseRequested:Fire()
		return
	end
	if not inGameplay() then
		return
	end
	if action == "Grab" and not State.Settings().GrabToggle then
		grabHeld = true
		if not State.Player:GetAttribute("Holding") then
			fire("Grab")
		end
		return
	end
	fire(action)
end

function Input.ReleasePress(action: string)
	if action == "Grab" and not State.Settings().GrabToggle and grabHeld then
		grabHeld = false
		if State.Player:GetAttribute("Holding") then
			Net.Action:FireServer("Release")
			Input.ActionFired:Fire("Release")
		end
	end
end

local function actionForKey(key: Enum.KeyCode): string?
	for _, action in Config.Bindings.Remappable do
		if keyFor(action) == key.Name or Config.Bindings.KeyboardAlt[action] == key.Name then
			return action
		end
	end
	if key == Enum.KeyCode.P or key == Enum.KeyCode.Escape then
		return "Pause"
	end
	return nil
end

local function actionForButton(key: Enum.KeyCode): string?
	for action, name in Config.Bindings.Gamepad do
		if name == key.Name and action ~= "Jump" then
			return action
		end
	end
	for action, name in Config.Bindings.GamepadAlt do
		if name == key.Name then
			return action
		end
	end
	return nil
end

-- Remapping: the next key press is handed to fn instead of the game.
function Input.Capture(fn: (Enum.KeyCode) -> ())
	capturing = fn
end

function Input.SetBinding(action: string, key: Enum.KeyCode)
	State.Profile.Bindings = State.Profile.Bindings or {}
	State.Profile.Bindings[action] = key.Name
	Net.Action:FireServer("SaveBindings", State.Profile.Bindings)
end

function Input.ResetBindings()
	State.Profile.Bindings = {}
	Net.Action:FireServer("SaveBindings", {})
end

function Input.KeyName(action: string): string
	return keyFor(action)
end

-- Character controls are off while a modal menu is open or the mover is frozen.
function Input.SetControlsEnabled(on: boolean)
	if not controls then
		return
	end
	if on then
		controls:Enable()
	else
		controls:Disable()
	end
end

local function setDevice(d: string)
	if Input.Device ~= d then
		Input.Device = d
		Input.DeviceChanged:Fire(d)
	end
end

local function clearHeldInput(reason: string)
	grabHeld = false
	if State.Player:GetAttribute("Holding") then
		Net.Action:FireServer("Release")
	end
	local solo = (State.Game():GetAttribute("MoverCount") or 0) <= 1
	if State.Phase() == "Playing" and not State.Game():GetAttribute("Paused") and (solo or reason == "gamepad") then
		Net.Action:FireServer("Pause")
	end
end

function Input.Init()
	task.spawn(function()
		local ok, module = pcall(function()
			return require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		end)
		if ok and module then
			controls = module:GetControls()
		end
	end)

	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		setDevice("Touch")
	end

	UserInputService.LastInputTypeChanged:Connect(function(t)
		if t == Enum.UserInputType.Touch then
			setDevice("Touch")
		elseif t.Name:find("Gamepad") then
			setDevice("Gamepad")
		elseif t == Enum.UserInputType.Keyboard or t.Name:find("Mouse") then
			setDevice("Keyboard")
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if capturing and input.UserInputType == Enum.UserInputType.Keyboard then
			local fn = capturing
			capturing = nil
			fn(input.KeyCode) -- Escape means "cancel"
			return
		end
		local key = input.KeyCode
		-- menu navigation (keyboard); gamepad navigation is Roblox's own selection
		if UI.NavActive() and State.MenuOpen and input.UserInputType == Enum.UserInputType.Keyboard then
			if key == Enum.KeyCode.Up or key == Enum.KeyCode.W or key == Enum.KeyCode.Left or key == Enum.KeyCode.A then
				UI.NavMove(-1)
				return
			elseif key == Enum.KeyCode.Down or key == Enum.KeyCode.S or key == Enum.KeyCode.Right or key == Enum.KeyCode.D or key == Enum.KeyCode.Tab then
				UI.NavMove(1)
				return
			elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter or key == Enum.KeyCode.Space then
				UI.NavActivate()
				return
			elseif key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace then
				Input.BackRequested:Fire()
				return
			end
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local action = actionForKey(key)
			if action == "Pause" then
				if State.MenuOpen then
					Input.BackRequested:Fire()
				else
					Input.PauseRequested:Fire()
				end
			elseif action and not processed then
				Input.Press(action)
			end
		elseif input.UserInputType.Name:find("Gamepad") then
			if key == Enum.KeyCode.ButtonB and State.MenuOpen then
				Input.BackRequested:Fire()
				return
			end
			local action = actionForButton(key)
			if action == "Pause" then
				if State.MenuOpen then
					Input.BackRequested:Fire()
				else
					Input.PauseRequested:Fire()
				end
			elseif action and not State.MenuOpen then
				Input.Press(action)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local action = actionForKey(input.KeyCode)
			if action then
				Input.ReleasePress(action)
			end
		elseif input.UserInputType.Name:find("Gamepad") then
			local action = actionForButton(input.KeyCode)
			if action then
				Input.ReleasePress(action)
			end
		end
	end)

	-- don't let the game's own keys scroll or trigger default actions
	ContextActionService:BindActionAtPriority("MO_SinkTab", function()
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Tab)

	UserInputService.WindowFocusReleased:Connect(function()
		clearHeldInput("focus")
	end)
	GuiService.MenuOpened:Connect(function()
		clearHeldInput("focus")
	end)
	UserInputService.GamepadDisconnected:Connect(function()
		if Input.Device == "Gamepad" then
			clearHeldInput("gamepad")
			Input.ActionFired:Fire("GamepadLost")
		end
	end)
end

return Input
