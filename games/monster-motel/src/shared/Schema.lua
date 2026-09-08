--!strict
--[[
	Schema
	The shape of a saved profile, plus migrations.

	Adding a field means adding it to Template; DataService reconciles it into old
	saves on load. Changing the meaning of an existing field means bumping Version
	and writing a migration.
]]

local Guests = require(script.Parent.Config.Guests)
local GameConfig = require(script.Parent.Config.GameConfig)

local Schema = {}

Schema.Version = 1

--[[ A guest the player owns. `room` is the room number it is housed in, or 0 for
     storage (owned, not earning). `uid` lets a player own several of the same
     guest and lets theft point at one specific animal. ]]
export type OwnedGuest = {
	uid: string,
	guest: string,
	room: number,
}

export type QuestState = {
	id: string,
	progress: number,
	claimed: boolean,
}

--[[ One slot on the arrivals road. Persisted so the road a player is looking at
     survives a rejoin instead of rerolling, which would make it a slot machine. ]]
export type ArrivalSlot = {
	guest: string,
	price: number,
	takenAt: number,
}

export type Profile = {
	version: number,

	cash: number,
	stars: number,
	-- Rent sitting in the safe, waiting to be collected at the front desk.
	safe: number,

	rating: number,
	rooms: number,
	lockLevel: number,
	safeLevel: number,

	guests: { OwnedGuest },
	nextGuestUid: number,

	arrivals: { ArrivalSlot },
	nextArrivalAt: number,

	-- Levelled upgrades bought with Cash (Config/Upgrades.lua).
	upgrades: { [string]: number },
	-- Levelled upgrades bought with Stars (Config/Prestige.lua). Kept separate
	-- because they survive a renovation and the Cash ones do not.
	starShop: { [string]: number },
	-- The objective the player is currently working on, 1-based.
	objective: number,
	-- Cash earned since the last renovation, which is what Stars are paid on.
	earnedThisRun: number,
	renovations: number,

	quests: { day: number, list: { QuestState } },
	daily: { lastClaimAt: number, streak: number },
	playtime: { day: number, seconds: number, claimedStep: number },

	codes: { [string]: boolean },
	purchases: { string },
	boostUntil: number,
	boostMultiplier: number,

	stats: {
		checkIns: number,
		collected: number,
		guestsStolen: number,
		guestsLost: number,
		nightsSurvived: number,
		upgradesBought: number,
		celebritiesCaught: number,
		playSeconds: number,
		joins: number,
	},

	settings: { music: boolean, sfx: boolean },

	firstJoinAt: number,
	lastSeenAt: number,
}

Schema.Template = {
	version = Schema.Version,

	-- Seed money, and not a nicety: rent only comes from housed guests, so a
	-- profile starting at zero would have no income, no way to buy a first guest,
	-- and no way out of that. This is enough to fill a room or two immediately.
	cash = 1000,
	stars = 0,
	safe = 0,

	rating = 1,
	rooms = GameConfig.StartingRooms,
	lockLevel = 0,
	safeLevel = 1,

	guests = {},
	nextGuestUid = 1,

	arrivals = {},
	nextArrivalAt = 0,

	upgrades = { shoes = 0, service = 0, sign = 0, porter = 0 },
	starShop = { concierge = 0, wing = 0, deadbolt = 0 },
	objective = 1,
	earnedThisRun = 0,
	renovations = 0,

	quests = { day = 0, list = {} },
	daily = { lastClaimAt = 0, streak = 0 },
	playtime = { day = 0, seconds = 0, claimedStep = 0 },

	codes = {},
	purchases = {},
	boostUntil = 0,
	boostMultiplier = 1,

	stats = {
		checkIns = 0,
		collected = 0,
		guestsStolen = 0,
		guestsLost = 0,
		nightsSurvived = 0,
		upgradesBought = 0,
		celebritiesCaught = 0,
		playSeconds = 0,
		joins = 0,
	},

	settings = { music = true, sfx = true },

	firstJoinAt = 0,
	lastSeenAt = 0,
} :: Profile

Schema.Migrations = {} :: { (Profile) -> () }

function Schema.migrate(profile: Profile): Profile
	local from = profile.version or 1
	for version = from + 1, Schema.Version do
		local migration = Schema.Migrations[version]
		if migration then
			migration(profile)
		end
	end
	profile.version = Schema.Version
	return profile
end

--[[ Repairs what a migration cannot: references to guests that were renamed or
     removed, numbers that went negative, and two guests claiming one room. Keeps
     a player logged in with a valid motel rather than erroring on bad data. ]]
function Schema.sanitise(profile: Profile)
	profile.cash = math.max(0, profile.cash)
	profile.stars = math.max(0, math.floor(profile.stars))
	profile.safe = math.max(0, profile.safe)
	profile.earnedThisRun = math.max(0, profile.earnedThisRun)
	profile.renovations = math.max(0, math.floor(profile.renovations))

	profile.objective = math.max(1, math.floor(profile.objective or 1))
	profile.rating = math.max(1, math.floor(profile.rating))
	profile.rooms = math.max(GameConfig.StartingRooms, math.floor(profile.rooms))
	profile.lockLevel = math.max(0, math.floor(profile.lockLevel))
	profile.safeLevel = math.max(1, math.floor(profile.safeLevel))

	-- Drop guests whose id no longer exists, and make sure no two of them think
	-- they are in the same room.
	local kept: { OwnedGuest } = {}
	local occupied: { [number]: boolean } = {}

	for _, owned in profile.guests do
		if Guests.ById[owned.guest] then
			local room = math.floor(owned.room or 0)
			if room > 0 and (room > profile.rooms or occupied[room]) then
				-- Room is gone or already taken: move to storage rather than
				-- silently paying rent for a room that does not exist.
				room = 0
			end
			if room > 0 then
				occupied[room] = true
			end
			owned.room = room
			table.insert(kept, owned)
		end
	end
	profile.guests = kept

	-- Arrivals referring to removed guests would render as blank buttons.
	local arrivals: { ArrivalSlot } = {}
	for _, slot in profile.arrivals do
		if Guests.ById[slot.guest] then
			table.insert(arrivals, slot)
		end
	end
	profile.arrivals = arrivals
end

return Schema
