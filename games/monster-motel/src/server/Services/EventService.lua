--!strict
--[[
	EventService -- the Celebrity Arrival

	Every ten minutes a Celebrity lands on the stage in the middle of town, worth
	more rent than anything on the arrivals road will ever offer. Whoever carries it
	back to their own front desk keeps it.

	This is the event the whole server stops for, and it is deliberately not a
	private roll. Everybody sees the same countdown, everybody sees who is carrying
	it, and anyone who catches the carrier makes them drop it. A rare thing that
	arrives in public and has to be walked home in front of people is worth far
	more to a server than the same rare thing handed out quietly in a menu.

	It is also the one thing in the game with no price attached at all: no pass
	makes you faster at claiming it, and there is no way to buy a Celebrity.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Guests = require(Shared.Config.Guests)

local Remote = require(script.Parent.Remote)
local TheftService = require(script.Parent.TheftService)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local EventService = {}

local rng = Random.new()

local stage: BasePart
local titleLabel: TextLabel?
local subtitleLabel: TextLabel?

local activeGuest: string? = nil
local activeModel: Model? = nil
local claimEndsAt = 0
local nextEventAt = 0
local carriedBy: Player? = nil

function EventService.state(): { [string]: any }
	return {
		active = activeGuest ~= nil,
		guest = activeGuest,
		claimSecondsLeft = math.max(0, claimEndsAt - os.clock()),
		nextEventIn = math.max(0, nextEventAt - os.clock()),
		carriedBy = if carriedBy then carriedBy.Name else nil,
	}
end

local function setStageText(title: string, subtitle: string)
	if titleLabel then
		titleLabel.Text = title
	end
	if subtitleLabel then
		subtitleLabel.Text = subtitle
	end
end

local function despawn()
	if activeModel then
		activeModel:Destroy()
		activeModel = nil
	end
	activeGuest = nil
	carriedBy = nil
	Remote.effectAll("celebrity", EventService.state())
end

--[[ Puts the celebrity on the stage and opens the claim window. Called when the
     event fires and again whenever a carrier drops it. ]]
local function place(guestId: string, secondsLeft: number)
	local guest = Guests.get(guestId)
	if not guest then
		return
	end

	if activeModel then
		activeModel:Destroy()
	end

	local model = WorldBuilder.buildGuestModel(guest, "celebrity")
	model.Name = "Celebrity"
	model:PivotTo(stage.CFrame * CFrame.new(0, 4, 0))
	model.Parent = workspace:WaitForChild("World")

	if model.PrimaryPart then
		model.PrimaryPart.Touched:Connect(function(hit: BasePart)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player or activeGuest ~= guestId or carriedBy then
				return
			end
			EventService.claim(player)
		end)
	end

	activeModel = model
	activeGuest = guestId
	carriedBy = nil
	claimEndsAt = os.clock() + secondsLeft

	setStageText(string.upper(guest.name), `Grab them and get them to your front desk`)
	Remote.effectAll("celebrity", EventService.state())
end

function EventService.claim(player: Player): (boolean, string)
	if not activeGuest or carriedBy then
		return false, "Nobody is on the stage."
	end
	if TheftService.isCarrying(player) then
		return false, "Your hands are full."
	end

	local guestId = activeGuest
	if not TheftService.carryCelebrity(player, guestId) then
		return false, "Your hands are full."
	end

	carriedBy = player
	if activeModel then
		activeModel:Destroy()
		activeModel = nil
	end

	local guest = Guests.get(guestId)
	local name = if guest then guest.name else "The celebrity"

	setStageText(string.upper(name), `{player.DisplayName} has them!`)
	Remote.notifyAll(`{player.DisplayName} grabbed {name}! Catch them before they get home.`, "warn")
	Remote.effectAll("celebrity", EventService.state())

	return true, `You have {name}. Run.`
end

--[[ Called when a carry ends without delivery. The celebrity goes back on the
     stage with whatever is left of the claim window, so the scramble continues
     rather than the event quietly ending. ]]
local function onDropped(guestId: string)
	if carriedBy == nil then
		return
	end
	carriedBy = nil

	local remaining = math.max(20, claimEndsAt - os.clock())
	place(guestId, remaining)

	local guest = Guests.get(guestId)
	Remote.notifyAll(
		`{if guest then guest.name else "The celebrity"} is back on the stage. Go.`,
		"warn"
	)
end

--[[ Connected to TheftService.CelebrityDelivered. ]]
local function onDelivered(player: Player, guestId: string)
	if activeGuest ~= guestId then
		return
	end
	local guest = Guests.get(guestId)
	Remote.notifyAll(
		`{player.DisplayName} got {if guest then guest.name else "the celebrity"} home. `
			.. `+${Format.short(if guest then guest.rent else 0)}/s`,
		"good"
	)
	setStageText("TOWN SQUARE", "A celebrity checks in every 10 minutes")
	despawn()
end

local function runEvent()
	local pool = Guests.Celebrities
	if #pool == 0 then
		return
	end

	local guest = pool[rng:NextInteger(1, #pool)]

	Remote.notifyAll(
		`{guest.name} is checking into town in {GameConfig.EventWarning} seconds. Get to the square.`,
		"warn"
	)
	setStageText("ARRIVING", guest.name)
	task.wait(GameConfig.EventWarning)

	place(guest.id, GameConfig.EventClaimWindow)
	Remote.notifyAll(`{guest.name} has arrived. First to walk them home keeps them.`, "good")

	-- Wait out the claim window. If somebody is carrying when it expires we let
	-- them finish the run rather than yanking it out of their arms.
	while os.clock() < claimEndsAt or carriedBy do
		task.wait(1)
		if not activeGuest then
			return
		end
	end

	if activeGuest then
		Remote.notifyAll(`{guest.name} got bored and left. Next one in 10 minutes.`, "info")
		setStageText("TOWN SQUARE", "A celebrity checks in every 10 minutes")
		despawn()
	end
end

function EventService.start(built: WorldBuilder.Built)
	stage = built.stage

	local label = stage:FindFirstChild("Label")
	if label then
		titleLabel = label:FindFirstChild("EventTitle") :: TextLabel?
		subtitleLabel = label:FindFirstChild("EventSubtitle") :: TextLabel?
	end

	TheftService.CelebrityDropped:Connect(onDropped)
	TheftService.CelebrityDelivered:Connect(onDelivered)

	task.spawn(function()
		while true do
			nextEventAt = os.clock() + GameConfig.EventInterval
			Remote.effectAll("celebrity", EventService.state())

			task.wait(GameConfig.EventInterval - GameConfig.EventWarning)

			local ok, err = pcall(runEvent)
			if not ok then
				warn(`[EventService] celebrity arrival failed: {err}`)
				despawn()
			end
		end
	end)
end

return EventService
