--!strict
--[[
	Daily quests

	Three roll over each day, picked from the day number so every server agrees and
	rejoining cannot reroll them.

	Rewards are expressed in seconds of the player's own rent and converted at claim
	time, so a quest is worth roughly the same slice of an hour at rating 1 and at
	rating 7. Targets scale with rating for the same reason.

	Note the mix: two of the nine push you into other people's motels, two reward
	getting through a night without losing anyone. Rewarding only the raiding half
	would turn the server into a place nobody wants to defend in.
]]

export type QuestKind = "check_in" | "collect_cash" | "steal_guests" | "survive_nights" | "upgrades"

export type QuestDef = {
	id: string,
	kind: QuestKind,
	name: string,
	-- Target at rating 1. Scaled by (1 + (rating - 1) * TargetRatingScale).
	baseTarget: number,
	rewardSeconds: number,
}

local Quests = {}

Quests.TargetRatingScale = 0.35

Quests.Pool = {
	{ id = "checkin_few", kind = "check_in", name = "Fill the vacancies", baseTarget = 6, rewardSeconds = 240 },
	{ id = "checkin_many", kind = "check_in", name = "No vacancy", baseTarget = 18, rewardSeconds = 600 },
	{ id = "collect_small", kind = "collect_cash", name = "Clear the safe", baseTarget = 0, rewardSeconds = 300 },
	{ id = "collect_big", kind = "collect_cash", name = "A good week's takings", baseTarget = 0, rewardSeconds = 660 },
	{ id = "steal_one", kind = "steal_guests", name = "Poach a guest", baseTarget = 1, rewardSeconds = 360 },
	{ id = "steal_three", kind = "steal_guests", name = "Busy night out", baseTarget = 3, rewardSeconds = 720 },
	{ id = "survive_one", kind = "survive_nights", name = "Hold the door", baseTarget = 1, rewardSeconds = 300 },
	{ id = "survive_three", kind = "survive_nights", name = "Nobody got in", baseTarget = 3, rewardSeconds = 700 },
	{ id = "upgrades", kind = "upgrades", name = "Renovate a little", baseTarget = 4, rewardSeconds = 420 },
} :: { QuestDef }

Quests.ById = {} :: { [string]: QuestDef }
for _, quest in Quests.Pool do
	Quests.ById[quest.id] = quest
end

-- collect_cash has no fixed target; it is expressed as seconds of the player's
-- own rent and resolved by QuestService against their motel.
Quests.CollectSecondsSmall = 900
Quests.CollectSecondsBig = 2400

function Quests.targetFor(def: QuestDef, rating: number): number
	local scaled = def.baseTarget * (1 + math.max(0, rating - 1) * Quests.TargetRatingScale)
	return math.max(1, math.floor(scaled))
end

--[[ Picks the day's quests deterministically from a day number. Every server
     running today offers the same three. ]]
function Quests.pickForDay(dayNumber: number, count: number): { string }
	local rng = Random.new(dayNumber * 7919)
	local bag = {}
	for _, def in Quests.Pool do
		table.insert(bag, def.id)
	end
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
