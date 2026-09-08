--!strict
--[[
	CodeService
	One redemption per code per account, tracked in the profile.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Codes = require(Shared.Config.Codes)
local Format = require(Shared.Util.Format)
local Schema = require(Shared.Schema)

local EconomyService = require(script.Parent.EconomyService)

type Profile = Schema.Profile

local CodeService = {}

function CodeService.redeem(player: Player, profile: Profile, input: unknown): (boolean, string)
	if type(input) ~= "string" or #input == 0 or #input > 40 then
		return false, "Type a code first."
	end

	local entry = Codes.get(input)
	if not entry then
		return false, "That code is not valid."
	end

	local key = string.upper(entry.code)
	if profile.codes[key] then
		return false, "You have already used that code."
	end

	profile.codes[key] = true

	local parts = {}
	if entry.seconds then
		local cash = EconomyService.secondsToCash(player, profile, entry.seconds, 500)
		EconomyService.addCash(player, profile, cash)
		table.insert(parts, `${Format.short(cash)}`)
	end
	if entry.stars then
		EconomyService.addStars(player, profile, entry.stars)
		table.insert(parts, `{entry.stars} Stars`)
	end

	EconomyService.markDirty(player)
	return true, `Code redeemed: {table.concat(parts, " and ")}.`
end

return CodeService
