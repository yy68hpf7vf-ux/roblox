--!strict
--[[
	Schema
	The shape of a saved profile, plus migrations.

	Adding a field means adding it to Template; DataService reconciles it into old
	saves on load. Changing the *meaning* of an existing field means bumping
	Version and writing a migration, because reconcile cannot know that "zone"
	used to hold a number.
]]

local Tools = require(script.Parent.Config.Tools)
local Backpacks = require(script.Parent.Config.Backpacks)
local Zones = require(script.Parent.Config.Zones)

local Schema = {}

Schema.Version = 1

export type OwnedPet = {
	uid: string,
	pet: string,
}

export type QuestState = {
	id: string,
	progress: number,
	claimed: boolean,
}

export type Profile = {
	version: number,

	crystals: number,
	cores: number,
	ore: number,

	tool: string,
	backpack: string,
	zone: string,

	ownedTools: { [string]: boolean },
	ownedBackpacks: { [string]: boolean },
	unlockedZones: { [string]: boolean },

	pets: { OwnedPet },
	equipped: { string },
	nextPetUid: number,

	rebirths: number,
	upgrades: { [string]: number },

	quests: { day: number, list: { QuestState } },
	daily: { lastClaimAt: number, streak: number },
	playtime: { day: number, seconds: number, claimedStep: number },

	codes: { [string]: boolean },
	-- Recent Roblox PurchaseIds, newest last. ProcessReceipt can be called more
	-- than once for the same purchase, so a receipt is only granted if its id is
	-- not already in here.
	purchases: { string },
	boostUntil: number,
	boostMultiplier: number,

	stats: {
		oreMined: number,
		nodesBroken: number,
		sells: number,
		hatches: number,
		crystalsEarned: number,
		playSeconds: number,
		joins: number,
	},

	settings: { music: boolean, sfx: boolean },

	firstJoinAt: number,
	lastSeenAt: number,
}

Schema.Template = {
	version = Schema.Version,

	crystals = 0,
	cores = 0,
	ore = 0,

	tool = Tools.Starter,
	backpack = Backpacks.Starter,
	zone = Zones.Starter,

	ownedTools = { [Tools.Starter] = true },
	ownedBackpacks = { [Backpacks.Starter] = true },
	unlockedZones = { [Zones.Starter] = true },

	pets = {},
	equipped = {},
	nextPetUid = 1,

	rebirths = 0,
	upgrades = { refinery = 0, yield = 0, kennel = 0 },

	quests = { day = 0, list = {} },
	daily = { lastClaimAt = 0, streak = 0 },
	playtime = { day = 0, seconds = 0, claimedStep = 0 },

	codes = {},
	purchases = {},
	boostUntil = 0,
	boostMultiplier = 1,

	stats = {
		oreMined = 0,
		nodesBroken = 0,
		sells = 0,
		hatches = 0,
		crystalsEarned = 0,
		playSeconds = 0,
		joins = 0,
	},

	settings = { music = true, sfx = true },

	firstJoinAt = 0,
	lastSeenAt = 0,
} :: Profile

--[[ Ordered list of migrations. Each entry upgrades a profile from index-1 to
     index. Version 1 is the first schema, so there is nothing to run yet -- the
     table exists so the next change has an obvious place to go. ]]
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

--[[ Repairs anything a migration cannot: references to config entries that were
     renamed or removed since the save was written. Keeps a player logged in with
     a valid loadout instead of erroring on a missing id. ]]
function Schema.sanitise(profile: Profile)
	if not Tools.ById[profile.tool] or not profile.ownedTools[profile.tool] then
		profile.tool = Tools.Starter
	end
	if not Backpacks.ById[profile.backpack] or not profile.ownedBackpacks[profile.backpack] then
		profile.backpack = Backpacks.Starter
	end
	if not Zones.ById[profile.zone] then
		profile.zone = Zones.Starter
	end

	profile.ownedTools[Tools.Starter] = true
	profile.ownedBackpacks[Backpacks.Starter] = true
	profile.unlockedZones[Zones.Starter] = true

	profile.crystals = math.max(0, profile.crystals)
	profile.cores = math.max(0, profile.cores)
	profile.ore = math.max(0, profile.ore)
	profile.rebirths = math.max(0, math.floor(profile.rebirths))
end

return Schema
