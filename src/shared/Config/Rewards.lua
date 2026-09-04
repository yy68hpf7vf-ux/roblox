--!strict
--[[
	Daily login streak and playtime rewards

	Both ladders exist to make coming back and staying a while feel paid-for. Two
	deliberate limits:

	  * The streak has a two-day grace window (GameConfig.DailyStreakGrace). Miss
	    one evening and you keep your streak. The ladder is a thank-you for
	    returning, not a punishment for having a life.
	  * The playtime ladder stops at the last rung. It does not keep dangling a
	    bigger prize to hold someone in the server, and it never asks anyone to
	    idle rather than play.

	Rewards are expressed in seconds-of-income and converted to Crystals against
	the player's own progression, so they stay worth collecting at any rebirth.
]]

export type Rung = {
	label: string,
	seconds: number,
	cores: number?,
}

local Rewards = {}

Rewards.Daily = {
	{ label = "Day 1", seconds = 180 },
	{ label = "Day 2", seconds = 300 },
	{ label = "Day 3", seconds = 480 },
	{ label = "Day 4", seconds = 720 },
	{ label = "Day 5", seconds = 1020 },
	{ label = "Day 6", seconds = 1400 },
	{ label = "Day 7", seconds = 2100, cores = 1 },
} :: { Rung }

-- One rung every GameConfig.PlaytimeRewardInterval seconds, resetting each day.
Rewards.Playtime = {
	{ label = "5m", seconds = 60 },
	{ label = "10m", seconds = 90 },
	{ label = "15m", seconds = 120 },
	{ label = "20m", seconds = 160 },
	{ label = "25m", seconds = 200 },
	{ label = "30m", seconds = 260 },
	{ label = "35m", seconds = 320 },
	{ label = "40m", seconds = 400 },
	{ label = "45m", seconds = 480 },
	{ label = "50m", seconds = 580 },
	{ label = "55m", seconds = 700 },
	{ label = "60m", seconds = 900 },
} :: { Rung }

function Rewards.dailyRung(day: number): Rung
	local index = math.clamp(day, 1, #Rewards.Daily)
	return Rewards.Daily[index]
end

function Rewards.playtimeRung(step: number): Rung?
	return Rewards.Playtime[step]
end

return Rewards
