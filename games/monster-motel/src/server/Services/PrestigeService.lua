--!strict
--[[
	PrestigeService
	Renovating, and the Star Shop it pays for.

	A renovation takes the motel back to three rooms and a one-star rating. It does
	not take your guests -- they move into storage and wait. That choice is what
	makes the reset something players opt into rather than dread: you lose the
	building, you keep the collection, and rebuilding is fast because your best
	guests move straight back in the moment you have rooms for them.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Prestige = require(Shared.Config.Prestige)
local Schema = require(Shared.Schema)

local EconomyService = require(script.Parent.EconomyService)
local Remote = require(script.Parent.Remote)

type Profile = Schema.Profile

local PrestigeService = {}

function PrestigeService.pending(profile: Profile): number
	return Prestige.starsFor(profile.earnedThisRun)
end

function PrestigeService.canRenovate(profile: Profile): (boolean, string?)
	if profile.rating < Prestige.MinimumRating then
		return false, `Renovating needs a {Prestige.MinimumRating}-star motel.`
	end
	if PrestigeService.pending(profile) < 1 then
		local needed = Prestige.earningsForStars(1)
		return false, `Earn ${Format.short(needed)} this run to be worth a Star.`
	end
	return true, nil
end

function PrestigeService.renovate(player: Player, profile: Profile): (boolean, string)
	local allowed, why = PrestigeService.canRenovate(profile)
	if not allowed then
		return false, why or "Not yet."
	end

	local stars = PrestigeService.pending(profile)

	profile.cash = 0
	profile.safe = 0
	profile.earnedThisRun = 0
	profile.rating = 1
	profile.rooms = GameConfig.StartingRooms
	profile.lockLevel = 0
	profile.safeLevel = 1
	profile.arrivals = {}
	profile.nextArrivalAt = 0

	-- Guests stay owned. They move to storage because the rooms they were in no
	-- longer exist, and the player re-houses their best three immediately.
	for _, owned in profile.guests do
		owned.room = 0
	end

	profile.stars += stars
	profile.renovations += 1

	EconomyService.markDirty(player)
	Remote.effect(player, "renovated", { stars = stars, renovations = profile.renovations })

	return true,
		`Renovation {profile.renovations}. You earned {stars} Star{if stars == 1 then "" else "s"}, `
			.. `and every guest now pays {Format.multiplier(1 + profile.renovations * EconomyService.RenovationBonus)}.`
end

function PrestigeService.buyUpgrade(player: Player, profile: Profile, upgradeId: string): (boolean, string)
	local upgrade = Prestige.UpgradeById[upgradeId]
	if not upgrade then
		return false, "No such upgrade."
	end

	local level = profile.starShop[upgradeId] or 0
	if level >= upgrade.maxLevel then
		return false, `{upgrade.name} is already at its maximum.`
	end

	local cost = Prestige.upgradeCost(upgrade, level)
	if not EconomyService.spendStars(player, profile, cost) then
		return false, `{upgrade.name} costs {cost} Stars. You have {profile.stars}.`
	end

	profile.starShop[upgradeId] = level + 1
	EconomyService.markDirty(player)
	return true, `{upgrade.name} is now level {level + 1}.`
end

--[[ Everything the Renovate window needs, resolved server-side so a client cannot
     invent a cheaper price. ]]
function PrestigeService.view(player: Player, profile: Profile): { [string]: any }
	local pending = PrestigeService.pending(profile)
	local allowed, why = PrestigeService.canRenovate(profile)

	local upgrades = {}
	for _, upgrade in Prestige.Upgrades do
		local level = profile.starShop[upgrade.id] or 0
		local maxed = level >= upgrade.maxLevel
		table.insert(upgrades, {
			id = upgrade.id,
			name = upgrade.name,
			desc = upgrade.desc,
			level = level,
			maxLevel = upgrade.maxLevel,
			cost = if maxed then 0 else Prestige.upgradeCost(upgrade, level),
			perLevel = upgrade.perLevel,
			suffix = upgrade.suffix,
			maxed = maxed,
		})
	end

	return {
		renovations = profile.renovations,
		multiplier = 1 + profile.renovations * EconomyService.RenovationBonus,
		nextMultiplier = 1 + (profile.renovations + 1) * EconomyService.RenovationBonus,
		earnedThisRun = profile.earnedThisRun,
		pendingStars = pending,
		nextStarAt = Prestige.earningsForStars(pending + 1),
		minimumRating = Prestige.MinimumRating,
		canRenovate = allowed,
		blockedReason = why,
		upgrades = upgrades,
	}
end

return PrestigeService
