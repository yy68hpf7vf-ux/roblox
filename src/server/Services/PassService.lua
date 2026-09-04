--!strict
--[[
	PassService

	Caches gamepass ownership per session. `UserOwnsGamePassAsync` is a web call
	and the economy asks about ownership on every single sale, so the answer is
	fetched once on join, refreshed when a purchase prompt completes, and served
	from memory in between.

	Kept free of dependencies on the economy so that EconomyService can ask about
	passes without the two modules requiring each other.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Signal = require(Shared.Util.Signal)

local PassService = {}

PassService.Changed = Signal.new() :: Signal.Signal<Player, string, boolean>

local owned: { [Player]: { [string]: boolean } } = {}

local function fetch(player: Player, pass: Monetization.Gamepass): boolean
	if not Monetization.isConfigured(pass.assetId) then
		return false
	end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.assetId)
	end)
	if not ok then
		warn(`[PassService] ownership check failed for {player.Name} / {pass.id}: {result}`)
		return false
	end
	return result == true
end

function PassService.refresh(player: Player)
	local map = owned[player]
	if not map then
		map = {}
		owned[player] = map
	end
	for _, pass in Monetization.Gamepasses do
		local has = fetch(player, pass)
		if map[pass.id] ~= has then
			map[pass.id] = has
			if has then
				PassService.Changed:Fire(player, pass.id, true)
			end
		end
	end
end

function PassService.owns(player: Player, passId: string): boolean
	local map = owned[player]
	return map ~= nil and map[passId] == true
end

function PassService.ownedMap(player: Player): { [string]: boolean }
	return owned[player] or {}
end

--[[ Multiplier from every owned pass that contributes to a numeric field, e.g.
     `sellMultiplier`. Passes multiply together rather than adding, which is the
     behaviour the store copy describes. ]]
function PassService.multiplier(player: Player, field: string): number
	local total = 1
	for _, pass in Monetization.Gamepasses do
		local value = (pass :: any)[field]
		if value and PassService.owns(player, pass.id) then
			total *= value
		end
	end
	return total
end

function PassService.sum(player: Player, field: string): number
	local total = 0
	for _, pass in Monetization.Gamepasses do
		local value = (pass :: any)[field]
		if value and PassService.owns(player, pass.id) then
			total += value
		end
	end
	return total
end

function PassService.anyFlag(player: Player, field: string): boolean
	for _, pass in Monetization.Gamepasses do
		if (pass :: any)[field] == true and PassService.owns(player, pass.id) then
			return true
		end
	end
	return false
end

function PassService.start()
	local function setup(player: Player)
		owned[player] = {}
		task.spawn(PassService.refresh, player)
	end

	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, assetId, wasPurchased)
		if not wasPurchased then
			return
		end
		local pass = Monetization.GamepassByAsset[assetId]
		if not pass then
			return
		end
		local map = owned[player]
		if map then
			map[pass.id] = true
			PassService.Changed:Fire(player, pass.id, true)
		end
	end)
end

return PassService
