--!strict
--[[
	Rift Miner Simulator -- server entry point

	Boot order matters here:

	  1. Remotes exist before anything tries to find them.
	  2. The world is built before MiningService is told about its nodes and
	     before PadService goes looking for pads to connect.
	  3. Everything that listens for a profile is connected before DataService
	     starts loading them, or the first player to join is missed.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local Net = require(Shared.Net)

local Services = script.Services
local ActionService = require(Services.ActionService)
local DataService = require(Services.DataService)
local EconomyService = require(Services.EconomyService)
local LeaderboardService = require(Services.LeaderboardService)
local LoadoutService = require(Services.LoadoutService)
local MiningService = require(Services.MiningService)
local MonetizationService = require(Services.MonetizationService)
local PadService = require(Services.PadService)
local PassService = require(Services.PassService)
local PetService = require(Services.PetService)
local QuestService = require(Services.QuestService)
local RewardService = require(Services.RewardService)
local StateService = require(Services.StateService)

local WorldBuilder = require(script.World.WorldBuilder)

Net.build()

local world = WorldBuilder.build()
MiningService.register(world.nodesByZone)

-- Listeners first.
StateService.start()
LoadoutService.start()

--[[ Put a player back where they left off. A character can spawn before the
     profile arrives, so this waits rather than dumping everyone in Green Hollow
     and letting them notice. ]]
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

	local zone = Zones.get(profile.zone)
	if not EconomyService.hasZone(player, profile, zone) then
		-- A VIP zone they no longer have access to, or a zone removed in an
		-- update. Send them somewhere they can definitely stand.
		zone = Zones.get(Zones.Starter)
		profile.zone = zone.id
	end

	root.CFrame = WorldBuilder.spawnCFrame(zone)
end

DataService.Loaded:Connect(function(player, profile)
	QuestService.ensureDaily(player, profile)
	PetService.onLoaded(player, profile)

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

-- Then the systems that act on profiles.
PassService.start()
DataService.start()
RewardService.start()
MonetizationService.start()
MiningService.start()
PadService.start(world.root)
ActionService.start()
LeaderboardService.start()

print(`[{GameConfig.GameName}] server ready -- {#Zones.List} zones built`)
