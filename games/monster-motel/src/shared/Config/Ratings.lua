--!strict
--[[
	Motel Rating

	Your rating is what quality of guest bothers to pull off the highway. Each
	level unlocks a rarity and shifts the weights toward the top of the table.

	The weights below are the ones the server rolls against, and the Arrivals
	window renders your current row as exact percentages. There is no hidden luck
	stat, no per-player fudge, and nothing in the store changes a single number on
	this page -- Express Lane makes offers arrive twice as often, at exactly these
	odds.
]]

local Guests = require(script.Parent.Guests)

export type Rating = {
	level: number,
	name: string,
	desc: string,
	cost: number,
	-- Weights out of 1000, keyed by rarity. Missing rarity means it cannot appear.
	weights: { [string]: number },
}

local Ratings = {}

Ratings.List = {
	{
		level = 1,
		name = "One Star",
		desc = "There is a bed. There is a roof. That is the pitch.",
		cost = 0,
		weights = { Common = 1000 },
	},
	{
		level = 2,
		name = "Two Star",
		desc = "The ice machine works. Word gets around.",
		cost = 15000,
		weights = { Common = 750, Uncommon = 250 },
	},
	{
		level = 3,
		name = "Three Star",
		desc = "Clean towels, most days. Something rarer starts stopping in.",
		cost = 250000,
		weights = { Common = 500, Uncommon = 350, Rare = 150 },
	},
	{
		level = 4,
		name = "Four Star",
		desc = "A pool. A real one. The listings notice.",
		cost = 4000000,
		weights = { Common = 300, Uncommon = 340, Rare = 260, Epic = 100 },
	},
	{
		level = 5,
		name = "Five Star",
		desc = "People drive past three better motels to reach yours.",
		cost = 70000000,
		weights = { Common = 150, Uncommon = 280, Rare = 320, Epic = 200, Legendary = 50 },
	},
	{
		level = 6,
		name = "Six Star",
		desc = "A rating that does not officially exist. The guests insist.",
		cost = 1200000000,
		weights = { Common = 60, Uncommon = 180, Rare = 300, Epic = 290, Legendary = 150, Mythic = 20 },
	},
	{
		level = 7,
		name = "The Last Motel",
		desc = "Whatever is left out there ends up here eventually.",
		cost = 20000000000,
		weights = { Common = 20, Uncommon = 90, Rare = 240, Epic = 330, Legendary = 250, Mythic = 70 },
	},
} :: { Rating }

Ratings.ByLevel = {} :: { [number]: Rating }
for _, rating in Ratings.List do
	Ratings.ByLevel[rating.level] = rating
end

Ratings.Max = #Ratings.List

function Ratings.get(level: number): Rating
	return Ratings.ByLevel[math.clamp(math.floor(level), 1, Ratings.Max)]
end

function Ratings.next(level: number): Rating?
	return Ratings.ByLevel[math.floor(level) + 1]
end

--[[ How long a guest takes to pay for itself, by rarity. Rarer guests cost more
     up front relative to their rent, so a big one is a decision rather than an
     automatic buy -- but with rooms scarce, the ceiling always wins in the end. ]]
Ratings.PaybackSeconds = {
	Common = 60,
	Uncommon = 75,
	Rare = 95,
	Epic = 120,
	Legendary = 150,
	Mythic = 190,
	Celebrity = 0,
}

function Ratings.priceFor(guest: Guests.Guest): number
	local payback = Ratings.PaybackSeconds[guest.rarity] or 60
	return math.floor(guest.rent * payback)
end

function Ratings.totalWeight(rating: Rating): number
	local total = 0
	for _, weight in rating.weights do
		total += weight
	end
	return total
end

--[[ The odds shown in the Arrivals window, as fractions of 1, ordered from
     commonest to rarest. Same table the roll uses. ]]
function Ratings.odds(rating: Rating): { { rarity: string, chance: number } }
	local total = Ratings.totalWeight(rating)
	local out = {}
	for _, rarity in Guests.RarityOrder do
		local weight = rating.weights[rarity]
		if weight then
			table.insert(out, { rarity = rarity, chance = weight / total })
		end
	end
	return out
end

--[[ Rolls one rarity for an arrivals slot. `rng` is passed in so the server owns
     a single generator and nothing player-specific can seed it. ]]
function Ratings.rollRarity(rating: Rating, rng: Random): string
	local ticket = rng:NextInteger(1, Ratings.totalWeight(rating))
	local cursor = 0
	for _, rarity in Guests.RarityOrder do
		local weight = rating.weights[rarity]
		if weight then
			cursor += weight
			if ticket <= cursor then
				return rarity
			end
		end
	end
	return "Common"
end

return Ratings
