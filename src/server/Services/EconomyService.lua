--!strict
--[[
	EconomyService

	The single source of truth for "how much is this worth". Every multiplier the
	game applies is assembled here, in one function, so the number on the HUD, the
	number a sale pays out and the number a reward scales against can never
	disagree.

	Sell multiplier = rebirth x pets x Refinery x gamepasses x active boost.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Backpacks = require(Shared.Config.Backpacks)
local Monetization = require(Shared.Config.Monetization)
local Pets = require(Shared.Config.Pets)
local Rebirths = require(Shared.Config.Rebirths)
local Tools = require(Shared.Config.Tools)
local Zones = require(Shared.Config.Zones)
local Schema = require(Shared.Schema)
local Signal = require(Shared.Util.Signal)

local PassService = require(script.Parent.PassService)

type Profile = Schema.Profile

local EconomyService = {}

--[[ Fires whenever anything the client renders has changed. StateService listens
     and pushes; nothing else should be pushing state on its own. ]]
EconomyService.Changed = Signal.new() :: Signal.Signal<Player>

function EconomyService.markDirty(player: Player)
	EconomyService.Changed:Fire(player)
end

-- ---------------------------------------------------------------- pets

function EconomyService.equippedPetIds(profile: Profile): { string }
	local byUid: { [string]: string } = {}
	for _, entry in profile.pets do
		byUid[entry.uid] = entry.pet
	end

	local ids = {}
	for _, uid in profile.equipped do
		local petId = byUid[uid]
		if petId then
			table.insert(ids, petId)
		end
	end
	return ids
end

function EconomyService.petMultiplier(profile: Profile): number
	return Pets.multiplierFor(EconomyService.equippedPetIds(profile))
end

function EconomyService.petSlots(player: Player, profile: Profile): number
	local kennel = profile.upgrades.kennel or 0
	return GameConfig.BasePetSlots + kennel + PassService.sum(player, "petSlots")
end

-- ---------------------------------------------------------------- boosts

function EconomyService.boostRemaining(profile: Profile): number
	return math.max(0, profile.boostUntil - os.time())
end

function EconomyService.boostMultiplier(profile: Profile): number
	if EconomyService.boostRemaining(profile) > 0 then
		return profile.boostMultiplier
	end
	return 1
end

function EconomyService.grantBoost(profile: Profile, multiplier: number, duration: number)
	local now = os.time()
	local remaining = math.max(0, profile.boostUntil - now)
	local total = math.min(remaining + duration, Monetization.MaxBoostSeconds)
	profile.boostUntil = now + total
	profile.boostMultiplier = multiplier
end

-- ---------------------------------------------------------------- multipliers

function EconomyService.sellMultiplier(player: Player, profile: Profile): number
	return Rebirths.multiplierFor(profile.rebirths)
		* EconomyService.petMultiplier(profile)
		* Rebirths.upgradeMultiplier("refinery", profile.upgrades.refinery or 0)
		* PassService.multiplier(player, "sellMultiplier")
		* EconomyService.boostMultiplier(profile)
end

function EconomyService.oreMultiplier(profile: Profile): number
	return Rebirths.upgradeMultiplier("yield", profile.upgrades.yield or 0)
end

function EconomyService.capacity(player: Player, profile: Profile): number
	local pack = Backpacks.get(profile.backpack)
	return math.floor(pack.capacity * PassService.multiplier(player, "capacityMultiplier"))
end

function EconomyService.oreValue(player: Player, profile: Profile, zone: Zones.Zone): number
	return zone.oreValue * EconomyService.sellMultiplier(player, profile)
end

-- ---------------------------------------------------------------- access

function EconomyService.hasZone(player: Player, profile: Profile, zone: Zones.Zone): boolean
	if zone.gamepass then
		return PassService.owns(player, zone.gamepass)
	end
	return profile.unlockedZones[zone.id] == true
end

--[[ The furthest zone the player can actually mine in. Used to scale quest and
     reward payouts so they track the player rather than the calendar. ]]
function EconomyService.bestZone(player: Player, profile: Profile): Zones.Zone
	local best = Zones.get(Zones.Starter)
	local bestOrder = 0
	for _, zone in Zones.List do
		local order = Zones.OrderById[zone.id]
		if order > bestOrder and EconomyService.hasZone(player, profile, zone) then
			best = zone
			bestOrder = order
		end
	end
	return best
end

--[[ Crystals per second at the player's best zone, mining without pauses.

     This mirrors MiningService exactly: ore per swing is power x the zone's
     richness, a node absorbs `nodeHealth` of power before it breaks, and the
     breaking swing pays a bonus. It ignores the walk to the sell pad, so it reads
     slightly high -- the right direction to be wrong in for something that sizes
     a reward rather than a price. ]]
function EconomyService.incomePerSecond(player: Player, profile: Profile): number
	local zone = EconomyService.bestZone(player, profile)
	local tool = Tools.get(profile.tool)
	local power = math.max(1, tool.power)

	local perSwing = Zones.orePerSwing(zone, power) * EconomyService.oreMultiplier(profile)
	local swingsPerNode = math.max(1, math.ceil(zone.nodeHealth / power))

	local orePerCycle = perSwing * (swingsPerNode + GameConfig.NodeBreakBonusSwings)
	local secondsPerCycle = swingsPerNode * GameConfig.SwingCooldown

	return (orePerCycle / secondsPerCycle) * EconomyService.oreValue(player, profile, zone)
end

--[[ Turns "this is worth 10 minutes of your time" into Crystals. Every reward in
     the game that is not a fixed shop price goes through here. ]]
function EconomyService.secondsToCrystals(player: Player, profile: Profile, seconds: number, floor: number?): number
	local amount = EconomyService.incomePerSecond(player, profile) * seconds
	return math.max(math.floor(amount), floor or 1)
end

-- ---------------------------------------------------------------- currency

function EconomyService.addCrystals(player: Player, profile: Profile, amount: number)
	if amount <= 0 then
		return
	end
	profile.crystals += amount
	profile.stats.crystalsEarned += amount
	EconomyService.markDirty(player)
end

function EconomyService.spendCrystals(player: Player, profile: Profile, amount: number): boolean
	if amount < 0 or profile.crystals < amount then
		return false
	end
	profile.crystals -= amount
	EconomyService.markDirty(player)
	return true
end

function EconomyService.addCores(player: Player, profile: Profile, amount: number)
	if amount <= 0 then
		return
	end
	profile.cores += amount
	EconomyService.markDirty(player)
end

function EconomyService.spendCores(player: Player, profile: Profile, amount: number): boolean
	if amount < 0 or profile.cores < amount then
		return false
	end
	profile.cores -= amount
	EconomyService.markDirty(player)
	return true
end

return EconomyService
