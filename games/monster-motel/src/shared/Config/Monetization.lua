--!strict
--[[
	Gamepasses and developer products

	These are built to sell. Every one of them removes a real friction a player
	will have felt for themselves before they see the price -- that is what makes
	someone buy, far more reliably than a countdown does.

	Signature guests are sold outright, and they are the case worth explaining. They
	are strong -- each pays more than any Legendary -- but they are beside the
	ladder, not on top of it: the best Mythic out-earns all of them and Celebrities
	are worth several times more again. **The two best tiers in the game cannot be
	bought at any price.**

	They are also stealable, like every other guest, because a purchased immunity
	would be an advantage in a raid. What the purchase actually buys is a permanent
	entitlement rather than an object: lose one to a thief and it comes back to you
	at sunrise, while the thief keeps the copy they earned. Nobody loses Robux to a
	bad night, and nobody buys their way out of being raided.

	The one hard line: **nothing sold here touches theft.** Carry speed, lock break
	time, tag range, the new-player grace window, the steal cooldown and the night
	length are constants in GameConfig, identical for everyone in the server. You
	can buy your way to a richer motel. You cannot buy your way into someone
	else's, or out of your own being entered.

	That is not softness, it is the thing that keeps the game alive. A raiding game
	where the wallet wins the chase is a game where everyone who lost the chase
	leaves, and they take the population the payers were showing off to with them.

	Fill in the ids from the Creator Dashboard after publishing. Anything left at 0
	is hidden from the store instead of opening a prompt that cannot resolve.
]]

export type Gamepass = {
	id: string,
	assetId: number,
	name: string,
	desc: string,
	-- Multiplier on rent collected.
	rentMultiplier: number?,
	-- Extra rooms on top of the cap.
	extraRooms: number?,
	-- Rent goes straight to the wallet instead of filling the safe.
	autoCollect: boolean?,
	-- Arrivals road refreshes this many times faster. Odds are unchanged.
	arrivalSpeed: number?,
	-- Earns while logged out, up to GameConfig.MaxOfflineHours.
	offlineEarnings: boolean?,
	-- Unlocks the VIP Lounge, which holds guests without using a room.
	vipLounge: boolean?,
	-- Permanently entitles the owner to this Signature guest. It behaves like any
	-- other guest once it is in the motel -- it can be stolen -- but the
	-- entitlement is permanent, so a stolen one is re-summoned at sunrise.
	signatureGuest: string?,
}

export type Product = {
	id: string,
	assetId: number,
	name: string,
	desc: string,
	kind: "cash" | "boost",
	-- cash: grants this many seconds of the buyer's own rent, floored at `floor`.
	-- The exact figure is shown on the button before the prompt opens.
	seconds: number?,
	floor: number?,
	-- boost: multiplier and duration in seconds.
	multiplier: number?,
	duration: number?,
}

local Monetization = {}

Monetization.Gamepasses = {
	{
		id = "doublecash",
		assetId = 0,
		name = "2x Cash",
		desc = "Every guest pays double rent. Forever, on every server you join.",
		rentMultiplier = 2,
	},
	{
		id = "vip",
		assetId = 0,
		name = "VIP",
		desc = "+50% rent, a chat tag, a gold motel sign, and the VIP Lounge -- two guests that pay rent without taking a room.",
		rentMultiplier = 1.5,
		vipLounge = true,
	},
	{
		id = "autocollect",
		assetId = 0,
		name = "Auto Collect",
		desc = "Rent goes straight to your wallet. No safe to fill up, no walk to the front desk.",
		autoCollect = true,
	},
	{
		id = "extrarooms",
		assetId = 0,
		name = "+5 Rooms",
		desc = "Five more rooms than your motel could otherwise hold, at every rating.",
		extraRooms = 5,
	},
	{
		id = "nightowl",
		assetId = 0,
		name = "Night Owl",
		desc = "Your motel keeps earning while you are offline, up to 8 hours banked.",
		offlineEarnings = true,
	},
	-- ---------------------------------------------------------------- signatures
	-- Three guests sold outright. Each pays more than any Legendary and less than
	-- the best Mythic, so buying accelerates a motel without ever out-earning what
	-- the game gives away. The two strongest tiers -- Mythic and Celebrity -- are
	-- not for sale at any price.
	{
		id = "sig_nightmanager",
		assetId = 0,
		name = "The Night Manager",
		desc = "A Signature guest paying $30K/s, yours permanently. Can be stolen like anyone else -- if that happens you get them back at sunrise.",
		signatureGuest = "sig_nightmanager",
	},
	{
		id = "sig_madamevacancy",
		assetId = 0,
		name = "Madame Vacancy",
		desc = "A Signature guest paying $75K/s, yours permanently. Can be stolen like anyone else -- if that happens you get them back at sunrise.",
		signatureGuest = "sig_madamevacancy",
	},
	{
		id = "sig_cousin",
		assetId = 0,
		name = "The Owner's Cousin",
		desc = "A Signature guest paying $160K/s, yours permanently. Can be stolen like anyone else -- if that happens you get them back at sunrise.",
		signatureGuest = "sig_cousin",
	},

	{
		id = "expresslane",
		assetId = 0,
		name = "Express Lane",
		desc = "New guests pull off the highway twice as often. Same odds -- twice the chances at them.",
		arrivalSpeed = 2,
	},
} :: { Gamepass }

Monetization.Products = {
	{
		id = "cash_small",
		assetId = 0,
		name = "Small Cash Drop",
		desc = "About 20 minutes of rent at your current rate.",
		kind = "cash",
		seconds = 1200,
		floor = 5000,
	},
	{
		id = "cash_medium",
		assetId = 0,
		name = "Medium Cash Drop",
		desc = "About an hour of rent at your current rate.",
		kind = "cash",
		seconds = 3600,
		floor = 18000,
	},
	{
		id = "cash_large",
		assetId = 0,
		name = "Large Cash Drop",
		desc = "About three hours of rent at your current rate.",
		kind = "cash",
		seconds = 10800,
		floor = 60000,
	},
	{
		id = "cash_huge",
		assetId = 0,
		name = "Huge Cash Drop",
		desc = "About ten hours of rent at your current rate.",
		kind = "cash",
		seconds = 36000,
		floor = 220000,
	},
	{
		id = "boost_2x_30",
		assetId = 0,
		name = "2x Rent - 30 minutes",
		desc = "Doubles rent for 30 minutes. Stacks up to 4 hours of stored time.",
		kind = "boost",
		multiplier = 2,
		duration = 1800,
	},
} :: { Product }

Monetization.MaxBoostSeconds = 14400

-- The VIP Lounge holds this many guests outside the room count.
Monetization.VipLoungeSlots = 2

--[[ Fields no paid item is allowed to declare. The self-test walks every pass and
     product against this list, so a future edit that tries to sell a theft
     advantage fails at the terminal instead of shipping. ]]
Monetization.ForbiddenFields = {
	"carrySpeed",
	"walkSpeed",
	"lockStrength",
	"breakSpeed",
	"tagRange",
	"stealCooldown",
	"theftImmunity",
	"graceExtension",
	"nightLength",
	"luck",
	"rarityBoost",
}

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
