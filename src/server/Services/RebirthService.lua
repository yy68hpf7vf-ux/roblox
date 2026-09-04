--!strict
--[[
	RebirthService
	The prestige loop and the Core Shop it feeds.

	A rebirth wipes Crystals, ore, picks, backpacks and zone unlocks. It keeps
	pets, Cores and Core Shop levels, which is what makes the second run through
	the map roughly a third of the length of the first.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Backpacks = require(Shared.Config.Backpacks)
local Rebirths = require(Shared.Config.Rebirths)
local Tools = require(Shared.Config.Tools)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Util.Format)
local Schema = require(Shared.Schema)

local EconomyService = require(script.Parent.EconomyService)
local Remote = require(script.Parent.Remote)

type Profile = Schema.Profile

local RebirthService = {}

function RebirthService.canRebirth(profile: Profile): (boolean, number)
	local cost = Rebirths.costFor(profile.rebirths)
	return profile.crystals >= cost, cost
end

function RebirthService.rebirth(player: Player, profile: Profile): (boolean, string)
	local allowed, cost = RebirthService.canRebirth(profile)
	if not allowed then
		return false, `Rebirth costs {Format.short(cost)} Crystals. You have {Format.short(profile.crystals)}.`
	end

	local cores = Rebirths.coresFor(profile.rebirths)

	profile.crystals = 0
	profile.ore = 0
	profile.ownedTools = { [Tools.Starter] = true }
	profile.ownedBackpacks = { [Backpacks.Starter] = true }
	profile.unlockedZones = { [Zones.Starter] = true }
	profile.tool = Tools.Starter
	profile.backpack = Backpacks.Starter
	profile.zone = Zones.Starter

	profile.rebirths += 1
	profile.cores += cores

	EconomyService.markDirty(player)

	Remote.effect(player, "rebirthed", {
		rebirths = profile.rebirths,
		multiplier = Rebirths.multiplierFor(profile.rebirths),
		cores = cores,
	})

	return true,
		`Rebirth {profile.rebirths}. Everything you earn is now {Format.multiplier(Rebirths.multiplierFor(profile.rebirths))}, and you gained {cores} Cores.`
end

function RebirthService.buyUpgrade(player: Player, profile: Profile, upgradeId: string): (boolean, string)
	local upgrade = Rebirths.UpgradeById[upgradeId]
	if not upgrade then
		return false, "No such upgrade."
	end

	local level = profile.upgrades[upgradeId] or 0
	if level >= upgrade.maxLevel then
		return false, `{upgrade.name} is already at its maximum.`
	end

	local cost = Rebirths.upgradeCost(upgrade, level)
	if not EconomyService.spendCores(player, profile, cost) then
		return false, `{upgrade.name} costs {cost} Cores. You have {profile.cores}.`
	end

	profile.upgrades[upgradeId] = level + 1
	EconomyService.markDirty(player)
	return true, `{upgrade.name} is now level {level + 1}.`
end

--[[ Everything the Core Shop needs to render, resolved server-side so a client
     cannot invent a cheaper price. ]]
function RebirthService.upgradeView(profile: Profile): { { [string]: any } }
	local out = {}
	for _, upgrade in Rebirths.Upgrades do
		local level = profile.upgrades[upgrade.id] or 0
		local maxed = level >= upgrade.maxLevel
		table.insert(out, {
			id = upgrade.id,
			name = upgrade.name,
			desc = upgrade.desc,
			level = level,
			maxLevel = upgrade.maxLevel,
			cost = if maxed then 0 else Rebirths.upgradeCost(upgrade, level),
			perLevel = upgrade.perLevel,
			suffix = upgrade.suffix,
			maxed = maxed,
		})
	end
	return out
end

return RebirthService
