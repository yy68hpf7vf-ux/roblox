--!strict
--[[
	Redeemable codes

	Codes are the cheapest retention tool there is: they give people a reason to
	check the group or the video, and they cost nothing but a table entry.

	Rewards are in seconds-of-income like quests and daily rewards, so an old code
	is still worth typing at rebirth 8. Each code is one-per-account, tracked in
	the player's profile.
]]

export type Code = {
	code: string,
	seconds: number?,
	cores: number?,
	note: string,
	active: boolean,
}

local Codes = {}

Codes.List = {
	{ code = "RIFTOPEN", seconds = 600, note = "Launch", active = true },
	{ code = "FIRSTPICK", seconds = 300, note = "Launch", active = true },
	{ code = "DEEPSEAM", seconds = 900, note = "Update 1", active = true },
	{ code = "1KLIKES", seconds = 1200, cores = 1, note = "1,000 likes", active = true },
	{ code = "PETSDAY", seconds = 1500, note = "Pets update", active = true },
} :: { Code }

Codes.ByCode = {} :: { [string]: Code }
for _, entry in Codes.List do
	Codes.ByCode[string.upper(entry.code)] = entry
end

function Codes.get(input: string): Code?
	local entry = Codes.ByCode[string.upper(string.gsub(input, "%s", ""))]
	if entry and entry.active then
		return entry
	end
	return nil
end

return Codes
