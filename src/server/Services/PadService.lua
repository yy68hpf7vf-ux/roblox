--!strict
--[[
	PadService

	The pads on each island: sell, shop, egg, travel.

	Selling values ore at the pad you sell it at, which is why the walk back to the
	plaza is the pacing beat of the whole game. You cannot sell in a zone you have
	not unlocked, because you cannot stand in one.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local QuestService = require(script.Parent.QuestService)
local Remote = require(script.Parent.Remote)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local PadService = {}

local lastTouch: { [Player]: { [BasePart]: number } } = {}

local function debounced(player: Player, padPart: BasePart, seconds: number): boolean
	local map = lastTouch[player]
	if not map then
		map = {}
		lastTouch[player] = map
	end
	local now = os.clock()
	if map[padPart] and (now - map[padPart]) < seconds then
		return true
	end
	map[padPart] = now
	return false
end

local function playerFromTouch(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

-- ---------------------------------------------------------------- selling

function PadService.sell(player: Player, zone: Zones.Zone): (boolean, string)
	local profile = DataService.get(player)
	if not profile then
		return false, "Still loading."
	end
	if profile.ore <= 0 then
		return false, "Nothing to sell."
	end
	if not EconomyService.hasZone(player, profile, zone) then
		return false, "You do not have access to this seam."
	end

	local perOre = EconomyService.oreValue(player, profile, zone)
	local payout = math.floor(math.min(profile.ore * perOre, GameConfig.MaxSellValue))

	local sold = profile.ore
	profile.ore = 0
	profile.stats.sells += 1

	EconomyService.addCrystals(player, profile, payout)
	QuestService.addProgress(player, profile, "sell_trips", 1)
	QuestService.addProgress(player, profile, "earn_crystals", payout)

	Remote.effect(player, "sold", { crystals = payout, ore = sold })
	return true, `Sold {Format.short(sold)} ore for {Format.short(payout)} Crystals.`
end

-- ---------------------------------------------------------------- travel

function PadService.travel(player: Player, zoneId: string): (boolean, string)
	local profile = DataService.get(player)
	if not profile then
		return false, "Still loading."
	end

	local zone = Zones.ById[zoneId]
	if not zone then
		return false, "No such zone."
	end

	if not EconomyService.hasZone(player, profile, zone) then
		if zone.gamepass then
			return false, `{zone.name} comes with the VIP pass.`
		end
		return false, `{zone.name} is locked. Unlock it for {Format.short(zone.unlockCost)} Crystals.`
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "Respawning."
	end

	profile.zone = zone.id
	root.CFrame = WorldBuilder.spawnCFrame(zone)
	EconomyService.markDirty(player)

	return true, `Travelled to {zone.name}.`
end

-- ---------------------------------------------------------------- wiring

local function connectPad(padPart: BasePart)
	local kind = padPart.Name

	padPart.Touched:Connect(function(hit)
		local player = playerFromTouch(hit)
		if not player then
			return
		end

		if kind == "SellPad" then
			if debounced(player, padPart, GameConfig.SellPadCooldown) then
				return
			end
			local profile = DataService.get(player)
			if not profile or profile.ore <= 0 then
				return
			end
			local zone = Zones.get(padPart:GetAttribute("Zone") :: string?)
			local ok, message = PadService.sell(player, zone)
			if not ok then
				Remote.notify(player, message, "warn")
			end
		elseif kind == "TravelPad" then
			if debounced(player, padPart, 1.5) then
				return
			end
			local target = padPart:GetAttribute("Target") :: string?
			if target then
				local ok, message = PadService.travel(player, target)
				Remote.notify(player, message, if ok then "good" else "warn")
				if not ok then
					Remote.effect(player, "openWindow", { window = "zones" })
				end
			end
		else
			local opens = padPart:GetAttribute("Opens") :: string?
			if opens and not debounced(player, padPart, 2) then
				Remote.effect(player, "openWindow", {
					window = opens,
					egg = padPart:GetAttribute("Egg"),
				})
			end
		end
	end)
end

function PadService.start(root: Folder)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			local name = descendant.Name
			if name == "SellPad" or name == "TravelPad" or name == "ShopPad" or name == "EggPad" then
				connectPad(descendant)
			end
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastTouch[player] = nil
	end)
end

return PadService
