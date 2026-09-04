--!strict
--[[
	Pets

	A pet's `mult` is added to the player's pet multiplier while it is equipped,
	so the equipped total is 1 + sum(mult). Pets are the widest lever in the game
	and every one of them is bought with Crystals through an egg whose odds are
	printed on the hatch screen. See Eggs.lua for why none of them are sold for
	Robux directly.
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type Pet = {
	id: string,
	name: string,
	rarity: Rarity,
	mult: number,
	color: Color3,
}

local Pets = {}

Pets.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

Pets.RarityColor = {
	Common = Color3.fromRGB(170, 178, 186),
	Uncommon = Color3.fromRGB(118, 206, 120),
	Rare = Color3.fromRGB(96, 168, 255),
	Epic = Color3.fromRGB(188, 116, 246),
	Legendary = Color3.fromRGB(255, 186, 74),
	Mythic = Color3.fromRGB(255, 96, 132),
} :: { [string]: Color3 }

Pets.List = {
	-- Basic Egg
	{ id = "pebblepup", name = "Pebble Pup", rarity = "Common", mult = 0.05, color = Color3.fromRGB(158, 150, 140) },
	{ id = "mossmoth", name = "Moss Moth", rarity = "Uncommon", mult = 0.12, color = Color3.fromRGB(132, 190, 118) },
	{ id = "clovercat", name = "Clover Cat", rarity = "Rare", mult = 0.24, color = Color3.fromRGB(112, 208, 150) },
	{ id = "hollowfox", name = "Hollow Fox", rarity = "Epic", mult = 0.38, color = Color3.fromRGB(196, 140, 240) },
	{ id = "greenwarden", name = "Green Warden", rarity = "Legendary", mult = 0.5, color = Color3.fromRGB(255, 200, 108) },

	-- Amber Egg
	{ id = "amberbeetle", name = "Amber Beetle", rarity = "Common", mult = 0.15, color = Color3.fromRGB(206, 156, 84) },
	{ id = "sapfinch", name = "Sap Finch", rarity = "Uncommon", mult = 0.32, color = Color3.fromRGB(238, 186, 96) },
	{ id = "resinram", name = "Resin Ram", rarity = "Rare", mult = 0.6, color = Color3.fromRGB(240, 168, 72) },
	{ id = "fossilhound", name = "Fossil Hound", rarity = "Epic", mult = 0.9, color = Color3.fromRGB(206, 128, 224) },
	{ id = "amberking", name = "Amber King", rarity = "Legendary", mult = 1.2, color = Color3.fromRGB(255, 208, 116) },

	-- Frost Egg
	{ id = "frostmite", name = "Frost Mite", rarity = "Common", mult = 0.4, color = Color3.fromRGB(188, 214, 228) },
	{ id = "snowhare", name = "Snow Hare", rarity = "Uncommon", mult = 0.85, color = Color3.fromRGB(214, 236, 246) },
	{ id = "glacierowl", name = "Glacier Owl", rarity = "Rare", mult = 1.5, color = Color3.fromRGB(140, 214, 240) },
	{ id = "rimewolf", name = "Rime Wolf", rarity = "Epic", mult = 2.3, color = Color3.fromRGB(160, 176, 248) },
	{ id = "frostmonarch", name = "Frost Monarch", rarity = "Legendary", mult = 3, color = Color3.fromRGB(206, 244, 255) },

	-- Ember Egg
	{ id = "cinderbug", name = "Cinder Bug", rarity = "Common", mult = 1, color = Color3.fromRGB(216, 116, 76) },
	{ id = "ashcrow", name = "Ash Crow", rarity = "Uncommon", mult = 2.2, color = Color3.fromRGB(148, 104, 96) },
	{ id = "magmapup", name = "Magma Pup", rarity = "Rare", mult = 4, color = Color3.fromRGB(248, 132, 64) },
	{ id = "emberdrake", name = "Ember Drake", rarity = "Epic", mult = 6, color = Color3.fromRGB(255, 108, 84) },
	{ id = "forgeheart", name = "Forgeheart", rarity = "Legendary", mult = 8, color = Color3.fromRGB(255, 168, 96) },

	-- Storm Egg
	{ id = "sparkfly", name = "Spark Fly", rarity = "Common", mult = 2.5, color = Color3.fromRGB(176, 200, 248) },
	{ id = "gustferret", name = "Gust Ferret", rarity = "Uncommon", mult = 5.5, color = Color3.fromRGB(150, 178, 236) },
	{ id = "thunderelk", name = "Thunder Elk", rarity = "Rare", mult = 10, color = Color3.fromRGB(132, 174, 255) },
	{ id = "stormray", name = "Storm Ray", rarity = "Epic", mult = 15, color = Color3.fromRGB(108, 152, 255) },
	{ id = "tempestlord", name = "Tempest Lord", rarity = "Legendary", mult = 20, color = Color3.fromRGB(196, 220, 255) },

	-- Void Egg
	{ id = "voidmite", name = "Void Mite", rarity = "Common", mult = 6, color = Color3.fromRGB(120, 96, 168) },
	{ id = "nullhare", name = "Null Hare", rarity = "Uncommon", mult = 13, color = Color3.fromRGB(140, 108, 200) },
	{ id = "shadeserpent", name = "Shade Serpent", rarity = "Rare", mult = 24, color = Color3.fromRGB(164, 116, 240) },
	{ id = "abyssowl", name = "Abyss Owl", rarity = "Epic", mult = 36, color = Color3.fromRGB(128, 88, 226) },
	{ id = "voidsovereign", name = "Void Sovereign", rarity = "Legendary", mult = 50, color = Color3.fromRGB(196, 150, 255) },

	-- Nova Egg
	{ id = "emberling", name = "Emberling", rarity = "Common", mult = 15, color = Color3.fromRGB(255, 178, 108) },
	{ id = "solarfinch", name = "Solar Finch", rarity = "Uncommon", mult = 33, color = Color3.fromRGB(255, 200, 120) },
	{ id = "coronacat", name = "Corona Cat", rarity = "Rare", mult = 60, color = Color3.fromRGB(255, 168, 84) },
	{ id = "flarelion", name = "Flare Lion", rarity = "Epic", mult = 92, color = Color3.fromRGB(255, 146, 72) },
	{ id = "novaphoenix", name = "Nova Phoenix", rarity = "Legendary", mult = 130, color = Color3.fromRGB(255, 224, 150) },
	{ id = "sunlessone", name = "The Sunless One", rarity = "Mythic", mult = 260, color = Color3.fromRGB(255, 96, 132) },

	-- Rift Egg
	{ id = "riftling", name = "Riftling", rarity = "Common", mult = 40, color = Color3.fromRGB(216, 140, 220) },
	{ id = "seamstalker", name = "Seam Stalker", rarity = "Uncommon", mult = 88, color = Color3.fromRGB(232, 128, 204) },
	{ id = "paradoxhound", name = "Paradox Hound", rarity = "Rare", mult = 160, color = Color3.fromRGB(244, 116, 188) },
	{ id = "eventhorizon", name = "Event Horizon", rarity = "Epic", mult = 245, color = Color3.fromRGB(180, 120, 255) },
	{ id = "riftsovereign", name = "Rift Sovereign", rarity = "Legendary", mult = 350, color = Color3.fromRGB(255, 214, 240) },
	{ id = "thequiet", name = "The Quiet", rarity = "Mythic", mult = 700, color = Color3.fromRGB(255, 250, 250) },
} :: { Pet }

Pets.ById = {} :: { [string]: Pet }
for _, pet in Pets.List do
	Pets.ById[pet.id] = pet
end

function Pets.get(id: string): Pet?
	return Pets.ById[id]
end

--[[ Sum of the multipliers of every equipped pet, expressed as a multiplier
     (1.0 with nothing equipped). Unknown ids are skipped so that removing a pet
     from the config never breaks an existing save. ]]
function Pets.multiplierFor(equipped: { string }): number
	local total = 1
	for _, id in equipped do
		local pet = Pets.ById[id]
		if pet then
			total += pet.mult
		end
	end
	return total
end

--[[ Best pets first. Used to auto-equip after a hatch and to sort the pet list. ]]
function Pets.sortByPower(ids: { string }): { string }
	local copy = table.clone(ids)
	table.sort(copy, function(a, b)
		local petA, petB = Pets.ById[a], Pets.ById[b]
		local multA = if petA then petA.mult else 0
		local multB = if petB then petB.mult else 0
		if multA == multB then
			return a < b
		end
		return multA > multB
	end)
	return copy
end

return Pets
