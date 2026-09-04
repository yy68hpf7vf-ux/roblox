--!strict
--[[
	StateService

	Turns a profile into the view the client renders, and pushes it when something
	changes. The client holds no authoritative numbers of its own -- every figure
	on screen came from here.

	Pushes are coalesced on Heartbeat: a sale that touches ore, crystals, stats and
	two quests marks the player dirty five times and sends one packet.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Rebirths = require(Shared.Config.Rebirths)
local Zones = require(Shared.Config.Zones)
local Net = require(Shared.Net)
local Schema = require(Shared.Schema)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PassService = require(script.Parent.PassService)
local QuestService = require(script.Parent.QuestService)
local RebirthService = require(script.Parent.RebirthService)
local RewardService = require(script.Parent.RewardService)

type Profile = Schema.Profile

local StateService = {}

local PUSH_INTERVAL = 0.15

local dirty: { [Player]: boolean } = {}
local lastPush = 0

local stateRemote: RemoteEvent

local function productAmounts(player: Player, profile: Profile): { [string]: number }
	local amounts = {}
	for _, product in Monetization.Products do
		if product.kind == "crystals" and product.seconds then
			amounts[product.id] = EconomyService.secondsToCrystals(player, profile, product.seconds, product.floor)
		end
	end
	return amounts
end

function StateService.build(player: Player, profile: Profile): { [string]: any }
	local zone = Zones.get(profile.zone)

	return {
		crystals = profile.crystals,
		cores = profile.cores,
		ore = profile.ore,
		capacity = EconomyService.capacity(player, profile),

		tool = profile.tool,
		backpack = profile.backpack,
		zone = profile.zone,

		ownedTools = profile.ownedTools,
		ownedBackpacks = profile.ownedBackpacks,
		unlockedZones = profile.unlockedZones,

		pets = profile.pets,
		equipped = profile.equipped,
		petSlots = EconomyService.petSlots(player, profile),

		rebirths = profile.rebirths,
		rebirthCost = Rebirths.costFor(profile.rebirths),
		rebirthMultiplier = Rebirths.multiplierFor(profile.rebirths),
		nextRebirthMultiplier = Rebirths.multiplierFor(profile.rebirths + 1),
		rebirthCores = Rebirths.coresFor(profile.rebirths),
		upgrades = profile.upgrades,
		coreUpgrades = RebirthService.upgradeView(profile),

		-- Broken out so the HUD can show players exactly where their multiplier
		-- comes from instead of one opaque number.
		multipliers = {
			total = EconomyService.sellMultiplier(player, profile),
			rebirth = Rebirths.multiplierFor(profile.rebirths),
			pets = EconomyService.petMultiplier(profile),
			refinery = Rebirths.upgradeMultiplier("refinery", profile.upgrades.refinery or 0),
			passes = PassService.multiplier(player, "sellMultiplier"),
			boost = EconomyService.boostMultiplier(profile),
			ore = EconomyService.oreMultiplier(profile),
		},

		oreValue = EconomyService.oreValue(player, profile, zone),
		incomePerSecond = EconomyService.incomePerSecond(player, profile),

		quests = QuestService.view(player, profile),
		daily = RewardService.dailyView(player, profile),
		playtime = RewardService.playtimeView(player, profile),

		boostRemaining = EconomyService.boostRemaining(profile),
		boostMultiplier = EconomyService.boostMultiplier(profile),

		passes = PassService.ownedMap(player),
		productAmounts = productAmounts(player, profile),

		codes = profile.codes,
		stats = profile.stats,
		settings = profile.settings,

		-- True when DataStores were unreachable. The HUD says so plainly rather
		-- than letting someone grind for an hour into nothing.
		volatile = DataService.isVolatile(player),
	}
end

function StateService.push(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	stateRemote:FireClient(player, StateService.build(player, profile))
end

-- ---------------------------------------------------------------- leaderstats

local function attachLeaderstats(player: Player, profile: Profile)
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local crystals = Instance.new("StringValue")
	crystals.Name = "Crystals"
	crystals.Parent = folder

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder

	folder.Parent = player
end

local function updateLeaderstats(player: Player, profile: Profile)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local crystals = folder:FindFirstChild("Crystals") :: StringValue?
	local rebirths = folder:FindFirstChild("Rebirths") :: IntValue?
	if crystals then
		crystals.Value = Format.short(profile.crystals)
	end
	if rebirths then
		rebirths.Value = profile.rebirths
	end
end

-- ---------------------------------------------------------------- lifecycle

function StateService.start()
	local folder = Net.build()
	stateRemote = folder:FindFirstChild("State") :: RemoteEvent

	DataService.Loaded:Connect(function(player, profile)
		attachLeaderstats(player, profile)
		updateLeaderstats(player, profile)
		StateService.push(player)
	end)

	EconomyService.Changed:Connect(function(player)
		dirty[player] = true
	end)

	PassService.Changed:Connect(function(player)
		dirty[player] = true
	end)

	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastPush < PUSH_INTERVAL then
			return
		end
		lastPush = now

		if next(dirty) == nil then
			return
		end

		local pending = dirty
		dirty = {}
		for player in pending do
			if player.Parent then
				local profile = DataService.get(player)
				if profile then
					updateLeaderstats(player, profile)
					StateService.push(player)
				end
			end
		end
	end)
end

return StateService
