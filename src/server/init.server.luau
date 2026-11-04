--!strict
-- Pet Dynasty server bootstrap. Services start in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

Remotes.init()

local Services = script:WaitForChild("Services")
local DataService = require(Services.DataService)
local CoinService = require(Services.CoinService)
local PetService = require(Services.PetService)
local BreakableService = require(Services.BreakableService)

DataService.init()
CoinService.init()
PetService.init()
BreakableService.init()

-- Lets a client ask for its full data (used when the UI first loads).
Remotes.func("GetSnapshot").OnServerInvoke = function(player: Player)
	local data = DataService.waitFor(player)
	if not data then
		return nil
	end
	return {
		Coins = data.Coins,
		Pets = data.Pets,
		Equipped = data.Equipped,
		PetSlots = data.PetSlots,
		InventoryCapacity = data.InventoryCapacity,
	}
end

print("[PetDynasty] Server started")
