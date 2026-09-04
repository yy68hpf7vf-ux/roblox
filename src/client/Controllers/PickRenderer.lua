--!strict
--[[
	PickRenderer

	Draws the pick in every visible player's hand from their `Pick` attribute, and
	animates the local player's swing.

	This is a client-side cosmetic: the server never creates these parts, so a
	crowded server is not replicating thirty pickaxes to thirty clients.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)

local PickRenderer = {}

local localPlayer = Players.LocalPlayer
local motors: { [Player]: Motor6D } = {}

local REST = CFrame.new(0, -1.1, -0.6) * CFrame.Angles(math.rad(-100), 0, 0)
local SWUNG = CFrame.new(0, -0.9, -1.1) * CFrame.Angles(math.rad(-20), 0, 0)

local function handOf(character: Model): BasePart?
	return (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
end

--[[ Destroys the model *and* the motor that drove it. Leaving the motor behind
     would strand a broken Motor6D in the hand every time a player swapped picks. ]]
local function clearPick(character: Model, hand: BasePart?)
	local existing = character:FindFirstChild("PickVisual")
	if existing then
		existing:Destroy()
	end
	if hand then
		local motor = hand:FindFirstChild("PickMotor")
		if motor then
			motor:Destroy()
		end
	end
end

local function buildPick(player: Player, character: Model)
	local hand = handOf(character)
	if not hand then
		return
	end

	clearPick(character, hand)

	local tool = Tools.get(player:GetAttribute("Pick") :: string?)

	local model = Instance.new("Model")
	model.Name = "PickVisual"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.24, 2.4, 0.24)
	handle.Color = Color3.fromRGB(92, 68, 48)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.9, 0.42, 0.42)
	head.Color = tool.color
	head.Material = Enum.Material.Metal
	head.Reflectance = 0.12
	head.CanCollide = false
	head.CanQuery = false
	head.CanTouch = false
	head.Massless = true
	head.Parent = model

	-- The head sits at the top of the shaft; a rigid weld keeps them together
	-- while the Motor6D below animates the whole model from the hand.
	head.CFrame = handle.CFrame * CFrame.new(0, 1.2, 0)
	local join = Instance.new("WeldConstraint")
	join.Part0 = handle
	join.Part1 = head
	join.Parent = head

	model.PrimaryPart = handle
	model.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name = "PickMotor"
	motor.Part0 = hand
	motor.Part1 = handle
	motor.C0 = REST
	motor.Parent = hand

	motors[player] = motor
end

local function watch(player: Player)
	local function onCharacter(character: Model)
		-- The hand can arrive a frame after the model does.
		task.defer(function()
			if character.Parent then
				buildPick(player, character)
			end
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	player:GetAttributeChangedSignal("Pick"):Connect(function()
		local character = player.Character
		if character then
			buildPick(player, character)
		end
	end)
end

function PickRenderer.swing(player: Player)
	local motor = motors[player]
	if not motor or not motor.Parent then
		return
	end

	TweenService:Create(motor, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = SWUNG })
		:Play()
	task.delay(0.12, function()
		if motor.Parent then
			TweenService
				:Create(motor, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = REST })
				:Play()
		end
	end)
end

function PickRenderer.swingLocal()
	PickRenderer.swing(localPlayer)
end

function PickRenderer.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		motors[player] = nil
	end)
end

return PickRenderer
