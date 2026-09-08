--!strict
--[[
	AmbienceService

	Sky, atmosphere, street lighting and sound.

	Lights Out is the most important moment in the game, so it is worth making it
	unmistakable. Rather than the sky quietly changing colour, the whole town
	switches over at once: every lamp, window and neon sign comes on together, the
	fog closes in, and the ambient track changes. Nobody should ever have to check
	the clock to know it is night.

	Everything here is cosmetic. It reads the night state and changes nothing.
]]

local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local NightService = require(script.Parent.NightService)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local AmbienceService = {}

local lamps: { Light } = {}

--[[ Sound ids are left at 0 deliberately. Shipping with somebody else's audio
     asset baked in is how a game gets a copyright strike, so this ships silent
     and names exactly what to drop in. Anything left at 0 is skipped. ]]
AmbienceService.Sounds = {
	dayLoop = 0,
	nightLoop = 0,
}

local DAY = {
	ClockTime = 14.5,
	Brightness = 2.2,
	OutdoorAmbient = Color3.fromRGB(122, 118, 140),
	FogColor = Color3.fromRGB(178, 190, 210),
	FogEnd = 2600,
}

local NIGHT = {
	ClockTime = 0.4,
	Brightness = 0.5,
	OutdoorAmbient = Color3.fromRGB(44, 42, 72),
	FogColor = Color3.fromRGB(26, 26, 44),
	-- Fog is the real mechanic here: at night you cannot read a motel sign from
	-- across the map, so raiders have to commit to a direction.
	FogEnd = 620,
}

local function buildSky()
	for _, existing in Lighting:GetChildren() do
		if existing:IsA("Sky") or existing:IsA("Atmosphere") then
			existing:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.Name = "Sky"
	sky.StarCount = 4000
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "Atmosphere"
	atmosphere.Density = 0.32
	atmosphere.Haze = 1.2
	atmosphere.Glare = 0.2
	atmosphere.Color = Color3.fromRGB(210, 206, 200)
	atmosphere.Decay = Color3.fromRGB(120, 124, 150)
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Bloom"
	bloom.Intensity = 0.5
	bloom.Size = 20
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
end

local function makeLoop(id: number, volume: number): Sound?
	if id == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = `rbxassetid://{id}`
	sound.Looped = true
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local dayLoop: Sound? = nil
local nightLoop: Sound? = nil

local function applyPhase(night: boolean, instant: boolean)
	local target = if night then NIGHT else DAY
	local info = TweenInfo.new(if instant then 0 else 5, Enum.EasingStyle.Sine)

	TweenService:Create(Lighting, info, {
		ClockTime = target.ClockTime,
		Brightness = target.Brightness,
		OutdoorAmbient = target.OutdoorAmbient,
		FogColor = target.FogColor,
		FogEnd = target.FogEnd,
	}):Play()

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, {
			Density = if night then 0.42 else 0.32,
			Color = if night then Color3.fromRGB(90, 92, 130) else Color3.fromRGB(210, 206, 200),
		}):Play()
	end

	-- The whole town, at once.
	for _, light in lamps do
		if light.Parent then
			light.Enabled = night
		end
	end

	if dayLoop then
		dayLoop.Playing = not night
	end
	if nightLoop then
		nightLoop.Playing = night
	end
end

function AmbienceService.start(built: WorldBuilder.Built)
	lamps = built.lamps

	Lighting.GlobalShadows = true
	Lighting.Technology = Enum.Technology.ShadowMap
	Lighting.FogStart = 80
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3

	buildSky()

	dayLoop = makeLoop(AmbienceService.Sounds.dayLoop, 0.25)
	nightLoop = makeLoop(AmbienceService.Sounds.nightLoop, 0.3)

	applyPhase(NightService.isNight(), true)
	NightService.Changed:Connect(function(night: boolean)
		applyPhase(night, false)
	end)

	if AmbienceService.Sounds.dayLoop == 0 and AmbienceService.Sounds.nightLoop == 0 then
		print(
			`[{GameConfig.GameName}] no ambience audio configured -- `
				.. "set AmbienceService.Sounds to your own asset ids when you have them"
		)
	end
end

return AmbienceService
