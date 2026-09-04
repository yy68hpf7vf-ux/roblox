--!strict
--[[
	Daily quests

	Three quests roll over once per day. Targets scale with rebirth count and
	rewards scale with the best zone the player has unlocked, so a quest is worth
	roughly the same slice of an hour at rebirth 0 and at rebirth 9 -- the list
	never becomes something you ignore.

	Quests refresh on a schedule and expire quietly. Nothing here counts down at
	the player, and no quest can be finished with Robux.
]]

export type QuestKind = "mine_ore" | "break_nodes" | "sell_trips" | "hatch_eggs" | "earn_crystals"

export type QuestDef = {
	id: string,
	kind: QuestKind,
	name: string,
	-- Target at rebirth 0. Scaled by (1 + rebirths * TargetRebirthScale).
	baseTarget: number,
	-- Reward in "seconds of mining at the player's best zone", turned into
	-- Crystals by QuestService. Keeps a quest worth doing at every rebirth.
	rewardSeconds: number,
}

local Quests = {}

Quests.TargetRebirthScale = 0.45

Quests.Pool = {
	{ id = "mine_small", kind = "mine_ore", name = "Fill the pack", baseTarget = 250, rewardSeconds = 240 },
	{ id = "mine_big", kind = "mine_ore", name = "Serious hauling", baseTarget = 900, rewardSeconds = 600 },
	{ id = "nodes_small", kind = "break_nodes", name = "Clear the seam", baseTarget = 40, rewardSeconds = 240 },
	{ id = "nodes_big", kind = "break_nodes", name = "Strip the shelf", baseTarget = 140, rewardSeconds = 600 },
	{ id = "sell_trips", kind = "sell_trips", name = "Regular deliveries", baseTarget = 15, rewardSeconds = 300 },
	{ id = "sell_many", kind = "sell_trips", name = "Run the route", baseTarget = 45, rewardSeconds = 540 },
	{ id = "hatch_few", kind = "hatch_eggs", name = "Something new", baseTarget = 5, rewardSeconds = 300 },
	{ id = "hatch_many", kind = "hatch_eggs", name = "A whole clutch", baseTarget = 20, rewardSeconds = 660 },
	{ id = "earn_day", kind = "earn_crystals", name = "Good day's work", baseTarget = 0, rewardSeconds = 480 },
} :: { QuestDef }

Quests.ById = {} :: { [string]: QuestDef }
for _, quest in Quests.Pool do
	Quests.ById[quest.id] = quest
end

--[[ earn_crystals has no fixed base target -- it is expressed as seconds of
     income, resolved by QuestService against the player's own progression. ]]
Quests.EarnCrystalsSeconds = 900

function Quests.targetFor(def: QuestDef, rebirths: number): number
	return math.max(1, math.floor(def.baseTarget * (1 + rebirths * Quests.TargetRebirthScale)))
end

--[[ Picks the day's quests deterministically from a day number, so every server
     running on the same day offers the same three and a player cannot reroll by
     rejoining. ]]
function Quests.pickForDay(dayNumber: number, count: number): { string }
	local rng = Random.new(dayNumber * 7919)
	local bag = {}
	for _, def in Quests.Pool do
		table.insert(bag, def.id)
	end
	-- Fisher-Yates over a copy, then take the first `count`.
	for index = #bag, 2, -1 do
		local swap = rng:NextInteger(1, index)
		bag[index], bag[swap] = bag[swap], bag[index]
	end
	local picked = {}
	for index = 1, math.min(count, #bag) do
		table.insert(picked, bag[index])
	end
	return picked
end

return Quests
