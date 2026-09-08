--!strict
--[[
	RentService

	Rent accrues into the motel safe once a second and stops at the safe's cap.
	Walking onto the front desk banks it.

	The cap is the loop's heartbeat: it is what brings a player back to their own
	motel instead of leaving it running unattended, and it is what makes Auto
	Collect a purchase somebody understands the value of before they see the price.
	It is also visible at all times on the HUD, because a cap you cannot see is
	just lost money.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)
local Schema = require(Shared.Schema)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local QuestService = require(script.Parent.QuestService)
local Remote = require(script.Parent.Remote)

type Profile = Schema.Profile

local RentService = {}

local lastCollect: { [Player]: number } = {}

function RentService.safeFullness(player: Player, profile: Profile): number
	local capacity = EconomyService.safeCapacity(player, profile)
	if capacity <= 0 then
		return 0
	end
	return math.clamp(profile.safe / capacity, 0, 1)
end

--[[ One second of rent. With Auto Collect it goes straight to the wallet; without
     it, into the safe until the safe is full. ]]
local function tick(player: Player, profile: Profile, seconds: number)
	local rate = EconomyService.rentPerSecond(player, profile)
	if rate <= 0 then
		return
	end

	local earned = rate * seconds

	if EconomyService.autoCollects(player) then
		EconomyService.addCash(player, profile, earned)
		return
	end

	local capacity = EconomyService.safeCapacity(player, profile)
	local before = profile.safe
	profile.safe = math.min(profile.safe + earned, capacity)

	if profile.safe ~= before then
		EconomyService.markDirty(player)
	end
end

function RentService.collect(player: Player, profile: Profile): (boolean, string)
	if profile.safe <= 0 then
		return false, "The safe is empty."
	end

	local amount = math.floor(math.min(profile.safe, GameConfig.MaxSingleCollect))
	profile.safe = 0
	profile.stats.collected += amount

	EconomyService.addCash(player, profile, amount)
	QuestService.addProgress(player, profile, "collect_cash", amount)

	Remote.effect(player, "collected", { amount = amount })
	return true, `Collected ${Format.short(amount)}.`
end

--[[ Granted on load, and only with the Night Owl pass. Capped at
     GameConfig.MaxOfflineHours so it stays a convenience rather than a reason not
     to play. ]]
function RentService.grantOffline(player: Player, profile: Profile)
	if not EconomyService.earnsOffline(player) then
		return
	end
	if profile.lastSeenAt <= 0 then
		return
	end

	local away = os.time() - profile.lastSeenAt
	if away < 60 then
		return
	end

	local capped = math.min(away, GameConfig.MaxOfflineHours * 3600)
	local rate = EconomyService.rentPerSecond(player, profile)
	local earned = math.floor(rate * capped)

	if earned <= 0 then
		return
	end

	EconomyService.addCash(player, profile, earned)
	Remote.notify(
		player,
		`Night Owl: your motel earned ${Format.short(earned)} over {Format.duration(capped)} while you were away.`,
		"good"
	)
end

local function connectDesk(plot: any)
	plot.desk.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		-- Only the owner banks at their own desk. Standing on someone else's does
		-- nothing -- the safe is not what thieves are here for.
		if PlotService.plotFor(player) ~= plot then
			return
		end

		local now = os.clock()
		if lastCollect[player] and now - lastCollect[player] < GameConfig.FrontDeskCooldown then
			return
		end
		lastCollect[player] = now

		local profile = DataService.get(player)
		if profile and profile.safe > 0 then
			RentService.collect(player, profile)
		end
	end)
end

function RentService.start()
	for _, plot in PlotService.plots() do
		connectDesk(plot)
	end

	DataService.Loaded:Connect(function(player, profile)
		RentService.grantOffline(player, profile)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCollect[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.RentTickInterval)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile then
					tick(player, profile, GameConfig.RentTickInterval)
				end
			end
		end
	end)
end

return RentService
