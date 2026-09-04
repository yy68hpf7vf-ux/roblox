--!strict
--[[
	ShopService
	Picks, backpacks and zone unlocks. Every purchase re-checks price, ownership
	and rebirth requirement against the config on the server -- the client's copy
	of the shop is for drawing buttons, nothing else.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Backpacks = require(Shared.Config.Backpacks)
local Tools = require(Shared.Config.Tools)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Util.Format)
local Schema = require(Shared.Schema)

local EconomyService = require(script.Parent.EconomyService)

type Profile = Schema.Profile

local ShopService = {}

function ShopService.buyTool(player: Player, profile: Profile, toolId: string): (boolean, string)
	local tool = Tools.ById[toolId]
	if not tool then
		return false, "No such pick."
	end

	if Tools.isOwned(profile.ownedTools, toolId) then
		profile.tool = toolId
		EconomyService.markDirty(player)
		return true, `Equipped the {tool.name}.`
	end

	if profile.rebirths < tool.rebirths then
		return false, `The {tool.name} needs {tool.rebirths} rebirths.`
	end
	if not EconomyService.spendCrystals(player, profile, tool.price) then
		return false, `You need {Format.short(tool.price - profile.crystals)} more Crystals.`
	end

	profile.ownedTools[toolId] = true
	profile.tool = toolId
	EconomyService.markDirty(player)
	return true, `Bought the {tool.name}.`
end

function ShopService.buyBackpack(player: Player, profile: Profile, backpackId: string): (boolean, string)
	local pack = Backpacks.ById[backpackId]
	if not pack then
		return false, "No such backpack."
	end

	if Backpacks.isOwned(profile.ownedBackpacks, backpackId) then
		profile.backpack = backpackId
		EconomyService.markDirty(player)
		return true, `Equipped the {pack.name}.`
	end

	if profile.rebirths < pack.rebirths then
		return false, `The {pack.name} needs {pack.rebirths} rebirths.`
	end
	if not EconomyService.spendCrystals(player, profile, pack.price) then
		return false, `You need {Format.short(pack.price - profile.crystals)} more Crystals.`
	end

	profile.ownedBackpacks[backpackId] = true
	profile.backpack = backpackId
	EconomyService.markDirty(player)
	return true, `Bought the {pack.name}.`
end

function ShopService.unlockZone(player: Player, profile: Profile, zoneId: string): (boolean, string)
	local zone = Zones.ById[zoneId]
	if not zone then
		return false, "No such zone."
	end
	if zone.gamepass then
		return false, `{zone.name} comes with the VIP pass.`
	end
	if profile.unlockedZones[zoneId] then
		return true, `{zone.name} is already open.`
	end
	if profile.rebirths < zone.rebirths then
		return false, `{zone.name} needs {zone.rebirths} rebirths.`
	end
	if not EconomyService.spendCrystals(player, profile, zone.unlockCost) then
		return false, `You need {Format.short(zone.unlockCost - profile.crystals)} more Crystals.`
	end

	profile.unlockedZones[zoneId] = true
	EconomyService.markDirty(player)
	return true, `{zone.name} unlocked.`
end

return ShopService
