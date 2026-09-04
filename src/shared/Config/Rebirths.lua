--!strict
--[[
	Rebirths and the Core Shop

	Rebirthing wipes Crystals, ore, picks, backpacks and zone unlocks, and returns
	a permanent earnings multiplier plus Cores. Pets, Cores and Core Shop upgrades
	survive, so a rebirth is always a step forward even though the map resets.

	Cores cannot be bought. Every Core in the game came from a rebirth, which
	keeps the prestige track -- the part long-term players actually care about --
	entirely on the gameplay side of the line.
]]

local Rebirths = {}

-- cost(n) = BASE * GROWTH^n, where n is the number of rebirths already done.
-- The first rebirth lands around Stormvault, a little under an hour in, so a new
-- player sees five zones before they are asked to give any of them up. The second
-- run through the map takes roughly half as long, the third a third as long.
Rebirths.BaseCost = 3000000
Rebirths.CostGrowth = 5

-- Each rebirth adds this to the earnings multiplier (rebirth 4 => x5). Pets and
-- Cores are kept through a rebirth, so the second run through the map is much
-- faster than the first -- that gap is what makes the reset worth taking.
Rebirths.MultiplierPerRebirth = 1

function Rebirths.costFor(current: number): number
	return math.floor(Rebirths.BaseCost * (Rebirths.CostGrowth ^ current))
end

function Rebirths.multiplierFor(current: number): number
	return 1 + Rebirths.MultiplierPerRebirth * current
end

--[[ Cores granted for the rebirth that takes a player from `current` to
     `current + 1`. Later rebirths pay more, so the Core Shop keeps opening up. ]]
function Rebirths.coresFor(current: number): number
	return current + 1
end

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

--[[ Core Shop costs are linear -- level L costs `baseCost + costStep * L`.

     Geometric costs are the usual choice and they are wrong here. Cores are small
     integers: a rebirth mints `rebirths + 1` of them, so the entire game produces
     55 Cores across ten rebirths and about 465 across thirty. A 1.28x curve over
     fifty levels would ask for millions, and rounding a slow curve to whole Cores
     also makes consecutive levels cost the same, which looks like a bug to a
     player counting their Cores.

     Linear keeps it legible ("level 7 costs 7 Cores"), guarantees every level
     costs more than the last, and puts the full Core Shop at roughly forty
     rebirths -- a long tail for people who want one, with the first few levels
     cheap enough to reach in an evening. ]]
Rebirths.Upgrades = {
	{
		id = "refinery",
		name = "Refinery",
		desc = "Every ore sells for more, in every zone, permanently.",
		maxLevel = 30,
		baseCost = 1,
		costStep = 1,
		perLevel = 0.1,
		suffix = "crystal value",
	},
	{
		id = "yield",
		name = "Deep Yield",
		desc = "Nodes give more ore for the same swing.",
		maxLevel = 20,
		baseCost = 2,
		costStep = 2,
		perLevel = 0.05,
		suffix = "ore yield",
	},
	{
		id = "kennel",
		name = "Kennel",
		desc = "One more pet follows you around and pulls its weight.",
		maxLevel = 2,
		baseCost = 15,
		costStep = 25,
		perLevel = 1,
		suffix = "pet slot",
	},
} :: { Upgrade }

Rebirths.UpgradeById = {} :: { [string]: Upgrade }
for _, upgrade in Rebirths.Upgrades do
	Rebirths.UpgradeById[upgrade.id] = upgrade
end

function Rebirths.upgradeCost(upgrade: Upgrade, currentLevel: number): number
	return upgrade.baseCost + upgrade.costStep * currentLevel
end

--[[ Total Cores to take an upgrade from nothing to its cap. Used by the docs and
     by anyone sanity-checking the Core budget against `coresFor`. ]]
function Rebirths.upgradeTotalCost(upgrade: Upgrade): number
	local levels = upgrade.maxLevel
	return levels * upgrade.baseCost + upgrade.costStep * (levels * (levels - 1) / 2)
end

--[[ Multiplier contributed by a levelled upgrade, e.g. Refinery 12 => 2.2x. ]]
function Rebirths.upgradeMultiplier(id: string, level: number): number
	local upgrade = Rebirths.UpgradeById[id]
	if not upgrade then
		return 1
	end
	return 1 + upgrade.perLevel * level
end

return Rebirths
