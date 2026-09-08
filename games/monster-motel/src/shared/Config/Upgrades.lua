--!strict
--[[
	Motel upgrades -- bought with Cash

	Rooms, rating, locks and the safe are step upgrades with their own screens.
	These are the levelled ones: things you keep sinking money into, so that
	collecting rent still has a point once the obvious purchases are made.

	Every one of these is bought with Cash, which means every player can have all of
	them. That is a different thing from selling them for Robux, and the distinction
	is the whole design:

	  * **Running Shoes** raises your normal walk speed. It is earnable by anyone,
	    it is capped, and it never applies while you are carrying a guest -- see
	    below.
	  * Nothing here is in the Robux store, and the store cannot reach any of it.

	`GameConfig.CarryWalkSpeed` is deliberately NOT upgradable by anything, at any
	price, in any currency. The moment you pick up somebody's guest you move at the
	same speed as every other player in the server. Running Shoes get you to the
	door and get you home after a chase; they never help you outrun the person whose
	guest you are holding. That is what keeps a raid a decision rather than a
	stat check.
]]

export type Upgrade = {
	id: string,
	name: string,
	desc: string,
	maxLevel: number,
	baseCost: number,
	costGrowth: number,
	-- How much one level adds. Read as a fraction for rent, whole units otherwise.
	perLevel: number,
	-- Rendered after the number in the UI.
	unit: string,
}

local Upgrades = {}

Upgrades.List = {
	{
		id = "shoes",
		name = "Running Shoes",
		desc = "Move faster everywhere. Never while carrying a guest -- that speed is fixed for everyone.",
		maxLevel = 8,
		baseCost = 6000,
		costGrowth = 2.4,
		perLevel = 1,
		unit = "walk speed",
	},
	{
		id = "service",
		name = "Room Service",
		desc = "Every guest in every room pays more rent, permanently.",
		maxLevel = 20,
		baseCost = 9000,
		costGrowth = 1.9,
		perLevel = 0.06,
		unit = "rent",
	},
	{
		id = "sign",
		name = "Neon Sign",
		desc = "Drivers notice you sooner. New guests pull off the highway more often.",
		maxLevel = 6,
		baseCost = 25000,
		costGrowth = 3.2,
		perLevel = 1,
		unit = "second off arrivals",
	},
	{
		id = "porter",
		name = "Night Porter",
		desc = "Somebody watches the door after dark. Level 1 tells you the moment a thief starts on it; level 2 marks them so you can find them.",
		maxLevel = 2,
		baseCost = 150000,
		costGrowth = 12,
		perLevel = 1,
		unit = "watch level",
	},
} :: { Upgrade }

Upgrades.ById = {} :: { [string]: Upgrade }
for _, upgrade in Upgrades.List do
	Upgrades.ById[upgrade.id] = upgrade
end

--[[ Geometric, unlike the Star Shop. Cash is a large, fast-growing number so a
     multiplying curve reads naturally and never rounds two levels to one price. ]]
function Upgrades.costFor(upgrade: Upgrade, currentLevel: number): number
	return math.floor(upgrade.baseCost * (upgrade.costGrowth ^ currentLevel))
end

function Upgrades.level(levels: { [string]: number }, id: string): number
	return levels[id] or 0
end

--[[ Total effect of an upgrade at a level, in its own units. Callers decide what
     that means -- +N walk speed, +N% rent, -N seconds. ]]
function Upgrades.bonus(id: string, level: number): number
	local upgrade = Upgrades.ById[id]
	if not upgrade then
		return 0
	end
	return upgrade.perLevel * math.clamp(level, 0, upgrade.maxLevel)
end

function Upgrades.multiplier(id: string, level: number): number
	return 1 + Upgrades.bonus(id, level)
end

return Upgrades
