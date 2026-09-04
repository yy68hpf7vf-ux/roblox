--!strict
--[[
	WorldBuilder

	Builds every island from Zones.lua at runtime. Nothing about the map lives in
	the .rbxl, which means re-tuning a zone is a config edit rather than an hour of
	dragging parts, and every server generates an identical map from the same seed.

	Layout per island, in local coordinates:

	    plaza  (z = -78)   sell pad, shop pad, egg pad, travel pads
	    field  (z > -60)   nodes, scattered on a fixed seed
]]

local Zones = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Zones)
local Eggs = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Eggs)

local WorldBuilder = {}

local ISLAND_SIZE = 240
local ISLAND_THICKNESS = 8
local FIELD_HALF = 92
local PLAZA_Z = -78

export type Built = {
	root: Folder,
	nodesByZone: { [string]: { BasePart } },
	sellPads: { [string]: BasePart },
}

local function part(props: { [string]: any }): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.CanCollide = true
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local function label(parent: BasePart, title: string, subtitle: string?, height: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(14, 4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 220
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, if subtitle then 0.58 else 1)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextStrokeTransparency = 0.4
	titleLabel.Text = title
	titleLabel.Parent = gui

	if subtitle then
		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "Subtitle"
		subLabel.BackgroundTransparency = 1
		subLabel.Position = UDim2.fromScale(0, 0.58)
		subLabel.Size = UDim2.fromScale(1, 0.42)
		subLabel.Font = Enum.Font.Gotham
		subLabel.TextScaled = true
		subLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
		subLabel.TextStrokeTransparency = 0.6
		subLabel.Text = subtitle
		subLabel.Parent = gui
	end

	return gui
end

local function pad(parent: Instance, name: string, position: Vector3, color: Color3, size: Vector3): Part
	local instance = part({
		Name = name,
		Size = size,
		Position = position,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})

	local outline = Instance.new("SelectionBox")
	outline.Adornee = instance
	outline.LineThickness = 0.06
	outline.Color3 = color
	outline.Transparency = 0.4
	outline.Parent = instance

	return instance
end

local function buildNode(parent: Instance, zone: Zones.Zone, index: number, position: Vector3, rng: Random): Part
	local size = rng:NextNumber(5, 7.5)
	local node = part({
		Name = "Node",
		Size = Vector3.new(size, size * rng:NextNumber(0.9, 1.4), size),
		CFrame = CFrame.new(position)
			* CFrame.Angles(
				math.rad(rng:NextNumber(-12, 12)),
				math.rad(rng:NextNumber(0, 360)),
				math.rad(rng:NextNumber(-12, 12))
			),
		Color = zone.nodeColor,
		Material = Enum.Material.Glass,
		Reflectance = 0.15,
		Parent = parent,
	})

	node:SetAttribute("Zone", zone.id)
	node:SetAttribute("Index", index)

	local glow = Instance.new("PointLight")
	glow.Color = zone.nodeColor
	glow.Range = 12
	glow.Brightness = 0.8
	glow.Parent = node

	return node
end

--[[ Node placement is seeded per zone, so every server in the game has its nodes
     in exactly the same place -- players can learn a route. The plaza strip is
     excluded so nodes never spawn on top of the sell pad. ]]
local function nodePositions(zone: Zones.Zone): { Vector3 }
	local rng = Random.new(#zone.id * 104729 + zone.nodeCount)
	local positions = {}
	local attempts = 0

	while #positions < zone.nodeCount and attempts < zone.nodeCount * 40 do
		attempts += 1
		local x = rng:NextNumber(-FIELD_HALF, FIELD_HALF)
		local z = rng:NextNumber(-52, FIELD_HALF)
		local candidate = Vector3.new(x, 3, z)

		local tooClose = false
		for _, existing in positions do
			if (existing - candidate).Magnitude < 18 then
				tooClose = true
				break
			end
		end

		if not tooClose then
			table.insert(positions, candidate)
		end
	end

	return positions
end

local function buildIsland(root: Folder, zone: Zones.Zone, built: Built)
	local model = Instance.new("Model")
	model.Name = zone.id
	model.Parent = root

	local origin = zone.origin

	part({
		Name = "Ground",
		Size = Vector3.new(ISLAND_SIZE, ISLAND_THICKNESS, ISLAND_SIZE),
		Position = origin + Vector3.new(0, -ISLAND_THICKNESS / 2, 0),
		Color = zone.groundColor,
		Material = Enum.Material.Grass,
		Parent = model,
	})

	-- A low rim so a stray jump does not drop a player into the void.
	for _, offset in { Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0) } do
		local horizontal = math.abs(offset.X) > 0
		part({
			Name = "Rim",
			Size = if horizontal
				then Vector3.new(4, 10, ISLAND_SIZE)
				else Vector3.new(ISLAND_SIZE, 10, 4),
			Position = origin + offset * (ISLAND_SIZE / 2) + Vector3.new(0, 3, 0),
			Color = zone.groundColor:Lerp(Color3.new(0, 0, 0), 0.35),
			Material = Enum.Material.Slate,
			Parent = model,
		})
	end

	local zoneSign = part({
		Name = "ZoneSign",
		Size = Vector3.new(24, 1, 1),
		Position = origin + Vector3.new(0, 14, PLAZA_Z - 16),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	label(zoneSign, zone.name, zone.desc, 0)

	-- Plaza
	local sellPad = pad(
		model,
		"SellPad",
		origin + Vector3.new(0, 0.5, PLAZA_Z),
		Color3.fromRGB(96, 220, 138),
		Vector3.new(22, 1, 22)
	)
	sellPad:SetAttribute("Zone", zone.id)
	label(sellPad, "SELL", "Walk on to sell your ore", 6)
	built.sellPads[zone.id] = sellPad

	local shopPad = pad(
		model,
		"ShopPad",
		origin + Vector3.new(-44, 0.5, PLAZA_Z),
		Color3.fromRGB(120, 176, 255),
		Vector3.new(16, 1, 16)
	)
	shopPad:SetAttribute("Zone", zone.id)
	shopPad:SetAttribute("Opens", "shop")
	label(shopPad, "SHOP", "Picks and backpacks", 6)

	for _, egg in Eggs.List do
		if egg.zone == zone.id then
			local eggPad = pad(model, "EggPad", origin + egg.position + Vector3.new(0, 0.5, 0), egg.color, Vector3.new(16, 1, 16))
			eggPad:SetAttribute("Zone", zone.id)
			eggPad:SetAttribute("Egg", egg.id)
			eggPad:SetAttribute("Opens", "eggs")
			label(eggPad, egg.name, "Odds shown before you hatch", 6)
		end
	end

	-- Travel pads. The zone list in the UI can jump anywhere unlocked; these are
	-- for players who would rather just walk to the next island.
	local order = Zones.OrderById[zone.id]
	local nextZone = Zones.List[order + 1]
	if nextZone then
		local travel = pad(
			model,
			"TravelPad",
			origin + Vector3.new(ISLAND_SIZE / 2 - 14, 0.5, 0),
			Color3.fromRGB(255, 196, 96),
			Vector3.new(14, 1, 14)
		)
		travel:SetAttribute("Zone", zone.id)
		travel:SetAttribute("Target", nextZone.id)
		label(travel, nextZone.name, "Travel", 6)
	end

	local previousZone = Zones.List[order - 1]
	if previousZone then
		local back = pad(
			model,
			"TravelPad",
			origin + Vector3.new(-(ISLAND_SIZE / 2 - 14), 0.5, 0),
			Color3.fromRGB(196, 204, 216),
			Vector3.new(14, 1, 14)
		)
		back:SetAttribute("Zone", zone.id)
		back:SetAttribute("Target", previousZone.id)
		label(back, previousZone.name, "Travel", 6)
	end

	-- Nodes
	local nodeFolder = Instance.new("Folder")
	nodeFolder.Name = "Nodes"
	nodeFolder.Parent = model

	local rng = Random.new(#zone.name * 7919 + zone.nodeCount)
	local nodes = {}
	for index, position in nodePositions(zone) do
		table.insert(nodes, buildNode(nodeFolder, zone, index, origin + position, rng))
	end
	built.nodesByZone[zone.id] = nodes

	if zone.id == Zones.Starter then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.CanCollide = true
		spawn.Size = Vector3.new(20, 1, 20)
		spawn.Position = origin + Vector3.new(0, 0.5, PLAZA_Z - 34)
		spawn.Color = Color3.fromRGB(240, 240, 240)
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Duration = 0
		spawn.Parent = model
	end
end

function WorldBuilder.build(): Built
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "World"

	local built: Built = {
		root = root,
		nodesByZone = {},
		sellPads = {},
	}

	for _, zone in Zones.List do
		buildIsland(root, zone, built)
	end

	root.Parent = workspace
	return built
end

--[[ Where a player should be placed when they arrive in a zone: just behind the
     sell pad, facing the field. ]]
function WorldBuilder.spawnCFrame(zone: Zones.Zone): CFrame
	local position = zone.origin + Vector3.new(0, 4, PLAZA_Z - 26)
	return CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
end

return WorldBuilder
