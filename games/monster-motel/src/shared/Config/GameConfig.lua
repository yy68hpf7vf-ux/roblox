--!strict
--[[
	GameConfig

	Global constants. The block that matters most is "Theft" -- every number in it
	is identical for every player in the server, and nothing sold in the store
	touches any of them. See docs/FAIRNESS.md.
]]

local GameConfig = {
	GameName = "Monster Motel",

	-- Data
	DataStoreName = "MonsterMotel_PlayerData_v1",
	AutosaveInterval = 120,
	SessionLockStaleAfter = 900,
	DataRetryAttempts = 5,

	-- Rent
	-- Rent accrues into the motel safe and is collected at the front desk. The
	-- safe has a cap so the loop has a reason to bring you back to the desk; the
	-- HUD always shows how full it is.
	RentTickInterval = 1,
	BaseSafeCapacitySeconds = 240,
	FrontDeskCooldown = 0.25,

	-- Arrivals
	-- A new guest offer appears on the arrivals road this often. Express Lane
	-- halves it. The odds of what appears are NOT affected by anything bought.
	ArrivalInterval = 12,
	ArrivalSlots = 4,

	-- Rooms
	StartingRooms = 3,
	BaseMaxRooms = 24,

	-- Night cycle. Theft is only possible during Lights Out.
	DayDuration = 300,
	NightDuration = 90,

	-- ------------------------------------------------------------------ Theft
	-- Fixed for everyone. No gamepass, product, star upgrade or level changes a
	-- single value in this block -- that is what keeps the PvP honest.
	CarryWalkSpeed = 11,
	NormalWalkSpeed = 16,
	-- How close a victim must get to a thief to make them drop the guest.
	TagRange = 7,
	-- A thief may only take one guest per victim per night.
	StealCooldownPerVictim = 1,
	-- New players cannot be robbed for this long after joining.
	NewPlayerGrace = 600,
	-- Nobody with this many guests or fewer can be robbed at all.
	MinimumGuestsToRob = 3,
	-- A dropped guest walks itself home after this long.
	DroppedGuestReturn = 20,

	-- Celebrity Arrival event
	EventInterval = 600,
	EventWarning = 60,
	EventClaimWindow = 180,

	-- Rewards
	PlaytimeRewardInterval = 300,
	PlaytimeRewardCount = 12,
	DailyStreakLength = 7,
	DailyStreakGrace = 172800,

	-- Quests
	DailyQuestCount = 3,

	-- Leaderboards
	LeaderboardRefreshInterval = 90,
	LeaderboardSize = 25,

	-- Offline earnings, granted only with the Night Owl pass.
	MaxOfflineHours = 8,

	-- Sanity ceilings on what any single action can produce.
	MaxSingleCollect = 1e15,
}

return table.freeze(GameConfig)
