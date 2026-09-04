--!strict
--[[
	ActionService

	The one entry point the client can call. Every request arrives as a named
	action with a payload table, is rate limited, is checked for a loaded profile,
	and is dispatched to a handler that re-validates everything against the server's
	own config.

	Handlers return (ok, message). Anything that throws is caught here and reported
	as a generic failure rather than leaking a stack trace to the client.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Schema = require(Shared.Schema)

local CodeService = require(script.Parent.CodeService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)
local PadService = require(script.Parent.PadService)
local PetService = require(script.Parent.PetService)
local QuestService = require(script.Parent.QuestService)
local RebirthService = require(script.Parent.RebirthService)
local RewardService = require(script.Parent.RewardService)
local ShopService = require(script.Parent.ShopService)

type Profile = Schema.Profile
type Payload = { [string]: any }
type Handler = (Player, Profile, Payload) -> (boolean, string)

local ActionService = {}

-- Generous enough that a player mashing buttons never notices, tight enough that
-- a script cannot use the remote as a free loop.
local RATE_WINDOW = 1
local RATE_LIMIT = 20

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
	buyTool = function(player, profile, payload)
		local id = str(payload, "id")
		if not id then
			return false, "Missing id."
		end
		return ShopService.buyTool(player, profile, id)
	end,

	buyBackpack = function(player, profile, payload)
		local id = str(payload, "id")
		if not id then
			return false, "Missing id."
		end
		return ShopService.buyBackpack(player, profile, id)
	end,

	unlockZone = function(player, profile, payload)
		local id = str(payload, "id")
		if not id then
			return false, "Missing id."
		end
		local ok, message = ShopService.unlockZone(player, profile, id)
		if ok then
			PadService.travel(player, id)
		end
		return ok, message
	end,

	travel = function(player, _profile, payload)
		local id = str(payload, "id")
		if not id then
			return false, "Missing id."
		end
		return PadService.travel(player, id)
	end,

	hatch = function(player, profile, payload)
		local id = str(payload, "egg")
		if not id then
			return false, "Missing egg."
		end
		return PetService.hatch(player, profile, id, tonumber(payload.count) or 1)
	end,

	equipPet = function(player, profile, payload)
		local uid = str(payload, "uid")
		if not uid then
			return false, "Missing pet."
		end
		return PetService.equip(player, profile, uid)
	end,

	unequipPet = function(player, profile, payload)
		local uid = str(payload, "uid")
		if not uid then
			return false, "Missing pet."
		end
		return PetService.unequip(player, profile, uid)
	end,

	deletePet = function(player, profile, payload)
		local uid = str(payload, "uid")
		if not uid then
			return false, "Missing pet."
		end
		return PetService.deleteOne(player, profile, uid)
	end,

	deletePetsBelow = function(player, profile, payload)
		local rarity = str(payload, "rarity")
		if not rarity then
			return false, "Missing rarity."
		end
		return PetService.deleteBelow(player, profile, rarity)
	end,

	autoEquipPets = function(player, profile)
		PetService.autoEquipBest(player, profile)
		EconomyService.markDirty(player)
		return true, "Equipped your best pets."
	end,

	rebirth = function(player, profile)
		return RebirthService.rebirth(player, profile)
	end,

	buyUpgrade = function(player, profile, payload)
		local id = str(payload, "id")
		if not id then
			return false, "Missing id."
		end
		return RebirthService.buyUpgrade(player, profile, id)
	end,

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
