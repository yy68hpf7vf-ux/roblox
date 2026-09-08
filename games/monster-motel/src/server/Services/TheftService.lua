--!strict
--[[
	TheftService

	The raid: break a door during Lights Out, carry a guest out, walk it home.

	The rule this file exists to enforce is that a guest is never duplicated and
	never lost. A guest in transit belongs to nobody's profile -- it is held here,
	in one place, with exactly four ways out: delivered to the thief, tagged back to
	the victim, dropped when the thief dies or leaves, or returned at sunrise.
	Every one of those paths ends in `settle`, so there is a single function that
	decides who owns it.

	The other rule is fairness. Break time reads only the defender's lock. Carry
	speed is a constant. Tag range is a constant. The grace window is a constant.
	None of them are multiplied by anything a player owns or bought -- see
	docs/FAIRNESS.md, and the self-test that asserts the store never sells any of
	them.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Guests = require(Shared.Config.Guests)
local Format = require(Shared.Util.Format)
local Schema = require(Shared.Schema)
local Signal = require(Shared.Util.Signal)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GuestService = require(script.Parent.GuestService)
local NightService = require(script.Parent.NightService)
local PlotService = require(script.Parent.PlotService)
local QuestService = require(script.Parent.QuestService)
local Remote = require(script.Parent.Remote)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

type Profile = Schema.Profile

local TheftService = {}

local DOOR_RANGE = 14

--[[ A guest that has left one profile and not yet joined another. `victim` is nil
     for a celebrity, which nobody owned to begin with. ]]
type Carry = {
	guestId: string,
	victim: Player?,
	model: Model?,
	startedAt: number,
}

type Breaking = {
	plotIndex: number,
	elapsed: number,
}

--[[ Celebrity outcomes are announced as signals rather than called directly, so
     EventService can require TheftService without the two requiring each other. ]]
TheftService.CelebrityDropped = Signal.new() :: Signal.Signal<string>
TheftService.CelebrityDelivered = Signal.new() :: Signal.Signal<Player, string>

local carrying: { [Player]: Carry } = {}
local breaking: { [Player]: Breaking } = {}
-- thief -> plot index -> true, cleared at sunrise.
local access: { [Player]: { [number]: boolean } } = {}
-- thief -> victim -> steals taken tonight, cleared at sunrise.
local takenTonight: { [Player]: { [Player]: number } } = {}
-- Plots that lost nobody tonight, for the "survive a night" quest.
local robbedTonight: { [Player]: boolean } = {}

function TheftService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function TheftService.carriedGuest(player: Player): string?
	local carry = carrying[player]
	return if carry then carry.guestId else nil
end

function TheftService.breakProgress(player: Player): (number, number)
	local record = breaking[player]
	if not record then
		return 0, 0
	end
	local owner = PlotService.ownerOf(record.plotIndex)
	local profile = owner and DataService.get(owner)
	local needed = if profile then EconomyService.breakSeconds(profile) else 0
	return record.elapsed, needed
end

-- ---------------------------------------------------------------- helpers

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setCarrySpeed(player: Player, slow: boolean)
	local humanoid = humanoidOf(player)
	if humanoid then
		-- A flat constant both ways. Nothing scales it, so a thief with every
		-- pass in the store runs home at exactly the speed a new player does.
		humanoid.WalkSpeed = if slow then GameConfig.CarryWalkSpeed else GameConfig.NormalWalkSpeed
	end
end

local function attachCarryModel(player: Player, guestId: string): Model?
	local guest = Guests.get(guestId)
	local character = player.Character
	local root = rootOf(player)
	if not guest or not character or not root then
		return nil
	end

	local model = WorldBuilder.buildGuestModel(guest, "carried")
	model.Name = "CarriedGuest"
	model.Parent = character

	local primary = model.PrimaryPart
	if primary then
		model:PivotTo(root.CFrame * CFrame.new(0, 4.6, 0))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = primary
		weld.Parent = primary
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
				descendant.CanCollide = false
				descendant.Massless = true
			end
		end
	end

	return model
end

-- ---------------------------------------------------------------- settlement

--[[ The single exit from being in transit. `toThief` decides who ends up owning
     the guest; either way the carry record is cleared and the thief is released
     back to normal speed. There is no other way to end a carry. ]]
local function settle(thief: Player, toThief: boolean, reason: string)
	local carry = carrying[thief]
	if not carry then
		return
	end
	carrying[thief] = nil

	if carry.model then
		carry.model:Destroy()
	end
	setCarrySpeed(thief, false)

	local guest = Guests.get(carry.guestId)
	local guestName = if guest then guest.name else "The guest"

	if toThief then
		local profile = DataService.get(thief)
		if profile then
			local owned, housed = GuestService.give(thief, profile, carry.guestId)
			if owned then
				profile.stats.guestsStolen += 1
				QuestService.addProgress(thief, profile, "steal_guests", 1)

				Remote.notify(
					thief,
					if housed
						then `{guestName} checked into your motel. +${Format.short(if guest then guest.rent else 0)}/s`
						else `{guestName} is in storage -- you have no free room.`,
					"good"
				)
				Remote.effect(thief, "stoleGuest", { guest = carry.guestId })

				if not carry.victim then
					-- Nobody owned it, so this was the town square celebrity.
					profile.stats.celebritiesCaught += 1
					TheftService.CelebrityDelivered:Fire(thief, carry.guestId)
				end

				if carry.victim then
					local victimProfile = DataService.get(carry.victim)
					if victimProfile then
						victimProfile.stats.guestsLost += 1
					end
					Remote.notify(
						carry.victim,
						`{thief.DisplayName} got away with your {guestName}.`,
						"bad"
					)
					Remote.effect(carry.victim, "lostGuest", { guest = carry.guestId, thief = thief.Name })
				end
				return
			end
		end
		-- Could not hand it over (profile gone, at the ownership cap). Fall
		-- through and give it back rather than deleting it.
	end

	-- Back to the victim. A celebrity with no victim simply returns to the square,
	-- which EventService handles by re-listing it.
	if carry.victim then
		local victimProfile = DataService.get(carry.victim)
		if victimProfile then
			GuestService.give(carry.victim, victimProfile, carry.guestId)
			Remote.notify(carry.victim, `You got your {guestName} back. {reason}`, "good")
		end
		Remote.notify(thief, `You lost the {guestName}. {reason}`, "warn")
	else
		TheftService.CelebrityDropped:Fire(carry.guestId)
		Remote.notify(thief, `You lost the {guestName}. {reason}`, "warn")
	end
end

function TheftService.drop(thief: Player, reason: string)
	settle(thief, false, reason)
end

-- ---------------------------------------------------------------- breaking in

function TheftService.startBreak(thief: Player, plotIndex: unknown): (boolean, string)
	local index = tonumber(plotIndex)
	if not index then
		return false, "No door there."
	end
	if not NightService.isNight() then
		return false, "Doors are sealed until Lights Out."
	end
	if carrying[thief] then
		return false, "You already have your hands full."
	end

	local owner = PlotService.ownerOf(index)
	if not owner then
		return false, "Nobody lives there."
	end
	if owner == thief then
		return false, "That is your own motel."
	end

	local victimProfile = DataService.get(owner)
	if not victimProfile then
		return false, "That motel is still waking up."
	end

	local robbable, why = EconomyService.robbable(victimProfile, PlotService.joinedAt(owner))
	if not robbable then
		return false, why or "You cannot rob them right now."
	end

	if (access[thief] or {})[index] then
		return true, "The door is already open."
	end

	breaking[thief] = { plotIndex = index, elapsed = 0 }
	return true, ""
end

function TheftService.stopBreak(thief: Player): (boolean, string)
	breaking[thief] = nil
	return true, ""
end

-- ---------------------------------------------------------------- taking

function TheftService.grab(thief: Player, plotIndex: unknown, uid: unknown): (boolean, string)
	local index = tonumber(plotIndex)
	if not index or type(uid) ~= "string" then
		return false, "Pick a guest."
	end
	if not NightService.isNight() then
		return false, "Doors are sealed until Lights Out."
	end
	if carrying[thief] then
		return false, "You can only carry one at a time."
	end
	if not (access[thief] or {})[index] then
		return false, "You have not broken that door yet."
	end

	local owner = PlotService.ownerOf(index)
	if not owner or owner == thief then
		return false, "Nobody to steal from."
	end

	local victimProfile = DataService.get(owner)
	if not victimProfile then
		return false, "That motel is still waking up."
	end

	local robbable, why = EconomyService.robbable(victimProfile, PlotService.joinedAt(owner))
	if not robbable then
		return false, why or "You cannot rob them right now."
	end

	local already = (takenTonight[thief] or {})[owner] or 0
	if already >= GameConfig.StealCooldownPerVictim then
		return false, "You have already taken one from them tonight."
	end

	local thiefRoot = rootOf(thief)
	local model = PlotService.guestModel(owner, uid)
	if not thiefRoot or not model or not model.PrimaryPart then
		return false, "Get closer to the guest."
	end
	if (model.PrimaryPart.Position - thiefRoot.Position).Magnitude > DOOR_RANGE then
		return false, "Get closer to the guest."
	end

	local owned = GuestService.find(victimProfile, uid)
	if not owned or owned.room == 0 then
		return false, "That guest is not in a room."
	end

	-- Leaves the victim's profile here and does not enter anyone else's until
	-- `settle` runs. This is the only place a guest becomes in-transit.
	local removed = GuestService.remove(owner, victimProfile, uid)
	if not removed then
		return false, "Too slow -- someone else got them."
	end

	local map = takenTonight[thief]
	if not map then
		map = {}
		takenTonight[thief] = map
	end
	map[owner] = already + 1
	robbedTonight[owner] = true

	carrying[thief] = {
		guestId = removed.guest,
		victim = owner,
		model = attachCarryModel(thief, removed.guest),
		startedAt = os.clock(),
	}
	setCarrySpeed(thief, true)

	local guest = Guests.get(removed.guest)
	local name = if guest then guest.name else "a guest"

	Remote.notify(owner, `{thief.DisplayName} is walking off with your {name}!`, "bad")
	Remote.effect(owner, "beingRobbed", { thief = thief.Name, guest = removed.guest })
	Remote.effect(thief, "carrying", { guest = removed.guest })

	return true, `You have their {name}. Get it home.`
end

--[[ Gives a celebrity to a thief to carry. Used by EventService -- nobody owns a
     celebrity, so there is no victim and nothing to give back. ]]
function TheftService.carryCelebrity(player: Player, guestId: string): boolean
	if carrying[player] then
		return false
	end
	carrying[player] = {
		guestId = guestId,
		victim = nil,
		model = attachCarryModel(player, guestId),
		startedAt = os.clock(),
	}
	setCarrySpeed(player, true)
	Remote.effect(player, "carrying", { guest = guestId, celebrity = true })
	return true
end

function TheftService.deliver(player: Player): (boolean, string)
	local carry = carrying[player]
	if not carry then
		return false, "You are not carrying anyone."
	end
	settle(player, true, "Delivered.")
	return true, ""
end

-- ---------------------------------------------------------------- loops

local function tickBreaking(dt: number)
	for thief, record in breaking do
		local owner = PlotService.ownerOf(record.plotIndex)
		local victimProfile = owner and DataService.get(owner)
		local plot = owner and PlotService.plotFor(owner)
		local thiefRoot = rootOf(thief)

		if not NightService.isNight() or not owner or not victimProfile or not plot or not thiefRoot then
			breaking[thief] = nil
			continue
		end

		if (plot.door.Position - thiefRoot.Position).Magnitude > DOOR_RANGE then
			breaking[thief] = nil
			Remote.effect(thief, "breakCancelled", {})
			continue
		end

		record.elapsed += dt
		local needed = EconomyService.breakSeconds(victimProfile)

		if record.elapsed >= needed then
			breaking[thief] = nil
			local map = access[thief]
			if not map then
				map = {}
				access[thief] = map
			end
			map[record.plotIndex] = true

			Remote.effect(thief, "doorOpen", { plot = record.plotIndex })
			Remote.notify(thief, "The door gives. Grab someone and run.", "good")
			Remote.notify(owner, `{thief.DisplayName} just broke your door open.`, "bad")
		else
			Remote.effect(thief, "breakProgress", { elapsed = record.elapsed, needed = needed })
		end
	end
end

--[[ Getting close enough to a carrier makes them drop what they are holding.

     For a stolen guest only its owner can do it -- otherwise a bystander could
     grief a raid they had no stake in. For the town square celebrity, which
     nobody owns, *anyone* can, which is what turns the walk home into the best
     ninety seconds in the game.

     Range is a constant either way, so catching someone is a question of whether
     you set off after them, not of what either of you owns. ]]
local function tickTagging()
	for thief, carry in carrying do
		local thiefRoot = rootOf(thief)
		if not thiefRoot then
			continue
		end

		local chasers: { Player } = {}
		if carry.victim then
			if carry.victim.Parent then
				table.insert(chasers, carry.victim)
			end
		else
			for _, other in Players:GetPlayers() do
				if other ~= thief then
					table.insert(chasers, other)
				end
			end
		end

		for _, chaser in chasers do
			local chaserRoot = rootOf(chaser)
			if chaserRoot and (thiefRoot.Position - chaserRoot.Position).Magnitude <= GameConfig.TagRange then
				settle(thief, false, `{chaser.DisplayName} caught up with you.`)
				break
			end
		end
	end
end

local function connectDelivery(plot: any)
	plot.desk.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or not carrying[player] then
			return
		end
		if PlotService.plotFor(player) ~= plot then
			return
		end
		TheftService.deliver(player)
	end)
end

function TheftService.start()
	for _, plot in PlotService.plots() do
		connectDelivery(plot)
	end

	-- Sunrise: every door relocks, every raid in progress ends, and anyone still
	-- holding a guest gives it back. Nobody keeps a prize they did not get home.
	NightService.Changed:Connect(function(night: boolean)
		if night then
			table.clear(robbedTonight)
			return
		end

		table.clear(access)
		table.clear(breaking)
		table.clear(takenTonight)

		for thief in carrying do
			settle(thief, false, "The sun came up.")
		end

		-- Anyone who kept everyone gets credit for the night.
		for _, player in Players:GetPlayers() do
			local profile = DataService.get(player)
			if profile and not robbedTonight[player] then
				profile.stats.nightsSurvived += 1
				QuestService.addProgress(player, profile, "survive_nights", 1)
			end
		end
		table.clear(robbedTonight)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				humanoid.WalkSpeed = GameConfig.NormalWalkSpeed
				humanoid.Died:Connect(function()
					TheftService.drop(player, "You dropped them.")
				end)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Leaving mid-carry gives the guest back rather than deleting it.
		TheftService.drop(player, "They left the server.")
		breaking[player] = nil
		access[player] = nil
		takenTonight[player] = nil
		robbedTonight[player] = nil

		for thief, carry in carrying do
			if carry.victim == player then
				-- The victim left, so there is nobody to return it to. The thief
				-- keeps it -- better than the guest vanishing.
				settle(thief, true, "")
			end
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		local step = accumulator
		accumulator = 0

		tickBreaking(step)
		tickTagging()
	end)
end

return TheftService
