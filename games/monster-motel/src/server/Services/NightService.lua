--!strict
--[[
	NightService

	The day/night cycle, which is the metronome the whole game runs on.

	Day is long and safe: you buy guests, fill rooms, upgrade. Night is short and
	dangerous: doors can be broken and guests carried off. Everyone in the server
	is on the same clock, and the HUD counts down to the flip, so a raid is
	something you plan for rather than something that happens to you.

	The lengths are constants in GameConfig. Nothing extends your day or shortens
	someone else's night.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Signal = require(Shared.Util.Signal)

local Remote = require(script.Parent.Remote)

local NightService = {}

NightService.Changed = Signal.new() :: Signal.Signal<boolean>

local isNight = false
local phaseEndsAt = 0

function NightService.isNight(): boolean
	return isNight
end

function NightService.secondsLeft(): number
	return math.max(0, phaseEndsAt - os.clock())
end

function NightService.state(): { [string]: any }
	return {
		night = isNight,
		secondsLeft = NightService.secondsLeft(),
		phaseLength = if isNight then GameConfig.NightDuration else GameConfig.DayDuration,
	}
end

local function applyLighting(night: boolean)
	local info = TweenInfo.new(4, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = if night then 0 else 15,
		Brightness = if night then 0.6 else 2,
		OutdoorAmbient = if night then Color3.fromRGB(48, 44, 76) else Color3.fromRGB(110, 106, 128),
	}):Play()
end

local function setPhase(night: boolean)
	isNight = night
	phaseEndsAt = os.clock() + (if night then GameConfig.NightDuration else GameConfig.DayDuration)

	applyLighting(night)
	NightService.Changed:Fire(night)

	Remote.effectAll("phase", NightService.state())
	Remote.notifyAll(
		if night
			then "LIGHTS OUT. Doors can be broken until sunrise."
			else "Sunrise. Every motel is sealed until tonight.",
		if night then "warn" else "good"
	)
end

function NightService.start()
	setPhase(false)

	task.spawn(function()
		while true do
			task.wait(NightService.secondsLeft())
			setPhase(not isNight)
		end
	end)
end

return NightService
