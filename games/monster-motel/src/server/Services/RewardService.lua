--!strict
--[[
	RewardService

	Two ladders: a daily login streak and a playtime ladder that resets each day.

	The streak is forgiving on purpose. It only breaks if a player is away longer
	than GameConfig.DailyStreakGrace, so missing one evening costs nothing. A
	streak that punishes a missed day converts a good habit into an obligation,
	and the people it hurts most are the ones who cannot log in on demand.

	The playtime ladder ends at its last rung and stays ended. It is a thank-you
	for an hour, not a reason to leave the game open overnight.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Rewards = require(Shared.Config.Rewards)
local Schema = require(Shared.Schema)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

type Profile = Schema.Profile

local RewardService = {}

local TICK = 5

local function today(): number
	return math.floor(os.time() / 86400)
end

-- ---------------------------------------------------------------- daily

function RewardService.dailyAvailable(profile: Profile): boolean
	if profile.daily.lastClaimAt == 0 then
		return true
	end
	return math.floor(profile.daily.lastClaimAt / 86400) < today()
end

local function nextStreak(profile: Profile): number
	local elapsed = os.time() - profile.daily.lastClaimAt
	if profile.daily.lastClaimAt == 0 or elapsed > GameConfig.DailyStreakGrace then
		return 1
	end
	return profile.daily.streak + 1
end

--[[ The ladder cycles: streak 8 pays the Day 1 rung again, streak 14 the Day 7
     rung. Nobody falls off the end of the rewards for being a regular. ]]
function RewardService.rungForStreak(streak: number): Rewards.Rung
	return Rewards.dailyRung(((math.max(1, streak) - 1) % GameConfig.DailyStreakLength) + 1)
end

function RewardService.dailyView(player: Player, profile: Profile): { [string]: any }
	local upcoming = nextStreak(profile)
	local rung = RewardService.rungForStreak(upcoming)
	return {
		available = RewardService.dailyAvailable(profile),
		streak = profile.daily.streak,
		nextStreak = upcoming,
		label = rung.label,
		cash = EconomyService.secondsToCash(player, profile, rung.seconds, 250),
		stars = rung.stars or 0,
	}
end

function RewardService.claimDaily(player: Player, profile: Profile): (boolean, string)
	if not RewardService.dailyAvailable(profile) then
		return false, "You have already claimed today. Come back tomorrow."
	end

	local streak = nextStreak(profile)
	local rung = RewardService.rungForStreak(streak)
	local cash = EconomyService.secondsToCash(player, profile, rung.seconds, 250)

	profile.daily.streak = streak
	profile.daily.lastClaimAt = os.time()

	EconomyService.addCash(player, profile, cash)
	if rung.stars then
		EconomyService.addStars(player, profile, rung.stars)
	end

	return true, `Day {streak} claimed.`
end

-- ---------------------------------------------------------------- playtime

local function resetPlaytimeIfNewDay(profile: Profile): boolean
	local day = today()
	if profile.playtime.day ~= day then
		profile.playtime.day = day
		profile.playtime.seconds = 0
		profile.playtime.claimedStep = 0
		return true
	end
	return false
end

function RewardService.playtimeView(player: Player, profile: Profile): { [string]: any }
	resetPlaytimeIfNewDay(profile)

	local reached = math.floor(profile.playtime.seconds / GameConfig.PlaytimeRewardInterval)
	reached = math.min(reached, #Rewards.Playtime)

	local nextStep = math.min(profile.playtime.claimedStep + 1, #Rewards.Playtime)
	local rung = Rewards.playtimeRung(nextStep)

	return {
		seconds = profile.playtime.seconds,
		interval = GameConfig.PlaytimeRewardInterval,
		reached = reached,
		claimed = profile.playtime.claimedStep,
		total = #Rewards.Playtime,
		nextLabel = if rung then rung.label else "",
		nextCash = if rung then EconomyService.secondsToCash(player, profile, rung.seconds, 150) else 0,
		canClaim = reached > profile.playtime.claimedStep,
		finished = profile.playtime.claimedStep >= #Rewards.Playtime,
	}
end

function RewardService.claimPlaytime(player: Player, profile: Profile): (boolean, string)
	resetPlaytimeIfNewDay(profile)

	local reached = math.min(
		math.floor(profile.playtime.seconds / GameConfig.PlaytimeRewardInterval),
		#Rewards.Playtime
	)
	if reached <= profile.playtime.claimedStep then
		return false, "Nothing ready yet. Keep playing."
	end

	local step = profile.playtime.claimedStep + 1
	local rung = Rewards.playtimeRung(step)
	if not rung then
		return false, "You have collected every playtime reward today."
	end

	profile.playtime.claimedStep = step
	local cash = EconomyService.secondsToCash(player, profile, rung.seconds, 150)
	EconomyService.addCash(player, profile, cash)

	return true, `{rung.label} reward claimed.`
end

-- ---------------------------------------------------------------- loop

function RewardService.start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile then
					resetPlaytimeIfNewDay(profile)
					profile.playtime.seconds += TICK
					profile.stats.playSeconds += TICK

					-- Only nudge the client when a new rung actually unlocks,
					-- rather than pushing state every five seconds forever.
					local before = math.floor((profile.playtime.seconds - TICK) / GameConfig.PlaytimeRewardInterval)
					local after = math.floor(profile.playtime.seconds / GameConfig.PlaytimeRewardInterval)
					if after > before and after <= #Rewards.Playtime then
						EconomyService.markDirty(player)
					end
				end
			end
		end
	end)
end

return RewardService
