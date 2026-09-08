--!strict
--[[
	Redeemable codes

	The cheapest retention tool there is: a reason to check the group or the video,
	costing one table entry.

	Rewards are in seconds-of-rent like quests and dailies, so a launch code is
	still worth typing at rating 7. One redemption per account, tracked in the save.
]]

export type Code = {
	code: string,
	seconds: number?,
	stars: number?,
	note: string,
	active: boolean,
}

local Codes = {}

Codes.List = {
	{ code = "VACANCY", seconds = 600, note = "Launch", active = true },
	{ code = "CHECKIN", seconds = 400, note = "Launch", active = true },
	{ code = "LIGHTSOUT", seconds = 900, note = "Update 1", active = true },
	{ code = "NOVACANCY", seconds = 1200, stars = 1, note = "1,000 likes", active = true },
	{ code = "ROOMSERVICE", seconds = 1500, note = "Celebrity update", active = true },
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
