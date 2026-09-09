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

--[[ Ownership is asked once on join, and a failed web call used to be answered
     with a flat `false` -- which reads, to every other system, as "this player
     does not own the pass". UserOwnsGamePassAsync fails for ordinary reasons
     (throttling, a Roblox API hiccup), so that turned a transient blip into a
     paying player losing what they bought for the whole session, silently.

     A purchase is the one thing in this game that must not be quietly lost, so
     this retries before it gives up, and says so loudly when it does. ]]
local FETCH_ATTEMPTS = 3
local FETCH_BACKOFF = 1.5

local function fetch(player: Player, pass: Monetization.Gamepass): (boolean, boolean)
	if not Monetization.isConfigured(pass.assetId) then
		return false, true
	end

	for attempt = 1, FETCH_ATTEMPTS do
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.assetId)
		end)
		if ok then
			return result == true, true
		end
		if attempt < FETCH_ATTEMPTS and player.Parent then
			task.wait(FETCH_BACKOFF * attempt)
		else
			warn(
				`[PassService] ownership check for {player.Name} / {pass.id} failed `
					.. `{FETCH_ATTEMPTS} times: {result}. Treating as not owned for now.`
			)
		end
	end
	return false, false
end

--[[ Returns whether every pass was answered. A false here means at least one
     answer is a guess, not a fact, which is why the caller schedules another go. ]]
function PassService.refresh(player: Player): boolean
	local map = owned[player]
	if not map then
		map = {}
		owned[player] = map
	end

	local complete = true
	for _, pass in Monetization.Gamepasses do
		local has, answered = fetch(player, pass)
		complete = complete and answered
		-- Only ever move an answer from false to true here. A later failed sweep
		-- must not take away a pass an earlier successful one confirmed.
		if has and map[pass.id] ~= true then
			map[pass.id] = true
			PassService.Changed:Fire(player, pass.id, true)
		elseif map[pass.id] == nil then
			map[pass.id] = has
		end
	end
	return complete
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
	--[[ Keep sweeping until every pass has a real answer. Without this, a player
	     who joined during an API blip would stay un-refunded and un-entitled until
	     they rejoined, and would have no way of knowing why. ]]
	local function setup(player: Player)
		owned[player] = {}
		task.spawn(function()
			for attempt = 1, 5 do
				if not player.Parent then
					return
				end
				if PassService.refresh(player) then
					return
				end
				task.wait(10 * attempt)
			end
			warn(`[PassService] gave up confirming pass ownership for {player.Name}`)
		end)
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
