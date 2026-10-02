--[[
	Menus.luau
	Every full menu: Title, Look (mover style), Job Board (with assists), Briefing,
	Pause (with confirmations), Results, Settings (volumes, grab mode, motion, text size,
	quality, key remapping) and Controls. Screens follow the shared game phase; every
	button does a real thing, and works with mouse, touch, keyboard and gamepad.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Jobs = require(ReplicatedStorage.Shared.Jobs)
local Movers = require(ReplicatedStorage.Shared.Movers)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local Input = require(script.Parent.Input)
local Audio = require(script.Parent.Audio)
local Effects = require(script.Parent.Effects)

local Menus = {}

local C = UI.Colors
local root: ScreenGui
local screens: { [string]: Frame } = {}
local navs: { [string]: { GuiObject } } = {}
local current: string? = nil
local stack: { string } = {}
local refreshers: { [string]: () -> () } = {}
local lastResults: any = nil
local selectedJob: string? = nil
local assists = table.clone(Config.Assists.Defaults)

Menus.Changed = State.Signal()

local function U(xs: number, xo: number, ys: number, yo: number): UDim2
	return UDim2.new(xs, xo, ys, yo)
end

local function screen(name: string, dim: boolean?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(30, 22, 40)
	f.BackgroundTransparency = dim == false and 1 or 0.45
	f.Visible = false
	f.Parent = root
	screens[name] = f
	return f
end

local function card(parent: Instance, w: number, h: number): Frame
	local p = UI.Panel(parent, UDim2.fromScale(w, h), UDim2.fromScale(0.5, 0.5))
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(980, 700)
	lim.Parent = p
	UI.Scaled(p)
	return p
end

function Menus.Current(): string?
	return current
end

-- Shows a screen (nil = none). push keeps the current one to come back to; pop is
-- used by Back so the rest of the stack survives.
function Menus.Show(name: string?, push: boolean?, pop: boolean?)
	if push and current and name then
		table.insert(stack, current)
	elseif not push and not pop then
		table.clear(stack)
	end
	for n, f in screens do
		f.Visible = n == name
	end
	current = name
	if name and refreshers[name] then
		refreshers[name]()
	end
	if name then
		local inner = screens[name]:FindFirstChildWhichIsA("Frame")
		if inner then
			UI.PopIn(inner)
		end
	end
	UI.SetNav(name and navs[name] or {})
	Input.SetControlsEnabled(name == nil)
	Audio.SetDucked(name == "Pause")
	Menus.Changed:Fire(name)
end

function Menus.Back()
	local prev = table.remove(stack)
	if prev then
		Menus.Show(prev, false, true)
	elseif current == "Pause" then
		Net.Action:FireServer("Resume")
	elseif current == "Title" or current == "Briefing" or current == "Results" then
		return -- these follow the game phase
	else
		Menus.Show(nil)
	end
end

----------------------------------------------------------------------------------------
-- Title

local function buildTitle()
	local s = screen("Title", false)
	local logo = UI.Title(s, Config.GameName, U(0.8, 0, 0.2, 0), U(0.5, 0, 0.22, 0), C.Yellow)
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.Rotation = -3
	local sub = UI.Title(s, "Physics furniture moving - solo or with up to 4 movers", U(0.7, 0, 0.06, 0), U(0.5, 0, 0.36, 0), C.White)
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = U(0.32, 0, 0.4, 0)
	holder.Position = U(0.5, 0, 0.66, 0)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Parent = s
	local lim = Instance.new("UISizeConstraint")
	lim.MinSize = Vector2.new(220, 180)
	lim.MaxSize = Vector2.new(420, 330)
	lim.Parent = holder
	UI.Scaled(holder)
	local play = UI.NavButton(holder, "PLAY", U(1, 0, 0.3, 0), U(0.5, 0, 0.15, 0), function()
		State.Joined = true
		Net.Action:FireServer("Play")
		Menus.Show(nil)
		Menus.FollowPhase()
	end, C.Yellow)
	local settings = UI.NavButton(holder, "SETTINGS", U(1, 0, 0.2, 0), U(0.5, 0, 0.45, 0), function()
		Menus.Show("Settings", true)
	end, C.White)
	local controls = UI.NavButton(holder, "CONTROLS", U(1, 0, 0.2, 0), U(0.5, 0, 0.7, 0), function()
		Menus.Show("Controls", true)
	end, C.White)
	local note = UI.Title(s, "", U(0.8, 0, 0.04, 0), U(0.5, 0, 0.95, 0), C.White)
	note.AnchorPoint = Vector2.new(0.5, 0.5)
	navs.Title = { play, settings, controls }
	refreshers.Title = function()
		local status = State.SaveStatus
		note.Text = (status == "ok") and ("v" .. Config.Version) or ("v" .. Config.Version .. "  ·  progress is not being saved this session")
	end
end

----------------------------------------------------------------------------------------
-- Look (mover style)

local function buildLook()
	local s = screen("Look")
	local p = card(s, 0.7, 0.6)
	UI.Text(p, "CHOOSE YOUR MOVER", U(1, -40, 0.14, 0), U(0, 20, 0, 12), { MaxText = 40 })
	UI.Text(p, "Your shirt is always your player colour; the look changes your hat and hair.", U(1, -40, 0.08, 0), U(0, 20, 0.15, 0), { TextColor3 = C.PanelDark, MaxText = 20 })
	local list = {}
	for i, style in Movers.Styles do
		local col = (i - 1) % 4
		local row = (i - 1) // 4
		local b = UI.NavButton(p, style.Name, U(0.22, 0, 0.16, 0), U(0.14 + col * 0.24, 0, 0.38 + row * 0.2, 0), function()
			Net.Action:FireServer("SetStyle", i)
			State.Profile.Style = i
			if refreshers.Look then
				refreshers.Look()
			end
		end, C.White)
		b:SetAttribute("Style", i)
		table.insert(list, b)
	end
	local done = UI.NavButton(p, "DONE", U(0.3, 0, 0.13, 0), U(0.5, 0, 0.86, 0), function()
		Menus.Back()
	end, C.Green)
	table.insert(list, done)
	navs.Look = list
	refreshers.Look = function()
		local mine = (State.Player:GetAttribute("Style") :: number?) or State.Profile.Style or 1
		for _, b in list do
			local st = b:GetAttribute("Style")
			if st then
				(b :: TextButton).BackgroundColor3 = st == mine and C.Yellow or C.White
			end
		end
	end
end

----------------------------------------------------------------------------------------
-- Job board

local function medalColor(m: string?): Color3
	return m == "Gold" and C.Gold or m == "Silver" and C.Silver or m == "Bronze" and C.Bronze or C.Grey
end

local function buildBoard()
	local s = screen("Board")
	local p = card(s, 0.94, 0.9)
	UI.Text(p, "JOB BOARD", U(0.5, 0, 0.08, 0), U(0, 20, 0, 10), { TextXAlignment = Enum.TextXAlignment.Left, MaxText = 40 })
	local hostNote = UI.Text(p, "", U(0.45, 0, 0.06, 0), U(0.53, 0, 0, 16), { TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.PanelDark, MaxText = 20 })
	local list: { GuiObject } = {}
	local cards: { [string]: TextButton } = {}
	for i, job in Jobs.List do
		local b = UI.NavButton(p, "", U(0.23, 0, 0.42, 0), U(0.135 + (i - 1) * 0.243, 0, 0.36, 0), function()
			selectedJob = job.Id
			if refreshers.Board then
				refreshers.Board()
			end
		end, C.White)
		b.TextTransparency = 1
		local title = UI.Text(b, job.Name, U(1, 0, 0.2, 0), U(0, 0, 0, 0), { MaxText = 24 })
		title.Name = "JobTitle"
		local desc = UI.Text(b, job.Tagline or "", U(1, 0, 0.3, 0), U(0, 0, 0.22, 0), { TextColor3 = C.PanelDark, MaxText = 15 })
		desc.Name = "Desc"
		local info = UI.Text(b, "", U(1, 0, 0.26, 0), U(0, 0, 0.53, 0), { MaxText = 16 })
		info.Name = "Info"
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.Size = U(0.5, 0, 0.16, 0)
		badge.Position = U(0.25, 0, 0.82, 0)
		badge.Parent = b
		UI.Corner(badge, 10)
		UI.Stroke(badge, 2)
		local bt = UI.Text(badge, "", UDim2.fromScale(1, 1), UDim2.new(), { MaxText = 16 })
		bt.Name = "BadgeText"
		cards[job.Id] = b
		table.insert(list, b)
	end

	-- assists
	local ax = Instance.new("Frame")
	ax.BackgroundTransparency = 1
	ax.Size = U(0.62, 0, 0.3, 0)
	ax.Position = U(0.02, 0, 0.6, 0)
	ax.Parent = p
	UI.Text(ax, "ASSISTS (host's choice, apply to everyone)", U(1, 0, 0.16, 0), U(0, 0, 0, 0), { TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18 })
	local assistInfo = UI.Text(ax, "", U(1, 0, 0.2, 0), U(0, 0, 0.82, 0), { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.PanelDark, MaxText = 14 })
	local function assistButton(label: string, x: number, y: number, explain: string, onClick: () -> ()): TextButton
		local b = UI.NavButton(ax, label, U(0.48, 0, 0.26, 0), U(x, 0, y, 0), function()
			onClick()
			assistInfo.Text = explain
			if refreshers.Board then
				refreshers.Board()
			end
		end, C.White)
		b.MouseEnter:Connect(function()
			assistInfo.Text = explain
		end)
		b.SelectionGained:Connect(function()
			assistInfo.Text = explain
		end)
		table.insert(list, b)
		return b
	end
	local timeB = assistButton("", 0.25, 0.33, "Award targets: multiplies the gold / silver / bronze times (easier awards).", function()
		local opts = Config.Assists.TimeTargetScale
		local i = table.find(opts, assists.TimeScale) or 1
		assists.TimeScale = opts[i % #opts + 1]
	end)
	local hazB = assistButton("", 0.75, 0.33, "Fewer hazards: longer gaps between cars and slower ghosts.", function()
		assists.ReducedHazards = not assists.ReducedHazards
	end)
	local heavyB = assistButton("", 0.25, 0.63, "Easier heavy items: more lift and speed when carrying big furniture.", function()
		assists.EasyHeavy = not assists.EasyHeavy
	end)
	local vanishB = assistButton("", 0.75, 0.63, "Delivered items vanish: furniture disappears once it counts, so the truck never fills up.", function()
		assists.VanishDelivered = not assists.VanishDelivered
	end)

	local start = UI.NavButton(p, "START JOB", U(0.3, 0, 0.12, 0), U(0.82, 0, 0.7, 0), function()
		if selectedJob and State.IsLeader() then
			Net.Action:FireServer("SelectJob", selectedJob, assists)
		end
	end, C.Green)
	local back = UI.NavButton(p, "BACK", U(0.3, 0, 0.1, 0), U(0.82, 0, 0.85, 0), function()
		Menus.Show(nil)
	end, C.White)
	table.insert(list, start)
	table.insert(list, back)
	navs.Board = list

	refreshers.Board = function()
		local profile = State.Profile
		local leader = State.IsLeader()
		hostNote.Text = leader and "You're the host: pick a job" or "Only the host (P1) can start a job"
		for i, job in Jobs.List do
			local b = cards[job.Id]
			local unlocked = i == 1 or (profile.Unlocked and profile.Unlocked[job.Id])
			local best = profile.Best and profile.Best[job.Id]
			local medal = profile.Medals and profile.Medals[job.Id]
			local info = b:FindFirstChild("Info") :: TextLabel
			local badge = b:FindFirstChild("Badge") :: Frame
			local bt = badge:FindFirstChild("BadgeText") :: TextLabel
			if unlocked then
				local a = job.Awards
				local sc = assists.TimeScale
				info.Text = string.format("%d items\nBest: %s\nGold %s · Silver %s · Bronze %s", Jobs.RequiredCount(job), best and UI.FormatTime(best) or "--", UI.FormatTime(a.Gold * sc), UI.FormatTime(a.Silver * sc), UI.FormatTime(a.Bronze * sc))
				badge.BackgroundColor3 = medalColor(medal)
				bt.Text = medal and medal ~= "None" and string.upper(medal) or "NO AWARD"
			else
				info.Text = "Finish the previous job to unlock"
				badge.BackgroundColor3 = C.Grey
				bt.Text = "LOCKED"
			end
			b.BackgroundColor3 = (selectedJob == job.Id) and C.Yellow or (unlocked and C.White or C.Grey)
			UI.SetDisabled(b, not unlocked)
		end
		timeB.Text = "Award times x" .. tostring(assists.TimeScale)
		hazB.Text = "Fewer hazards: " .. (assists.ReducedHazards and "ON" or "OFF")
		heavyB.Text = "Easier heavy: " .. (assists.EasyHeavy and "ON" or "OFF")
		vanishB.Text = "Items vanish: " .. (assists.VanishDelivered and "ON" or "OFF")
		UI.SetDisabled(start, not (leader and selectedJob ~= nil))
		for _, ab in { timeB, hazB, heavyB, vanishB } do
			UI.SetDisabled(ab, not leader)
		end
	end
	State.ProfileChanged:Connect(function()
		if current == "Board" then
			refreshers.Board()
		end
	end)
end

----------------------------------------------------------------------------------------
-- Briefing

local function buildBriefing()
	local s = screen("Briefing")
	local p = card(s, 0.8, 0.8)
	local title = UI.Text(p, "", U(1, -40, 0.12, 0), U(0, 20, 0, 12), { MaxText = 44 })
	local objective = UI.Text(p, "", U(1, -40, 0.1, 0), U(0, 20, 0.13, 0), { TextColor3 = C.Orange, MaxText = 26 })
	local body = UI.Text(p, "", U(0.55, -30, 0.5, 0), U(0, 20, 0.25, 0), { TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, MaxText = 18 })
	local controls = UI.Text(p, "", U(0.42, -20, 0.5, 0), U(0.57, 0, 0.25, 0), { TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.PanelDark, MaxText = 16 })
	local wait = UI.Text(p, "", U(0.6, 0, 0.06, 0), U(0.2, 0, 0.77, 0), { TextColor3 = C.PanelDark, MaxText = 18 })
	local start = UI.NavButton(p, "START!", U(0.3, 0, 0.12, 0), U(0.66, 0, 0.9, 0), function()
		Net.Action:FireServer("StartJob")
	end, C.Green)
	local back = UI.NavButton(p, "JOB BOARD", U(0.26, 0, 0.1, 0), U(0.3, 0, 0.9, 0), function()
		Net.Action:FireServer("Board")
	end, C.White)
	navs.Briefing = { start, back }
	refreshers.Briefing = function()
		local id = State.Game():GetAttribute("JobId")
		local job = Jobs.ById[id or ""]
		if not job then
			return
		end
		local movers = (State.Game():GetAttribute("MoverCount") :: number?) or 1
		title.Text = job.Name
		objective.Text = "Move every required item into the truck as fast as you can!"
		local lines = {}
		for _, l in job.Briefing or {} do
			table.insert(lines, "• " .. l)
		end
		table.insert(lines, string.format("• %d items must end up in the truck.", Jobs.RequiredCount(job)))
		if movers > 1 then
			table.insert(lines, "• Heavy things: one mover grabs each end. Walk together to carry, walk around each other to turn it, both press Throw to toss it.")
		else
			table.insert(lines, "• Solo: you can drag heavy things alone - slower, but always possible.")
		end
		body.Text = table.concat(lines, "\n")
		controls.Text = table.concat({
			"Move: " .. (Input.Device == "Gamepad" and "left stick" or Input.Device == "Touch" and "thumbstick" or "WASD / arrows"),
			"Grab / drop: " .. Input.Label("Grab"),
			"Throw: " .. Input.Label("Throw"),
			"Slap: " .. Input.Label("Slap"),
			"Jump: " .. (Input.Device == "Gamepad" and "A" or Input.Device == "Touch" and "jump button" or "Space"),
			"Pause: " .. (Input.Device == "Gamepad" and "Menu" or Input.Device == "Touch" and "II button" or "P"),
		}, "\n")
		local leader = State.IsLeader()
		start.Visible = leader
		back.Visible = leader
		wait.Text = leader and "" or "Waiting for the host to start..."
	end
end

----------------------------------------------------------------------------------------
-- Pause

local confirmAction: (() -> ())? = nil

local function buildPause()
	local s = screen("Pause")
	local p = card(s, 0.42, 0.78)
	local title = UI.Text(p, "PAUSED", U(1, -40, 0.12, 0), U(0, 20, 0, 12), { MaxText = 44 })
	local by = UI.Text(p, "", U(1, -40, 0.06, 0), U(0, 20, 0.13, 0), { TextColor3 = C.PanelDark, MaxText = 18 })
	local y = 0.27
	local function b(text: string, fn: () -> (), color: Color3?): TextButton
		local btn = UI.NavButton(p, text, U(0.8, 0, 0.1, 0), U(0.5, 0, y, 0), fn, color or C.White)
		y += 0.125
		return btn
	end
	local resume = b("RESUME", function()
		Net.Action:FireServer("Resume")
	end, C.Green)
	local restart = b("RESTART JOB", function()
		confirmAction = function()
			Net.Action:FireServer("Restart")
		end
		Menus.Show("Confirm", true)
	end)
	local board = b("QUIT TO JOB BOARD", function()
		confirmAction = function()
			Net.Action:FireServer("Board")
		end
		Menus.Show("Confirm", true)
	end)
	local settings = b("SETTINGS", function()
		Menus.Show("Settings", true)
	end)
	local controls = b("CONTROLS", function()
		Menus.Show("Controls", true)
	end)
	local note = UI.Text(p, "", U(0.9, 0, 0.06, 0), U(0.05, 0, 0.9, 0), { TextColor3 = C.PanelDark, MaxText = 14 })
	navs.Pause = { resume, restart, board, settings, controls }
	refreshers.Pause = function()
		local slot = (State.Game():GetAttribute("PausedBy") :: number?) or 0
		by.Text = slot > 0 and ("Paused by " .. Config.Slots[slot].Name) or ""
		local leader = State.IsLeader()
		UI.SetDisabled(restart, not leader)
		UI.SetDisabled(board, not leader)
		note.Text = leader and "" or "Only the host can restart or quit the job."
		title.Text = "PAUSED"
	end

	-- confirmation dialog
	local cs = screen("Confirm")
	local cp = card(cs, 0.42, 0.36)
	local ct = UI.Text(cp, "Are you sure? Progress in this job will be lost.", U(0.9, 0, 0.4, 0), U(0.05, 0, 0.08, 0), { MaxText = 24 })
	ct.Name = "Question"
	local yes = UI.NavButton(cp, "YES", U(0.38, 0, 0.24, 0), U(0.28, 0, 0.75, 0), function()
		local fn = confirmAction
		confirmAction = nil
		Menus.Back()
		if fn then
			fn()
		end
	end, C.Red)
	local no = UI.NavButton(cp, "NO", U(0.38, 0, 0.24, 0), U(0.72, 0, 0.75, 0), function()
		confirmAction = nil
		Menus.Back()
	end, C.White)
	navs.Confirm = { no, yes }
end

----------------------------------------------------------------------------------------
-- Results

local function buildResults()
	local s = screen("Results")
	local p = card(s, 0.6, 0.82)
	local title = UI.Text(p, "JOB COMPLETE!", U(1, -40, 0.12, 0), U(0, 20, 0, 12), { MaxText = 48, TextColor3 = C.Orange })
	local time = UI.Text(p, "", U(1, -40, 0.13, 0), U(0, 20, 0.14, 0), { MaxText = 52 })
	local medal = Instance.new("Frame")
	medal.Size = U(0.36, 0, 0.12, 0)
	medal.Position = U(0.32, 0, 0.29, 0)
	medal.Parent = p
	UI.Corner(medal, 20)
	UI.Stroke(medal, 4)
	local medalText = UI.Text(medal, "", UDim2.fromScale(1, 1), UDim2.new(), { MaxText = 34 })
	local detail = UI.Text(p, "", U(0.9, 0, 0.24, 0), U(0.05, 0, 0.43, 0), { TextColor3 = C.PanelDark, MaxText = 20 })
	local replay = UI.NavButton(p, "REPLAY", U(0.28, 0, 0.11, 0), U(0.2, 0, 0.82, 0), function()
		Net.Action:FireServer("Replay")
	end, C.Yellow)
	local nextB = UI.NavButton(p, "NEXT JOB", U(0.28, 0, 0.11, 0), U(0.5, 0, 0.82, 0), function()
		Net.Action:FireServer("NextJob")
	end, C.Green)
	local board = UI.NavButton(p, "JOB BOARD", U(0.28, 0, 0.11, 0), U(0.8, 0, 0.82, 0), function()
		Net.Action:FireServer("Board")
	end, C.White)
	local wait = UI.Text(p, "", U(0.9, 0, 0.05, 0), U(0.05, 0, 0.93, 0), { TextColor3 = C.PanelDark, MaxText = 14 })
	navs.Results = { nextB, replay, board }
	refreshers.Results = function()
		local r = lastResults
		if not r then
			time.Text = "..."
			return
		end
		local job = Jobs.ById[r.JobId]
		title.Text = "JOB COMPLETE!"
		time.Text = UI.FormatTime(r.Time)
		medal.BackgroundColor3 = medalColor(r.Medal)
		medalText.Text = r.Medal == "None" and "NO AWARD" or string.upper(r.Medal)
		local lines = {}
		if r.NewBest then
			table.insert(lines, r.PrevBest and string.format("NEW BEST! (was %s)", UI.FormatTime(r.PrevBest)) or "First clear - best time saved!")
		elseif r.PrevBest then
			table.insert(lines, "Best: " .. UI.FormatTime(r.PrevBest))
		end
		if job then
			local a = job.Awards
			local sc = r.Scale or 1
			table.insert(lines, string.format("Gold %s · Silver %s · Bronze %s", UI.FormatTime(a.Gold * sc), UI.FormatTime(a.Silver * sc), UI.FormatTime(a.Bronze * sc)))
		end
		if r.Unlocked and Jobs.ById[r.Unlocked] then
			table.insert(lines, "Unlocked: " .. Jobs.ById[r.Unlocked].Name)
		end
		if r.Assisted then
			table.insert(lines, "(assists were on)")
		end
		detail.Text = table.concat(lines, "\n")
		local leader = State.IsLeader()
		local hasNext = job and Jobs.Next(job.Id) ~= nil
		replay.Visible = leader
		board.Visible = leader
		nextB.Visible = leader and hasNext == true
		wait.Text = leader and "" or "Waiting for the host..."
	end
	Effects.Event:Connect(function(kind, data)
		if kind == "Results" then
			lastResults = data
			if current == "Results" then
				refreshers.Results()
			end
		end
	end)
end

----------------------------------------------------------------------------------------
-- Settings

local function buildSettings()
	local s = screen("Settings")
	local p = card(s, 0.8, 0.88)
	UI.Text(p, "SETTINGS", U(1, -40, 0.09, 0), U(0, 20, 0, 8), { MaxText = 40 })
	local list: { GuiObject } = {}
	local labels: { [string]: TextButton } = {}
	local explain = UI.Text(p, "", U(0.9, 0, 0.06, 0), U(0.05, 0, 0.8, 0), { TextColor3 = C.PanelDark, MaxText = 15 })
	local row = 0
	local function item(key: string, onClick: () -> (), help: string, col: number): TextButton
		local b = UI.NavButton(p, "", U(0.44, 0, 0.075, 0), U(0.27 + col * 0.46, 0, 0.17 + row * 0.088, 0), function()
			onClick()
			if refreshers.Settings then
				refreshers.Settings()
			end
			explain.Text = help
		end, C.White)
		b.MouseEnter:Connect(function()
			explain.Text = help
		end)
		b.SelectionGained:Connect(function()
			explain.Text = help
		end)
		labels[key] = b
		b:SetAttribute("Label", key)
		table.insert(list, b)
		if col == 1 then
			row += 1
		end
		return b
	end
	local textFns: { [TextButton]: () -> string } = {}
	local function add(key: string, text: () -> string, onClick: () -> (), help: string, col: number)
		local b = item(key, onClick, help, col)
		textFns[b] = text
	end
	local function cycleVolume(key: string)
		local v = State.Settings()[key] or 0.5
		v = math.floor(v * 10 + 0.5) / 10 + 0.2
		if v > 1.01 then
			v = 0
		end
		State.SetSetting(key, v)
	end
	local function pct(key: string): string
		return tostring(math.floor((State.Settings()[key] or 0) * 100 + 0.5)) .. "%"
	end
	add("Master", function()
		return "Master volume: " .. pct("Master")
	end, function()
		cycleVolume("Master")
	end, "Overall volume (tap to step 0-100%).", 0)
	add("Mute", function()
		return "Mute: " .. (State.Settings().Mute and "ON" or "OFF")
	end, function()
		State.SetSetting("Mute", not State.Settings().Mute)
	end, "Silences all game sound.", 1)
	add("Music", function()
		return "Music: " .. pct("Music")
	end, function()
		cycleVolume("Music")
	end, "Volume of the generated music.", 0)
	add("Effects", function()
		return "Effects: " .. pct("Effects")
	end, function()
		cycleVolume("Effects")
	end, "Volume of sound effects.", 1)
	add("GrabToggle", function()
		return "Grab mode: " .. (State.Settings().GrabToggle and "TOGGLE" or "HOLD")
	end, function()
		State.SetSetting("GrabToggle", not State.Settings().GrabToggle)
	end, "Toggle: press grab to pick up, press again to drop. Hold: keep the button held to carry.", 0)
	add("ReducedShake", function()
		return "Reduced motion: " .. (State.Settings().ReducedShake and "ON" or "OFF")
	end, function()
		State.SetSetting("ReducedShake", not State.Settings().ReducedShake)
	end, "Turns off screen shake and menu bounce animations.", 1)
	add("TextScale", function()
		return "Text & HUD size: " .. tostring(State.Settings().TextScale or 1) .. "x"
	end, function()
		local opts = { 0.85, 1, 1.15, 1.3 }
		local i = table.find(opts, State.Settings().TextScale) or 2
		State.SetSetting("TextScale", opts[i % #opts + 1])
	end, "Makes menus and the HUD bigger or smaller.", 0)
	add("Quality", function()
		return "Graphics: " .. (State.Settings().Quality or "High")
	end, function()
		State.SetSetting("Quality", State.Settings().Quality == "Low" and "High" or "Low")
	end, "Low: fewer shadows and effects for older devices. Gameplay is identical.", 1)
	add("ShowTutorialHints", function()
		return "Tutorial hints: " .. (State.Settings().ShowTutorialHints and "ON" or "OFF")
	end, function()
		State.SetSetting("ShowTutorialHints", not State.Settings().ShowTutorialHints)
	end, "Shows the step-by-step hints card in the yard and the first job.", 0)
	add("Reset", function()
		return "Reset key bindings"
	end, function()
		Input.ResetBindings()
	end, "Puts Grab / Throw / Slap back on E / Q / F.", 1)
	for _, action in Config.Bindings.Remappable do
		add("Bind" .. action, function()
			return action .. " key: " .. Input.KeyName(action)
		end, function()
			local b = labels["Bind" .. action]
			b.Text = "Press a key... (Esc cancels)"
			Input.Capture(function(key)
				if key ~= Enum.KeyCode.Escape then
					Input.SetBinding(action, key)
				end
				if refreshers.Settings then
					refreshers.Settings()
				end
			end)
		end, "Choose a new keyboard key. The alternate keys (L-Shift / R / G) always work too.", action == "Throw" and 1 or 0)
	end
	local back = UI.NavButton(p, "BACK", U(0.3, 0, 0.08, 0), U(0.5, 0, 0.92, 0), function()
		Menus.Back()
	end, C.Green)
	table.insert(list, back)
	navs.Settings = list
	refreshers.Settings = function()
		for b, fn in textFns do
			b.Text = fn()
		end
	end
end

----------------------------------------------------------------------------------------
-- Controls

local function buildControls()
	local s = screen("Controls")
	local p = card(s, 0.8, 0.84)
	UI.Text(p, "CONTROLS", U(1, -40, 0.1, 0), U(0, 20, 0, 10), { MaxText = 40 })
	local cols = {
		{ "KEYBOARD", "Move: WASD or arrows\nGrab / drop: E (or L-Shift)\nThrow: Q (or R)\nSlap: F (or G)\nJump: Space\nPause: P or Esc\nMenus: arrows + Enter" },
		{ "GAMEPAD", "Move: left stick\nGrab / drop: RB (or RT)\nThrow: X (or B)\nSlap: Y (or LB)\nJump: A\nPause: Menu\nMenus: d-pad + A, B back" },
		{ "TOUCH", "Move: thumbstick\nGrab / drop: GRAB\nThrow: THROW\nSlap: SLAP\nJump: jump button\nPause: II (top left)" },
	}
	for i, c in cols do
		UI.Text(p, c[1], U(0.3, 0, 0.07, 0), U(0.03 + (i - 1) * 0.32, 0, 0.14, 0), { TextColor3 = C.Orange, MaxText = 24 })
		UI.Text(p, c[2], U(0.3, 0, 0.42, 0), U(0.03 + (i - 1) * 0.32, 0, 0.23, 0), { TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, MaxText = 18 })
	end
	UI.Text(p, "Heavy furniture: grab one end each. Walk together to carry, walk around each other to turn it, and both press Throw within a moment to toss it. Light things fly far: throw them over gaps and into the truck!", U(0.94, 0, 0.16, 0), U(0.03, 0, 0.68, 0), { TextColor3 = C.PanelDark, MaxText = 17 })
	local back = UI.NavButton(p, "BACK", U(0.3, 0, 0.09, 0), U(0.5, 0, 0.91, 0), function()
		Menus.Back()
	end, C.Green)
	navs.Controls = { back }
end

----------------------------------------------------------------------------------------

-- Opens the right screen for the shared phase (called whenever it changes).
function Menus.FollowPhase()
	if not State.Joined then
		Menus.Show("Title")
		return
	end
	local phase = State.Phase()
	local paused = State.Game():GetAttribute("Paused") == true
	if phase == "Briefing" or phase == "Countdown" then
		lastResults = nil
	end
	if phase == "Briefing" then
		if current ~= "Settings" and current ~= "Controls" then
			Menus.Show("Briefing")
		end
	elseif phase == "Results" then
		Menus.Show("Results")
	elseif phase == "Playing" and paused then
		if current ~= "Pause" and current ~= "Confirm" and current ~= "Settings" and current ~= "Controls" then
			Menus.Show("Pause")
		end
	elseif phase == "Playing" or phase == "Countdown" then
		if current ~= nil then
			Menus.Show(nil)
		end
	elseif phase == "Lobby" then
		if current == "Briefing" or current == "Results" or current == "Pause" or current == "Confirm" then
			Menus.Show(nil)
		end
		if current == "Board" and refreshers.Board then
			refreshers.Board()
		end
	end
	if current == "Briefing" and refreshers.Briefing then
		refreshers.Briefing()
	end
end

function Menus.OpenBoard()
	selectedJob = selectedJob or Jobs.List[1].Id
	Menus.Show("Board")
end

function Menus.OpenLook()
	Menus.Show("Look")
end

function Menus.Open(name: string)
	Menus.Show(name, current ~= nil)
end

function Menus.Init()
	root = UI.Root("Menus", 20)
	root.ScreenInsets = Enum.ScreenInsets.None -- the dimmer covers the notch strips too
	buildTitle()
	buildLook()
	buildBoard()
	buildBriefing()
	buildPause()
	buildResults()
	buildSettings()
	buildControls()
	local game_ = State.Game()
	for _, attr in { "Phase", "Paused", "Leader", "JobId", "MoverCount" } do
		game_:GetAttributeChangedSignal(attr):Connect(Menus.FollowPhase)
	end
	Input.BackRequested:Connect(function()
		if current == "Title" then
			return
		end
		Menus.Back()
	end)
	Input.PauseRequested:Connect(function()
		if State.Phase() == "Playing" and not State.Game():GetAttribute("Paused") then
			Net.Action:FireServer("Pause")
		elseif current == nil and State.Joined and State.Phase() == "Lobby" then
			Menus.Show("Board")
		end
	end)
	State.SettingsChanged:Connect(function()
		if current and refreshers[current] then
			refreshers[current]()
		end
	end)
	Workspace:GetAttributeChangedSignal("ServerStarted"):Connect(Menus.FollowPhase)
	Menus.Show("Title")
end

return Menus
