--!strict
--[[
	ObjectiveService

	Advances the one-at-a-time objective chip and pays out when it completes.

	Completion is checked on every state change rather than polled, which means an
	objective clears the instant the thing happens -- you walk onto your front desk
	and the chip flips before you have stepped off it. A tutorial that lags behind
	the player is worse than none at all, because they stop believing it.

	Rewards are in seconds of the player's own rent, so the early ones are a
	meaningful boost when a motel earns almost nothing and are not still handing out
	free money at rating 7.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Objectives = require(Shared.Config.Objectives)
local Schema = require(Shared.Schema)

local EconomyService = require(script.Parent.EconomyService)
local Remote = require(script.Parent.Remote)

type Profile = Schema.Profile

local ObjectiveService = {}

-- Guards against re-entry: granting cash marks the player dirty, which is what
-- triggers the next check.
local advancing: { [Player]: boolean } = {}

--[[ Completes as many objectives as the profile now satisfies. More than one can
     clear at once -- checking in three guests finishes "first guest" and "fill all
     three rooms" together -- and each pays out. ]]
function ObjectiveService.check(player: Player, profile: Profile)
	if advancing[player] then
		return
	end
	advancing[player] = true

	local completed = 0
	while profile.objective <= Objectives.Count and Objectives.isComplete(profile.objective, profile) do
		local objective = Objectives.get(profile.objective)
		if not objective then
			break
		end

		profile.objective += 1
		completed += 1

		local reward = EconomyService.secondsToCash(player, profile, objective.rewardSeconds, 400)
		EconomyService.addCash(player, profile, reward)

		Remote.notify(player, `{objective.name} -- done. +${Format.short(reward)}`, "good")
		Remote.effect(player, "objectiveComplete", { id = objective.id, reward = reward })

		-- A safety valve: if a config change ever made an objective complete on
		-- the frame it appears, this stops it running the whole list at once.
		if completed >= Objectives.Count then
			break
		end
	end

	advancing[player] = nil

	if completed > 0 and profile.objective > Objectives.Count then
		Remote.notify(player, "That is the whole game. Now go and build the biggest motel in town.", "good")
	end
end

--[[ What the HUD chip shows, or nil once the list is finished. ]]
function ObjectiveService.view(profile: Profile): { [string]: any }?
	local objective = Objectives.get(profile.objective)
	if not objective then
		return nil
	end

	local current, target = objective.progress(profile)
	return {
		id = objective.id,
		index = profile.objective,
		total = Objectives.Count,
		name = objective.name,
		hint = objective.hint,
		progress = math.min(current, target),
		target = target,
	}
end

function ObjectiveService.start()
	local DataService = require(script.Parent.DataService)

	DataService.Loaded:Connect(function(player, profile)
		ObjectiveService.check(player, profile)
	end)

	EconomyService.Changed:Connect(function(player)
		local profile = DataService.get(player)
		if profile then
			ObjectiveService.check(player, profile)
		end
	end)
end

return ObjectiveService
