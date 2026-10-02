--[[
	Audio.luau
	Effects and generated music, mixed by the player's settings (master / music /
	effects volume, mute).

	* Effects come from Config.Sounds (built-in Roblox sounds, so they can't be missing).
	  Each play gets a little pitch variation; the same sound can't restart faster than
	  MinGap and at most SoundRules.MaxVoices effects play at once, so a pile of
	  colliding boxes is one clatter, not fifty.
	* World sounds play from a pooled emitter at a position (3D roll-off).
	* Music is generated: a short original bouncy tune sequenced from one tone sample at
	  different pitches (no licensed track needed). It ducks while paused.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Audio = {}

local effects: SoundGroup
local music: SoundGroup
local pools: { [string]: { Sound } } = {}
local poolIndex: { [string]: number } = {}
local lastPlayed: { [string]: number } = {}
local voices = 0
local emitters: { { Part: BasePart, Sound: Sound } } = {}
local emitterIndex = 0
local rng = Random.new()
local ducked = false

local MIN_GAP = 0.04

local function applyVolumes()
	local s = State.Settings()
	local master = s.Mute and 0 or (s.Master or 0.8)
	effects.Volume = master * (s.Effects or 0.8)
	music.Volume = master * (s.Music or 0.5) * (ducked and 0.35 or 1)
end

local function newSound(def: any, parent: Instance, group: SoundGroup): Sound
	local snd = Instance.new("Sound")
	snd.SoundId = def.Id
	snd.Volume = def.Volume or 0.5
	snd.SoundGroup = group
	snd.Parent = parent
	return snd
end

local function pooled(name: string): Sound?
	local def = Config.Sounds[name]
	if not def then
		return nil
	end
	local pool = pools[name]
	if not pool then
		pool = {}
		for _ = 1, 3 do
			table.insert(pool, newSound(def, SoundService, effects))
		end
		pools[name] = pool
		poolIndex[name] = 0
	end
	poolIndex[name] = poolIndex[name] % #pool + 1
	return pool[poolIndex[name]]
end

function Audio.Play(name: string, pitch: number?, volumeScale: number?)
	local t = os.clock()
	if lastPlayed[name] and t - lastPlayed[name] < MIN_GAP then
		return
	end
	if voices >= Config.SoundRules.MaxVoices then
		return
	end
	local def = Config.Sounds[name]
	local snd = pooled(name)
	if not snd or not def then
		return
	end
	lastPlayed[name] = t
	snd.PlaybackSpeed = (pitch or def.Pitch or 1) * (1 + rng:NextNumber(-0.05, 0.05))
	snd.Volume = (def.Volume or 0.5) * (volumeScale or 1)
	snd.TimePosition = 0
	snd:Play()
	voices += 1
	task.delay(1.2, function()
		voices = math.max(0, voices - 1)
	end)
end

function Audio.PlayAt(name: string, pos: Vector3?, pitch: number?, volumeScale: number?)
	if not pos then
		Audio.Play(name, pitch, volumeScale)
		return
	end
	local def = Config.Sounds[name]
	if not def then
		return
	end
	local t = os.clock()
	local key = name .. "@"
	if lastPlayed[key] and t - lastPlayed[key] < MIN_GAP then
		return
	end
	if voices >= Config.SoundRules.MaxVoices then
		return
	end
	lastPlayed[key] = t
	emitterIndex = emitterIndex % #emitters + 1
	local e = emitters[emitterIndex]
	e.Part.Position = pos
	e.Sound.SoundId = def.Id
	e.Sound.Volume = (def.Volume or 0.5) * (volumeScale or 1)
	e.Sound.PlaybackSpeed = (pitch or def.Pitch or 1) * (1 + rng:NextNumber(-0.06, 0.06))
	e.Sound.TimePosition = 0
	e.Sound:Play()
	voices += 1
	task.delay(1.2, function()
		voices = math.max(0, voices - 1)
	end)
end

----------------------------------------------------------------------------------------
-- Generated music: two bars of melody over a walking bass, 132 bpm, C major pentatonic.

local MELODY = { 0, 4, 7, 9, 7, 4, 2, -1, 4, 7, 9, 12, 9, 7, 4, -1, 2, 4, 7, 4, 2, 0, 2, -1, 0, 4, 7, 9, 12, 9, 7, -1 }
local BASS = { -12, -12, -5, -5, -7, -7, -5, -5 }
local musicNotes: { Sound } = {}
local bassNotes: { Sound } = {}
local musicOn = true

local function semis(n: number): number
	return 2 ^ (n / 12)
end

local function startMusic()
	for _ = 1, 4 do
		table.insert(musicNotes, newSound(Config.Sounds.Note, SoundService, music))
		table.insert(bassNotes, newSound(Config.Sounds.Bass, SoundService, music))
	end
	task.spawn(function()
		local step = 0
		local beat = 60 / 132 / 2 -- eighth notes
		local nextTime = os.clock()
		while true do
			nextTime += beat
			if musicOn then
				local m = MELODY[step % #MELODY + 1]
				if m >= 0 then
					local s = musicNotes[step % #musicNotes + 1]
					s.PlaybackSpeed = semis(m) * 1.0
					s.TimePosition = 0
					s:Play()
				end
				if step % 4 == 0 then
					local b = BASS[(step // 4) % #BASS + 1]
					local s = bassNotes[(step // 4) % #bassNotes + 1]
					s.PlaybackSpeed = semis(b + 12) * Config.Sounds.Bass.Pitch
					s.TimePosition = 0
					s:Play()
				end
			end
			step += 1
			local wait = nextTime - os.clock()
			if wait > 0 then
				task.wait(wait)
			else
				nextTime = os.clock()
				RunService.Heartbeat:Wait()
			end
		end
	end)
end

function Audio.SetDucked(value: boolean)
	ducked = value
	applyVolumes()
end

function Audio.Init()
	effects = Instance.new("SoundGroup")
	effects.Name = "MO_Effects"
	effects.Parent = SoundService
	music = Instance.new("SoundGroup")
	music.Name = "MO_Music"
	music.Parent = SoundService
	local folder = Instance.new("Folder")
	folder.Name = "SoundEmitters"
	folder.Parent = Workspace
	for _ = 1, 10 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Parent = folder
		local s = Instance.new("Sound")
		s.SoundGroup = effects
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 80
		s.RollOffMaxDistance = 260
		s.Parent = p
		table.insert(emitters, { Part = p, Sound = s })
	end
	applyVolumes()
	State.SettingsChanged:Connect(applyVolumes)
	-- audio start errors (blocked / unavailable) are harmless: sounds just stay silent
	pcall(startMusic)
end

return Audio
