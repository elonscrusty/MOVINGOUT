--[[
	Config.luau
	Every gameplay tuning value in one place, readable by server and client.

	IMPORTANT: these numbers are RECONSTRUCTION DEFAULTS chosen to make a working game.
	None of them are measurements of the original Moving Out. Tune them by playtesting.

	Units are Roblox studs. As a rule of thumb one "metre" of the design brief is about
	4.5 studs (a mover is roughly 4.5 studs tall), so a 0.95 m doorway is about 5 studs.
	Never put secrets here: this module replicates to every client.
]]

local Config = {
	GameName = "MOVING OUT",
	Version = "0.1.0",
	MaxMovers = 4,
	StudsPerMetre = 4.5,
}

-- Fixed-rate gameplay tick on the server (Roblox steps rigid-body physics itself; this is
-- the rate our own gameplay logic, delivery checks and hazards update at).
Config.Tick = {
	Rate = 1 / 60,
	MaxCatchUp = 5, -- at most this many gameplay ticks after a stall
	DeliveryInterval = 0.1,
}

Config.Movement = {
	WalkSpeed = 16, -- ~3.6 m/s
	JumpHeight = 3.2, -- short hop: clears a step or a fallen box, not a wall
	HeightScale = 0.78, -- R15 scale for short cartoon movers
	WidthScale = 1.0,
	DepthScale = 1.0,
	-- walking speed while carrying, as a fraction of WalkSpeed, by how much of the item's
	-- needed strength the holders supply (see Carry.Strength). Resistance, not input lag.
	CarrySpeedMin = 0.42,
	CarrySpeedMax = 0.95,
}

Config.Carry = {
	Reach = 4.2, -- from the root part centre to the nearest point of the item's box
	ServerReachSlack = 2.5, -- extra distance the server tolerates (latency)
	GripSpacing = 2.4, -- two grips on the same item can't be closer than this
	HoldOffset = Vector3.new(0, 0.1, -1.9), -- carry point, root-part space (in front, waist)
	Responsiveness = 28,
	MaxVelocity = 60,
	-- lift force per holder as a fraction of the item's weight (mass * gravity)
	LiftPerHolder = { Light = 3.0, Medium = 1.6, Heavy = 0.8 },
	-- extra fraction for a holder who is the only mover in the job (solo play):
	-- heavy items become carryable but stay slow and awkward
	SoloBonus = { Light = 0, Medium = 0.3, Heavy = 0.45 },
	-- "strength needed" to walk at full carry speed, in holders
	Strength = { Light = 0.6, Medium = 1.2, Heavy = 2.0 },
	UprightTorque = 4000, -- per unit of item mass; keeps carried things upright
	UprightResponsiveness = 18,
	SpinDamping = 60, -- per unit of item mass; stops held items spinning wildly
	TargetHysteresis = 1.2, -- a new target must score this much better to steal focus
	FacingWeight = 2.5, -- how much "in front of me" matters when picking a target
	DropProtect = 0.25, -- seconds before the same player can re-grab after release
}

Config.Throw = {
	Windup = 0.22, -- single throw anticipation
	CoopWindow = 0.3, -- partners must press throw within this many seconds
	CoopWindup = 0.35,
	-- launch velocity (studs/s) by item weight class: Forward, Up
	Velocity = {
		Light = { Forward = 52, Up = 34 },
		Medium = { Forward = 38, Up = 28 },
		Heavy = { Forward = 34, Up = 30 }, -- cooperative only
	},
	ServerOwnSeconds = 1.6, -- server simulates a thrown item for this long
	Cooldown = 0.45,
}

Config.Slap = {
	Range = 4.5,
	Radius = 3.2,
	Cooldown = 0.6,
	PlayerKnock = 26,
	PlayerStun = 0.45,
	ItemPush = 18,
	GhostStun = 3.0,
}

Config.Stun = {
	CarHit = 1.3,
	GhostSpook = 1.1,
	RespawnProtect = 1.6,
}

Config.Delivery = {
	-- an item counts as delivered when at least InFraction of its 8 box corners are inside
	-- the cargo volume (with Tolerance studs of slack), it isn't held, and it has stayed
	-- that way for SettleTime. It stops counting when fewer than OutFraction are inside.
	InFraction = 7 / 8,
	OutFraction = 5 / 8,
	Tolerance = 0.6,
	SettleTime = 0.5,
	VanishDelay = 0.6, -- assist: delivered furniture disappears after this
}

Config.Recovery = {
	KillY = -30, -- below this, items and movers are recovered
	ItemDelay = 1.2,
	PlayerDelay = 1.0,
	ClearanceTries = 6,
}

Config.Breakable = {
	ImpactSpeed = 14, -- relative speed of a furniture hit that breaks a window
	ShardCount = 8,
	ShardLife = 1.4,
	DoorSlaps = 3, -- boarded doors break after this many slaps (or a hard hit)
	DoorImpactSpeed = 22,
}

Config.Hazards = {
	CarWarnTime = 2.0,
	CarSpeed = 34,
	CarKnock = 55,
	ItemKnock = 30,
	GhostSpeed = 7,
	GhostChaseSpeed = 13,
	GhostNotice = 9,
	GhostCooldown = 4.5,
	-- assist "reduced hazards" multiplies spawn intervals by this and slows ghosts
	ReducedIntervalScale = 1.8,
	ReducedSpeedScale = 0.7,
}

Config.Camera = {
	Pitch = 62, -- degrees down: near top-down like the original
	Yaw = 25, -- degrees around the up axis (levels can override)
	FieldOfView = 26, -- low FOV = restrained perspective, walls barely lean
	MinDistance = 120,
	MaxDistance = 420,
	Margin = 5, -- studs kept around each mover
	ScreenPad = 0.04, -- fraction of the half-screen kept free at the edges
	DistancePerStud = 1.05, -- preview tool fallback framing only
	FollowSpeed = 4,
	ZoomSpeed = 2,
	ZoomDeadband = 6, -- ignore distance changes smaller than this (no zoom breathing)
	FadeTransparency = 0.75,
}

Config.Countdown = 3

-- Assist options the host (first player) chooses on the job board.
Config.Assists = {
	TimeTargetScale = { 1, 1.25, 1.5, 2 },
	Defaults = {
		TimeScale = 1,
		ReducedHazards = false,
		EasyHeavy = false,
		VanishDelivered = false,
	},
}

-- Player slots: colour + number + a symbol so colour is never the only cue.
Config.Slots = {
	{ Name = "P1", Color = Color3.fromRGB(235, 72, 72), Symbol = "▲" },
	{ Name = "P2", Color = Color3.fromRGB(64, 140, 240), Symbol = "●" },
	{ Name = "P3", Color = Color3.fromRGB(245, 196, 40), Symbol = "■" },
	{ Name = "P4", Color = Color3.fromRGB(70, 200, 110), Symbol = "◆" },
}

-- Default bindings. Players can remap the three actions (saved in their profile).
Config.Bindings = {
	Keyboard = {
		Grab = "E",
		Throw = "Q",
		Slap = "F",
		Jump = "Space", -- jump is Roblox's own; listed for the controls screen
		Pause = "Escape",
	},
	-- second set that always works, for keyboards that drop key combinations
	KeyboardAlt = {
		Grab = "LeftShift",
		Throw = "R",
		Slap = "G",
	},
	Gamepad = {
		Grab = "ButtonR1",
		Throw = "ButtonX",
		Slap = "ButtonY",
		Jump = "ButtonA",
		Pause = "ButtonStart",
	},
	GamepadAlt = {
		Grab = "ButtonR2",
		Throw = "ButtonB",
		Slap = "ButtonL1",
	},
	Remappable = { "Grab", "Throw", "Slap" },
}

-- Built-in Roblox sounds (shipped with every client, so they can never be missing).
Config.Sounds = {
	Click = { Id = "rbxasset://sounds/button.wav", Volume = 0.45, Pitch = 1 },
	Focus = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.2, Pitch = 1.4 },
	Grab = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Pitch = 0.8 },
	Release = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.35, Pitch = 0.6 },
	Windup = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.25, Pitch = 0.9 },
	Throw = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.2, Pitch = 1.4 },
	ImpactWood = { Id = "rbxasset://sounds/collide.wav", Volume = 0.35, Pitch = 1.1 },
	ImpactHeavy = { Id = "rbxasset://sounds/collide.wav", Volume = 0.55, Pitch = 0.7 },
	ImpactSoft = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.45, Pitch = 1.2 },
	ImpactMetal = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.25, Pitch = 1.3 },
	Glass = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.8, Pitch = 1.6 },
	GlassTinkle = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Pitch = 2.6 },
	WoodBreak = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.8, Pitch = 0.8 },
	Deliver = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1.25 },
	Undeliver = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Pitch = 0.7 },
	Splash = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.7, Pitch = 1 },
	Slap = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.35, Pitch = 1.5 },
	SlapHit = { Id = "rbxasset://sounds/splat.wav", Volume = 0.5, Pitch = 1.6 },
	Jump = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.3, Pitch = 1.2 },
	Land = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.25, Pitch = 1.1 },
	Honk = { Id = "rbxasset://sounds/Launching rocket.wav", Volume = 0.25, Pitch = 2.4 },
	CarHit = { Id = "rbxasset://sounds/collide.wav", Volume = 0.7, Pitch = 0.9 },
	Ghost = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.35, Pitch = 0.45 },
	Stun = { Id = "rbxasset://sounds/splat.wav", Volume = 0.4, Pitch = 0.8 },
	Countdown = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1 },
	Go = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.5 },
	Complete = { Id = "rbxasset://sounds/victory.wav", Volume = 0.6, Pitch = 1 },
	Error = { Id = "rbxasset://sounds/button.wav", Volume = 0.35, Pitch = 0.6 },
	-- tones used by the generated music
	Note = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.12, Pitch = 1 },
	Bass = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.18, Pitch = 0.5 },
}

Config.SoundRules = {
	ImpactMinSpeed = 9, -- softer contacts make no sound
	ImpactGap = 0.12, -- per item
	GlobalImpactGap = 0.04,
	MaxVoices = 16,
}

-- Defaults for per-player settings (saved in the profile; validated on load).
Config.SettingsDefaults = {
	Master = 0.8,
	Music = 0.5,
	Effects = 0.8,
	Mute = false,
	GrabToggle = true, -- press to grab, press again to drop (off = hold to carry)
	ReducedShake = false,
	TextScale = 1,
	Quality = "High", -- "High" or "Low" (fewer shadows / effects, same gameplay)
	ShowTutorialHints = true,
}

return Config
