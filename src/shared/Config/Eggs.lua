--!strict
--[[
	Eggs

	Eggs are the only random system in the game, and they are deliberately fenced:

	  * They cost Crystals. There is no Robux -> random pet path anywhere in this
	    game. You can buy Crystals, but the loop between money and a rare pet
	    always runs through gameplay the player controls.
	  * Odds are stored here as integer weights and rendered as exact percentages
	    on the hatch screen, next to every pet in the pool. Nothing is hidden and
	    nothing is "approximate".
	  * The odds do not change based on who is looking at them. There is no
	    per-player luck tuning, no near-miss weighting, no first-hatch boost that
	    quietly disappears.

	If you change a weight, the displayed percentage changes with it, because the
	UI reads this table rather than a second hard-coded list.
]]

local Pets = require(script.Parent.Pets)

export type EggEntry = { pet: string, weight: number }

export type Egg = {
	id: string,
	name: string,
	desc: string,
	price: number,
	zone: string,
	-- Where the hatch pad sits, relative to its zone's origin.
	position: Vector3,
	color: Color3,
	pool: { EggEntry },
}

local Eggs = {}

-- Weights are out of 1000 so a weight reads directly as a tenth of a percent.
local STANDARD = { 550, 280, 130, 35, 5 }
local WITH_MYTHIC = { 549, 280, 130, 35, 5, 1 }

local function pool(ids: { string }, weights: { number }): { EggEntry }
	local entries = {}
	for index, id in ids do
		assert(Pets.ById[id], `Eggs: unknown pet id "{id}"`)
		table.insert(entries, { pet = id, weight = weights[index] })
	end
	return entries
end

Eggs.List = {
	{
		id = "basic",
		name = "Basic Egg",
		desc = "Where everybody's first pet comes from.",
		price = 250,
		zone = "hollow",
		position = Vector3.new(44, 0, -78),
		color = Color3.fromRGB(206, 214, 220),
		pool = pool({ "pebblepup", "mossmoth", "clovercat", "hollowfox", "greenwarden" }, STANDARD),
	},
	{
		id = "amber",
		name = "Amber Egg",
		desc = "Warm to the touch. Slightly sticky.",
		price = 4000,
		zone = "amber",
		position = Vector3.new(44, 0, -78),
		color = Color3.fromRGB(240, 178, 92),
		pool = pool({ "amberbeetle", "sapfinch", "resinram", "fossilhound", "amberking" }, STANDARD),
	},
	{
		id = "frost",
		name = "Frost Egg",
		desc = "Do not hold it for longer than the hatch takes.",
		price = 40000,
		zone = "frost",
		position = Vector3.new(44, 0, -78),
		color = Color3.fromRGB(168, 226, 244),
		pool = pool({ "frostmite", "snowhare", "glacierowl", "rimewolf", "frostmonarch" }, STANDARD),
	},
	{
		id = "ember",
		name = "Ember Egg",
		desc = "Ticks quietly, like a cooling engine.",
		price = 400000,
		zone = "ember",
		position = Vector3.new(44, 0, -78),
		color = Color3.fromRGB(250, 132, 78),
		pool = pool({ "cinderbug", "ashcrow", "magmapup", "emberdrake", "forgeheart" }, STANDARD),
	},
	{
		id = "storm",
		name = "Storm Egg",
		desc = "Hums. Occasionally sparks. Perfectly safe, mostly.",
		price = 4800000,
		zone = "storm",
		position = Vector3.new(44, 0, -78),
		color = Color3.fromRGB(146, 186, 255),
		pool = pool({ "sparkfly", "gustferret", "thunderelk", "stormray", "tempestlord" }, STANDARD),
	},
	{
		id = "void",
		name = "Void Egg",
		desc = "Casts a shadow in the wrong direction.",
		price = 60000000,
		zone = "void",
		position = Vector3.new(44, 0, -78),
		color = Color3.fromRGB(168, 120, 246),
		pool = pool({ "voidmite", "nullhare", "shadeserpent", "abyssowl", "voidsovereign" }, STANDARD),
	},
	{
		id = "nova",
		name = "Nova Egg",
		desc = "Bright enough to read by. Heavy enough to notice.",
		price = 780000000,
		zone = "nova",
		position = Vector3.new(44, 0, -78),
		color = Color3.fromRGB(255, 190, 104),
		pool = pool(
			{ "emberling", "solarfinch", "coronacat", "flarelion", "novaphoenix", "sunlessone" },
			WITH_MYTHIC
		),
	},
	{
		id = "rift",
		name = "Rift Egg",
		desc = "The last egg. Everything in it is a little bit wrong.",
		price = 10500000000,
		zone = "riftcore",
		position = Vector3.new(44, 0, -78),
		color = Color3.fromRGB(244, 128, 200),
		pool = pool(
			{ "riftling", "seamstalker", "paradoxhound", "eventhorizon", "riftsovereign", "thequiet" },
			WITH_MYTHIC
		),
	},
} :: { Egg }

Eggs.ById = {} :: { [string]: Egg }
for _, egg in Eggs.List do
	Eggs.ById[egg.id] = egg
end

function Eggs.get(id: string): Egg?
	return Eggs.ById[id]
end

function Eggs.totalWeight(egg: Egg): number
	local total = 0
	for _, entry in egg.pool do
		total += entry.weight
	end
	return total
end

--[[ The odds shown to the player, as a fraction of 1. This is the same table the
     roll uses, so the screen can never drift from the behaviour. ]]
function Eggs.odds(egg: Egg): { { pet: string, chance: number } }
	local total = Eggs.totalWeight(egg)
	local out = {}
	for _, entry in egg.pool do
		table.insert(out, { pet = entry.pet, chance = entry.weight / total })
	end
	return out
end

--[[ Rolls one pet. `rng` is passed in so the server can own a single seeded
     Random and the roll is never influenced by anything player-specific. ]]
function Eggs.roll(egg: Egg, rng: Random): string
	local ticket = rng:NextInteger(1, Eggs.totalWeight(egg))
	local cursor = 0
	for _, entry in egg.pool do
		cursor += entry.weight
		if ticket <= cursor then
			return entry.pet
		end
	end
	return egg.pool[#egg.pool].pet
end

return Eggs
