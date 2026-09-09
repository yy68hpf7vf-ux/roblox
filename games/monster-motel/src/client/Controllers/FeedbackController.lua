--!strict
--[[
	FeedbackController

	The moment-to-moment feel: numbers that fly off things, a flash when somebody
	robs you, a pop when a guest checks in.

	This was a real gap rather than a polish nicety. The server has been firing a
	`collected` effect since the day it was written and the client threw it away, so
	the single most repeated action in the game -- walking onto your desk and banking
	your rent -- produced no feedback at all beyond a number quietly changing in the
	corner. An action with no response does not feel like an action.

	All of it is local and cosmetic. Nothing here decides anything.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Guests = require(Shared.Config.Guests)

local FeedbackController = {}

local player = Players.LocalPlayer
local screen: ScreenGui

--[[ A number that rises off a point in the world and fades. The workhorse: cash
     collected, rent gained, a guest lost. ]]
local function floatText(position: Vector3, text: string, color: Color3, scale: number?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(8 * (scale or 1), 2.4 * (scale or 1))
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui

	TweenService:Create(anchor, TweenInfo.new(1.1), { Position = position + Vector3.new(0, 9, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	Debris:AddItem(anchor, 1.3)
end

local function burst(position: Vector3, color: Color3, count: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(10, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.7, 0)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(count)

	Debris:AddItem(attachment, 1.5)
end

--[[ A coloured vignette across the screen. Used only for the two things a player
     must not miss: being robbed, and a celebrity landing. ]]
local function flash(color: Color3, strength: number)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - strength
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = -1
	frame.Parent = screen

	TweenService:Create(frame, TweenInfo.new(0.75), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(frame, 1)
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

-- ---------------------------------------------------------------- handlers

function FeedbackController.onCollected(amount: number)
	local position = rootPosition()
	if not position or amount <= 0 then
		return
	end
	floatText(position + Vector3.new(0, 5, 0), `+${Format.short(amount)}`, Color3.fromRGB(96, 220, 138), 1.3)
	burst(position + Vector3.new(0, 3, 0), Color3.fromRGB(96, 220, 138), 18)
end

function FeedbackController.onCheckedIn(guestId: string?)
	local position = rootPosition()
	local guest = if guestId then Guests.get(guestId) else nil
	if not position or not guest then
		return
	end
	floatText(position + Vector3.new(0, 6, 0), guest.name, guest.color)
	burst(position + Vector3.new(0, 3, 0), guest.color, 14)
end

function FeedbackController.onDiscovered(guestId: string?)
	local position = rootPosition()
	local guest = if guestId then Guests.get(guestId) else nil
	if not position or not guest then
		return
	end
	local color = Guests.RarityColor[guest.rarity] or guest.color
	floatText(position + Vector3.new(0, 9, 0), `NEW  ·  {guest.rarity}`, color, 1.4)
	burst(position + Vector3.new(0, 4, 0), color, 40)
end

function FeedbackController.onStole(guestId: string?)
	local position = rootPosition()
	local guest = if guestId then Guests.get(guestId) else nil
	if position and guest then
		floatText(position + Vector3.new(0, 7, 0), `+${Format.short(guest.rent)}/s`, guest.color, 1.3)
		burst(position + Vector3.new(0, 3, 0), guest.color, 30)
	end
	flash(Color3.fromRGB(96, 220, 138), 0.16)
end

--[[ The moment somebody lifts a guest off your desk. Loud on purpose: the whole
     point of the carry walk is that you get a window to chase, and a window you
     do not notice is not a window. ]]
function FeedbackController.onBeingRobbed(guestId: string?)
	local guest = if guestId then Guests.get(guestId) else nil
	local position = rootPosition()
	if position and guest then
		floatText(position + Vector3.new(0, 8, 0), `{guest.name} taken!`, Color3.fromRGB(255, 108, 128), 1.4)
	end
	flash(Color3.fromRGB(255, 60, 90), 0.32)
end

--[[ And the moment they get it home. Quieter than the alarm above -- by now you
     already knew, and there is nothing left to do about it. ]]
function FeedbackController.onRobbed(guestId: string?)
	local guest = if guestId then Guests.get(guestId) else nil
	local position = rootPosition()
	if position and guest then
		floatText(position + Vector3.new(0, 7, 0), `-${Format.short(guest.rent)}/s`, Color3.fromRGB(255, 108, 128), 1.3)
	end
	flash(Color3.fromRGB(255, 60, 90), 0.18)
end

function FeedbackController.onRenovated(stars: number)
	local position = rootPosition()
	if position then
		floatText(position + Vector3.new(0, 8, 0), `+{stars}★`, Color3.fromRGB(255, 200, 92), 1.6)
		burst(position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 200, 92), 60)
	end
	flash(Color3.fromRGB(255, 200, 92), 0.22)
end

--[[ The celebrity effect is a full state push and fires on every change --
     spawned, claimed, delivered, expired. Only the arrival is worth a flash, so
     this watches for the edge rather than reacting to the message. ]]
local celebrityWasActive = false

function FeedbackController.onCelebrity(active: boolean)
	if active and not celebrityWasActive then
		flash(Color3.fromRGB(255, 236, 140), 0.18)
	end
	celebrityWasActive = active
end

function FeedbackController.start(parent: ScreenGui)
	screen = parent
end

return FeedbackController
