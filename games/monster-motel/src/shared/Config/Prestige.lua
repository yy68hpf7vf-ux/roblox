--!strict
--[[
	Renovation and the Star Shop

	Renovating knocks the motel back to three rooms and a one-star rating. You keep
	every guest you own -- they just move into storage until you have rooms again --
	and you keep every Star you have ever earned.

	Stars cannot be bought. Not as a gamepass, not as a product, not indirectly.
	Every Star in the game came from someone renovating a motel they had spent
	hours building, which is the whole reason the number means anything.
]]

local Prestige = {}

--[[ A renovation is only offered once a player has actually seen the game. Four
     stars lands a little over an hour in, which is late enough that the reset
     costs something real and early enough that a first session can reach it --
     a prestige loop nobody sees on day one may as well not exist. ]]
Prestige.MinimumRating = 4

--[[ stars = floor(sqrt(earnedThisRun / Divisor)).

     A square root rather than a straight division, so the first renovation is
     quick and the tenth is a project. Doubling your run earnings does not double
     your Stars, which stops the last hour before a renovation from being the only
     hour that matters.

     The divisor was picked by sweeping it against tools/balance.py rather than by
     feel: it puts the first renovation around two hours for a player with no
     quests, dailies or passes, which lands near ninety minutes for one who has
     them. ]]
Prestige.StarDivisor = 60000000

function Prestige.starsFor(earnedThisRun: number): number
	if earnedThisRun <= 0 then
		return 0
	end
	return math.floor(math.sqrt(earnedThisRun / Prestige.StarDivisor))
end

--[[ What the next Star costs, in run earnings. The UI shows this so a player can
     see how close they are instead of guessing. ]]
function Prestige.earningsForStars(stars: number): number
	return (stars * stars) * Prestige.StarDivisor
end

-- ---------------------------------------------------------------- star shop

export type Upgrade = {
	id: string,
	name: string,
	desc: string,
	maxLevel: number,
	baseCost: number,
	costStep: number,
	perLevel: number,
	suffix: string,
}

--[[ Costs are linear -- level L costs `baseCost + costStep * L`.

     Stars are small integers earned slowly, so a geometric curve would either
     round two consecutive levels to the same price or ask for more Stars than the
     game will ever mint. Linear keeps it legible and keeps the full shop at a
     reachable, if long, distance. The self-test asserts it stays reachable. ]]
Prestige.Upgrades = {
	{
		id = "concierge",
		name = "Concierge",
		desc = "Every guest in every room pays more, permanently.",
		maxLevel = 40,
		baseCost = 1,
		costStep = 1,
		perLevel = 0.08,
		suffix = "rent",
	},
	{
		id = "wing",
		name = "Extra Wing",
		desc = "Raises the ceiling on how many rooms your motel can hold.",
		maxLevel = 12,
		baseCost = 5,
		costStep = 5,
		perLevel = 1,
		suffix = "max room",
	},
	{
		id = "deadbolt",
		name = "Deadbolt",
		desc = "Thieves need longer on your door before it opens.",
		maxLevel = 6,
		baseCost = 8,
		costStep = 8,
		perLevel = 1.5,
		suffix = "second on your lock",
	},
} :: { Upgrade }

Prestige.UpgradeById = {} :: { [string]: Upgrade }
for _, upgrade in Prestige.Upgrades do
	Prestige.UpgradeById[upgrade.id] = upgrade
end

function Prestige.upgradeCost(upgrade: Upgrade, currentLevel: number): number
	return upgrade.baseCost + upgrade.costStep * currentLevel
end

function Prestige.upgradeTotalCost(upgrade: Upgrade): number
	local levels = upgrade.maxLevel
	return levels * upgrade.baseCost + upgrade.costStep * (levels * (levels - 1) / 2)
end

--[[ Multiplier form, for upgrades that scale a number (Concierge). Additive
     upgrades (Extra Wing, Deadbolt) read `perLevel * level` directly. ]]
function Prestige.upgradeMultiplier(id: string, level: number): number
	local upgrade = Prestige.UpgradeById[id]
	if not upgrade then
		return 1
	end
	return 1 + upgrade.perLevel * level
end

function Prestige.upgradeBonus(id: string, level: number): number
	local upgrade = Prestige.UpgradeById[id]
	if not upgrade then
		return 0
	end
	return upgrade.perLevel * level
end

return Prestige
