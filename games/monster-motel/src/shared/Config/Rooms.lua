--!strict
--[[
	Rooms, the safe, and door locks.

	Rooms are the scarce resource: a guest only pays rent while it is in one. That
	scarcity is what makes theft hurt and what makes a Mythic worth chasing.

	Locks are bought with Cash and upgraded with Stars. They are never sold for
	Robux and their break time is the same number for the thief regardless of who
	either player is -- see docs/FAIRNESS.md.
]]

local GameConfig = require(script.Parent.GameConfig)

local Rooms = {}

-- roomCost(n) is the price of the nth room. Rooms 1..StartingRooms are free.
Rooms.BaseCost = 4000
Rooms.CostGrowth = 2.3

function Rooms.costFor(nextRoomNumber: number): number
	local paid = nextRoomNumber - GameConfig.StartingRooms
	if paid <= 0 then
		return 0
	end
	return math.floor(Rooms.BaseCost * (Rooms.CostGrowth ^ (paid - 1)))
end

-- ---------------------------------------------------------------- the safe

--[[ Rent piles up in the safe and stops at the cap until it is collected at the
     front desk. The cap is expressed in seconds of your own rent, so it scales
     with you instead of becoming meaningless. Upgrading buys more seconds. ]]
export type SafeLevel = {
	level: number,
	seconds: number,
	cost: number,
}

Rooms.SafeLevels = {
	{ level = 1, seconds = 240, cost = 0 },
	{ level = 2, seconds = 420, cost = 12000 },
	{ level = 3, seconds = 720, cost = 180000 },
	{ level = 4, seconds = 1200, cost = 3000000 },
	{ level = 5, seconds = 1800, cost = 50000000 },
	{ level = 6, seconds = 2700, cost = 800000000 },
	{ level = 7, seconds = 3600, cost = 14000000000 },
} :: { SafeLevel }

Rooms.MaxSafeLevel = #Rooms.SafeLevels

function Rooms.safe(level: number): SafeLevel
	return Rooms.SafeLevels[math.clamp(math.floor(level), 1, Rooms.MaxSafeLevel)]
end

-- ---------------------------------------------------------------- locks

export type Lock = {
	level: number,
	name: string,
	-- Seconds a thief must hold the door to get in.
	breakSeconds: number,
	cost: number,
}

Rooms.Locks = {
	{ level = 0, name = "No Lock", breakSeconds = 2, cost = 0 },
	{ level = 1, name = "Chain", breakSeconds = 4, cost = 8000 },
	{ level = 2, name = "Deadlatch", breakSeconds = 6, cost = 120000 },
	{ level = 3, name = "Steel Bolt", breakSeconds = 8, cost = 2000000 },
	{ level = 4, name = "Bar Brace", breakSeconds = 10, cost = 30000000 },
	{ level = 5, name = "Vault Door", breakSeconds = 13, cost = 450000000 },
	{ level = 6, name = "The Night Gate", breakSeconds = 16, cost = 7000000000 },
} :: { Lock }

Rooms.MaxLockLevel = #Rooms.Locks - 1

--[[ Total break time is capped so a maxed door is still a door. A night is 90
     seconds; a thief who commits their whole night to one lock should get in. ]]
Rooms.MaxBreakSeconds = 30

function Rooms.lock(level: number): Lock
	return Rooms.Locks[math.clamp(math.floor(level), 0, Rooms.MaxLockLevel) + 1]
end

--[[ Break time including the Deadbolt star upgrade, clamped to the cap. The
     thief's own progress, passes and purchases are not inputs here -- only the
     defender's investment. ]]
function Rooms.breakSecondsFor(lockLevel: number, deadboltLevel: number, deadboltPerLevel: number): number
	local base = Rooms.lock(lockLevel).breakSeconds
	return math.min(base + deadboltLevel * deadboltPerLevel, Rooms.MaxBreakSeconds)
end

return Rooms
