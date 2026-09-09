--!strict
--[[
	PlotService

	Hands each player a motel plot and keeps what is standing on it in sync with
	what is in their save.

	Guests are real server instances rather than client-side cosmetics, unlike the
	pets in most games of this shape. They have to be: another player needs to walk
	up, read the sign, see a Mythic standing in room 4 and decide it is worth the
	night. If guests were drawn locally there would be nothing to steal.

	Rendering reconciles rather than rebuilds -- a rent tick marks the player dirty
	every second, and tearing down twenty models a second would be absurd.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Guests = require(Shared.Config.Guests)
local Format = require(Shared.Util.Format)
local Schema = require(Shared.Schema)
local Signal = require(Shared.Util.Signal)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NightService = require(script.Parent.NightService)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

type Profile = Schema.Profile
type Plot = WorldBuilder.Plot

local PlotService = {}

PlotService.Assigned = Signal.new() :: Signal.Signal<Player, Plot>

local plots: { Plot } = {}
local ownerByPlot: { [number]: Player } = {}
local plotByPlayer: { [Player]: Plot } = {}
local joinedAt: { [Player]: number } = {}

-- uid -> the model currently standing in a room, per plot.
local rendered: { [number]: { [string]: Model } } = {}

function PlotService.plotFor(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.ownerOf(plotIndex: number): Player?
	return ownerByPlot[plotIndex]
end

function PlotService.joinedAt(player: Player): number
	return joinedAt[player] or os.time()
end

function PlotService.plots(): { Plot }
	return plots
end

-- ---------------------------------------------------------------- rendering

local function clearPlot(plot: Plot)
	local map = rendered[plot.index]
	if map then
		for _, model in map do
			model:Destroy()
		end
	end
	rendered[plot.index] = {}
end

--[[ Puts every housed guest on its room marker, adds models that appeared and
     removes ones that left. Called whenever the player's state changes. ]]
function PlotService.renderGuests(player: Player)
	local plot = plotByPlayer[player]
	local profile = DataService.get(player)
	if not plot or not profile then
		return
	end

	local map = rendered[plot.index]
	if not map then
		map = {}
		rendered[plot.index] = map
	end

	local wanted: { [string]: Schema.OwnedGuest } = {}
	for _, owned in profile.guests do
		if owned.room > 0 then
			wanted[owned.uid] = owned
		end
	end

	-- Remove anything that is no longer housed here.
	for uid, model in map do
		if not wanted[uid] then
			model:Destroy()
			map[uid] = nil
		end
	end

	for uid, owned in wanted do
		local marker = plot.roomMarkers[owned.room]
		if marker then
			local model = map[uid]
			if not model then
				local guest = Guests.get(owned.guest)
				if guest then
					model = WorldBuilder.buildGuestModel(guest, uid)
					model.Parent = plot.model
					map[uid] = model
				end
			end
			if model and model.PrimaryPart then
				-- Snap to the marker; guests do not wander.
				model:PivotTo(marker.CFrame * CFrame.new(0, 2.4, 0))
			end
		end
	end
end

function PlotService.guestModel(player: Player, uid: string): Model?
	local plot = plotByPlayer[player]
	if not plot then
		return nil
	end
	local map = rendered[plot.index]
	return if map then map[uid] else nil
end

--[[ The sign is the game's shop window. It shows who owns the motel, what it
     earns, and whether the door is worth trying -- so a raid is an informed
     decision rather than a coin flip. ]]
function PlotService.refreshSign(player: Player)
	local plot = plotByPlayer[player]
	local profile = DataService.get(player)
	if not plot or not profile then
		return
	end

	local rent = EconomyService.rentPerSecond(player, profile)
	local housed = EconomyService.housedCount(profile)
	local capacity = EconomyService.housedCapacity(player, profile)

	-- The building itself reflects the rating: paint, planters, awning, pool,
	-- roof neon, beacon, arch. Early-returns unless the rating actually moved.
	WorldBuilder.applyRating(plot, profile.rating)

	plot.nameLabel.Text = `{player.DisplayName}'s Motel`
	plot.rentLabel.Text = `${Format.short(rent)}/s  ·  {housed}/{capacity} rooms  ·  {profile.renovations}★`

	-- The lit board. Readable from across the square, which is the point: a raider
	-- should be able to pick a target without walking up to every door.
	local free = capacity - housed
	if free > 0 then
		plot.vacancyLabel.Text = "VACANCY"
		plot.vacancyLabel.TextColor3 = Color3.fromRGB(120, 255, 190)
		plot.vacancyLight.Color = Color3.fromRGB(120, 255, 190)
	else
		plot.vacancyLabel.Text = "NO VACANCY"
		plot.vacancyLabel.TextColor3 = Color3.fromRGB(255, 108, 128)
		plot.vacancyLight.Color = Color3.fromRGB(255, 108, 128)
	end

	local doorTitle = plot.door:FindFirstChild("Label")
	if doorTitle then
		local title = doorTitle:FindFirstChild("DoorTitle") :: TextLabel?
		local subtitle = doorTitle:FindFirstChild("DoorSubtitle") :: TextLabel?
		if title and subtitle then
			local seconds = EconomyService.breakSeconds(profile)
			title.Text = if NightService.isNight() then "DOOR" else "SEALED"
			local robbable, reason = EconomyService.robbable(profile, PlotService.joinedAt(player))
			if not NightService.isNight() then
				subtitle.Text = "Opens at Lights Out"
			elseif not robbable then
				subtitle.Text = reason or "Protected"
			else
				subtitle.Text = `Hold for {seconds}s to break in`
			end
		end
	end
end

local function markVacant(plot: Plot)
	-- Strip the last owner's upgrades back to a bare One Star.
	WorldBuilder.applyRating(plot, 1)
	plot.nameLabel.Text = "VACANT PLOT"
	plot.rentLabel.Text = "Nobody has claimed this one"
	plot.vacancyLabel.Text = "VACANCY"
	plot.vacancyLabel.TextColor3 = Color3.fromRGB(120, 255, 190)
	clearPlot(plot)
end

-- ---------------------------------------------------------------- assignment

local function assign(player: Player)
	for _, plot in plots do
		if not ownerByPlot[plot.index] then
			ownerByPlot[plot.index] = player
			plotByPlayer[player] = plot
			joinedAt[player] = os.time()
			-- The client reads this to know which door is its own, so it never
			-- offers to break into the motel the player already owns.
			player:SetAttribute("Plot", plot.index)
			rendered[plot.index] = {}
			PlotService.Assigned:Fire(player, plot)
			return
		end
	end
	-- More players than plots. The server is sized to PlotCount, so this only
	-- happens if someone raises MaxPlayers without raising the ring.
	warn(`[PlotService] no free plot for {player.Name}`)
	player:Kick("This motel town is full. Please join another server.")
end

local function release(player: Player)
	local plot = plotByPlayer[player]
	if plot then
		ownerByPlot[plot.index] = nil
		markVacant(plot)
	end
	plotByPlayer[player] = nil
	joinedAt[player] = nil
	player:SetAttribute("Plot", nil)
end

--[[ Where a player should be put when they spawn: in front of their own desk,
     facing their motel. ]]
function PlotService.spawnCFrame(player: Player): CFrame?
	local plot = plotByPlayer[player]
	if not plot then
		return nil
	end
	return plot.origin * CFrame.new(0, 5, 22) * CFrame.Angles(0, math.pi, 0)
end

function PlotService.start(built: WorldBuilder.Built)
	plots = built.plots

	for _, player in Players:GetPlayers() do
		assign(player)
	end
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)

	DataService.Loaded:Connect(function(player)
		PlotService.renderGuests(player)
		PlotService.refreshSign(player)
	end)

	EconomyService.Changed:Connect(function(player)
		PlotService.renderGuests(player)
		PlotService.refreshSign(player)
	end)

	-- Door labels flip for everyone at sunrise and sunset.
	NightService.Changed:Connect(function()
		for player in plotByPlayer do
			PlotService.refreshSign(player)
		end
	end)
end

return PlotService
