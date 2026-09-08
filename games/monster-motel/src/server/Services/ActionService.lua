--!strict
--[[
	ActionService

	The one entry point the client can call. Every request arrives as a named action
	with a payload, is rate limited, is checked for a loaded profile, and is
	dispatched to a handler that re-validates everything against the server's own
	config.

	Note what is not in this list: there is no "collect" action. Rent is banked by
	walking onto your own front desk, because that walk is the loop. Auto Collect
	removes it, and that is exactly what makes the pass worth buying.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Schema = require(Shared.Schema)

local CodeService = require(script.Parent.CodeService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local GuestService = require(script.Parent.GuestService)
local MonetizationService = require(script.Parent.MonetizationService)
local PrestigeService = require(script.Parent.PrestigeService)
local QuestService = require(script.Parent.QuestService)
local RewardService = require(script.Parent.RewardService)
local ShopService = require(script.Parent.ShopService)
local TheftService = require(script.Parent.TheftService)

type Profile = Schema.Profile
type Payload = { [string]: any }
type Handler = (Player, Profile, Payload) -> (boolean, string)

local ActionService = {}

-- Generous enough that a player mashing buttons never notices, tight enough that
-- a script cannot use the remote as a free loop. Raids need a higher ceiling
-- because holding a door sends a start and a stop each time the key repeats.
local RATE_WINDOW = 1
local RATE_LIMIT = 30

local requestCounts: { [Player]: { count: number, windowStart: number } } = {}

local function withinRateLimit(player: Player): boolean
	local now = os.clock()
	local record = requestCounts[player]
	if not record or (now - record.windowStart) > RATE_WINDOW then
		requestCounts[player] = { count = 1, windowStart = now }
		return true
	end
	record.count += 1
	return record.count <= RATE_LIMIT
end

local function str(payload: Payload, key: string): string?
	local value = payload[key]
	if type(value) == "string" and #value > 0 and #value <= 64 then
		return value
	end
	return nil
end

local handlers: { [string]: Handler } = {
	-- ---------------------------------------------------------- the motel
	checkIn = function(player, profile, payload)
		return GuestService.checkIn(player, profile, payload.slot)
	end,

	houseGuest = function(player, profile, payload)
		local uid = str(payload, "uid")
		if not uid then
			return false, "Pick a guest."
		end
		return GuestService.house(player, profile, uid)
	end,

	storeGuest = function(player, profile, payload)
		local uid = str(payload, "uid")
		if not uid then
			return false, "Pick a guest."
		end
		return GuestService.store(player, profile, uid)
	end,

	houseBest = function(player, profile)
		return GuestService.houseBest(player, profile)
	end,

	optimise = function(player, profile)
		return GuestService.optimise(player, profile)
	end,

	releaseBelow = function(player, profile, payload)
		local rarity = str(payload, "rarity")
		if not rarity then
			return false, "Pick a rarity."
		end
		return GuestService.releaseBelow(player, profile, rarity)
	end,

	-- ---------------------------------------------------------- upgrades
	buyRoom = function(player, profile)
		return ShopService.buyRoom(player, profile)
	end,

	buyRating = function(player, profile)
		return ShopService.buyRating(player, profile)
	end,

	buyLock = function(player, profile)
		return ShopService.buyLock(player, profile)
	end,

	buySafe = function(player, profile)
		return ShopService.buySafe(player, profile)
	end,

	-- ---------------------------------------------------------- raiding
	startBreak = function(player, _profile, payload)
		return TheftService.startBreak(player, payload.plot)
	end,

	stopBreak = function(player)
		return TheftService.stopBreak(player)
	end,

	grabGuest = function(player, _profile, payload)
		return TheftService.grab(player, payload.plot, payload.uid)
	end,

	claimCelebrity = function(player)
		return EventService.claim(player)
	end,

	-- ---------------------------------------------------------- prestige
	renovate = function(player, profile)
		return PrestigeService.renovate(player, profile)
	end,

	buyUpgrade = function(player, profile, payload)
		local id = str(payload, "id")
		if not id then
			return false, "Missing id."
		end
		return PrestigeService.buyUpgrade(player, profile, id)
	end,

	-- ---------------------------------------------------------- dailies
	claimQuest = function(player, profile, payload)
		local id = str(payload, "id")
		if not id then
			return false, "Missing quest."
		end
		return QuestService.claim(player, profile, id)
	end,

	claimDaily = function(player, profile)
		return RewardService.claimDaily(player, profile)
	end,

	claimPlaytime = function(player, profile)
		return RewardService.claimPlaytime(player, profile)
	end,

	redeemCode = function(player, profile, payload)
		return CodeService.redeem(player, profile, payload.code)
	end,

	-- ---------------------------------------------------------- store
	promptProduct = function(player, _profile, payload)
		local id = str(payload, "id")
		if not id then
			return false, "Missing id."
		end
		return MonetizationService.promptProduct(player, id)
	end,

	promptGamepass = function(player, _profile, payload)
		local id = str(payload, "id")
		if not id then
			return false, "Missing id."
		end
		return MonetizationService.promptGamepass(player, id)
	end,

	setSetting = function(player, profile, payload)
		local key = str(payload, "key")
		if key ~= "music" and key ~= "sfx" then
			return false, "Unknown setting."
		end
		profile.settings[key] = payload.value == true
		EconomyService.markDirty(player)
		return true, ""
	end,
}

local function invoke(player: Player, action: unknown, payload: unknown): Net.Response
	if type(action) ~= "string" then
		return Net.fail("Bad request.")
	end
	if not withinRateLimit(player) then
		return Net.fail("Slow down a moment.")
	end

	local handler = handlers[action]
	if not handler then
		return Net.fail("Unknown action.")
	end

	local profile = DataService.get(player)
	if not profile then
		return Net.fail("Your save is still loading.")
	end

	local body: Payload = if type(payload) == "table" then payload else {}

	local ok, result, message = pcall(handler, player, profile, body)
	if not ok then
		warn(`[ActionService] {action} failed for {player.Name}: {result}`)
		return Net.fail("Something went wrong. Try again.")
	end

	if result then
		return Net.ok(message)
	end
	return Net.fail(message or "That did not work.")
end

function ActionService.start()
	local remote = Net.folder():FindFirstChild("Invoke") :: RemoteFunction
	remote.OnServerInvoke = function(player, action, payload)
		return invoke(player, action, payload)
	end

	Players.PlayerRemoving:Connect(function(player)
		requestCounts[player] = nil
	end)
end

return ActionService
