--!strict
--[[
	QuestService

	Three quests a day, rolled from the day number so every server agrees and
	rejoining cannot reroll them. Progress is server-side only -- the client never
	reports a quest as done, it renders what the server sends.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Quests = require(Shared.Config.Quests)
local Schema = require(Shared.Schema)

local EconomyService = require(script.Parent.EconomyService)

type Profile = Schema.Profile

local QuestService = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

function QuestService.ensureDaily(player: Player, profile: Profile)
	local day = today()
	if profile.quests.day == day and #profile.quests.list > 0 then
		return
	end

	local picked = Quests.pickForDay(day, GameConfig.DailyQuestCount)
	local list: { Schema.QuestState } = {}
	for _, id in picked do
		table.insert(list, { id = id, progress = 0, claimed = false })
	end

	profile.quests.day = day
	profile.quests.list = list
	EconomyService.markDirty(player)
end

--[[ Targets and rewards resolve fresh every time rather than freezing into the
     save, so a player who upgrades their rating mid-day sees the quest scale with
     them instead of being stuck on this morning's numbers. ]]
function QuestService.targetFor(player: Player, profile: Profile, def: Quests.QuestDef): number
	if def.kind == "collect_cash" then
		local seconds = if def.id == "collect_big" then Quests.CollectSecondsBig else Quests.CollectSecondsSmall
		return EconomyService.secondsToCash(player, profile, seconds, 2000)
	end
	return Quests.targetFor(def, profile.rating)
end

function QuestService.rewardFor(player: Player, profile: Profile, def: Quests.QuestDef): number
	return EconomyService.secondsToCash(player, profile, def.rewardSeconds, 1000)
end

function QuestService.view(player: Player, profile: Profile): { { [string]: any } }
	QuestService.ensureDaily(player, profile)

	local out = {}
	for _, state in profile.quests.list do
		local def = Quests.ById[state.id]
		if def then
			local target = QuestService.targetFor(player, profile, def)
			table.insert(out, {
				id = state.id,
				name = def.name,
				kind = def.kind,
				progress = math.min(state.progress, target),
				target = target,
				reward = QuestService.rewardFor(player, profile, def),
				claimed = state.claimed,
				complete = state.progress >= target,
			})
		end
	end
	return out
end

function QuestService.addProgress(player: Player, profile: Profile, kind: Quests.QuestKind, amount: number)
	if amount <= 0 then
		return
	end
	QuestService.ensureDaily(player, profile)

	local changed = false
	for _, state in profile.quests.list do
		local def = Quests.ById[state.id]
		if def and def.kind == kind and not state.claimed then
			state.progress += amount
			changed = true
		end
	end

	if changed then
		EconomyService.markDirty(player)
	end
end

function QuestService.claim(player: Player, profile: Profile, questId: string): (boolean, string)
	QuestService.ensureDaily(player, profile)

	for _, state in profile.quests.list do
		if state.id == questId then
			if state.claimed then
				return false, "Already claimed."
			end
			local def = Quests.ById[questId]
			if not def then
				return false, "That quest is no longer available."
			end

			local target = QuestService.targetFor(player, profile, def)
			if state.progress < target then
				return false, "Not finished yet."
			end

			state.claimed = true
			EconomyService.addCash(player, profile, QuestService.rewardFor(player, profile, def))
			return true, `{def.name} complete.`
		end
	end

	return false, "No such quest."
end

return QuestService
