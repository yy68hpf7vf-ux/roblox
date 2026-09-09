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

--[[ Ambient is in here, not just OutdoorAmbient, and that matters more than it
     looks. Ambient is flat fill applied to every surface no matter where the sun
     is -- so a high one washes the day out by erasing shadow, and worse, it sets
     a floor on how dark night can ever get. Lights Out is the game's best moment
     and it cannot happen underneath a permanent 70/66/82 of fill. ]]
local DAY = {
	ClockTime = 14.5,
	Brightness = 2.6,
	Ambient = Color3.fromRGB(26, 24, 38),
	OutdoorAmbient = Color3.fromRGB(108, 106, 128),
	FogColor = Color3.fromRGB(178, 190, 210),
	FogEnd = 2600,
	-- Atmosphere, tuned with the rest of the phase rather than left on one setting
	-- for both. Haze is the knob that whitens everything, so it stays low by day.
	Density = 0.3,
	Haze = 0.2,
	AtmosphereColor = Color3.fromRGB(206, 204, 200),
}

local NIGHT = {
	ClockTime = 0.4,
	Brightness = 0.4,
	Ambient = Color3.fromRGB(12, 11, 24),
	OutdoorAmbient = Color3.fromRGB(38, 36, 64),
	FogColor = Color3.fromRGB(26, 26, 44),
	-- Fog is the real mechanic here: at night you cannot read a motel sign from
	-- across the map, so raiders have to commit to a direction.
	FogEnd = 620,
	Density = 0.42,
	Haze = 0.7,
	AtmosphereColor = Color3.fromRGB(84, 86, 124),
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
	atmosphere.Density = DAY.Density
	atmosphere.Haze = DAY.Haze
	-- Glare blooms the sun itself. Left off: with a bright sky and a bloom pass
	-- already running it is the difference between a warm scene and a white one.
	atmosphere.Glare = 0
	atmosphere.Color = DAY.AtmosphereColor
	atmosphere.Decay = Color3.fromRGB(112, 118, 146)
	atmosphere.Parent = Lighting

	--[[ Threshold above 1 on purpose. Below it, ordinary lit surfaces -- a pavement
	     apron, a pale motel wall -- cross the line and bloom, and the whole scene
	     turns into a white sheet. Only genuine highlights should glow. ]]
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Bloom"
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 2.2
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
		Ambient = target.Ambient,
		OutdoorAmbient = target.OutdoorAmbient,
		FogColor = target.FogColor,
		FogEnd = target.FogEnd,
	}):Play()

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, {
			Density = target.Density,
			Haze = target.Haze,
			Color = target.AtmosphereColor,
		}):Play()
	end

	-- Publish the phase so WorldBuilder.applyRating can light a prop revealed
	-- mid-night rather than leaving it dark until dawn.
	WorldBuilder.nightMode = night

	-- The whole town, at once -- except anything hanging off a prop the motel has
	-- not earned yet. A hidden pool must not glow.
	for _, light in lamps do
		local host = light.Parent
		if host and host:IsA("BasePart") then
			light.Enabled = night and host.Transparency < 1
		elseif host then
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
	-- Environment light is another flat fill. Dialled back for the same reason as
	-- Ambient: it is light that casts nothing and hides the shape of the town.
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.ExposureCompensation = 0

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
