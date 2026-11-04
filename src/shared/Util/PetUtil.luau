--!nonstrict
-- Helpers for working with saved pet data. Used by both server and client.

local Config = script.Parent.Parent.Config
local Pets = require(Config.Pets)
local Variants = require(Config.Variants)
local Rarities = require(Config.Rarities)

local PetUtil = {}

function PetUtil.getDef(petData)
	return Pets[petData.Name]
end

function PetUtil.getPower(petData): number
	local def = Pets[petData.Name]
	local variant = Variants[petData.Variant]
	if not def or not variant then
		return 0
	end
	return math.floor(def.BasePower * variant.PowerMultiplier)
end

-- Returns an array of { Id = string, Data = petData } sorted by `mode`:
-- "Power" (highest first), "Rarity" (rarest first), "Name" (A-Z).
function PetUtil.sortedList(pets, mode: string)
	local list = {}
	for id, data in pets do
		table.insert(list, { Id = id, Data = data })
	end
	table.sort(list, function(a, b)
		local pa, pb = PetUtil.getPower(a.Data), PetUtil.getPower(b.Data)
		if mode == "Rarity" then
			local ra = Rarities[Pets[a.Data.Name].Rarity].Order
			local rb = Rarities[Pets[b.Data.Name].Rarity].Order
			if ra ~= rb then
				return ra > rb
			end
		elseif mode == "Name" then
			if a.Data.Name ~= b.Data.Name then
				return a.Data.Name < b.Data.Name
			end
		end
		if pa ~= pb then
			return pa > pb
		end
		return a.Id < b.Id
	end)
	return list
end

return PetUtil
