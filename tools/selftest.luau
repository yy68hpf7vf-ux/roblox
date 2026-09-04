--!nocheck
--[[
	Config self-test -- assertions.

	Runs the shared layer (every config table, Format, Signal, TableUtil and
	Schema) outside Roblox and checks the invariants the rest of the game assumes.
	It catches the class of bug a parser cannot: an egg pointing at a pet id that
	was renamed, a price curve that goes backwards, odds that do not sum to one, a
	rarity with no colour. All of those are silent until a player finds them.

	Do not run this file directly -- it expects `shared()` and `Random` from the
	bundle that wraps it. Run:

	    python3 tools/selftest.py

	which stubs the Roblox globals, wraps each module so `script` and `require`
	arrive as parameters, and hands the whole thing to the luau interpreter.
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

local function section(name)
	print("\n" .. name)
end

local function near(actual, expected, tolerance, message)
	checks += 1
	if math.abs(actual - expected) > tolerance then
		failures += 1
		print(`  FAIL  {message}: expected ~{expected}, got {actual}`)
	end
end

-- ---------------------------------------------------------------- load config

local GameConfig = shared("Config", "GameConfig")
local Tools = shared("Config", "Tools")
local Backpacks = shared("Config", "Backpacks")
local Zones = shared("Config", "Zones")
local Pets = shared("Config", "Pets")
local Eggs = shared("Config", "Eggs")
local Rebirths = shared("Config", "Rebirths")
local Quests = shared("Config", "Quests")
local Rewards = shared("Config", "Rewards")
local Codes = shared("Config", "Codes")
local Monetization = shared("Config", "Monetization")
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

-- ---------------------------------------------------------------- tests

section("Identity")
uniqueIds(Tools.List, "Tools")
uniqueIds(Backpacks.List, "Backpacks")
uniqueIds(Zones.List, "Zones")
uniqueIds(Pets.List, "Pets")
uniqueIds(Eggs.List, "Eggs")
uniqueIds(Monetization.Gamepasses, "Gamepasses")
uniqueIds(Monetization.Products, "Products")

section("Progression curves")
for index = 2, #Tools.List do
	local previous, current = Tools.List[index - 1], Tools.List[index]
	check(current.price > previous.price, `Tools: {current.id} is not more expensive than {previous.id}`)
	check(current.power > previous.power, `Tools: {current.id} is not stronger than {previous.id}`)
	check(current.rebirths >= previous.rebirths, `Tools: {current.id} needs fewer rebirths than {previous.id}`)
end

for index = 2, #Backpacks.List do
	local previous, current = Backpacks.List[index - 1], Backpacks.List[index]
	check(current.price > previous.price, `Backpacks: {current.id} is not more expensive than {previous.id}`)
	check(current.capacity > previous.capacity, `Backpacks: {current.id} does not hold more than {previous.id}`)
	check(current.rebirths >= previous.rebirths, `Backpacks: {current.id} needs fewer rebirths than {previous.id}`)
end

local freeZones = {}
for _, zone in Zones.List do
	if not zone.gamepass then
		table.insert(freeZones, zone)
	end
end

for index = 2, #freeZones do
	local previous, current = freeZones[index - 1], freeZones[index]
	check(current.oreValue > previous.oreValue, `Zones: {current.id} does not pay more than {previous.id}`)
	check(current.unlockCost > previous.unlockCost, `Zones: {current.id} is not dearer than {previous.id}`)
	check(current.rebirths >= previous.rebirths, `Zones: {current.id} needs fewer rebirths than {previous.id}`)
end

check(Tools.List[1].price == 0, "Tools: the starter pick must be free")
check(Backpacks.List[1].price == 0, "Backpacks: the starter pack must be free")
check(Zones.List[1].unlockCost == 0, "Zones: the starting zone must be free")

section("Gamepass zones are a shortcut, not a wall")
for _, zone in Zones.List do
	if zone.gamepass then
		check(
			Monetization.GamepassById[zone.gamepass] ~= nil,
			`Zones: {zone.id} points at unknown gamepass "{zone.gamepass}"`
		)
		-- A paid zone must sit between two free ones in value, so the free path
		-- always overtakes it.
		local better, worse = false, false
		for _, other in freeZones do
			if other.oreValue > zone.oreValue then
				better = true
			end
			if other.oreValue < zone.oreValue then
				worse = true
			end
		end
		check(better, `Zones: {zone.id} is the best-paying zone in the game and is behind a gamepass`)
		check(worse, `Zones: {zone.id} is worse than every free zone, which makes the pass pointless`)
	end
end

section("Zone economy")
for _, zone in Zones.List do
	check(zone.orePerPower > 0, `Zones: {zone.id} has no ore yield`)
	check(zone.nodeHealth > 0, `Zones: {zone.id} has a node with no health`)
	check(zone.nodeCount > 0, `Zones: {zone.id} has no nodes`)
	equal(Zones.orePerSwing(zone, 10), 10 * zone.orePerPower, `Zones: orePerSwing wrong for {zone.id}`)
end

section("Pets")
for _, pet in Pets.List do
	check(pet.mult > 0, `Pets: {pet.id} has no multiplier`)
	check(Pets.RarityColor[pet.rarity] ~= nil, `Pets: {pet.id} has rarity "{pet.rarity}" with no colour`)
	check(table.find(Pets.RarityOrder, pet.rarity) ~= nil, `Pets: {pet.id} has unranked rarity "{pet.rarity}"`)
end

equal(Pets.multiplierFor({}), 1, "Pets: no pets equipped should be x1")
equal(
	Pets.multiplierFor({ "pebblepup", "mossmoth" }),
	1 + Pets.ById.pebblepup.mult + Pets.ById.mossmoth.mult,
	"Pets: equipped multipliers should add"
)
equal(Pets.multiplierFor({ "does_not_exist" }), 1, "Pets: an unknown id should be ignored, not fatal")

local sorted = Pets.sortByPower({ "pebblepup", "greenwarden", "mossmoth" })
equal(sorted[1], "greenwarden", "Pets: sortByPower should put the strongest first")

section("Egg odds")
for _, egg in Eggs.List do
	check(Zones.ById[egg.zone] ~= nil, `Eggs: {egg.id} lives in unknown zone "{egg.zone}"`)
	check(egg.price > 0, `Eggs: {egg.id} is free`)

	local total = Eggs.totalWeight(egg)
	equal(total, 1000, `Eggs: {egg.id} weights should total 1000 so a weight reads as a tenth of a percent`)

	local sum = 0
	for _, entry in Eggs.odds(egg) do
		check(Pets.ById[entry.pet] ~= nil, `Eggs: {egg.id} references unknown pet "{entry.pet}"`)
		check(entry.chance > 0, `Eggs: {egg.id} lists {entry.pet} at a zero chance`)
		sum += entry.chance
	end
	near(sum, 1, 1e-9, `Eggs: {egg.id} odds do not sum to 100%`)

	-- Rarer pets must be worth more, or the odds are lying about what they buy.
	local pool = egg.pool
	for index = 2, #pool do
		local previous = Pets.ById[pool[index - 1].pet]
		local current = Pets.ById[pool[index].pet]
		check(
			current.mult > previous.mult,
			`Eggs: {egg.id} lists {current.id} after {previous.id} but it is not stronger`
		)
		check(
			pool[index].weight <= pool[index - 1].weight,
			`Eggs: {egg.id} makes {current.id} at least as likely as the commoner {previous.id}`
		)
	end
end

section("Egg rolls match the printed odds")
do
	local egg = Eggs.ById.basic
	local rng = Random.new(12345)
	local counts = {}
	local samples = 60000

	for _ = 1, samples do
		local id = Eggs.roll(egg, rng)
		counts[id] = (counts[id] or 0) + 1
	end

	for _, entry in Eggs.odds(egg) do
		local observed = (counts[entry.pet] or 0) / samples
		-- Loose enough not to be flaky, tight enough to catch a mis-weighted pool.
		near(observed, entry.chance, 0.02, `Eggs: basic egg rolls {entry.pet} at the wrong rate`)
	end
end

section("Rebirths")
for level = 0, 9 do
	check(
		Rebirths.costFor(level + 1) > Rebirths.costFor(level),
		`Rebirths: cost does not rise from {level} to {level + 1}`
	)
	check(
		Rebirths.multiplierFor(level + 1) > Rebirths.multiplierFor(level),
		`Rebirths: multiplier does not rise from {level} to {level + 1}`
	)
	check(Rebirths.coresFor(level) > 0, `Rebirths: rebirth {level} pays no Cores`)
end
equal(Rebirths.multiplierFor(0), 1, "Rebirths: rebirth 0 must be x1")

for _, upgrade in Rebirths.Upgrades do
	check(upgrade.maxLevel > 0, `Core Shop: {upgrade.id} cannot be levelled`)
	for level = 0, math.min(upgrade.maxLevel, 8) - 1 do
		check(
			Rebirths.upgradeCost(upgrade, level + 1) > Rebirths.upgradeCost(upgrade, level),
			`Core Shop: {upgrade.id} does not get dearer at level {level + 1}`
		)
	end
	equal(
		Rebirths.upgradeMultiplier(upgrade.id, 0),
		1,
		`Core Shop: {upgrade.id} at level 0 should be neutral`
	)
end

do
	-- Every Core in the game comes from a rebirth, so the shop has to be
	-- affordable out of what rebirths actually mint.
	local totalCost = 0
	for _, upgrade in Rebirths.Upgrades do
		totalCost += Rebirths.upgradeTotalCost(upgrade)
	end

	local minted, rebirthsNeeded = 0, 0
	while minted < totalCost and rebirthsNeeded < 500 do
		minted += Rebirths.coresFor(rebirthsNeeded)
		rebirthsNeeded += 1
	end

	check(
		rebirthsNeeded < 100,
		`Core Shop: maxing everything costs {totalCost} Cores, which takes {rebirthsNeeded} rebirths`
	)
	print(`  (maxing the Core Shop costs {totalCost} Cores -- about {rebirthsNeeded} rebirths)`)
end
equal(Rebirths.upgradeMultiplier("not_a_real_upgrade", 5), 1, "Core Shop: unknown upgrade should be neutral")

section("Quests")
do
	local picked = Quests.pickForDay(20000, GameConfig.DailyQuestCount)
	equal(#picked, GameConfig.DailyQuestCount, "Quests: wrong number picked for a day")

	local again = Quests.pickForDay(20000, GameConfig.DailyQuestCount)
	for index, id in picked do
		equal(again[index], id, "Quests: the same day must always pick the same quests")
		check(Quests.ById[id] ~= nil, `Quests: picked unknown quest "{id}"`)
	end

	local seen = {}
	for _, id in picked do
		check(seen[id] == nil, `Quests: picked "{id}" twice in one day`)
		seen[id] = true
	end

	local different = false
	for day = 20001, 20020 do
		local other = Quests.pickForDay(day, GameConfig.DailyQuestCount)
		if other[1] ~= picked[1] then
			different = true
		end
	end
	check(different, "Quests: every day picks the same first quest, so they never rotate")

	for _, def in Quests.Pool do
		check(def.rewardSeconds > 0, `Quests: {def.id} pays nothing`)
		local atZero = Quests.targetFor(def, 0)
		local atFive = Quests.targetFor(def, 5)
		check(atFive >= atZero, `Quests: {def.id} gets easier with rebirths`)
		check(atZero >= 1, `Quests: {def.id} has a target below 1`)
	end
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
check(Rewards.playtimeRung(#Rewards.Playtime + 1) == nil, "Rewards: playtime ladder must end")
check(GameConfig.DailyStreakGrace > 86400, "Rewards: the streak grace window must be longer than a day")

section("Codes")
do
	local seen = {}
	for _, entry in Codes.List do
		local upper = string.upper(entry.code)
		check(seen[upper] == nil, `Codes: duplicate code "{entry.code}"`)
		seen[upper] = true
		check((entry.seconds or 0) > 0 or (entry.cores or 0) > 0, `Codes: "{entry.code}" gives nothing`)
	end

	check(Codes.get("RIFTOPEN") ~= nil, "Codes: exact match should resolve")
	check(Codes.get("riftopen") ~= nil, "Codes: lookup should be case-insensitive")
	check(Codes.get("  riftopen ") ~= nil, "Codes: lookup should tolerate stray whitespace")
	check(Codes.get("NOPE") == nil, "Codes: an unknown code should not resolve")
end

section("Monetization")
do
	-- Asset ids are 0 until the place is published. Either state is valid; what
	-- must never happen is two items pointing at the same id, which would grant
	-- the wrong thing.
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
		checkAsset("Gamepasses", pass.id, pass.assetId)
	end
	for _, product in Monetization.Products do
		checkAsset("Products", product.id, product.assetId)
	end

	local total = #Monetization.Gamepasses + #Monetization.Products
	if configured == 0 then
		print(`  (no asset ids set yet -- all {total} store items are hidden in game)`)
	elseif configured < total then
		print(`  ({configured} of {total} store items have asset ids; the rest stay hidden)`)
	end
end

for _, pass in Monetization.Gamepasses do
	check(#pass.name > 0 and #pass.desc > 0, `Gamepasses: {pass.id} has no name or description`)
end
for _, product in Monetization.Products do
	check(#product.name > 0 and #product.desc > 0, `Products: {product.id} has no name or description`)
	if product.kind == "crystals" then
		check((product.seconds or 0) > 0, `Products: {product.id} grants no crystals`)
		check((product.floor or 0) > 0, `Products: {product.id} has no floor for new players`)
	else
		check((product.multiplier or 0) > 1, `Products: {product.id} is a boost that boosts nothing`)
		check((product.duration or 0) > 0, `Products: {product.id} is a boost with no duration`)
	end
end
check(Monetization.MaxBoostSeconds > 0, "Monetization: boosts must have a stacking cap")

-- The rule the whole design rests on: nothing random is bought with Robux.
for _, product in Monetization.Products do
	check(
		product.kind == "crystals" or product.kind == "boost",
		`Products: {product.id} is a "{product.kind}" -- only deterministic kinds may be sold`
	)
end

section("Format")
equal(Format.short(0), "0", "short(0)")
equal(Format.short(999), "999", "short(999)")
equal(Format.short(1000), "1.00K", "short(1000)")
equal(Format.short(1500), "1.50K", "short(1500)")
equal(Format.short(12345), "12.3K", "short(12345)")
equal(Format.short(123456), "123K", "short(123456)")
equal(Format.short(1234567), "1.23M", "short(1234567)")
equal(Format.short(-1500), "-1.50K", "short(-1500)")
equal(Format.short(1e12), "1.00T", "short(1e12)")

equal(Format.comma(0), "0", "comma(0)")
equal(Format.comma(999), "999", "comma(999)")
equal(Format.comma(1000), "1,000", "comma(1000)")
equal(Format.comma(123456), "123,456", "comma(123456)")
equal(Format.comma(1234567), "1,234,567", "comma(1234567)")
equal(Format.comma(-1234), "-1,234", "comma(-1234)")

equal(Format.percent(0.55), "55%", "percent(0.55)")
equal(Format.percent(0.035), "3.5%", "percent(0.035)")
equal(Format.percent(0.005), "0.50%", "percent(0.005)")
equal(Format.percent(0.001), "0.10%", "percent(0.001)")
equal(Format.percent(0.0005), "0.050%", "percent should keep digits below a tenth of a percent")

equal(Format.duration(30), "30s", "duration(30)")
equal(Format.duration(65), "1m 5s", "duration(65)")
equal(Format.duration(3725), "1h 2m", "duration(3725)")
equal(Format.duration(-5), "0s", "duration of a negative should clamp")

equal(Format.multiplier(2), "x2", "multiplier(2)")
equal(Format.multiplier(1.5), "x1.50", "multiplier(1.5)")

section("TableUtil")
do
	local source = { a = 1, nested = { b = 2, list = { 1, 2, 3 } } }
	local copy = TableUtil.deepCopy(source)
	copy.nested.b = 99
	copy.nested.list[1] = 99
	equal(source.nested.b, 2, "deepCopy: nested values must not be shared")
	equal(source.nested.list[1], 1, "deepCopy: nested arrays must not be shared")

	local data = { kept = "yes", nested = { existing = 1 } }
	TableUtil.reconcile(data, { kept = "no", added = 5, nested = { existing = 0, alsoAdded = 7 } })
	equal(data.kept, "yes", "reconcile: existing values must be left alone")
	equal(data.added, 5, "reconcile: missing values must be filled in")
	equal(data.nested.alsoAdded, 7, "reconcile: nested missing values must be filled in")
	equal(data.nested.existing, 1, "reconcile: nested existing values must be left alone")

	equal(TableUtil.count({ a = 1, b = 2 }), 2, "count")
	equal(#TableUtil.keys({ a = 1, b = 2 }), 2, "keys")
end

section("Signal")
do
	local signal = Signal.new()
	local seen = {}
	local connection = signal:Connect(function(value)
		table.insert(seen, value)
	end)

	signal:Fire("one")
	equal(#seen, 1, "Signal: a connected handler should fire")
	equal(seen[1], "one", "Signal: arguments should pass through")

	connection:Disconnect()
	signal:Fire("two")
	equal(#seen, 1, "Signal: a disconnected handler must not fire")

	local onceCount = 0
	signal:Once(function()
		onceCount += 1
	end)
	signal:Fire()
	signal:Fire()
	equal(onceCount, 1, "Signal: Once should fire exactly once")

	signal:Connect(function() end)
	signal:DisconnectAll()
	signal:Fire()
	equal(onceCount, 1, "Signal: DisconnectAll should remove everything")
end

section("Schema")
do
	local template = Schema.Template
	equal(template.tool, Tools.Starter, "Schema: template must hold the starter pick")
	equal(template.backpack, Backpacks.Starter, "Schema: template must hold the starter pack")
	equal(template.zone, Zones.Starter, "Schema: template must start in the first zone")
	check(template.ownedTools[Tools.Starter], "Schema: template must own the starter pick")
	check(template.unlockedZones[Zones.Starter], "Schema: template must have the first zone unlocked")
	equal(template.version, Schema.Version, "Schema: template version must match Schema.Version")

	local broken = TableUtil.deepCopy(template)
	broken.tool = "a_pick_that_was_deleted"
	broken.backpack = "a_pack_that_was_deleted"
	broken.zone = "a_zone_that_was_deleted"
	broken.crystals = -500
	broken.rebirths = -3
	broken.ownedTools = {}
	broken.unlockedZones = {}

	Schema.sanitise(broken)

	equal(broken.tool, Tools.Starter, "sanitise: an unknown pick should fall back to the starter")
	equal(broken.backpack, Backpacks.Starter, "sanitise: an unknown pack should fall back to the starter")
	equal(broken.zone, Zones.Starter, "sanitise: an unknown zone should fall back to the starter")
	equal(broken.crystals, 0, "sanitise: negative crystals should clamp to zero")
	equal(broken.rebirths, 0, "sanitise: negative rebirths should clamp to zero")
	check(broken.ownedTools[Tools.Starter], "sanitise: the starter pick must always be owned")
	check(broken.unlockedZones[Zones.Starter], "sanitise: the first zone must always be unlocked")

	-- A profile that claims to own a pick it does not have in its owned list must
	-- not keep it equipped.
	local liar = TableUtil.deepCopy(template)
	liar.tool = "riftbreaker"
	Schema.sanitise(liar)
	equal(liar.tool, Tools.Starter, "sanitise: an unowned pick must not stay equipped")
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
