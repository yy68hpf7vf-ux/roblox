--!strict
--[[
	Gamepasses and developer products

	Rules this file is built to:

	  1. Every paid item states exactly what it does, in the same units the game
	     already uses. No "mystery", no "?", no bundles whose contents are decided
	     after payment.
	  2. Nothing sold here is a random roll. Crystals are sold; pets are not.
	  3. Nothing sold here is required to finish the game. Passes are speed and
	     convenience, and the Robux-free path reaches every zone, every pet and
	     every rebirth.
	  4. Prices and contents are fixed. There is no countdown, no "was 999 R$",
	     no first-purchase-only price, and no offer that appears because a player
	     hesitated or ran out of Crystals.

	Fill in the ids below from the Creator Dashboard after you publish the place.
	Anything left at 0 is treated as unconfigured: the item is hidden from the
	store instead of throwing prompts that cannot resolve.
]]

export type Gamepass = {
	id: string,
	assetId: number,
	name: string,
	desc: string,
	-- Multiplier applied to Crystals earned when selling.
	sellMultiplier: number?,
	-- Multiplier applied to backpack capacity.
	capacityMultiplier: number?,
	-- Extra equipped pet slots.
	petSlots: number?,
	-- Swings the equipped pick without holding the mouse down. Same swing rate
	-- as everyone else -- it removes the clicking, not the time.
	autoMine: boolean?,
	-- Zones keyed to this pass in Zones.lua become accessible.
	unlocksZone: string?,
}

export type Product = {
	id: string,
	assetId: number,
	name: string,
	desc: string,
	kind: "crystals" | "boost",
	-- crystals: granted amount is this many seconds of the buyer's own current
	-- income, floored at `floor` so it is never a bad deal for a new player. The
	-- exact number is shown in the store before the prompt opens.
	seconds: number?,
	floor: number?,
	-- boost: multiplier and duration in seconds.
	multiplier: number?,
	duration: number?,
}

local Monetization = {}

Monetization.Gamepasses = {
	{
		id = "doublecrystals",
		assetId = 0,
		name = "2x Crystals",
		desc = "Every sale is worth double. Forever, on every account you play on.",
		sellMultiplier = 2,
	},
	{
		id = "vip",
		assetId = 0,
		name = "VIP",
		desc = "+50% Crystals, a chat tag, and the key to the VIP Vault seam.",
		sellMultiplier = 1.5,
		unlocksZone = "vipvault",
	},
	{
		id = "automine",
		assetId = 0,
		name = "Auto Mine",
		desc = "Your pick swings on its own at the normal speed. Saves your hand, not your time.",
		autoMine = true,
	},
	{
		id = "petslots",
		assetId = 0,
		name = "+2 Pet Slots",
		desc = "Equip two more pets at once. Stacks with Kennel from the Core Shop.",
		petSlots = 2,
	},
	{
		id = "megabackpack",
		assetId = 0,
		name = "Mega Backpack",
		desc = "Double capacity on whatever pack you are carrying. Half as many walks back.",
		capacityMultiplier = 2,
	},
} :: { Gamepass }

Monetization.Products = {
	{
		id = "crystals_small",
		assetId = 0,
		name = "Small Crystal Pack",
		desc = "About 20 minutes of mining at your current rate.",
		kind = "crystals",
		seconds = 1200,
		floor = 2500,
	},
	{
		id = "crystals_medium",
		assetId = 0,
		name = "Medium Crystal Pack",
		desc = "About an hour of mining at your current rate.",
		kind = "crystals",
		seconds = 3600,
		floor = 9000,
	},
	{
		id = "crystals_large",
		assetId = 0,
		name = "Large Crystal Pack",
		desc = "About three hours of mining at your current rate.",
		kind = "crystals",
		seconds = 10800,
		floor = 30000,
	},
	{
		id = "crystals_huge",
		assetId = 0,
		name = "Huge Crystal Pack",
		desc = "About ten hours of mining at your current rate.",
		kind = "crystals",
		seconds = 36000,
		floor = 110000,
	},
	{
		id = "boost_2x_30",
		assetId = 0,
		name = "2x Crystals - 30 minutes",
		desc = "Doubles Crystals for 30 minutes. Stacks up to 4 hours of stored time.",
		kind = "boost",
		multiplier = 2,
		duration = 1800,
	},
} :: { Product }

-- A boost purchase adds to the remaining time rather than replacing it, and the
-- total is capped so nobody buys eight of them expecting eight separate windows.
Monetization.MaxBoostSeconds = 14400

Monetization.GamepassById = {} :: { [string]: Gamepass }
Monetization.GamepassByAsset = {} :: { [number]: Gamepass }
for _, pass in Monetization.Gamepasses do
	Monetization.GamepassById[pass.id] = pass
	if pass.assetId ~= 0 then
		Monetization.GamepassByAsset[pass.assetId] = pass
	end
end

Monetization.ProductById = {} :: { [string]: Product }
Monetization.ProductByAsset = {} :: { [number]: Product }
for _, product in Monetization.Products do
	Monetization.ProductById[product.id] = product
	if product.assetId ~= 0 then
		Monetization.ProductByAsset[product.assetId] = product
	end
end

function Monetization.isConfigured(assetId: number): boolean
	return assetId ~= 0
end

return Monetization
