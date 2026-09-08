--!strict
--[[
	Daily login streak and playtime rewards

	Both ladders pay people for coming back and for staying, without punishing
	them for leaving:

	  * The streak has a two-day grace window (GameConfig.DailyStreakGrace). Miss
	    one evening and it survives. A streak that snaps the first time somebody
	    has a busy Tuesday turns a good habit into a chore, and it costs you the
	    player rather than the day.
	  * The playtime ladder stops at its last rung and says so. It never dangles a
	    bigger prize to keep somebody parked in the server, and it never pays more
	    for idling than for playing.

	Rewards are in seconds-of-rent, converted against the player's own motel, so
	they stay worth collecting at any rating.
]]

export type Rung = {
	label: string,
	seconds: number,
	stars: number?,
}

local Rewards = {}

Rewards.Daily = {
	{ label = "Day 1", seconds = 240 },
	{ label = "Day 2", seconds = 380 },
	{ label = "Day 3", seconds = 560 },
	{ label = "Day 4", seconds = 800 },
	{ label = "Day 5", seconds = 1100 },
	{ label = "Day 6", seconds = 1500 },
	{ label = "Day 7", seconds = 2200, stars = 1 },
} :: { Rung }

Rewards.Playtime = {
	{ label = "5m", seconds = 90 },
	{ label = "10m", seconds = 120 },
	{ label = "15m", seconds = 160 },
	{ label = "20m", seconds = 200 },
	{ label = "25m", seconds = 250 },
	{ label = "30m", seconds = 310 },
	{ label = "35m", seconds = 380 },
	{ label = "40m", seconds = 460 },
	{ label = "45m", seconds = 550 },
	{ label = "50m", seconds = 650 },
	{ label = "55m", seconds = 780 },
	{ label = "60m", seconds = 950 },
} :: { Rung }

function Rewards.dailyRung(day: number): Rung
	return Rewards.Daily[math.clamp(day, 1, #Rewards.Daily)]
end

function Rewards.playtimeRung(step: number): Rung?
	return Rewards.Playtime[step]
end

return Rewards
