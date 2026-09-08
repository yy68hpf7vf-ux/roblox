--!strict
--[[
	WorldBuilder

	Builds the whole town at runtime: a ring road with twelve motels along it,
	around a central square where the Celebrity Arrival lands.

	Nothing about the map lives in the .rbxl, so changing the plot count or the
	layout is a config edit rather than an hour of dragging parts, and every server
	generates an identical town.

	Two things the geometry is doing on purpose:

	  * **Every motel faces the square.** You can stand at your own front desk and
	    see the celebrity land, see who is sprinting for it, and read the lit sign
	    of every motel worth robbing. A raiding game where you cannot see the other
	    players is just an idle game with extra walking.
	  * **Everything that lights up is collected into `built.lamps`.** Lights Out
	    is the most important moment in the game, so AmbienceService switches the
	    whole town over at once rather than the sky quietly changing colour.
]]

local Guests = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Guests)
local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.GameConfig)

local WorldBuilder = {}

WorldBuilder.PlotCount = 12

local RING_RADIUS = 320
local ROAD_RADIUS = 205
local ROAD_WIDTH = 34
local PLOT_SIZE = Vector3.new(120, 4, 120)
local SQUARE_SIZE = 210

local ASPHALT = Color3.fromRGB(58, 58, 64)
local KERB = Color3.fromRGB(176, 176, 168)
local GRASS = Color3.fromRGB(88, 122, 74)
local WALL = Color3.fromRGB(206, 186, 150)
local WALL_TRIM = Color3.fromRGB(140, 84, 72)
local ROOF = Color3.fromRGB(112, 68, 60)

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
	vacancyLabel: TextLabel,
	vacancyLight: SurfaceLight,
}

export type Built = {
	root: Folder,
	plots: { Plot },
	square: BasePart,
	stage: BasePart,
	-- Everything that should come on at Lights Out.
	lamps: { Light },
}

local lamps: { Light } = {}

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

--[[ A light that AmbienceService will switch on at dusk. Registered rather than
     found by name, so a renamed part cannot silently leave the town dark. ]]
local function streetLight(parent: BasePart, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Enabled = false
	light.Parent = parent
	table.insert(lamps, light)
	return light
end

local function lampPost(parent: Instance, position: Vector3)
	part({
		Name = "LampPost",
		Size = Vector3.new(1, 18, 1),
		Position = position + Vector3.new(0, 9, 0),
		Color = Color3.fromRGB(46, 48, 56),
		Material = Enum.Material.Metal,
		Parent = parent,
	})

	local head = part({
		Name = "LampHead",
		Size = Vector3.new(3.4, 1.2, 3.4),
		Position = position + Vector3.new(0, 18, 0),
		Color = Color3.fromRGB(255, 236, 190),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	streetLight(head, Color3.fromRGB(255, 226, 170), 34, 2)
end

local function billboard(adornee: BasePart, height: number, width: number): (BillboardGui, TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(width, width * 0.3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 500
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

-- ---------------------------------------------------------------- roads

--[[ The ring road, approximated with straight slabs. Sixty of them around a
     205-stud circle is close enough that the seams do not read as corners. ]]
local function buildRoads(root: Folder)
	local model = Instance.new("Model")
	model.Name = "Roads"
	model.Parent = root

	local segments = 60
	local segmentLength = (2 * math.pi * ROAD_RADIUS) / segments + 2

	for index = 1, segments do
		local angle = (index / segments) * math.pi * 2
		local position = Vector3.new(math.cos(angle) * ROAD_RADIUS, 0, math.sin(angle) * ROAD_RADIUS)
		local facing = CFrame.lookAt(position, Vector3.new(0, 0, 0))

		part({
			Name = "Road",
			Size = Vector3.new(segmentLength, 1, ROAD_WIDTH),
			CFrame = facing * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, 0.5, 0),
			Color = ASPHALT,
			Material = Enum.Material.Asphalt,
			Parent = model,
		})

		-- Dashed centre line, every fourth segment.
		if index % 4 == 0 then
			part({
				Name = "RoadLine",
				Size = Vector3.new(segmentLength * 0.5, 0.1, 1.4),
				CFrame = facing * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, 1.05, 0),
				Color = Color3.fromRGB(238, 226, 150),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Parent = model,
			})
		end

		-- A lamp on alternating sides, every fifth segment.
		if index % 5 == 0 then
			local side = if index % 10 == 0 then 1 else -1
			lampPost(model, position + (position.Unit * (side * (ROAD_WIDTH / 2 + 4))))
		end
	end

	-- A spoke from the ring up to each motel forecourt.
	for index = 1, WorldBuilder.PlotCount do
		local angle = (index - 1) / WorldBuilder.PlotCount * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local midpoint = direction * ((ROAD_RADIUS + RING_RADIUS - PLOT_SIZE.X / 2) / 2)
		local length = (RING_RADIUS - PLOT_SIZE.X / 2) - ROAD_RADIUS + 20

		part({
			Name = "Driveway",
			Size = Vector3.new(length, 1, 22),
			CFrame = CFrame.lookAt(midpoint, midpoint + direction) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, 0.5, 0),
			Color = ASPHALT,
			Material = Enum.Material.Asphalt,
			Parent = model,
		})
	end
end

-- ---------------------------------------------------------------- a motel

local function buildMotelBlock(model: Model, origin: CFrame)
	-- Ground floor and upper floor, with a walkway between them. Two storeys
	-- reads as a motel from any distance; one box reads as a shed.
	for floor = 0, 1 do
		local y = 8 + floor * 15

		part({
			Name = "Wall",
			Size = Vector3.new(78, 14, 30),
			CFrame = origin * CFrame.new(0, y, -36),
			Color = WALL,
			Material = Enum.Material.Concrete,
			Parent = model,
		})

		-- Doors and windows along the front, so the building reads as rooms.
		for slot = -3, 3 do
			local x = slot * 11

			part({
				Name = "RoomDoor",
				Size = Vector3.new(4.5, 9, 0.6),
				CFrame = origin * CFrame.new(x - 2.6, y - 2.2, -21.2),
				Color = WALL_TRIM,
				Material = Enum.Material.WoodPlanks,
				Parent = model,
			})

			local window = part({
				Name = "RoomWindow",
				Size = Vector3.new(5.5, 5, 0.5),
				CFrame = origin * CFrame.new(x + 3.4, y - 0.4, -21.2),
				Color = Color3.fromRGB(70, 92, 112),
				Material = Enum.Material.Glass,
				Reflectance = 0.25,
				Parent = model,
			})
			streetLight(window, Color3.fromRGB(255, 220, 160), 12, 1)
		end

		-- The upper walkway and its railing.
		if floor == 0 then
			part({
				Name = "Walkway",
				Size = Vector3.new(80, 1, 8),
				CFrame = origin * CFrame.new(0, y + 7.5, -17),
				Color = Color3.fromRGB(150, 146, 140),
				Material = Enum.Material.Concrete,
				Parent = model,
			})
			part({
				Name = "Railing",
				Size = Vector3.new(80, 3.5, 0.5),
				CFrame = origin * CFrame.new(0, y + 9.7, -13.2),
				Color = Color3.fromRGB(64, 66, 74),
				Material = Enum.Material.Metal,
				Parent = model,
			})

			-- Stairs up to it.
			for step = 1, 8 do
				part({
					Name = "Step",
					Size = Vector3.new(6, 1, 2.4),
					CFrame = origin * CFrame.new(-44, 1 + step * 1.05, -14 - step * 1.2),
					Color = Color3.fromRGB(150, 146, 140),
					Material = Enum.Material.Concrete,
					Parent = model,
				})
			end
		end
	end

	part({
		Name = "Roof",
		Size = Vector3.new(84, 2, 36),
		CFrame = origin * CFrame.new(0, 30.5, -36),
		Color = ROOF,
		Material = Enum.Material.Slate,
		Parent = model,
	})
end

--[[ The lit VACANCY board. It is the single most useful object on the map for a
     raider: it says, from across the square, whether a motel is worth the night. ]]
local function buildVacancySign(model: Model, origin: CFrame): (TextLabel, SurfaceLight)
	part({
		Name = "SignPost",
		Size = Vector3.new(1.6, 22, 1.6),
		CFrame = origin * CFrame.new(30, 11, -14),
		Color = Color3.fromRGB(52, 54, 62),
		Material = Enum.Material.Metal,
		Parent = model,
	})

	local board = part({
		Name = "VacancyBoard",
		Size = Vector3.new(18, 10, 1),
		CFrame = origin * CFrame.new(30, 26, -14),
		Color = Color3.fromRGB(28, 30, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Vacancy"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(360, 200)
	surface.LightInfluence = 0
	surface.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(120, 255, 190)
	label.Text = "VACANCY"
	label.Parent = surface

	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Front
	glow.Color = Color3.fromRGB(120, 255, 190)
	glow.Range = 26
	glow.Brightness = 3
	glow.Angle = 120
	glow.Enabled = false
	glow.Parent = board
	table.insert(lamps, glow)

	return label, glow
end

local function buildPlot(root: Folder, index: number): Plot
	local angle = (index - 1) / WorldBuilder.PlotCount * math.pi * 2
	local position = Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)
	-- Every motel faces the square, so the celebrity is visible from every desk.
	local origin = CFrame.lookAt(position, Vector3.new(0, 0, 0))

	local model = Instance.new("Model")
	model.Name = `Plot{index}`
	model.Parent = root

	part({
		Name = "Ground",
		Size = PLOT_SIZE,
		CFrame = origin * CFrame.new(0, -PLOT_SIZE.Y / 2, 0),
		Color = ASPHALT,
		Material = Enum.Material.Asphalt,
		Parent = model,
	})

	-- A kerb so the forecourt reads as a property rather than a patch of road.
	for _, offset in { Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1) } do
		local horizontal = math.abs(offset.X) > 0
		part({
			Name = "Kerb",
			Size = if horizontal then Vector3.new(2, 1.6, PLOT_SIZE.Z) else Vector3.new(PLOT_SIZE.X, 1.6, 2),
			CFrame = origin * CFrame.new(offset * (PLOT_SIZE.X / 2) + Vector3.new(0, 0.8, 0)),
			Color = KERB,
			Material = Enum.Material.Concrete,
			Parent = model,
		})
	end

	buildMotelBlock(model, origin)
	local vacancyLabel, vacancyLight = buildVacancySign(model, origin)

	-- The door thieves have to break. Named so TheftService can find it.
	local door = part({
		Name = "Door",
		Size = Vector3.new(12, 16, 1.5),
		CFrame = origin * CFrame.new(0, 8, -20),
		Color = Color3.fromRGB(84, 60, 48),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	door:SetAttribute("Plot", index)

	local _, doorTitle, doorSub = billboard(door, 11, 13)
	doorTitle.Name = "DoorTitle"
	doorSub.Name = "DoorSubtitle"
	doorTitle.Text = "OFFICE"
	doorSub.Text = "Locked"

	-- Front desk: walk onto it to bank the safe.
	local desk = part({
		Name = "FrontDesk",
		Size = Vector3.new(18, 1, 12),
		CFrame = origin * CFrame.new(0, 0.5, 6),
		Color = Color3.fromRGB(96, 220, 138),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	desk:SetAttribute("Plot", index)
	local _, deskTitle, deskSub = billboard(desk, 7, 15)
	deskTitle.Text = "FRONT DESK"
	deskSub.Text = "Walk here to collect rent"
	streetLight(desk, Color3.fromRGB(96, 220, 138), 20, 1.5)

	-- Owner board, facing the square.
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(26, 12, 1.5),
		CFrame = origin * CFrame.new(-32, 15, -12),
		Color = Color3.fromRGB(38, 40, 52),
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	part({
		Name = "SignPost",
		Size = Vector3.new(1.6, 16, 1.6),
		CFrame = origin * CFrame.new(-32, 7, -12),
		Color = Color3.fromRGB(52, 54, 62),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local _, nameLabel, rentLabel = billboard(sign, 9, 22)
	nameLabel.Text = "VACANT PLOT"
	rentLabel.Text = "Nobody has claimed this one"

	-- Room markers: where housed guests stand, in two rows on the forecourt.
	local markers: { BasePart } = {}
	local perRow = 12
	for room = 1, GameConfig.BaseMaxRooms + 20 do
		local row = math.floor((room - 1) / perRow)
		local column = (room - 1) % perRow
		local marker = part({
			Name = `Room{room}`,
			Size = Vector3.new(4.4, 0.4, 4.4),
			CFrame = origin * CFrame.new(-33 + column * 6, 0.2, -6 - row * 7),
			Color = Color3.fromRGB(88, 88, 96),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Transparency = 0.5,
			Parent = model,
		})
		marker:SetAttribute("Room", room)
		table.insert(markers, marker)
	end

	lampPost(model, (origin * CFrame.new(-52, 0, 4)).Position)
	lampPost(model, (origin * CFrame.new(52, 0, 4)).Position)

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
		vacancyLabel = vacancyLabel,
		vacancyLight = vacancyLight,
	}
end

-- ---------------------------------------------------------------- the square

local function buildSquare(root: Folder): (BasePart, BasePart)
	local model = Instance.new("Model")
	model.Name = "TownSquare"
	model.Parent = root

	local square = part({
		Name = "Ground",
		Size = Vector3.new(SQUARE_SIZE, 4, SQUARE_SIZE),
		CFrame = CFrame.new(0, -2, 0),
		Color = GRASS,
		Material = Enum.Material.Grass,
		Parent = model,
	})

	-- A paved apron so the stage does not sit straight on grass.
	part({
		Name = "Apron",
		Size = Vector3.new(90, 1, 90),
		CFrame = CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(150, 148, 142),
		Material = Enum.Material.Pavement,
		Parent = model,
	})

	-- Stage: where the Celebrity Arrival lands.
	for step = 1, 3 do
		part({
			Name = "StageStep",
			Size = Vector3.new(34 - step * 3, 1.2, 34 - step * 3),
			CFrame = CFrame.new(0, step * 1.1, 0),
			Color = Color3.fromRGB(120, 118, 112),
			Material = Enum.Material.Concrete,
			Parent = model,
		})
	end

	local stage = part({
		Name = "Stage",
		Size = Vector3.new(24, 1.4, 24),
		CFrame = CFrame.new(0, 4.2, 0),
		Color = Color3.fromRGB(255, 236, 140),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	streetLight(stage, Color3.fromRGB(255, 236, 140), 60, 3)

	local _, title, subtitle = billboard(stage, 16, 30)
	title.Name = "EventTitle"
	subtitle.Name = "EventSubtitle"
	title.Text = "TOWN SQUARE"
	subtitle.Text = "A celebrity checks in every 10 minutes"

	-- Corner lamps and a few benches, so the square reads as a place.
	for corner = 1, 4 do
		local a = (corner / 4) * math.pi * 2 + math.pi / 4
		lampPost(model, Vector3.new(math.cos(a) * 62, 0, math.sin(a) * 62))

		local benchPosition = Vector3.new(math.cos(a) * 40, 2, math.sin(a) * 40)
		part({
			Name = "Bench",
			Size = Vector3.new(12, 1, 3.5),
			CFrame = CFrame.lookAt(benchPosition, Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(126, 88, 62),
			Material = Enum.Material.WoodPlanks,
			Parent = model,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Size = Vector3.new(26, 1, 26)
	spawn.CFrame = CFrame.new(0, 1.5, 70)
	spawn.Color = Color3.fromRGB(236, 240, 246)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = model

	return square, stage
end

-- ---------------------------------------------------------------- entry

function WorldBuilder.build(): Built
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	table.clear(lamps)

	local root = Instance.new("Folder")
	root.Name = "World"

	local square, stage = buildSquare(root)
	buildRoads(root)

	local plots: { Plot } = {}
	for index = 1, WorldBuilder.PlotCount do
		table.insert(plots, buildPlot(root, index))
	end

	root.Parent = workspace

	return { root = root, plots = plots, square = square, stage = stage, lamps = table.clone(lamps) }
end

--[[ A visible stand-in for a guest. A real server instance rather than a
     client-side cosmetic, because other players have to be able to walk up, see
     what is standing in room four, and decide it is worth the night. ]]
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

	-- The rarer the guest, the more it glows. A Mythic standing on a forecourt
	-- should be visible from the far side of the square.
	local rank = Guests.rarityRank(guest.rarity)
	if rank >= 4 then
		local glow = Instance.new("PointLight")
		glow.Color = Guests.RarityColor[guest.rarity] or guest.color
		glow.Range = 8 + rank * 2
		glow.Brightness = 1 + rank * 0.3
		glow.Parent = body
	end

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
