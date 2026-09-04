--!strict
--[[
	LoadoutService

	Publishes the cosmetic half of a player's loadout as attributes on the Player
	object: which pick they hold, which pets follow them, how many rebirths they
	have.

	Cosmetics are rendered by every client from these attributes rather than being
	built as server instances. A server-side pet is five parts replicated to
	everyone on every frame it moves; an attribute is a short string that changes
	when the player changes it, and each client draws what it can already see. It
	is the difference between a server that holds thirty players and one that
	holds eight.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Schema = require(Shared.Schema)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

type Profile = Schema.Profile

local LoadoutService = {}

local function publish(player: Player, profile: Profile)
	player:SetAttribute("Pick", profile.tool)
	player:SetAttribute("Rebirths", profile.rebirths)
	player:SetAttribute("Pets", table.concat(EconomyService.equippedPetIds(profile), ","))
end

function LoadoutService.start()
	DataService.Loaded:Connect(function(player, profile)
		publish(player, profile)

		player.CharacterAdded:Connect(function()
			local current = DataService.get(player)
			if current then
				publish(player, current)
			end
		end)
	end)

	EconomyService.Changed:Connect(function(player)
		local profile = DataService.get(player)
		if profile then
			publish(player, profile)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		-- Defaults so another client rendering this player before their profile
		-- arrives draws a starter pick rather than nothing at all.
		player:SetAttribute("Pick", "rusty")
		player:SetAttribute("Rebirths", 0)
		player:SetAttribute("Pets", "")
	end)
end

return LoadoutService
