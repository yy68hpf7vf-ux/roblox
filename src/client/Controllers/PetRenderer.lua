--!strict
--[[
	PetRenderer

	Draws everyone's equipped pets from their `Pets` attribute -- a comma-separated
	list of pet ids the server maintains.

	Pets are unanchored-looking but actually anchored and moved by CFrame each
	frame, which is far cheaper than physics and cannot shove a player off a ledge.
	They are also purely local, so a server with twenty players carrying five pets
	each is not replicating a hundred moving parts.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Pets = require(Shared.Config.Pets)

local PetRenderer = {}

type Rendered = {
	part: BasePart,
	slot: number,
	total: number,
}

local rendered: { [Player]: { Rendered } } = {}
local container: Folder

local function destroyFor(player: Player)
	local list = rendered[player]
	if not list then
		return
	end
	for _, entry in list do
		entry.part:Destroy()
	end
	rendered[player] = nil
end

local function makePet(pet: Pets.Pet, slot: number, total: number): Rendered
	local part = Instance.new("Part")
	part.Name = pet.id
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2.1, 2.1, 2.1)
	part.Color = pet.color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = container

	local glow = Instance.new("PointLight")
	glow.Color = pet.color
	glow.Range = 8
	glow.Brightness = 0.6
	glow.Parent = part

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(5, 1.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	gui.MaxDistance = 90
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Pets.RarityColor[pet.rarity] or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = pet.name
	label.Parent = gui

	return { part = part, slot = slot, total = total }
end

local function rebuild(player: Player)
	destroyFor(player)

	local raw = player:GetAttribute("Pets")
	if type(raw) ~= "string" or #raw == 0 then
		return
	end

	local list: { Rendered } = {}
	local ids = string.split(raw, ",")

	for index, id in ids do
		local pet = Pets.get(id)
		if pet then
			table.insert(list, makePet(pet, index, #ids))
		end
	end

	rendered[player] = list
end

--[[ Pets fan out in an arc behind their owner and bob out of phase, so a row of
     five reads as five creatures rather than one wide object. ]]
local function positionFor(root: BasePart, entry: Rendered, clock: number): CFrame
	local spread = math.rad(28)
	local centred = entry.slot - (entry.total + 1) / 2
	local angle = centred * spread

	local offset = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, GameConfig.PetFollowDistance)
	local bob = math.sin(clock * 2.4 + entry.slot * 1.3) * 0.45

	local base = root.CFrame * offset
	return CFrame.new(base.Position + Vector3.new(0, 1.4 + bob, 0)) * CFrame.Angles(0, clock * 0.8 + entry.slot, 0)
end

local function watch(player: Player)
	rebuild(player)
	player:GetAttributeChangedSignal("Pets"):Connect(function()
		rebuild(player)
	end)
	player.CharacterAdded:Connect(function()
		rebuild(player)
	end)
end

function PetRenderer.start()
	container = Instance.new("Folder")
	container.Name = "PetVisuals"
	container.Parent = workspace

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(destroyFor)

	RunService.Heartbeat:Connect(function()
		local clock = os.clock()
		for player, list in rendered do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			for _, entry in list do
				if root then
					entry.part.CFrame = entry.part.CFrame:Lerp(positionFor(root, entry, clock), 0.18)
					entry.part.Transparency = 0
				else
					entry.part.Transparency = 1
				end
			end
		end
	end)
end

return PetRenderer
