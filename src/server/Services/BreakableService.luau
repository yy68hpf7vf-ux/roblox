--!nonstrict
-- Spawns breakable objects, applies pet damage on a server tick, and pays out Coins.
-- Health, damage and rewards exist only here; clients just send "I'm targeting X".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Config.Economy)
local Types = require(Shared.Config.Breakables)
local SpawnConfig = require(Shared.Config.Spawns)

local DataService = require(script.Parent.DataService)
local CoinService = require(script.Parent.CoinService)
local PetService = require(script.Parent.PetService)
local RateLimiter = require(script.Parent.RateLimiter)

local BreakableService = {}

local folder: Folder
local breakables = {} -- [id] = { Model, Type, Health, MaxHealth, Alive, Position, Contributors }
local targets = {} -- [Player] = id
local nextId = 0

local function part(model, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- Builds the visual model for a type at `cf` (the bottom-center sits on the ground).
-- Returns the model and a representative color and height.
local function buildModel(typeName: string, cf: CFrame)
	local model = Instance.new("Model")
	local color, height
	if typeName == "CoinPile" then
		color, height = Color3.fromRGB(255, 205, 50), 2.4
		local base = part(model, "Base", Vector3.new(0.8, 3.6, 3.6), cf * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Metal, Enum.PartType.Cylinder)
		part(model, "Coins2", Vector3.new(0.8, 2.8, 2.8), cf * CFrame.new(0.2, 1.2, 0.2) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Metal, Enum.PartType.Cylinder)
		part(model, "Coins3", Vector3.new(0.8, 2.0, 2.0), cf * CFrame.new(-0.1, 2.0, -0.1) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 225, 90), Enum.Material.Metal, Enum.PartType.Cylinder)
		model.PrimaryPart = base
	elseif typeName == "WoodenCrate" then
		color, height = Color3.fromRGB(176, 120, 60), 4
		local box = part(model, "Box", Vector3.new(4, 4, 4), cf * CFrame.new(0, 2, 0), color, Enum.Material.Wood)
		part(model, "TrimX", Vector3.new(4.2, 0.5, 4.2), cf * CFrame.new(0, 0.3, 0), Color3.fromRGB(120, 78, 38), Enum.Material.Wood)
		part(model, "TrimY", Vector3.new(4.2, 0.5, 4.2), cf * CFrame.new(0, 3.7, 0), Color3.fromRGB(120, 78, 38), Enum.Material.Wood)
		part(model, "Band", Vector3.new(0.5, 4.2, 4.2), cf * CFrame.new(0, 2, 0), Color3.fromRGB(120, 78, 38), Enum.Material.Wood)
		model.PrimaryPart = box
	else -- TreasureChest
		color, height = Color3.fromRGB(255, 190, 40), 4
		local box = part(model, "Base", Vector3.new(5.5, 2.6, 3.6), cf * CFrame.new(0, 1.3, 0), Color3.fromRGB(150, 90, 40), Enum.Material.Wood)
		part(model, "Lid", Vector3.new(5.5, 1.4, 3.6), cf * CFrame.new(0, 3.3, 0), Color3.fromRGB(120, 70, 30), Enum.Material.Wood)
		part(model, "Band", Vector3.new(0.7, 4.2, 3.8), cf * CFrame.new(0, 2.1, 0), Color3.fromRGB(255, 200, 50), Enum.Material.Metal)
		part(model, "Lock", Vector3.new(0.9, 0.9, 0.5), cf * CFrame.new(0, 2.7, -1.9), Color3.fromRGB(255, 225, 90), Enum.Material.Metal)
		model.PrimaryPart = box
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(100, 12)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 1.5, 0)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.Adornee = model.PrimaryPart
	gui.Parent = model
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 230, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	for _, f in { back, fill } do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = f
	end
	return model, color, height
end

local function groundCFrame(position: Vector3): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local result = Workspace:Raycast(Vector3.new(position.X, 300, position.Z), Vector3.new(0, -600, 0), params)
	local y = result and result.Position.Y or 0
	return CFrame.new(position.X, y, position.Z)
end

local function pickType(rng: Random): string
	local total = 0
	for _, def in Types do
		total += def.Weight
	end
	local roll = rng:NextNumber() * total
	for name, def in Types do
		roll -= def.Weight
		if roll <= 0 then
			return name
		end
	end
	return "CoinPile"
end

local function spawnBreakable(id: string, typeName: string, position: Vector3)
	local def = Types[typeName]
	local cf = groundCFrame(position)
	local model, color, height = buildModel(typeName, cf)
	model.Name = id
	model.Parent = folder
	breakables[id] = {
		Model = model,
		Type = typeName,
		Health = def.Health,
		MaxHealth = def.Health,
		Alive = true,
		Position = cf.Position + Vector3.new(0, height / 2, 0),
		Color = color,
		Size = height,
		Contributors = {},
		SpawnPosition = position,
	}
end

local function clearTargetsOn(id: string)
	for player, targetId in targets do
		if targetId == id then
			targets[player] = nil
			player:SetAttribute("TargetId", nil)
		end
	end
end

local function breakObject(id: string)
	local b = breakables[id]
	if not b or not b.Alive then
		return -- already broken: never pay twice
	end
	b.Alive = false

	local def = Types[b.Type]
	local total = 0
	for player, damage in b.Contributors do
		if player.Parent == Players then
			total += damage
		end
	end
	if total > 0 then
		for player, damage in b.Contributors do
			if player.Parent == Players then
				local share = math.max(1, math.floor(def.Reward * damage / total))
				if CoinService.add(player, share) then
					local data = DataService.get(player)
					if data then
						data.Stats.ObjectsBroken += 1
					end
					Remotes.event("CoinReward"):FireClient(player, b.Position, share)
				end
			end
		end
	end

	Remotes.event("BreakableBroken"):FireAllClients(b.Position, b.Color, b.Size)
	clearTargetsOn(id)
	b.Model:Destroy()
	b.Model = nil

	task.delay(def.RespawnTime, function()
		spawnBreakable(id, b.Type, b.SpawnPosition)
	end)
end

local function tick()
	for player, id in targets do
		local b = breakables[id]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not b or not b.Alive or not root or (root.Position - b.Position).Magnitude > Economy.StopRange then
			targets[player] = nil
			player:SetAttribute("TargetId", nil)
		else
			local damage = PetService.getTotalPower(player)
			if damage > 0 then
				b.Health = math.max(0, b.Health - damage)
				b.Contributors[player] = (b.Contributors[player] or 0) + damage
				local fraction = b.Health / b.MaxHealth
				local gui = b.Model:FindFirstChild("HealthBar")
				if gui then
					gui.Enabled = true
					gui.Frame.Fill.Size = UDim2.fromScale(fraction, 1)
				end
				Remotes.event("BreakableHit"):FireAllClients(id, damage, fraction, b.Position)
				if b.Health <= 0 then
					breakObject(id)
				end
			end
		end
	end
end

function BreakableService.init()
	folder = Instance.new("Folder")
	folder.Name = "Breakables"
	folder.Parent = Workspace

	local rng = Random.new(SpawnConfig.Seed)
	for i = 1, SpawnConfig.Count do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = SpawnConfig.MinRadius + rng:NextNumber() * (SpawnConfig.MaxRadius - SpawnConfig.MinRadius)
		local position = SpawnConfig.Origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		nextId += 1
		spawnBreakable("B" .. nextId, pickType(rng), position)
	end

	Remotes.event("TargetBreakable").OnServerEvent:Connect(function(player, id)
		if not RateLimiter.allow(player, "Target", 10, 1) then
			return
		end
		if id == nil then
			targets[player] = nil
			player:SetAttribute("TargetId", nil)
			return
		end
		if type(id) ~= "string" then
			return
		end
		local b = breakables[id]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not b or not b.Alive or not root then
			return
		end
		if (root.Position - b.Position).Magnitude > Economy.TargetRange then
			return
		end
		targets[player] = id
		player:SetAttribute("TargetId", id)
	end)

	Players.PlayerRemoving:Connect(function(player)
		targets[player] = nil
		for _, b in breakables do
			b.Contributors[player] = nil
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= Economy.DamageTickSeconds then
			elapsed -= Economy.DamageTickSeconds
			tick()
		end
	end)
end

return BreakableService
