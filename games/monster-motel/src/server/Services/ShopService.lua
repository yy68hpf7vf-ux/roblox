--!strict
--[[
	ShopService
	The four things Cash buys: rooms, rating, locks and a bigger safe.

	Every purchase re-checks price, level and cap against the config on the server.
	The client's copy of the shop is for drawing buttons and nothing else.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Ratings = require(Shared.Config.Ratings)
local Rooms = require(Shared.Config.Rooms)
local Schema = require(Shared.Schema)

local EconomyService = require(script.Parent.EconomyService)
local QuestService = require(script.Parent.QuestService)

type Profile = Schema.Profile

local ShopService = {}

local function bought(player: Player, profile: Profile)
	profile.stats.upgradesBought += 1
	QuestService.addProgress(player, profile, "upgrades", 1)
	EconomyService.markDirty(player)
end

function ShopService.buyRoom(player: Player, profile: Profile): (boolean, string)
	local maxRooms = EconomyService.maxRooms(player, profile)
	if profile.rooms >= maxRooms then
		return false,
			`Your motel holds {maxRooms} rooms. Extra Wing in the Star Shop raises the ceiling.`
	end

	local cost = Rooms.costFor(profile.rooms + 1)
	if not EconomyService.spendCash(player, profile, cost) then
		return false, `Room {profile.rooms + 1} costs ${Format.short(cost)}. You have ${Format.short(profile.cash)}.`
	end

	profile.rooms += 1
	bought(player, profile)
	return true, `Room {profile.rooms} opened.`
end

function ShopService.buyRating(player: Player, profile: Profile): (boolean, string)
	local next = Ratings.next(profile.rating)
	if not next then
		return false, "You are already The Last Motel. There is nothing above it."
	end

	if not EconomyService.spendCash(player, profile, next.cost) then
		return false, `{next.name} costs ${Format.short(next.cost)}. You have ${Format.short(profile.cash)}.`
	end

	profile.rating = next.level
	bought(player, profile)
	return true, `{next.name}. Better guests start pulling off the highway.`
end

function ShopService.buyLock(player: Player, profile: Profile): (boolean, string)
	if profile.lockLevel >= Rooms.MaxLockLevel then
		return false, "That is the strongest lock there is. Deadbolt in the Star Shop adds more time."
	end

	local next = Rooms.lock(profile.lockLevel + 1)
	if not EconomyService.spendCash(player, profile, next.cost) then
		return false, `A {next.name} costs ${Format.short(next.cost)}. You have ${Format.short(profile.cash)}.`
	end

	profile.lockLevel += 1
	bought(player, profile)
	return true, `{next.name} fitted. Thieves now need {EconomyService.breakSeconds(profile)}s on your door.`
end

function ShopService.buySafe(player: Player, profile: Profile): (boolean, string)
	if profile.safeLevel >= Rooms.MaxSafeLevel then
		return false, "Your safe is as big as it gets."
	end

	local next = Rooms.safe(profile.safeLevel + 1)
	if not EconomyService.spendCash(player, profile, next.cost) then
		return false, `The next safe costs ${Format.short(next.cost)}. You have ${Format.short(profile.cash)}.`
	end

	profile.safeLevel += 1
	bought(player, profile)
	return true, `Safe upgraded. It now holds {Format.duration(next.seconds)} of rent.`
end

--[[ Everything the Motel window renders, resolved server-side so a client cannot
     invent a cheaper price. ]]
function ShopService.view(player: Player, profile: Profile): { [string]: any }
	local maxRooms = EconomyService.maxRooms(player, profile)
	local nextRating = Ratings.next(profile.rating)
	local nextLock = if profile.lockLevel < Rooms.MaxLockLevel then Rooms.lock(profile.lockLevel + 1) else nil
	local nextSafe = if profile.safeLevel < Rooms.MaxSafeLevel then Rooms.safe(profile.safeLevel + 1) else nil

	return {
		rooms = profile.rooms,
		maxRooms = maxRooms,
		roomCost = if profile.rooms < maxRooms then Rooms.costFor(profile.rooms + 1) else 0,

		rating = profile.rating,
		ratingName = Ratings.get(profile.rating).name,
		ratingDesc = Ratings.get(profile.rating).desc,
		nextRatingName = if nextRating then nextRating.name else nil,
		nextRatingDesc = if nextRating then nextRating.desc else nil,
		ratingCost = if nextRating then nextRating.cost else 0,

		lockLevel = profile.lockLevel,
		lockName = Rooms.lock(profile.lockLevel).name,
		breakSeconds = EconomyService.breakSeconds(profile),
		nextLockName = if nextLock then nextLock.name else nil,
		lockCost = if nextLock then nextLock.cost else 0,

		safeLevel = profile.safeLevel,
		safeSeconds = Rooms.safe(profile.safeLevel).seconds,
		nextSafeSeconds = if nextSafe then nextSafe.seconds else nil,
		safeCost = if nextSafe then nextSafe.cost else 0,
	}
end

return ShopService
