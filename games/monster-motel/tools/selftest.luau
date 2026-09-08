--!nocheck
--[[
	Monster Motel config self-test -- assertions.

	Runs the shared layer outside Roblox and checks the invariants the rest of the
	game assumes. Two groups matter most:

	  * **Fairness.** A block of checks walks every gamepass and product and proves
	    none of them declares a field that could influence a raid. If somebody later
	    adds a "+2s carry speed" pass, this fails at the terminal rather than
	    shipping and quietly turning the PvP into a wallet contest.

	  * **Reachability.** The Star Shop has to be affordable out of the Stars the
	    game actually mints, and a fully upgraded door has to be breakable inside one
	    night. Both are easy to break with a plausible-looking number change.

	Run with:  python3 tools/selftest.py <luau> games/monster-motel
]]

-- ---------------------------------------------------------------- assertions

local failures = 0
local checks = 0

local function check(condition, message)
	checks += 1
	if not condition then
		failures += 1
		print("  FAIL  " .. message)
	end
end

local function equal(actual, expected, message)
	checks += 1
	if actual ~= expected then
		failures += 1
		print(`  FAIL  {message}: expected "{expected}", got "{actual}"`)
	end
end

local function near(actual, expected, tolerance, message)
	checks += 1
	if math.abs(actual - expected) > tolerance then
		failures += 1
		print(`  FAIL  {message}: expected ~{expected}, got {actual}`)
	end
end

local function section(name)
	print("\n" .. name)
end

-- ---------------------------------------------------------------- load config

local GameConfig = shared("Config", "GameConfig")
local Guests = shared("Config", "Guests")
local Ratings = shared("Config", "Ratings")
local Rooms = shared("Config", "Rooms")
local Prestige = shared("Config", "Prestige")
local Upgrades = shared("Config", "Upgrades")
local Objectives = shared("Config", "Objectives")
local Monetization = shared("Config", "Monetization")
local Quests = shared("Config", "Quests")
local Rewards = shared("Config", "Rewards")
local Codes = shared("Config", "Codes")
local Format = shared("Util", "Format")
local Signal = shared("Util", "Signal")
local TableUtil = shared("Util", "TableUtil")
local Schema = shared("Schema")

local function uniqueIds(list, label)
	local seen = {}
	for _, entry in list do
		check(seen[entry.id] == nil, `{label}: duplicate id "{entry.id}"`)
		seen[entry.id] = true
	end
end

-- ---------------------------------------------------------------- fairness

section("Fairness: nothing sold may touch a raid")
do
	-- Every constant a raid depends on. None of these may be influenced by
	-- anything a player can buy.
	local raidConstants = {
		"CarryWalkSpeed",
		"NormalWalkSpeed",
		"TagRange",
		"StealCooldownPerVictim",
		"NewPlayerGrace",
		"MinimumGuestsToRob",
		"DayDuration",
		"NightDuration",
	}

	for _, name in raidConstants do
		check(GameConfig[name] ~= nil, `GameConfig is missing the raid constant {name}`)
		check(type(GameConfig[name]) == "number", `GameConfig.{name} must be a plain number`)
	end

	-- No paid item may declare a field from the forbidden list, and no paid item
	-- may name a raid constant either.
	local banned = {}
	for _, field in Monetization.ForbiddenFields do
		banned[field] = true
	end
	for _, name in raidConstants do
		banned[name] = true
	end

	local function auditItem(kind, item)
		for field in item do
			check(
				not banned[field],
				`{kind}: "{item.id}" declares "{field}", which would let Robux affect a raid`
			)
		end
	end

	for _, pass in Monetization.Gamepasses do
		auditItem("Gamepasses", pass)
	end
	for _, product in Monetization.Products do
		auditItem("Products", product)
	end

	check(#Monetization.ForbiddenFields > 0, "Monetization.ForbiddenFields must not be empty")

	-- Cash upgrades are earnable by everyone, so they may raise normal walk speed.
	-- They still may not touch the numbers a raid turns on. Running Shoes is the
	-- only movement upgrade and it must be capped well under a runaway value.
	local movementUpgrades = 0
	for _, upgrade in Upgrades.List do
		check(
			upgrade.id ~= "carry" and not string.find(string.lower(upgrade.id), "carry"),
			`Upgrades: "{upgrade.id}" looks like a carry-speed upgrade, which must never exist`
		)
		if upgrade.unit == "walk speed" then
			movementUpgrades += 1
			local top = GameConfig.NormalWalkSpeed + upgrade.perLevel * upgrade.maxLevel
			check(
				top <= GameConfig.NormalWalkSpeed * 2,
				`Upgrades: {upgrade.id} tops out at {top} walk speed, more than double the base`
			)
			-- The whole point: even fully upgraded, you are slower carrying.
			check(
				GameConfig.CarryWalkSpeed < GameConfig.NormalWalkSpeed,
				"Carrying must be slower than the base walk speed"
			)
			print(`  (walk speed {GameConfig.NormalWalkSpeed} -> {top} fully upgraded; carrying is always {GameConfig.CarryWalkSpeed})`)
		end
	end
	check(movementUpgrades <= 1, "There should be exactly one movement upgrade, so the cap is easy to reason about")

	-- A carried player must be slower than a free one, or theft has no risk.
	check(
		GameConfig.CarryWalkSpeed < GameConfig.NormalWalkSpeed,
		"Carrying must be slower than walking, or there is no chase"
	)
	-- Protections must actually protect.
	check(GameConfig.NewPlayerGrace > 0, "New players must have a grace window")
	check(GameConfig.MinimumGuestsToRob > 0, "There must be a floor below which nobody can be robbed")
	print(
		`  (carry {GameConfig.CarryWalkSpeed} vs walk {GameConfig.NormalWalkSpeed}, `
			.. `{GameConfig.NewPlayerGrace / 60}min grace, floor of {GameConfig.MinimumGuestsToRob} guests)`
	)
end

section("Fairness: a maxed door is still a door")
do
	local perLevel = Prestige.UpgradeById.deadbolt.perLevel
	local maxDeadbolt = Prestige.UpgradeById.deadbolt.maxLevel
	local worst = Rooms.breakSecondsFor(Rooms.MaxLockLevel, maxDeadbolt, perLevel)
	local base = Rooms.lock(0).breakSeconds

	-- The cap is a guard rail for future tuning, not necessarily the number the
	-- current config reaches. What must hold is that the worst case respects it
	-- and still leaves most of a night to get in and out.
	check(worst <= Rooms.MaxBreakSeconds, `The strongest door ({worst}s) exceeds the cap ({Rooms.MaxBreakSeconds}s)`)
	check(worst > base, "Investing in a lock should actually slow a thief down")
	check(
		worst < GameConfig.NightDuration * 0.5,
		`A maxed door takes {worst}s of a {GameConfig.NightDuration}s night, leaving too little time to carry anything home`
	)
	check(
		Rooms.MaxBreakSeconds < GameConfig.NightDuration,
		`The cap ({Rooms.MaxBreakSeconds}s) is longer than a night ({GameConfig.NightDuration}s) -- a capped door could never be opened`
	)

	-- The clamp has to actually clamp, even though nothing in the config reaches
	-- it today. This is the check that keeps the guard rail honest.
	equal(
		Rooms.breakSecondsFor(Rooms.MaxLockLevel, 999, perLevel),
		Rooms.MaxBreakSeconds,
		"An absurd Deadbolt level should clamp to MaxBreakSeconds"
	)

	print(
		`  (worst-case door {worst}s, cap {Rooms.MaxBreakSeconds}s, inside a {GameConfig.NightDuration}s night)`
	)
end

-- ---------------------------------------------------------------- content

section("Identity")
uniqueIds(Guests.List, "Guests")
uniqueIds(Monetization.Gamepasses, "Gamepasses")
uniqueIds(Monetization.Products, "Products")
uniqueIds(Prestige.Upgrades, "Star Shop")

section("Guests")
for _, guest in Guests.List do
	check(guest.rent > 0, `Guests: {guest.id} pays no rent`)
	check(#guest.quip > 0, `Guests: {guest.id} has no quip`)
	check(Guests.RarityColor[guest.rarity] ~= nil, `Guests: {guest.id} has rarity "{guest.rarity}" with no colour`)
	check(table.find(Guests.RarityOrder, guest.rarity) ~= nil, `Guests: {guest.id} has unranked rarity`)
end

do
	-- Within a rarity, rent must climb. Across rarities, the cheapest of a tier
	-- must beat the dearest of the tier below, or rarity would not mean anything.
	local previousTop = 0
	for _, rarity in Guests.LadderOrder do
		local pool = Guests.ByRarity[rarity]
		check(#pool > 0, `Guests: no guests of rarity {rarity}`)

		for index = 2, #pool do
			check(
				pool[index].rent > pool[index - 1].rent,
				`Guests: {pool[index].id} is not worth more than {pool[index - 1].id} in the same rarity`
			)
		end

		check(
			pool[1].rent > previousTop,
			`Guests: the cheapest {rarity} ({pool[1].id}) does not beat the best of the tier below`
		)
		previousTop = pool[#pool].rent
	end
end

equal(Guests.rentFor({}), 0, "Guests: an empty motel earns nothing")
equal(Guests.rentFor({ "unknown_guest" }), 0, "Guests: an unknown id should be ignored, not fatal")
equal(
	Guests.rentFor({ "grubling", "dustbunny" }),
	Guests.ById.grubling.rent + Guests.ById.dustbunny.rent,
	"Guests: housed rents should add"
)
equal(Guests.sortByRent({ "grubling", "lintwraith", "dustbunny" })[1], "lintwraith", "Guests: sortByRent")

section("Ratings and the arrivals road")
for index, rating in Ratings.List do
	equal(rating.level, index, `Ratings: entry {index} has the wrong level`)
	equal(Ratings.totalWeight(rating), 1000, `Ratings: {rating.name} weights should total 1000`)

	local sum = 0
	for _, entry in Ratings.odds(rating) do
		check(Guests.ByRarity[entry.rarity] ~= nil, `Ratings: {rating.name} references unknown rarity "{entry.rarity}"`)
		check(entry.chance > 0, `Ratings: {rating.name} lists {entry.rarity} at zero chance`)
		check(
			not Guests.isOffRoad(entry.rarity),
			`Ratings: {rating.name} can roll a {entry.rarity} -- those never appear on the arrivals road`
		)
		sum += entry.chance
	end
	near(sum, 1, 1e-9, `Ratings: {rating.name} odds do not sum to 100%`)

	if index > 1 then
		check(rating.cost > Ratings.List[index - 1].cost, `Ratings: {rating.name} is not dearer than the one below`)
		-- Each level must unlock at least as much as the last.
		for rarity in Ratings.List[index - 1].weights do
			check(
				rating.weights[rarity] ~= nil,
				`Ratings: {rating.name} dropped {rarity}, which the level below could roll`
			)
		end
	end
end
equal(Ratings.List[1].cost, 0, "Ratings: the starting rating must be free")

do
	-- Rarer guests must take longer to pay for themselves, or there would be no
	-- decision in buying one.
	local previous = 0
	for _, rarity in Guests.LadderOrder do
		if rarity ~= "Celebrity" then
			local payback = Ratings.PaybackSeconds[rarity]
			check(payback ~= nil, `Ratings: no payback time for {rarity}`)
			check(payback > previous, `Ratings: {rarity} does not take longer to pay back than the tier below`)
			previous = payback
		end
	end
	equal(Ratings.PaybackSeconds.Celebrity, 0, "Ratings: celebrities are never priced -- they are not for sale")

	for _, guest in Guests.List do
		if not Guests.isOffRoad(guest.rarity) then
			check(Ratings.priceFor(guest) > 0, `Ratings: {guest.id} has no price`)
		end
	end
end

section("Arrival rolls match the printed odds")
do
	local rating = Ratings.get(5)
	local rng = Random.new(4242)
	local counts = {}
	local samples = 60000

	for _ = 1, samples do
		local rarity = Ratings.rollRarity(rating, rng)
		counts[rarity] = (counts[rarity] or 0) + 1
	end

	for _, entry in Ratings.odds(rating) do
		local observed = (counts[entry.rarity] or 0) / samples
		near(observed, entry.chance, 0.02, `Ratings: five-star rolls {entry.rarity} at the wrong rate`)
	end
end

section("Rooms, safes and locks")
do
	equal(Rooms.costFor(GameConfig.StartingRooms), 0, "Rooms: the starting rooms must be free")
	check(Rooms.costFor(GameConfig.StartingRooms + 1) > 0, "Rooms: the first bought room must cost something")

	for room = GameConfig.StartingRooms + 2, GameConfig.BaseMaxRooms do
		check(
			Rooms.costFor(room) > Rooms.costFor(room - 1),
			`Rooms: room {room} is not dearer than room {room - 1}`
		)
	end

	for index = 2, #Rooms.SafeLevels do
		check(
			Rooms.SafeLevels[index].seconds > Rooms.SafeLevels[index - 1].seconds,
			`Safe: level {index} does not hold more than level {index - 1}`
		)
		check(
			Rooms.SafeLevels[index].cost > Rooms.SafeLevels[index - 1].cost,
			`Safe: level {index} is not dearer than level {index - 1}`
		)
	end
	equal(Rooms.SafeLevels[1].cost, 0, "Safe: the starting safe must be free")
	equal(
		Rooms.safe(1).seconds,
		GameConfig.BaseSafeCapacitySeconds,
		"Safe: level 1 should match GameConfig.BaseSafeCapacitySeconds"
	)

	for index = 2, #Rooms.Locks do
		check(
			Rooms.Locks[index].breakSeconds > Rooms.Locks[index - 1].breakSeconds,
			`Locks: {Rooms.Locks[index].name} is not slower to break than the one below`
		)
		check(
			Rooms.Locks[index].cost > Rooms.Locks[index - 1].cost,
			`Locks: {Rooms.Locks[index].name} is not dearer than the one below`
		)
	end
	equal(Rooms.Locks[1].cost, 0, "Locks: having no lock must cost nothing")
	equal(Rooms.lock(0).level, 0, "Locks: lock(0) should be the no-lock entry")
	equal(Rooms.lock(999).level, Rooms.MaxLockLevel, "Locks: an out-of-range level should clamp")
end

section("Renovation and the Star Shop")
do
	equal(Prestige.starsFor(0), 0, "Prestige: no earnings means no Stars")
	local previous = -1
	for exponent = 6, 15 do
		local stars = Prestige.starsFor(10 ^ exponent)
		check(stars >= previous, `Prestige: Stars went down between 1e{exponent - 1} and 1e{exponent}`)
		previous = stars
	end

	-- starsFor and earningsForStars must be inverses, or the "next Star at" figure
	-- on the renovate screen would be a lie.
	for stars = 1, 40 do
		local needed = Prestige.earningsForStars(stars)
		equal(Prestige.starsFor(needed), stars, `Prestige: earningsForStars({stars}) does not round-trip`)
		check(
			Prestige.starsFor(needed - 1) < stars,
			`Prestige: one short of the threshold for {stars} Stars still pays {stars}`
		)
	end

	for _, upgrade in Prestige.Upgrades do
		check(upgrade.maxLevel > 0, `Star Shop: {upgrade.id} cannot be levelled`)
		check(upgrade.perLevel > 0, `Star Shop: {upgrade.id} does nothing per level`)
		for level = 0, upgrade.maxLevel - 2 do
			check(
				Prestige.upgradeCost(upgrade, level + 1) > Prestige.upgradeCost(upgrade, level),
				`Star Shop: {upgrade.id} does not get dearer at level {level + 1}`
			)
		end
	end

	equal(Prestige.upgradeMultiplier("concierge", 0), 1, "Star Shop: Concierge at level 0 should be neutral")
	equal(Prestige.upgradeMultiplier("not_real", 5), 1, "Star Shop: an unknown upgrade should be neutral")
	equal(Prestige.upgradeBonus("wing", 3), 3, "Star Shop: Extra Wing should add one room per level")

	-- Every Star comes from a renovation, so the shop must be affordable out of
	-- renovations somebody would plausibly do.
	local totalCost = 0
	for _, upgrade in Prestige.Upgrades do
		totalCost += Prestige.upgradeTotalCost(upgrade)
	end
	-- A renovation is worth at least one Star, so this is a floor on the count.
	check(totalCost < 3000, `Star Shop: maxing everything costs {totalCost} Stars, which is out of reach`)
	print(`  (maxing the Star Shop costs {totalCost} Stars)`)
end

section("Signature guests")
do
	local signatures = Guests.ByRarity.Signature or {}
	check(#signatures > 0, "Signature: no Signature guests defined")

	-- Every Signature must be buyable, and every buyable one must exist.
	local entitled = {}
	for _, pass in Monetization.Gamepasses do
		if pass.signatureGuest then
			local guest = Guests.get(pass.signatureGuest)
			check(guest ~= nil, `Signature: pass "{pass.id}" points at unknown guest "{pass.signatureGuest}"`)
			if guest then
				equal(
					guest.rarity,
					"Signature",
					`Signature: pass "{pass.id}" sells {guest.id}, which is not a Signature guest`
				)
			end
			check(entitled[pass.signatureGuest] == nil, `Signature: two passes both sell "{pass.signatureGuest}"`)
			entitled[pass.signatureGuest] = pass.id
		end
	end

	for _, guest in signatures do
		check(entitled[guest.id] ~= nil, `Signature: {guest.id} exists but no gamepass sells it`)
	end

	-- Never on the road, never in the square.
	for _, rating in Ratings.List do
		check(
			rating.weights.Signature == nil,
			`Signature: {rating.name} has a Signature weight -- they are gamepass-only`
		)
	end
	for _, guest in Guests.Celebrities do
		check(guest.rarity == "Celebrity", "Signature: a Signature leaked into the celebrity pool")
	end

	-- The headline claim the store makes: the best guests are not for sale.
	local bestSignature, bestMythic, bestCelebrity = 0, 0, 0
	for _, guest in signatures do
		bestSignature = math.max(bestSignature, guest.rent)
	end
	for _, guest in Guests.ByRarity.Mythic do
		bestMythic = math.max(bestMythic, guest.rent)
	end
	for _, guest in Guests.Celebrities do
		bestCelebrity = math.max(bestCelebrity, guest.rent)
	end

	check(
		bestSignature < bestMythic,
		`Signature: the best purchasable guest (${bestSignature}/s) out-earns the best Mythic (${bestMythic}/s), `
			.. "which breaks the promise that the top tiers are not for sale"
	)
	check(bestMythic < bestCelebrity, "Signature: Celebrities should still be the best guests in the game")

	-- And they should be worth buying: better than anything below Mythic.
	local bestLegendary = 0
	for _, guest in Guests.ByRarity.Legendary do
		bestLegendary = math.max(bestLegendary, guest.rent)
	end
	check(
		bestSignature > bestLegendary,
		"Signature: the best purchasable guest does not beat the best Legendary, so it is not worth buying"
	)

	-- Ranked above everything, so a bulk release can never sweep a purchase away.
	equal(
		Guests.rarityRank("Signature"),
		#Guests.RarityOrder,
		"Signature: must rank highest so releaseBelow can never delete a purchased guest"
	)

	print(
		`  (best Signature ${bestSignature}/s < best Mythic ${bestMythic}/s < best Celebrity ${bestCelebrity}/s)`
	)
end

section("Cash upgrades")
for _, upgrade in Upgrades.List do
	check(upgrade.maxLevel > 0, `Upgrades: {upgrade.id} cannot be levelled`)
	check(upgrade.perLevel > 0, `Upgrades: {upgrade.id} does nothing per level`)
	check(#upgrade.name > 0 and #upgrade.desc > 0, `Upgrades: {upgrade.id} has no name or description`)
	check(#upgrade.unit > 0, `Upgrades: {upgrade.id} has no unit to render`)
	check(upgrade.baseCost > 0, `Upgrades: {upgrade.id} costs nothing at level 0`)

	for level = 0, upgrade.maxLevel - 2 do
		check(
			Upgrades.costFor(upgrade, level + 1) > Upgrades.costFor(upgrade, level),
			`Upgrades: {upgrade.id} does not get dearer at level {level + 1}`
		)
	end

	equal(Upgrades.bonus(upgrade.id, 0), 0, `Upgrades: {upgrade.id} at level 0 should do nothing`)
	-- Asking for more than the cap must not pay more than the cap.
	equal(
		Upgrades.bonus(upgrade.id, upgrade.maxLevel + 50),
		Upgrades.bonus(upgrade.id, upgrade.maxLevel),
		`Upgrades: {upgrade.id} keeps paying out past its maximum level`
	)
end
equal(Upgrades.bonus("not_a_real_upgrade", 5), 0, "Upgrades: an unknown id should be neutral")
equal(Upgrades.multiplier("service", 0), 1, "Upgrades: Room Service at level 0 should be neutral")

do
	-- The Neon Sign shortens the gap between arrivals; it must not be able to
	-- shorten it past the floor, or the road becomes a firehose.
	local sign = Upgrades.ById.sign
	local shortest = GameConfig.ArrivalInterval - Upgrades.bonus("sign", sign.maxLevel)
	check(
		shortest >= GameConfig.MinArrivalInterval,
		`Upgrades: a maxed Neon Sign gives an interval of {shortest}s, under the {GameConfig.MinArrivalInterval}s floor`
	)
	print(`  (arrivals every {GameConfig.ArrivalInterval}s -> {shortest}s fully upgraded)`)
end

section("Objectives")
do
	check(Objectives.Count > 0, "Objectives: the list is empty")

	local seen = {}
	for index, objective in Objectives.List do
		check(seen[objective.id] == nil, `Objectives: duplicate id "{objective.id}"`)
		seen[objective.id] = true
		check(#objective.name > 0, `Objectives: {objective.id} has no name`)
		check(#objective.hint > 0, `Objectives: {objective.id} has no hint -- the hint is the whole point`)
		check(objective.rewardSeconds > 0, `Objectives: {objective.id} pays nothing`)

		-- Every progress function must run against a fresh profile without
		-- erroring, and must return a target worth reaching.
		local current, target = objective.progress(Schema.Template)
		check(type(current) == "number", `Objectives: {objective.id} progress did not return a number`)
		check(type(target) == "number" and target > 0, `Objectives: {objective.id} has no target`)
		check(
			current < target,
			`Objectives: {objective.id} is already complete on a brand new profile`
		)
		equal(Objectives.isComplete(index, Schema.Template), false, `Objectives: {objective.id} completes instantly`)
	end

	-- Rewards should grow down the list, since later objectives take longer.
	for index = 2, Objectives.Count do
		check(
			Objectives.List[index].rewardSeconds >= Objectives.List[index - 1].rewardSeconds,
			`Objectives: "{Objectives.List[index].id}" pays less than the one before it`
		)
	end

	check(Objectives.get(Objectives.Count + 1) == nil, "Objectives: the list must end")
	print(`  ({Objectives.Count} objectives, first is "{Objectives.List[1].name}")`)
end

section("Monetization")
do
	local seenAsset = {}
	local configured = 0

	local function checkAsset(kind, id, assetId)
		if Monetization.isConfigured(assetId) then
			configured += 1
			check(assetId > 0 and assetId % 1 == 0, `{kind}: {id} has a malformed asset id`)
			check(seenAsset[assetId] == nil, `{kind}: {id} shares an asset id with "{seenAsset[assetId]}"`)
			seenAsset[assetId] = id
		end
	end

	for _, pass in Monetization.Gamepasses do
		check(#pass.name > 0 and #pass.desc > 0, `Gamepasses: {pass.id} has no name or description`)
		checkAsset("Gamepasses", pass.id, pass.assetId)
	end

	for _, product in Monetization.Products do
		check(#product.name > 0 and #product.desc > 0, `Products: {product.id} has no name or description`)
		checkAsset("Products", product.id, product.assetId)
		check(
			product.kind == "cash" or product.kind == "boost",
			`Products: {product.id} is a "{product.kind}" -- only deterministic kinds may be sold`
		)
		if product.kind == "cash" then
			check((product.seconds or 0) > 0, `Products: {product.id} grants nothing`)
			check((product.floor or 0) > 0, `Products: {product.id} has no floor for a new player`)
		else
			check((product.multiplier or 0) > 1, `Products: {product.id} is a boost that boosts nothing`)
			check((product.duration or 0) > 0, `Products: {product.id} is a boost with no duration`)
		end
	end

	check(Monetization.MaxBoostSeconds > 0, "Monetization: boosts must have a stacking cap")
	check(Monetization.VipLoungeSlots > 0, "Monetization: the VIP lounge should hold something")

	local total = #Monetization.Gamepasses + #Monetization.Products
	if configured == 0 then
		print(`  (no asset ids set yet -- all {total} store items are hidden in game)`)
	elseif configured < total then
		print(`  ({configured} of {total} store items have asset ids; the rest stay hidden)`)
	end
end

section("Quests")
do
	local picked = Quests.pickForDay(20000, GameConfig.DailyQuestCount)
	equal(#picked, GameConfig.DailyQuestCount, "Quests: wrong number picked for a day")

	local again = Quests.pickForDay(20000, GameConfig.DailyQuestCount)
	local seen = {}
	for index, id in picked do
		equal(again[index], id, "Quests: the same day must always pick the same quests")
		check(Quests.ById[id] ~= nil, `Quests: picked unknown quest "{id}"`)
		check(seen[id] == nil, `Quests: picked "{id}" twice in one day`)
		seen[id] = true
	end

	local different = false
	for day = 20001, 20020 do
		if Quests.pickForDay(day, GameConfig.DailyQuestCount)[1] ~= picked[1] then
			different = true
		end
	end
	check(different, "Quests: every day picks the same first quest, so they never rotate")

	local kinds = {}
	for _, def in Quests.Pool do
		check(def.rewardSeconds > 0, `Quests: {def.id} pays nothing`)
		check(Quests.targetFor(def, 7) >= Quests.targetFor(def, 1), `Quests: {def.id} gets easier as you grow`)
		check(Quests.targetFor(def, 1) >= 1, `Quests: {def.id} has a target below 1`)
		kinds[def.kind] = (kinds[def.kind] or 0) + 1
	end

	-- The pool has to reward defending as well as raiding, or a server fills up
	-- with people who only ever attack.
	check((kinds.steal_guests or 0) > 0, "Quests: nothing rewards raiding")
	check((kinds.survive_nights or 0) > 0, "Quests: nothing rewards defending")
	equal(
		kinds.steal_guests,
		kinds.survive_nights,
		"Quests: raiding and defending should be rewarded equally often"
	)
end

section("Rewards")
equal(#Rewards.Daily, GameConfig.DailyStreakLength, "Rewards: daily ladder length must match GameConfig")
equal(#Rewards.Playtime, GameConfig.PlaytimeRewardCount, "Rewards: playtime ladder length must match GameConfig")
for index = 2, #Rewards.Daily do
	check(
		Rewards.Daily[index].seconds > Rewards.Daily[index - 1].seconds,
		`Rewards: daily day {index} is not worth more than day {index - 1}`
	)
end
for index = 2, #Rewards.Playtime do
	check(
		Rewards.Playtime[index].seconds > Rewards.Playtime[index - 1].seconds,
		`Rewards: playtime rung {index} is not worth more than rung {index - 1}`
	)
end
check(Rewards.playtimeRung(#Rewards.Playtime + 1) == nil, "Rewards: the playtime ladder must end")
check(GameConfig.DailyStreakGrace > 86400, "Rewards: the streak grace window must be longer than a day")

section("Codes")
do
	local seen = {}
	for _, entry in Codes.List do
		local upper = string.upper(entry.code)
		check(seen[upper] == nil, `Codes: duplicate code "{entry.code}"`)
		seen[upper] = true
		check((entry.seconds or 0) > 0 or (entry.stars or 0) > 0, `Codes: "{entry.code}" gives nothing`)
	end
	check(Codes.get("VACANCY") ~= nil, "Codes: exact match should resolve")
	check(Codes.get("vacancy") ~= nil, "Codes: lookup should be case-insensitive")
	check(Codes.get("  vacancy ") ~= nil, "Codes: lookup should tolerate stray whitespace")
	check(Codes.get("NOPE") == nil, "Codes: an unknown code should not resolve")
end

section("Format")
equal(Format.short(0), "0", "short(0)")
equal(Format.short(1000), "1.00K", "short(1000)")
equal(Format.short(1234567), "1.23M", "short(1234567)")
equal(Format.comma(1234567), "1,234,567", "comma(1234567)")
equal(Format.percent(0.55), "55%", "percent(0.55)")
equal(Format.duration(3725), "1h 2m", "duration(3725)")
equal(Format.multiplier(2), "x2", "multiplier(2)")

section("TableUtil and Signal")
do
	local source = { a = 1, nested = { b = 2 } }
	local copy = TableUtil.deepCopy(source)
	copy.nested.b = 99
	equal(source.nested.b, 2, "deepCopy: nested values must not be shared")

	local data = { kept = "yes" }
	TableUtil.reconcile(data, { kept = "no", added = 5 })
	equal(data.kept, "yes", "reconcile: existing values must be left alone")
	equal(data.added, 5, "reconcile: missing values must be filled in")

	local signal = Signal.new()
	local count = 0
	local connection = signal:Connect(function()
		count += 1
	end)
	signal:Fire()
	connection:Disconnect()
	signal:Fire()
	equal(count, 1, "Signal: a disconnected handler must not fire")
end

section("Schema")
do
	local template = Schema.Template
	equal(template.rating, 1, "Schema: a new motel starts at one star")

	-- A motel earns rent only from housed guests, so a profile that starts with
	-- no cash AND no guests has no income and no way to ever get any. The seed
	-- money must at least cover the cheapest guest that can turn up.
	local cheapest = math.huge
	for _, guest in Guests.ByRarity.Common do
		cheapest = math.min(cheapest, Ratings.priceFor(guest))
	end
	check(#template.guests == 0, "Schema: a new profile is expected to start with no guests")
	check(
		template.cash >= cheapest,
		`Schema: a new profile starts with ${template.cash} but the cheapest guest costs ${cheapest} -- `
			.. "a new player would have no income and no way to get any"
	)
	print(`  (seed money ${template.cash}, cheapest guest ${cheapest})`)
	equal(template.rooms, GameConfig.StartingRooms, "Schema: a new motel starts with the starting rooms")
	equal(template.version, Schema.Version, "Schema: template version must match Schema.Version")
	equal(template.objective, 1, "Schema: a new profile starts on the first objective")

	-- The two upgrade maps must be separate and must cover their own configs.
	for _, upgrade in Upgrades.List do
		check(
			template.upgrades[upgrade.id] ~= nil,
			`Schema: template.upgrades is missing "{upgrade.id}"`
		)
		check(
			template.starShop[upgrade.id] == nil,
			`Schema: "{upgrade.id}" is a Cash upgrade but appears in starShop`
		)
	end
	for _, upgrade in Prestige.Upgrades do
		check(
			template.starShop[upgrade.id] ~= nil,
			`Schema: template.starShop is missing "{upgrade.id}"`
		)
		check(
			template.upgrades[upgrade.id] == nil,
			`Schema: "{upgrade.id}" is a Star upgrade but appears in upgrades`
		)
	end

	-- Negative numbers, guests that no longer exist, guests in rooms that no
	-- longer exist, and two guests booked into the same room.
	local broken = TableUtil.deepCopy(template)
	broken.cash = -500
	broken.stars = -3
	broken.rating = 0
	broken.rooms = 0
	broken.objective = 0
	broken.guests = {
		{ uid = "1", guest = "grubling", room = 1 },
		{ uid = "2", guest = "grubling", room = 1 },
		{ uid = "3", guest = "grubling", room = 99 },
		{ uid = "4", guest = "a_guest_that_was_deleted", room = 2 },
	}
	broken.arrivals = {
		{ guest = "grubling", price = 10, takenAt = 0 },
		{ guest = "a_guest_that_was_deleted", price = 10, takenAt = 0 },
	}

	Schema.sanitise(broken)

	equal(broken.cash, 0, "sanitise: negative cash should clamp to zero")
	equal(broken.stars, 0, "sanitise: negative stars should clamp to zero")
	equal(broken.rating, 1, "sanitise: rating should never drop below one")
	equal(broken.objective, 1, "sanitise: the objective pointer should never drop below one")
	equal(broken.rooms, GameConfig.StartingRooms, "sanitise: rooms should never drop below the starting count")
	equal(#broken.guests, 3, "sanitise: a guest whose id no longer exists should be dropped")
	equal(#broken.arrivals, 1, "sanitise: an arrival for a deleted guest should be dropped")

	local occupied = {}
	local stored = 0
	for _, owned in broken.guests do
		if owned.room > 0 then
			check(occupied[owned.room] == nil, `sanitise: room {owned.room} is double-booked`)
			check(owned.room <= broken.rooms, `sanitise: a guest is in room {owned.room} but the motel has {broken.rooms}`)
			occupied[owned.room] = true
		else
			stored += 1
		end
	end
	equal(stored, 2, "sanitise: the double-booked guest and the out-of-range one should go to storage")
end

-- ---------------------------------------------------------------- summary

print("")
if failures == 0 then
	print(`All {checks} checks passed.`)
else
	print(`{failures} of {checks} checks FAILED.`)
end

if failures > 0 then
	error("selftest failed", 0)
end
