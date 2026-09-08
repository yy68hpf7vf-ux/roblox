--!strict
--[[
	Objectives

	One goal at a time, in order, shown as a chip on the HUD.

	This exists because the game is not self-explanatory. A new player spawns in
	front of a building with no guests, a road full of monsters they have to pay
	for, and a night cycle nobody has told them about. Without a nudge, most of them
	stand still for thirty seconds and leave -- and the systems underneath never get
	a chance to do their job.

	The list is finite and it ends. Once somebody has run a raid and renovated once
	they have seen the whole game, and the chip gets out of the way rather than
	inventing errands forever.

	Each objective's `progress` reads only the profile, so the same function drives
	the chip on the client and the completion check on the server, and the two can
	never disagree about whether something is done.
]]

local Schema = require(script.Parent.Parent.Schema)

export type Objective = {
	id: string,
	name: string,
	hint: string,
	-- Reward in seconds of the player's own rent, resolved at claim time.
	rewardSeconds: number,
	progress: (Schema.Profile) -> (number, number),
}

local Objectives = {}

Objectives.List = {
	{
		id = "first_guest",
		name = "Check in your first guest",
		hint = "Open Arrivals and buy whoever is on the road. They start paying rent immediately.",
		rewardSeconds = 90,
		progress = function(profile)
			return profile.stats.checkIns, 1
		end,
	},
	{
		id = "first_collect",
		name = "Collect your rent",
		hint = "Rent fills your safe. Walk onto the green front desk outside your motel to bank it.",
		rewardSeconds = 90,
		progress = function(profile)
			return profile.stats.collected > 0 and 1 or 0, 1
		end,
	},
	{
		id = "fill_rooms",
		name = "Fill all three rooms",
		hint = "Only guests in a room pay rent. Check in two more.",
		rewardSeconds = 150,
		progress = function(profile)
			local housed = 0
			for _, owned in profile.guests do
				if owned.room > 0 then
					housed += 1
				end
			end
			return housed, 3
		end,
	},
	{
		id = "buy_room",
		name = "Build a fourth room",
		hint = "The Motel window sells rooms. More rooms means more guests paying at once.",
		rewardSeconds = 200,
		progress = function(profile)
			return profile.rooms, 4
		end,
	},
	{
		id = "two_star",
		name = "Reach Two Star",
		hint = "A better rating attracts better guests. Buy it in the Motel window.",
		rewardSeconds = 300,
		progress = function(profile)
			return profile.rating, 2
		end,
	},
	{
		id = "buy_lock",
		name = "Fit a lock on your door",
		hint = "At Lights Out anyone can break in. A lock makes them work for it.",
		rewardSeconds = 300,
		progress = function(profile)
			return profile.lockLevel, 1
		end,
	},
	{
		id = "survive_night",
		name = "Get through a night",
		hint = "Stay near your motel when the lights go out. Nobody can rob you in your first ten minutes anyway.",
		rewardSeconds = 360,
		progress = function(profile)
			return profile.stats.nightsSurvived, 1
		end,
	},
	{
		id = "buy_shoes",
		name = "Buy Running Shoes",
		hint = "In the Upgrades tab. Faster everywhere -- though never while carrying a guest.",
		rewardSeconds = 400,
		progress = function(profile)
			return profile.upgrades.shoes or 0, 1
		end,
	},
	{
		id = "first_raid",
		name = "Raid another motel",
		hint = "Wait for Lights Out, hold E on somebody's door, then carry a guest back to your own front desk.",
		rewardSeconds = 500,
		progress = function(profile)
			return profile.stats.guestsStolen, 1
		end,
	},
	{
		id = "celebrity",
		name = "Catch a celebrity",
		hint = "One lands in the town square every ten minutes. Anyone can knock them out of your arms, so run.",
		rewardSeconds = 700,
		progress = function(profile)
			return profile.stats.celebritiesCaught, 1
		end,
	},
	{
		id = "renovate",
		name = "Renovate once",
		hint = "At Four Star you can trade the building for a permanent multiplier. You keep every guest.",
		rewardSeconds = 900,
		progress = function(profile)
			return profile.renovations, 1
		end,
	},
} :: { Objective }

Objectives.ById = {} :: { [string]: Objective }
for _, objective in Objectives.List do
	Objectives.ById[objective.id] = objective
end

Objectives.Count = #Objectives.List

function Objectives.get(index: number): Objective?
	return Objectives.List[index]
end

--[[ Whether the objective at `index` is satisfied by this profile. Objectives are
     never un-completed, so this is only ever asked about the current one. ]]
function Objectives.isComplete(index: number, profile: Schema.Profile): boolean
	local objective = Objectives.List[index]
	if not objective then
		return false
	end
	local current, target = objective.progress(profile)
	return current >= target
end

return Objectives
