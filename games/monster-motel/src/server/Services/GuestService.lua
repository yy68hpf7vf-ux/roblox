--!strict
--[[
	GuestService

	Owning, housing and storing guests. Every path that adds or removes a guest --
	checking one in, stealing one, losing one, catching a celebrity -- goes through
	here, so there is exactly one place that can get the room bookkeeping wrong.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Guests = require(Shared.Config.Guests)
local Schema = require(Shared.Schema)

local ArrivalService = require(script.Parent.ArrivalService)
local EconomyService = require(script.Parent.EconomyService)
local FeedService = require(script.Parent.FeedService)
local QuestService = require(script.Parent.QuestService)
local Remote = require(script.Parent.Remote)

type Profile = Schema.Profile

local GuestService = {}

GuestService.MaxOwned = 200

local function nextUid(profile: Profile): string
	local uid = tostring(profile.nextGuestUid)
	profile.nextGuestUid += 1
	return uid
end

function GuestService.find(profile: Profile, uid: string): (Schema.OwnedGuest?, number?)
	for index, owned in profile.guests do
		if owned.uid == uid then
			return owned, index
		end
	end
	return nil, nil
end

--[[ Adds a guest the player did not have. Houses it if there is a free room,
     otherwise it lands in storage and the caller says so. ]]
function GuestService.give(player: Player, profile: Profile, guestId: string): (Schema.OwnedGuest?, boolean)
	if not Guests.ById[guestId] then
		return nil, false
	end
	if #profile.guests >= GuestService.MaxOwned then
		return nil, false
	end

	local room = EconomyService.freeRoom(player, profile) or 0
	local owned: Schema.OwnedGuest = {
		uid = nextUid(profile),
		guest = guestId,
		room = room,
	}
	table.insert(profile.guests, owned)

	-- Every route in goes through here -- checked in, stolen, a celebrity walked
	-- home, a Signature restored -- so this is the one place the index needs to
	-- learn about. Discovery is permanent; losing the guest later does not undo it.
	if not profile.discovered[guestId] then
		profile.discovered[guestId] = true
		Remote.effect(player, "discovered", { guest = guestId })
		FeedService.discovery(player, guestId)
	end

	EconomyService.markDirty(player)
	return owned, room > 0
end

function GuestService.remove(player: Player, profile: Profile, uid: string): Schema.OwnedGuest?
	local owned, index = GuestService.find(profile, uid)
	if not owned or not index then
		return nil
	end
	table.remove(profile.guests, index)
	EconomyService.markDirty(player)
	return owned
end

-- ---------------------------------------------------------------- check-in

function GuestService.checkIn(player: Player, profile: Profile, slotIndex: unknown): (boolean, string)
	local index = tonumber(slotIndex)
	if not index then
		return false, "Pick a guest first."
	end

	local slot = profile.arrivals[index]
	if not slot then
		return false, "That one already checked in somewhere else."
	end

	local guest = Guests.get(slot.guest)
	if not guest then
		return false, "That guest is no longer available."
	end

	if EconomyService.freeRoom(player, profile) == nil then
		return false, "No vacancies. Buy another room first."
	end

	if not EconomyService.spendCash(player, profile, slot.price) then
		return false, `You need ${Format.short(slot.price - profile.cash)} more.`
	end

	ArrivalService.take(profile, index)

	local owned = GuestService.give(player, profile, guest.id)
	if not owned then
		-- Refund rather than take the money and hand over nothing.
		EconomyService.addCash(player, profile, slot.price)
		return false, "Your motel is full."
	end

	profile.stats.checkIns += 1
	QuestService.addProgress(player, profile, "check_in", 1)

	Remote.effect(player, "checkedIn", { uid = owned.uid, guest = guest.id, room = owned.room })
	return true, `{guest.name} checked in. +${Format.short(guest.rent)}/s`
end

-- ---------------------------------------------------------------- housing

function GuestService.house(player: Player, profile: Profile, uid: string): (boolean, string)
	local owned = GuestService.find(profile, uid)
	if not owned then
		return false, "You do not own that guest."
	end
	if owned.room > 0 then
		return true, "Already in a room."
	end

	local room = EconomyService.freeRoom(player, profile)
	if not room then
		return false, "No vacancies. Buy another room first."
	end

	owned.room = room
	EconomyService.markDirty(player)

	local guest = Guests.get(owned.guest)
	return true, `{if guest then guest.name else "Guest"} moved into room {room}.`
end

function GuestService.store(player: Player, profile: Profile, uid: string): (boolean, string)
	local owned = GuestService.find(profile, uid)
	if not owned then
		return false, "You do not own that guest."
	end
	if owned.room == 0 then
		return true, "Already in storage."
	end

	owned.room = 0
	EconomyService.markDirty(player)

	local guest = Guests.get(owned.guest)
	return true, `{if guest then guest.name else "Guest"} moved to storage. They stop paying rent.`
end

--[[ Fills every free room with the best guests currently in storage. This is the
     button players actually press after a renovation, and doing it one at a time
     through the UI would be forty clicks. ]]
function GuestService.houseBest(player: Player, profile: Profile): (boolean, string)
	local stored: { Schema.OwnedGuest } = {}
	for _, owned in profile.guests do
		if owned.room == 0 then
			table.insert(stored, owned)
		end
	end

	if #stored == 0 then
		return false, "Nothing in storage."
	end

	table.sort(stored, function(a, b)
		local guestA, guestB = Guests.get(a.guest), Guests.get(b.guest)
		local rentA = if guestA then guestA.rent else 0
		local rentB = if guestB then guestB.rent else 0
		if rentA == rentB then
			return a.uid < b.uid
		end
		return rentA > rentB
	end)

	local moved = 0
	for _, owned in stored do
		local room = EconomyService.freeRoom(player, profile)
		if not room then
			break
		end
		owned.room = room
		moved += 1
	end

	if moved == 0 then
		return false, "No vacancies. Buy another room first."
	end

	EconomyService.markDirty(player)
	return true, `Checked in {moved} guest{if moved == 1 then "" else "s"} from storage.`
end

--[[ Swaps the weakest housed guest for the strongest stored one, repeatedly,
     until storage holds nothing better than the motel does. ]]
function GuestService.optimise(player: Player, profile: Profile): (boolean, string)
	local function rentOf(owned: Schema.OwnedGuest): number
		local guest = Guests.get(owned.guest)
		return if guest then guest.rent else 0
	end

	local swaps = 0
	local guard = 0

	while guard < GuestService.MaxOwned do
		guard += 1

		local worstHoused: Schema.OwnedGuest? = nil
		local bestStored: Schema.OwnedGuest? = nil

		for _, owned in profile.guests do
			if owned.room > 0 then
				if not worstHoused or rentOf(owned) < rentOf(worstHoused) then
					worstHoused = owned
				end
			else
				if not bestStored or rentOf(owned) > rentOf(bestStored) then
					bestStored = owned
				end
			end
		end

		if not worstHoused or not bestStored or rentOf(bestStored) <= rentOf(worstHoused) then
			break
		end

		bestStored.room = worstHoused.room
		worstHoused.room = 0
		swaps += 1
	end

	-- Fill any rooms still empty after the swaps.
	local housed, _ = GuestService.houseBest(player, profile)

	if swaps == 0 and not housed then
		return false, "Your best guests are already in the rooms."
	end

	EconomyService.markDirty(player)
	return true, `Rearranged the motel. {swaps} swap{if swaps == 1 then "" else "s"}.`
end

--[[ Releases every stored guest below a rarity, so a long-running motel does not
     drown in Grublings. Housed guests are never touched. ]]
function GuestService.releaseBelow(player: Player, profile: Profile, rarity: string): (boolean, string)
	local threshold = table.find(Guests.RarityOrder, rarity)
	if not threshold then
		return false, "Unknown rarity."
	end

	local kept: { Schema.OwnedGuest } = {}
	local released = 0

	for _, owned in profile.guests do
		local guest = Guests.get(owned.guest)
		local rank = if guest then Guests.rarityRank(guest.rarity) else nil
		if owned.room == 0 and rank and rank < threshold then
			released += 1
		else
			table.insert(kept, owned)
		end
	end

	if released == 0 then
		return false, "Nothing in storage matched."
	end

	profile.guests = kept
	EconomyService.markDirty(player)
	return true, `Released {released} guest{if released == 1 then "" else "s"} from storage.`
end

return GuestService
