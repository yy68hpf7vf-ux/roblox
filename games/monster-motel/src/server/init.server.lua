--!strict
--[[
	Monster Motel -- server entry point

	Boot order matters:

	  1. Remotes exist before anything looks for them.
	  2. The world is built before PlotService hands plots out and before
	     RentService and TheftService go looking for front desks to wire up.
	  3. Everything that listens for a profile is connected before DataService
	     starts loading them, or the first player to join is missed.
	  4. NightService goes last, because starting it fires the first phase change
	     and everything that reacts to sunrise should already be listening.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local Services = script.Services
local ActionService = require(Services.ActionService)
local AmbienceService = require(Services.AmbienceService)
local ArrivalService = require(Services.ArrivalService)
local ChatTagService = require(Services.ChatTagService)
local DataService = require(Services.DataService)
local EventService = require(Services.EventService)
local LeaderboardService = require(Services.LeaderboardService)
local MonetizationService = require(Services.MonetizationService)
local MovementService = require(Services.MovementService)
local NightService = require(Services.NightService)
local ObjectiveService = require(Services.ObjectiveService)
local PassService = require(Services.PassService)
local PlotService = require(Services.PlotService)
local QuestService = require(Services.QuestService)
local RentService = require(Services.RentService)
local RewardService = require(Services.RewardService)
local SafetyService = require(Services.SafetyService)
local SignatureService = require(Services.SignatureService)
local StateService = require(Services.StateService)
local TheftService = require(Services.TheftService)

local WorldBuilder = require(script.World.WorldBuilder)

Net.build()

local world = WorldBuilder.build()

-- Plots first: everything below assumes a player can be mapped to a motel.
PlotService.start(world)

-- Listeners before loaders. MovementService and ObjectiveService both react to
-- EconomyService.Changed, so they have to be connected before any profile loads.
StateService.start()
MovementService.start()
ObjectiveService.start()
-- SignatureService also reacts to a profile load and to a pass appearing, so it
-- has to be listening before DataService and PassService start.
SignatureService.start()

--[[ Put a player in front of their own motel. A character can spawn before the
     profile arrives, so this waits rather than dropping everyone in the square
     and letting them work out which building is theirs. ]]
local function placeCharacter(player: Player, character: Model)
	local profile = DataService.await(player, 20)
	if not profile then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	end
	if not root then
		return
	end

	local cframe = PlotService.spawnCFrame(player)
	if cframe then
		root.CFrame = cframe
	end
end

DataService.Loaded:Connect(function(player, profile)
	QuestService.ensureDaily(player, profile)

	local character = player.Character
	if character then
		task.spawn(placeCharacter, player, character)
	end
end)

local function watchSpawns(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(placeCharacter, player, character)
	end)
end

for _, player in Players:GetPlayers() do
	watchSpawns(player)
end
Players.PlayerAdded:Connect(watchSpawns)

-- Systems that act on profiles.
PassService.start()
DataService.start()
ArrivalService.start()
RentService.start()
TheftService.start()
EventService.start(world)
RewardService.start()
MonetizationService.start()
ActionService.start()
LeaderboardService.start()
ChatTagService.start()
SafetyService.start()

-- Cosmetic, and last of the world systems: it reads the night state and changes
-- nothing, so it can safely start after everything that owns state.
AmbienceService.start(world)

-- Last: starting the clock fires the first phase change.
NightService.start()

print(
	`[{GameConfig.GameName}] server ready -- {WorldBuilder.PlotCount} plots, `
		.. `{GameConfig.DayDuration}s days, {GameConfig.NightDuration}s nights`
)
