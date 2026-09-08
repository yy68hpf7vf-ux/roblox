--!strict
--[[
	WorldBuilder

	Builds the whole map at runtime: a ring of motel plots around a central town
	square. Nothing about the map lives in the .rbxl, so changing the plot count or
	the layout is a config edit rather than an hour of dragging parts.

	One plot per player slot. A plot is a slab, a motel building with a numbered
	door, a front desk, a sign, and a row of room markers the guests stand on.
]]

local Guests = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Guests)
local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.GameConfig)

local WorldBuilder = {}

WorldBuilder.PlotCount = 12

local RING_RADIUS = 320
local PLOT_SIZE = Vector3.new(120, 4, 120)
local SQUARE_SIZE = 200

export type Plot = {
	index: number,
	model: Model,
	origin: CFrame,
	door: BasePart,
	desk: BasePart,
	sign: BasePart,
	roomMarkers: { BasePart },
	nameLabel: TextLabel,
	rentLabel: TextLabel,
}

export type Built = {
	root: Folder,
	plots: { Plot },
	square: BasePart,
	stage: BasePart,
}

local function part(props: { [string]: any }): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

local function billboard(adornee: BasePart, height: number, width: number): (BillboardGui, TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(width, width * 0.3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 400
	gui.Parent = adornee

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.6)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeTransparency = 0.35
	title.Text = ""
	title.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromScale(0, 0.6)
	subtitle.Size = UDim2.fromScale(1, 0.4)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(226, 232, 240)
	subtitle.TextStrokeTransparency = 0.5
	subtitle.Text = ""
	subtitle.Parent = gui

	return gui, title, subtitle
end

local function buildPlot(root: Folder, index: number): Plot
	local angle = (index - 1) / WorldBuilder.PlotCount * math.pi * 2
	local position = Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)
	-- Every motel faces the town square, so the Celebrity Arrival is visible from
	-- every front desk in the game.
	local origin = CFrame.lookAt(position, Vector3.new(0, 0, 0))

	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model.Parent = root

	part({
		Name = "Ground",
		Size = PLOT_SIZE,
		CFrame = origin * CFrame.new(0, -PLOT_SIZE.Y / 2, 0),
		Color = Color3.fromRGB(96, 102, 118),
		Material = Enum.Material.Concrete,
		Parent = model,
	})

	-- Motel block, set back from the square with the door facing in.
	local building = part({
		Name = "Building",
		Size = Vector3.new(76, 26, 30),
		CFrame = origin * CFrame.new(0, 13, -34),
		Color = Color3.fromRGB(198, 176, 140),
		Material = Enum.Material.Brick,
		Parent = model,
	})

	part({
		Name = "Roof",
		Size = Vector3.new(82, 2, 36),
		CFrame = origin * CFrame.new(0, 27, -34),
		Color = Color3.fromRGB(120, 74, 66),
		Material = Enum.Material.Slate,
		Parent = model,
	})

	-- The door is the thing thieves have to break. Named so TheftService can find
	-- it and so a designer can retexture it without touching code.
	local door = part({
		Name = "Door",
		Size = Vector3.new(10, 16, 1.5),
		CFrame = origin * CFrame.new(0, 8, -19),
		Color = Color3.fromRGB(72, 54, 44),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	door:SetAttribute("Plot", index)

	local _, doorTitle, doorSub = billboard(door, 11, 12)
	doorTitle.Text = "MOTEL"
	doorSub.Text = "Locked"
	doorTitle.Name = "DoorTitle"
	doorSub.Name = "DoorSubtitle"

	-- Front desk: walk onto it to bank the safe.
	local desk = part({
		Name = "FrontDesk",
		Size = Vector3.new(18, 1, 12),
		CFrame = origin * CFrame.new(0, 0.5, 4),
		Color = Color3.fromRGB(96, 220, 138),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	desk:SetAttribute("Plot", index)
	local _, deskTitle, deskSub = billboard(desk, 7, 14)
	deskTitle.Text = "FRONT DESK"
	deskSub.Text = "Collect rent"

	-- The sign carries the owner's name and live rent, so walking past a motel
	-- tells you whether it is worth robbing. That readability is the point.
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(26, 14, 2),
		CFrame = origin * CFrame.new(-40, 18, -10),
		Color = Color3.fromRGB(40, 42, 56),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	local _, nameLabel, rentLabel = billboard(sign, 10, 20)
	nameLabel.Text = "VACANT PLOT"
	rentLabel.Text = "Walk up to claim"

	-- Room markers: where housed guests stand. Two rows along the front.
	local markers: { BasePart } = {}
	local perRow = 12
	for room = 1, GameConfig.BaseMaxRooms + 20 do
		local row = math.floor((room - 1) / perRow)
		local column = (room - 1) % perRow
		local marker = part({
			Name = `Room{room}`,
			Size = Vector3.new(4, 0.4, 4),
			CFrame = origin * CFrame.new(-33 + column * 6, 0.2, -14 - row * 7),
			Color = Color3.fromRGB(70, 76, 92),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Transparency = 0.55,
			Parent = model,
		})
		marker:SetAttribute("Room", room)
		table.insert(markers, marker)
	end

	return {
		index = index,
		model = model,
		origin = origin,
		door = door,
		desk = desk,
		sign = sign,
		roomMarkers = markers,
		nameLabel = nameLabel,
		rentLabel = rentLabel,
	}
end

local function buildSquare(root: Folder): (BasePart, BasePart)
	local model = Instance.new("Model")
	model.Name = "TownSquare"
	model.Parent = root

	local square = part({
		Name = "Ground",
		Size = Vector3.new(SQUARE_SIZE, 4, SQUARE_SIZE),
		CFrame = CFrame.new(0, -2, 0),
		Color = Color3.fromRGB(84, 92, 78),
		Material = Enum.Material.Grass,
		Parent = model,
	})

	-- Where the Celebrity Arrival lands. Visible from every plot.
	local stage = part({
		Name = "Stage",
		Size = Vector3.new(26, 2, 26),
		CFrame = CFrame.new(0, 1, 0),
		Color = Color3.fromRGB(255, 236, 140),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	local _, title, subtitle = billboard(stage, 14, 26)
	title.Name = "EventTitle"
	subtitle.Name = "EventSubtitle"
	title.Text = "TOWN SQUARE"
	subtitle.Text = "A celebrity checks in every 10 minutes"

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Size = Vector3.new(24, 1, 24)
	spawn.CFrame = CFrame.new(0, 2.5, 54)
	spawn.Color = Color3.fromRGB(236, 240, 246)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = model

	return square, stage
end

function WorldBuilder.build(): Built
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "World"

	local square, stage = buildSquare(root)

	local plots: { Plot } = {}
	for index = 1, WorldBuilder.PlotCount do
		table.insert(plots, buildPlot(root, index))
	end

	root.Parent = workspace

	return { root = root, plots = plots, square = square, stage = stage }
end

--[[ A visible stand-in for a guest, parented to a room marker. Purely a server
     instance because other players need to see what is worth stealing. ]]
function WorldBuilder.buildGuestModel(guest: Guests.Guest, uid: string): Model
	local model = Instance.new("Model")
	model.Name = `Guest_{uid}`

	local body = part({
		Name = "Body",
		Size = Vector3.new(3, 4.4, 3),
		Color = guest.color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = model,
	})

	local eyes = part({
		Name = "Eyes",
		Size = Vector3.new(2.2, 0.7, 0.3),
		Color = Color3.fromRGB(20, 20, 26),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	eyes.CFrame = body.CFrame * CFrame.new(0, 1, -1.5)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = eyes
	weld.Parent = eyes

	local _, title, subtitle = billboard(body, 3.6, 8)
	title.Text = guest.name
	title.TextColor3 = Guests.RarityColor[guest.rarity] or Color3.new(1, 1, 1)
	subtitle.Name = "RentLabel"
	subtitle.Text = guest.rarity

	model.PrimaryPart = body
	model:SetAttribute("Uid", uid)
	model:SetAttribute("Guest", guest.id)

	return model
end

return WorldBuilder
