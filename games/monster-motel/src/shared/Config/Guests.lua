--!strict
--[[
	Guests

	Every monster that can check into a motel. `rent` is dollars per second while
	the guest is housed in a room.

	Rarity does two jobs: it sets how much a guest pays, and it gates which
	Motel Rating is needed before that guest will show up on your arrivals road at
	all. Both are visible in game -- the Arrivals window prints the exact weights
	for your current rating.

	Celebrities never appear on the road. They arrive once every ten minutes in the
	Town Square, in front of everyone, and whoever walks one home keeps it.

	Signature guests are the Robux ones. Three things are deliberately true of them:

	  * They sit beside the ladder rather than on top of it. A Signature pays more
	    than any Legendary, but **the best guests in the game are not for sale** --
	    the top Mythic out-earns every Signature, and Celebrities are worth several
	    times more again and can only be caught in the square.
	  * They can be stolen, exactly like every other guest. Buying one does not buy
	    theft immunity, because that would be buying an advantage in a raid.
	  * Losing one does not lose the purchase. The gamepass is a permanent
	    entitlement, so a stolen Signature can be re-summoned once the night ends.
	    The thief keeps the copy they carried home and you get yours back -- see
	    SignatureService.
]]

export type Rarity =
	"Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Celebrity" | "Signature"

export type Guest = {
	id: string,
	name: string,
	rarity: Rarity,
	rent: number,
	color: Color3,
	quip: string,
}

local Guests = {}

--[[ Ranking order, lowest first. Signature sits at the top so a bulk release can
     never sweep a purchased guest away; it is otherwise off the progression
     ladder, which runs Common -> Celebrity. ]]
Guests.RarityOrder =
	{ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celebrity", "Signature" }

--[[ The rarities that form the earned progression ladder, in order. Signature is
     excluded on purpose: it is bought, not progressed into. ]]
Guests.LadderOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celebrity" }

Guests.RarityColor = {
	Common = Color3.fromRGB(176, 182, 192),
	Uncommon = Color3.fromRGB(120, 208, 128),
	Rare = Color3.fromRGB(96, 168, 255),
	Epic = Color3.fromRGB(190, 116, 248),
	Legendary = Color3.fromRGB(255, 186, 74),
	Mythic = Color3.fromRGB(255, 96, 132),
	Celebrity = Color3.fromRGB(255, 236, 140),
	Signature = Color3.fromRGB(120, 232, 255),
} :: { [string]: Color3 }

Guests.List = {
	-- Common
	{ id = "grubling", name = "Grubling", rarity = "Common", rent = 1, color = Color3.fromRGB(150, 140, 110), quip = "Asked for a room with no floor." },
	{ id = "dustbunny", name = "Dust Bunny", rarity = "Common", rent = 2, color = Color3.fromRGB(184, 178, 168), quip = "Multiplies if you sweep." },
	{ id = "sockgremlin", name = "Sock Gremlin", rarity = "Common", rent = 3, color = Color3.fromRGB(138, 156, 132), quip = "You will not see your laundry again." },
	{ id = "moldblob", name = "Mold Blob", rarity = "Common", rent = 5, color = Color3.fromRGB(126, 158, 108), quip = "Pays rent. Slowly. In spores." },
	{ id = "piperat", name = "Pipe Rat", rarity = "Common", rent = 7, color = Color3.fromRGB(120, 112, 118), quip = "Knows the plumbing better than you." },
	{ id = "lintwraith", name = "Lint Wraith", rarity = "Common", rent = 10, color = Color3.fromRGB(196, 190, 200), quip = "Haunts the dryer. Only the dryer." },

	-- Uncommon
	{ id = "bogtoad", name = "Bog Toad", rarity = "Uncommon", rent = 18, color = Color3.fromRGB(104, 150, 96), quip = "Filled the tub with swamp. Tipped well." },
	{ id = "ceilingcrawler", name = "Ceiling Crawler", rarity = "Uncommon", rent = 26, color = Color3.fromRGB(132, 172, 118), quip = "Never once used the bed." },
	{ id = "vendingghoul", name = "Vending Ghoul", rarity = "Uncommon", rent = 35, color = Color3.fromRGB(118, 196, 140), quip = "Lives in machine four. Gives correct change." },
	{ id = "rustimp", name = "Rust Imp", rarity = "Uncommon", rent = 48, color = Color3.fromRGB(168, 124, 88), quip = "Eats the railings. Pays for the railings." },
	{ id = "dampmoth", name = "Damp Moth", rarity = "Uncommon", rent = 62, color = Color3.fromRGB(148, 190, 156), quip = "Enormous. Extremely polite." },
	{ id = "curtainlurker", name = "Curtain Lurker", rarity = "Uncommon", rent = 80, color = Color3.fromRGB(96, 178, 130), quip = "Is the curtains now. Rent still clears." },

	-- Rare
	{ id = "iceyeti", name = "Ice Machine Yeti", rarity = "Rare", rent = 130, color = Color3.fromRGB(140, 210, 255), quip = "The ice is free. The yeti is not." },
	{ id = "poolserpent", name = "Pool Serpent", rarity = "Rare", rent = 180, color = Color3.fromRGB(88, 170, 232), quip = "Chlorine does nothing. Guests love it." },
	{ id = "neonmoth", name = "Neon Moth", rarity = "Rare", rent = 240, color = Color3.fromRGB(120, 196, 255), quip = "Ate the VACANCY sign. Became the sign." },
	{ id = "statichound", name = "Static Hound", rarity = "Rare", rent = 310, color = Color3.fromRGB(150, 186, 255), quip = "Every television is its bed." },
	{ id = "laundrygolem", name = "Laundry Golem", rarity = "Rare", rent = 390, color = Color3.fromRGB(108, 158, 240), quip = "Made of towels. Owes for the towels." },
	{ id = "corridorstalker", name = "Corridor Stalker", rarity = "Rare", rent = 480, color = Color3.fromRGB(84, 148, 226), quip = "Only exists at the end of hallways." },

	-- Epic
	{ id = "vacancywraith", name = "Vacancy Wraith", rarity = "Epic", rent = 900, color = Color3.fromRGB(186, 124, 248), quip = "Appears in whichever room is empty." },
	{ id = "chandelierspider", name = "Chandelier Spider", rarity = "Epic", rent = 1200, color = Color3.fromRGB(170, 108, 236), quip = "Redecorated. Nobody asked it to." },
	{ id = "room13", name = "Room 13", rarity = "Epic", rent = 1600, color = Color3.fromRGB(200, 130, 255), quip = "Not a guest. A room that checked in." },
	{ id = "marblegargoyle", name = "Marble Gargoyle", rarity = "Epic", rent = 2100, color = Color3.fromRGB(158, 118, 220), quip = "Pays a year up front. Never leaves the roof." },
	{ id = "elevatorthing", name = "The Elevator Thing", rarity = "Epic", rent = 2700, color = Color3.fromRGB(206, 146, 255), quip = "Floor 4 does not exist. It disagrees." },
	{ id = "regret", name = "The Concierge's Regret", rarity = "Epic", rent = 3400, color = Color3.fromRGB(176, 100, 244), quip = "Hired once. Never dismissed." },

	-- Legendary
	{ id = "bellhop", name = "The Bellhop", rarity = "Legendary", rent = 7000, color = Color3.fromRGB(255, 196, 96), quip = "Carries everything. Has been here longest." },
	{ id = "penthousekraken", name = "Penthouse Kraken", rarity = "Legendary", rent = 9500, color = Color3.fromRGB(255, 176, 74), quip = "The top floor is a tank now. Worth it." },
	{ id = "chromebasilisk", name = "Chrome Basilisk", rarity = "Legendary", rent = 12500, color = Color3.fromRGB(255, 208, 120), quip = "Do not make eye contact at the buffet." },
	{ id = "midnightmanager", name = "The Midnight Manager", rarity = "Legendary", rent = 16000, color = Color3.fromRGB(255, 166, 60), quip = "Runs the place after Lights Out. Not yours." },
	{ id = "velvetbehemoth", name = "Velvet Behemoth", rarity = "Legendary", rent = 20000, color = Color3.fromRGB(255, 218, 150), quip = "Occupies six rooms. Booked one." },
	{ id = "longguest", name = "The Long Guest", rarity = "Legendary", rent = 25000, color = Color3.fromRGB(255, 186, 84), quip = "Checked in during the last renovation." },

	-- Mythic
	{ id = "permanentresident", name = "The Permanent Resident", rarity = "Mythic", rent = 60000, color = Color3.fromRGB(255, 112, 148), quip = "Predates the building. Predates the road." },
	{ id = "checkoutnever", name = "Checkout: Never", rarity = "Mythic", rent = 80000, color = Color3.fromRGB(255, 96, 132), quip = "The form was filled in wrong. It is binding." },
	{ id = "suiteinfinity", name = "Suite Infinity", rarity = "Mythic", rent = 105000, color = Color3.fromRGB(255, 130, 170), quip = "One room. Keeps going." },
	{ id = "therenovation", name = "The Renovation", rarity = "Mythic", rent = 135000, color = Color3.fromRGB(255, 88, 120), quip = "Still going. Still billing." },
	{ id = "theowner", name = "The Owner", rarity = "Mythic", rent = 170000, color = Color3.fromRGB(255, 146, 186), quip = "You only manage the place. This is a reminder." },
	{ id = "guestzero", name = "Guest Zero", rarity = "Mythic", rent = 210000, color = Color3.fromRGB(255, 72, 108), quip = "The first one. The reason there is a motel." },

	-- Celebrity -- event only, never on the arrivals road
	{ id = "duchess", name = "The Duchess of Vantablack", rarity = "Celebrity", rent = 900000, color = Color3.fromRGB(255, 240, 170), quip = "Six suitcases. None of them open." },
	{ id = "djbonepile", name = "DJ Bonepile", rarity = "Celebrity", rent = 1300000, color = Color3.fromRGB(255, 246, 190), quip = "The complaints ARE the set list." },
	{ id = "screamingtenor", name = "The Screaming Tenor", rarity = "Celebrity", rent = 1800000, color = Color3.fromRGB(255, 232, 150), quip = "Rehearses at 3am. Nobody dares complain." },
	{ id = "theinfluencer", name = "The Influencer", rarity = "Celebrity", rent = 2500000, color = Color3.fromRGB(255, 250, 210), quip = "Filming your motel right now. Rent is exposure." },

	-- Signature -- gamepass only. Never on the arrivals road, never in the square.
	-- Each pays more than any Legendary and less than the best Mythic, on purpose.
	{ id = "sig_nightmanager", name = "The Night Manager", rarity = "Signature", rent = 30000, color = Color3.fromRGB(108, 200, 255), quip = "Runs the desk from midnight to six. Never once blinked." },
	{ id = "sig_madamevacancy", name = "Madame Vacancy", rarity = "Signature", rent = 75000, color = Color3.fromRGB(130, 224, 255), quip = "Books every room and occupies none of them." },
	{ id = "sig_cousin", name = "The Owner's Cousin", rarity = "Signature", rent = 160000, color = Color3.fromRGB(160, 244, 255), quip = "Nobody hired them. Nobody is going to bring it up." },
} :: { Guest }

Guests.ById = {} :: { [string]: Guest }
Guests.ByRarity = {} :: { [string]: { Guest } }

for _, rarity in Guests.RarityOrder do
	Guests.ByRarity[rarity] = {}
end

for _, guest in Guests.List do
	Guests.ById[guest.id] = guest
	table.insert(Guests.ByRarity[guest.rarity], guest)
end

function Guests.get(id: string): Guest?
	return Guests.ById[id]
end

function Guests.rarityRank(rarity: string): number
	return table.find(Guests.RarityOrder, rarity) or 1
end

--[[ Total rent per second from a list of housed guest ids, before multipliers.
     Unknown ids are skipped so removing a guest from the config never breaks a
     save that still refers to it. ]]
function Guests.rentFor(ids: { string }): number
	local total = 0
	for _, id in ids do
		local guest = Guests.ById[id]
		if guest then
			total += guest.rent
		end
	end
	return total
end

--[[ Best first. Used when a renovation leaves a player with more guests than
     rooms and the game has to decide which ones stay housed. ]]
function Guests.sortByRent(ids: { string }): { string }
	local copy = table.clone(ids)
	table.sort(copy, function(a, b)
		local guestA, guestB = Guests.ById[a], Guests.ById[b]
		local rentA = if guestA then guestA.rent else 0
		local rentB = if guestB then guestB.rent else 0
		if rentA == rentB then
			return a < b
		end
		return rentA > rentB
	end)
	return copy
end

Guests.Celebrities = Guests.ByRarity.Celebrity
Guests.Signatures = Guests.ByRarity.Signature

--[[ True for guests that can never turn up on the arrivals road. Celebrities come
     from the square; Signatures come from a gamepass. ]]
function Guests.isOffRoad(rarity: string): boolean
	return rarity == "Celebrity" or rarity == "Signature"
end

return Guests
