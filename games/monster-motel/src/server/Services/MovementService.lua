--!strict
--[[
	MovementService

	The only place in the game that writes Humanoid.WalkSpeed.

	There are two speeds and exactly one rule about them:

	  * **Normal** is your base speed plus Running Shoes, which is bought with Cash
	    and capped by the upgrade. Everyone can earn all of it.
	  * **Carrying** is `GameConfig.CarryWalkSpeed`, a flat constant. Nothing adds
	    to it, nothing multiplies it, and it does not read the profile at all.

	Funnelling both through one function is the point. When the rule lives in one
	place, "shoes must not help you escape a chase" is a property of the code rather
	than a thing four call sites have to remember.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local MovementService = {}

-- Players currently holding a guest. Set by TheftService.
local carrying: { [Player]: boolean } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

--[[ Writes the correct speed for this player's current situation. Safe to call
     as often as you like; it is one property write. ]]
function MovementService.apply(player: Player)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end

	if carrying[player] then
		-- Deliberately does not look at the profile. A player with every upgrade
		-- in the game carries a guest at exactly this speed, same as everybody.
		humanoid.WalkSpeed = GameConfig.CarryWalkSpeed
		return
	end

	local profile = DataService.get(player)
	humanoid.WalkSpeed = if profile then EconomyService.walkSpeed(profile) else GameConfig.NormalWalkSpeed
end

function MovementService.setCarrying(player: Player, isCarrying: boolean)
	carrying[player] = isCarrying or nil
	MovementService.apply(player)
end

function MovementService.isCarrying(player: Player): boolean
	return carrying[player] == true
end

function MovementService.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- The humanoid can arrive a frame after the model, and Roblox resets
			-- WalkSpeed to the default on every respawn.
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid then
				MovementService.apply(player)
			end
		end)

		if player.Character then
			MovementService.apply(player)
		end
	end

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)

	Players.PlayerRemoving:Connect(function(player)
		carrying[player] = nil
	end)

	-- Buying Running Shoes should be felt immediately, not on next respawn.
	EconomyService.Changed:Connect(MovementService.apply)

	DataService.Loaded:Connect(function(player)
		MovementService.apply(player)
	end)
end

return MovementService
