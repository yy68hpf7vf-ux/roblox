--!strict
--[[
	ArrivalService

	The arrivals road: a short queue of monsters currently willing to check in,
	each with a price.

	Two deliberate choices:

	  * Slots persist in the save. Rejoining does not reroll the road, so nobody
	    can quit out and back in until a Mythic appears. A roll you cannot repeat
	    on demand is a decision; one you can is a slot machine.
	  * The roll reads only the player's Motel Rating. There is no luck stat, no
	    per-account weighting and no pass that shifts the odds. Express Lane makes
	    slots fill faster, at exactly the odds the Arrivals window prints.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Guests = require(Shared.Config.Guests)
local Ratings = require(Shared.Config.Ratings)
local Schema = require(Shared.Schema)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

type Profile = Schema.Profile

local ArrivalService = {}

-- One server-owned generator. Nothing player-specific ever seeds it.
local rng = Random.new()

local TICK = 1

--[[ Picks a guest for one slot: roll a rarity against the rating's weights, then
     pick evenly within that rarity. Celebrities are excluded -- they only ever
     arrive through the town square event. ]]
local function rollGuest(profile: Profile): Guests.Guest?
	local rating = Ratings.get(profile.rating)
	local rarity = Ratings.rollRarity(rating, rng)

	local pool = Guests.ByRarity[rarity]
	if not pool or #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

function ArrivalService.refill(player: Player, profile: Profile): boolean
	if #profile.arrivals >= GameConfig.ArrivalSlots then
		return false
	end

	local guest = rollGuest(profile)
	if not guest then
		return false
	end

	table.insert(profile.arrivals, {
		guest = guest.id,
		price = Ratings.priceFor(guest),
		takenAt = os.time(),
	})
	return true
end

--[[ Called on load and every tick. Fills any empty slot whose timer has come up,
     catching up several at once if the player has been away. ]]
function ArrivalService.update(player: Player, profile: Profile): boolean
	local now = os.time()
	if now < profile.nextArrivalAt and #profile.arrivals >= GameConfig.ArrivalSlots then
		return false
	end

	local interval = EconomyService.arrivalInterval(player, profile)
	local changed = false

	if profile.nextArrivalAt == 0 then
		profile.nextArrivalAt = now
	end

	-- Catch up, but never more than a full road in one go.
	local guard = 0
	while now >= profile.nextArrivalAt and #profile.arrivals < GameConfig.ArrivalSlots and guard < 16 do
		guard += 1
		if ArrivalService.refill(player, profile) then
			changed = true
		end
		profile.nextArrivalAt += interval
	end

	-- If the road is full the timer idles at "now" rather than banking credit, so
	-- clearing a full road does not instantly refill it.
	if #profile.arrivals >= GameConfig.ArrivalSlots then
		profile.nextArrivalAt = math.max(profile.nextArrivalAt, now + interval)
	end

	return changed
end

function ArrivalService.take(profile: Profile, slotIndex: number): Schema.ArrivalSlot?
	local slot = profile.arrivals[slotIndex]
	if not slot then
		return nil
	end
	table.remove(profile.arrivals, slotIndex)
	return slot
end

--[[ Everything the Arrivals window needs, including the exact odds table for the
     player's current rating and the next one, so the value of upgrading is
     visible before it is paid for. ]]
function ArrivalService.view(player: Player, profile: Profile): { [string]: any }
	local rating = Ratings.get(profile.rating)
	local slots = {}

	for index, slot in profile.arrivals do
		local guest = Guests.get(slot.guest)
		if guest then
			table.insert(slots, {
				index = index,
				guest = slot.guest,
				name = guest.name,
				rarity = guest.rarity,
				rent = guest.rent,
				price = slot.price,
				quip = guest.quip,
			})
		end
	end

	return {
		slots = slots,
		maxSlots = GameConfig.ArrivalSlots,
		interval = EconomyService.arrivalInterval(player, profile),
		nextAt = profile.nextArrivalAt,
		odds = Ratings.odds(rating),
		nextOdds = if Ratings.next(profile.rating) then Ratings.odds(Ratings.next(profile.rating) :: any) else nil,
	}
end

function ArrivalService.start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile and ArrivalService.update(player, profile) then
					EconomyService.markDirty(player)
				end
			end
		end
	end)

	DataService.Loaded:Connect(function(player, profile)
		ArrivalService.update(player, profile)
	end)
end

return ArrivalService
