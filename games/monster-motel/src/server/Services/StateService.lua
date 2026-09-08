--!strict
--[[
	StateService

	Turns a profile into the view the client renders and pushes it when something
	changes. The client holds no authoritative numbers of its own -- every figure on
	screen came from here.

	Pushes are coalesced on Heartbeat. Rent ticks once a second and marks the player
	dirty; a check-in touches cash, guests, rooms and two quests and marks them dirty
	five more times. All of it goes out as one packet.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Guests = require(Shared.Config.Guests)
local Monetization = require(Shared.Config.Monetization)
local Net = require(Shared.Net)
local Schema = require(Shared.Schema)

local ArrivalService = require(script.Parent.ArrivalService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local NightService = require(script.Parent.NightService)
local PassService = require(script.Parent.PassService)
local PrestigeService = require(script.Parent.PrestigeService)
local QuestService = require(script.Parent.QuestService)
local RewardService = require(script.Parent.RewardService)
local ShopService = require(script.Parent.ShopService)
local TheftService = require(script.Parent.TheftService)

type Profile = Schema.Profile

local StateService = {}

local PUSH_INTERVAL = 0.2

local dirty: { [Player]: boolean } = {}
local lastPush = 0
local stateRemote: RemoteEvent

local function productAmounts(player: Player, profile: Profile): { [string]: number }
	local amounts = {}
	for _, product in Monetization.Products do
		if product.kind == "cash" and product.seconds then
			amounts[product.id] = EconomyService.secondsToCash(player, profile, product.seconds, product.floor)
		end
	end
	return amounts
end

--[[ The player's guests, flattened for the UI: which room each is in, what it
     pays, and how rare it is. ]]
local function guestView(profile: Profile): { { [string]: any } }
	local out = {}
	for _, owned in profile.guests do
		local guest = Guests.get(owned.guest)
		if guest then
			table.insert(out, {
				uid = owned.uid,
				guest = owned.guest,
				name = guest.name,
				rarity = guest.rarity,
				rent = guest.rent,
				room = owned.room,
			})
		end
	end
	return out
end

function StateService.build(player: Player, profile: Profile): { [string]: any }
	local rent = EconomyService.rentPerSecond(player, profile)

	return {
		cash = profile.cash,
		stars = profile.stars,
		safe = profile.safe,
		safeCapacity = EconomyService.safeCapacity(player, profile),
		autoCollect = EconomyService.autoCollects(player),

		rentPerSecond = rent,
		rentMultiplier = EconomyService.rentMultiplier(player, profile),

		guests = guestView(profile),
		housed = EconomyService.housedCount(profile),
		capacity = EconomyService.housedCapacity(player, profile),
		loungeSlots = EconomyService.vipLoungeSlots(player),

		motel = ShopService.view(player, profile),
		arrivals = ArrivalService.view(player, profile),
		prestige = PrestigeService.view(player, profile),

		quests = QuestService.view(player, profile),
		daily = RewardService.dailyView(player, profile),
		playtime = RewardService.playtimeView(player, profile),

		night = NightService.state(),
		event = EventService.state(),
		carrying = TheftService.carriedGuest(player),

		-- Broken out so the HUD can show where the multiplier comes from rather
		-- than one opaque number.
		multipliers = {
			total = EconomyService.rentMultiplier(player, profile),
			renovations = 1 + profile.renovations * EconomyService.RenovationBonus,
			concierge = require(Shared.Config.Prestige).upgradeMultiplier("concierge", profile.upgrades.concierge or 0),
			passes = PassService.multiplier(player, "rentMultiplier"),
			boost = EconomyService.boostMultiplier(profile),
		},

		boostRemaining = EconomyService.boostRemaining(profile),
		boostMultiplier = EconomyService.boostMultiplier(profile),

		passes = PassService.ownedMap(player),
		productAmounts = productAmounts(player, profile),

		codes = profile.codes,
		stats = profile.stats,
		settings = profile.settings,

		-- True when DataStores were unreachable. The HUD says so plainly rather
		-- than letting somebody lose a guest out of a session that was never being
		-- saved in the first place.
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

local function attachLeaderstats(player: Player)
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local rent = Instance.new("StringValue")
	rent.Name = "Rent/s"
	rent.Parent = folder

	local renovations = Instance.new("IntValue")
	renovations.Name = "Renovations"
	renovations.Parent = folder

	folder.Parent = player
end

local function updateLeaderstats(player: Player, profile: Profile)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local rent = folder:FindFirstChild("Rent/s") :: StringValue?
	local renovations = folder:FindFirstChild("Renovations") :: IntValue?
	if rent then
		rent.Value = "$" .. Format.short(EconomyService.rentPerSecond(player, profile))
	end
	if renovations then
		renovations.Value = profile.renovations
	end
end

-- ---------------------------------------------------------------- lifecycle

function StateService.start()
	local folder = Net.build()
	stateRemote = folder:FindFirstChild("State") :: RemoteEvent

	DataService.Loaded:Connect(function(player, profile)
		attachLeaderstats(player)
		updateLeaderstats(player, profile)
		StateService.push(player)
	end)

	EconomyService.Changed:Connect(function(player)
		dirty[player] = true
	end)

	PassService.Changed:Connect(function(player)
		dirty[player] = true
	end)

	-- The night flip and the celebrity event change what everybody's HUD should
	-- say, whether or not their own motel changed.
	NightService.Changed:Connect(function()
		for _, player in Players:GetPlayers() do
			dirty[player] = true
		end
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
