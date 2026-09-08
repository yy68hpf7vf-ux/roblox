--!strict
--[[
	EconomyService

	The one place that answers "how much is this worth". Every multiplier in the
	game is assembled in one function so the HUD, a rent tick, a quest payout and a
	cash pack can never disagree about a player's rate.

	Rent multiplier = renovations x Room Service x Concierge x gamepasses x boost.

	Note what is NOT in this file: nothing about theft. Carry speed, break times and
	grace windows live in GameConfig as constants and are never multiplied by
	anything a player owns or bought.

	`walkSpeed` is the one movement number that does move, and it moves only with
	the Cash-bought Running Shoes -- earnable by every player, capped, and never
	applied while carrying. See Config/Upgrades.lua.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Guests = require(Shared.Config.Guests)
local Monetization = require(Shared.Config.Monetization)
local Prestige = require(Shared.Config.Prestige)
local Ratings = require(Shared.Config.Ratings)
local Rooms = require(Shared.Config.Rooms)
local Schema = require(Shared.Schema)
local Upgrades = require(Shared.Config.Upgrades)
local Signal = require(Shared.Util.Signal)

local PassService = require(script.Parent.PassService)

type Profile = Schema.Profile

local EconomyService = {}

--[[ Fires whenever anything the client renders has changed. StateService listens
     and pushes; nothing else should push state on its own. ]]
EconomyService.Changed = Signal.new() :: Signal.Signal<Player>

function EconomyService.markDirty(player: Player)
	EconomyService.Changed:Fire(player)
end

-- ---------------------------------------------------------------- rooms

--[[ How many rooms this motel may ever hold: the base cap, plus Extra Wing from
     the Star Shop, plus the +5 Rooms pass. ]]
function EconomyService.maxRooms(player: Player, profile: Profile): number
	local wings = Prestige.upgradeBonus("wing", profile.starShop.wing or 0)
	return GameConfig.BaseMaxRooms + wings + PassService.sum(player, "extraRooms")
end

function EconomyService.vipLoungeSlots(player: Player): number
	if PassService.anyFlag(player, "vipLounge") then
		return Monetization.VipLoungeSlots
	end
	return 0
end

--[[ Room numbers a guest may be housed in. Rooms 1..profile.rooms are the motel
     proper; the VIP Lounge sits above them and holds guests without using one. ]]
function EconomyService.housedCapacity(player: Player, profile: Profile): number
	return profile.rooms + EconomyService.vipLoungeSlots(player)
end

function EconomyService.occupiedRooms(profile: Profile): { [number]: string }
	local occupied: { [number]: string } = {}
	for _, owned in profile.guests do
		if owned.room > 0 then
			occupied[owned.room] = owned.uid
		end
	end
	return occupied
end

--[[ Lowest free room number, or nil if the motel is full. ]]
function EconomyService.freeRoom(player: Player, profile: Profile): number?
	local occupied = EconomyService.occupiedRooms(profile)
	for room = 1, EconomyService.housedCapacity(player, profile) do
		if not occupied[room] then
			return room
		end
	end
	return nil
end

function EconomyService.housedGuestIds(profile: Profile): { string }
	local ids = {}
	for _, owned in profile.guests do
		if owned.room > 0 then
			table.insert(ids, owned.guest)
		end
	end
	return ids
end

function EconomyService.housedCount(profile: Profile): number
	local count = 0
	for _, owned in profile.guests do
		if owned.room > 0 then
			count += 1
		end
	end
	return count
end

-- ---------------------------------------------------------------- boosts

function EconomyService.boostRemaining(profile: Profile): number
	return math.max(0, profile.boostUntil - os.time())
end

function EconomyService.boostMultiplier(profile: Profile): number
	if EconomyService.boostRemaining(profile) > 0 then
		return profile.boostMultiplier
	end
	return 1
end

function EconomyService.grantBoost(profile: Profile, multiplier: number, duration: number)
	local now = os.time()
	local remaining = math.max(0, profile.boostUntil - now)
	local total = math.min(remaining + duration, Monetization.MaxBoostSeconds)
	profile.boostUntil = now + total
	profile.boostMultiplier = multiplier
end

-- ---------------------------------------------------------------- rent

--[[ Renovations are worth +25% each, on top of the Star Shop's Concierge. ]]
EconomyService.RenovationBonus = 0.25

function EconomyService.rentMultiplier(player: Player, profile: Profile): number
	return (1 + profile.renovations * EconomyService.RenovationBonus)
		* Upgrades.multiplier("service", profile.upgrades.service or 0)
		* Prestige.upgradeMultiplier("concierge", profile.starShop.concierge or 0)
		* PassService.multiplier(player, "rentMultiplier")
		* EconomyService.boostMultiplier(profile)
end

--[[ Dollars per second this motel earns right now. Only housed guests count -- a
     guest in storage owns a bed, not a room. ]]
function EconomyService.rentPerSecond(player: Player, profile: Profile): number
	local base = Guests.rentFor(EconomyService.housedGuestIds(profile))
	return base * EconomyService.rentMultiplier(player, profile)
end

--[[ The safe holds this many dollars: its level's seconds, times the motel's own
     rate. Expressed in seconds so it scales with the player rather than becoming
     meaningless by rating 4. ]]
function EconomyService.safeCapacity(player: Player, profile: Profile): number
	local seconds = Rooms.safe(profile.safeLevel).seconds
	local rate = EconomyService.rentPerSecond(player, profile)
	-- A floor so a brand new motel with one guest still has somewhere to put it.
	return math.max(1000, rate * seconds)
end

function EconomyService.autoCollects(player: Player): boolean
	return PassService.anyFlag(player, "autoCollect")
end

function EconomyService.earnsOffline(player: Player): boolean
	return PassService.anyFlag(player, "offlineEarnings")
end

--[[ Seconds between arrivals. The Neon Sign takes whole seconds off it, then
     Express Lane divides what is left. Neither touches the odds of what turns up. ]]
function EconomyService.arrivalInterval(player: Player, profile: Profile): number
	local base = GameConfig.ArrivalInterval - Upgrades.bonus("sign", profile.upgrades.sign or 0)
	local speed = math.max(1, PassService.multiplier(player, "arrivalSpeed"))
	return math.max(GameConfig.MinArrivalInterval, base / speed)
end

-- ---------------------------------------------------------------- movement

--[[ How fast this player walks normally. Running Shoes is the only input, it is
     bought with Cash, and it is capped by the upgrade's own maxLevel.

     This is deliberately NOT used while carrying a guest -- TheftService applies
     GameConfig.CarryWalkSpeed instead, which is a flat constant for everyone in
     the server. Shoes get you to a door and home again; they never help you
     outrun the person whose guest you are holding. ]]
function EconomyService.walkSpeed(profile: Profile): number
	return GameConfig.NormalWalkSpeed + Upgrades.bonus("shoes", profile.upgrades.shoes or 0)
end

--[[ Night Porter level. 0 = you find out when the door opens; 1 = you are told
     the moment somebody starts on it; 2 = they are marked so you can find them. ]]
function EconomyService.porterLevel(profile: Profile): number
	return profile.upgrades.porter or 0
end

--[[ Turns "this is worth ten minutes of your time" into cash. Every reward that
     is not a fixed shop price goes through here. ]]
function EconomyService.secondsToCash(player: Player, profile: Profile, seconds: number, floor: number?): number
	local amount = EconomyService.rentPerSecond(player, profile) * seconds
	return math.max(math.floor(amount), floor or 1)
end

-- ---------------------------------------------------------------- currency

function EconomyService.addCash(player: Player, profile: Profile, amount: number)
	if amount <= 0 then
		return
	end
	profile.cash += amount
	profile.earnedThisRun += amount
	EconomyService.markDirty(player)
end

function EconomyService.spendCash(player: Player, profile: Profile, amount: number): boolean
	if amount < 0 or profile.cash < amount then
		return false
	end
	profile.cash -= amount
	EconomyService.markDirty(player)
	return true
end

function EconomyService.addStars(player: Player, profile: Profile, amount: number)
	if amount <= 0 then
		return
	end
	profile.stars += amount
	EconomyService.markDirty(player)
end

function EconomyService.spendStars(player: Player, profile: Profile, amount: number): boolean
	if amount < 0 or profile.stars < amount then
		return false
	end
	profile.stars -= amount
	EconomyService.markDirty(player)
	return true
end

-- ---------------------------------------------------------------- defence

--[[ Seconds a thief must hold this motel's door. Reads only the defender's lock
     and Deadbolt level -- the thief's own progress and purchases are not inputs,
     which is what stops the door from being a wallet-measuring contest. ]]
function EconomyService.breakSeconds(profile: Profile): number
	local perLevel = Prestige.UpgradeById.deadbolt.perLevel
	return Rooms.breakSecondsFor(profile.lockLevel, profile.starShop.deadbolt or 0, perLevel)
end

--[[ Whether this motel can be robbed at all right now. Three protections, none of
     which are for sale: a settling-in window for new players, a floor so nobody
     can be stripped bare, and the night cycle itself (checked by TheftService). ]]
function EconomyService.robbable(profile: Profile, joinedAt: number): (boolean, string?)
	if os.time() - joinedAt < GameConfig.NewPlayerGrace then
		return false, "They only just arrived. Give them a few minutes."
	end
	if EconomyService.housedCount(profile) <= GameConfig.MinimumGuestsToRob then
		return false, "They are down to their last few guests."
	end
	return true, nil
end

function EconomyService.currentRating(profile: Profile): Ratings.Rating
	return Ratings.get(profile.rating)
end

return EconomyService
