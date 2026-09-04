--!strict
--[[
	GameConfig
	Global tuning constants. Anything that is a single number used in more than
	one place belongs here rather than being written inline at the call site.
]]

local GameConfig = {
	GameName = "Rift Miner Simulator",

	-- Data
	DataStoreName = "RiftMiner_PlayerData_v1",
	AutosaveInterval = 120,
	SessionLockStaleAfter = 900,
	DataRetryAttempts = 5,

	-- Mining
	SwingCooldown = 0.55,
	MiningRange = 22,
	-- The server allows a little slack over SwingCooldown before it treats a
	-- client's swing rate as invalid, so ordinary latency does not drop hits.
	SwingRateGrace = 0.12,
	-- Ore awarded on the swing that breaks a node, as a multiple of a normal
	-- swing. Purely for rhythm -- it is not large enough to be worth chasing
	-- with a wildly over-levelled pick.
	NodeBreakBonusSwings = 2,
	NodeRespawnTime = 3,

	-- Selling
	SellPadCooldown = 0.25,

	-- Pets
	BasePetSlots = 3,
	MaxPetsOwned = 400,
	PetFollowDistance = 6,

	-- Rewards
	PlaytimeRewardInterval = 300,
	PlaytimeRewardCount = 12,
	DailyStreakLength = 7,
	-- A streak survives this long without a login before it resets, so a player
	-- who misses one evening does not lose a week of progress.
	DailyStreakGrace = 172800,

	-- Quests
	DailyQuestCount = 3,

	-- Leaderboards
	LeaderboardRefreshInterval = 90,
	LeaderboardSize = 25,

	-- Anti-exploit sanity bounds. These are ceilings on what any single legitimate
	-- action can produce; crossing one means the request was malformed or forged.
	MaxOrePerBreak = 1e6,
	MaxSellValue = 1e15,
}

return table.freeze(GameConfig)
