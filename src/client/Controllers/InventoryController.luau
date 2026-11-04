--!nonstrict
-- Pet inventory window: browse, search, sort, equip, favorite, lock, delete.
-- All changes are requests to the server (PetAction); this window only displays data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Pets = require(Shared.Config.Pets)
local Rarities = require(Shared.Config.Rarities)
local PetModels = require(Shared.PetModels)
local PetUtil = require(Shared.Util.PetUtil)
local NumberFormat = require(Shared.Util.NumberFormat)

local DataController = require(script.Parent.DataController)
local HUDController = require(script.Parent.HUDController)

local InventoryController = {}

local SORT_MODES = { "Power", "Rarity", "Name" }
local DEFAULT_CAPACITY = 50

local state = {
	pets = {},
	equipped = {},
	slots = 3,
	capacity = DEFAULT_CAPACITY,
	selected = nil,
	sortIndex = 1,
	search = "",
	confirmDelete = false,
}

local ui = {}

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
	return s
end

local function label(parent, text, size, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextSize = size
	l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	l.Text = text
	l.Parent = parent
	return l
end

local function button(parent, text, color, size, position)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 16
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Text = text
	b.Size = size
	b.Position = position or UDim2.new()
	b.Parent = parent
	corner(b, 8)
	stroke(b, Color3.fromRGB(20, 20, 50), 2)
	return b
end

local function isEquipped(id)
	return table.find(state.equipped, id) ~= nil
end

local function petCount()
	local n = 0
	for _ in state.pets do
		n += 1
	end
	return n
end

local function doAction(action, id)
	local ok, message = Remotes.func("PetAction"):InvokeServer(action, id)
	if not ok and message then
		HUDController.toast(message)
	end
	return ok
end

local refresh

local function makeIcon(parent, petData)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, -8, 1, -22)
	viewport.Position = UDim2.fromOffset(4, 4)
	viewport.BackgroundTransparency = 1
	viewport.Parent = parent
	local model = PetModels.build(petData.Name, petData.Variant)
	if not model then
		return
	end
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	local camera = Instance.new("Camera")
	local extent = model:GetExtentsSize().Magnitude
	local center = model:GetPivot().Position + Vector3.new(0, 0.3 * model:GetScale(), 0)
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0.7, 0.45, -1).Unit * extent * 1.05, center)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function buildDetails()
	local frame = ui.details
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local id = state.selected
	local petData = id and state.pets[id]
	if not petData then
		local hint = label(frame, "Select a pet", 20, Color3.fromRGB(200, 210, 255))
		hint.Size = UDim2.fromScale(1, 1)
		return
	end
	local def = Pets[petData.Name]
	local rarity = Rarities[def.Rarity]

	local preview = Instance.new("Frame")
	preview.Size = UDim2.new(1, -16, 0, 110)
	preview.Position = UDim2.fromOffset(8, 8)
	preview.BackgroundColor3 = Color3.fromRGB(30, 40, 110)
	preview.Parent = frame
	corner(preview, 10)
	stroke(preview, rarity.Color, 3)
	makeIcon(preview, petData)

	local name = label(frame, (petData.Variant ~= "Normal" and petData.Variant .. " " or "") .. petData.Name, 20)
	name.Size = UDim2.new(1, -16, 0, 24)
	name.Position = UDim2.fromOffset(8, 122)
	local rar = label(frame, def.Rarity, 16, rarity.Color)
	rar.Size = UDim2.new(1, -16, 0, 20)
	rar.Position = UDim2.fromOffset(8, 146)
	local power = label(frame, "Power: " .. NumberFormat.short(PetUtil.getPower(petData)), 16, Color3.fromRGB(255, 215, 80))
	power.Size = UDim2.new(1, -16, 0, 20)
	power.Position = UDim2.fromOffset(8, 166)

	local equipped = isEquipped(id)
	local equipBtn = button(frame, equipped and "Unequip" or "Equip", equipped and Color3.fromRGB(200, 80, 80) or Color3.fromRGB(70, 190, 90), UDim2.new(1, -16, 0, 32), UDim2.fromOffset(8, 192))
	equipBtn.Activated:Connect(function()
		doAction(equipped and "Unequip" or "Equip", id)
	end)
	local favBtn = button(frame, petData.Favorite and "Unfavorite" or "Favorite", Color3.fromRGB(230, 170, 40), UDim2.new(0.5, -12, 0, 28), UDim2.fromOffset(8, 230))
	favBtn.Activated:Connect(function()
		doAction("Favorite", id)
	end)
	local lockBtn = button(frame, petData.Locked and "Unlock" or "Lock", Color3.fromRGB(90, 110, 200), UDim2.new(0.5, -12, 0, 28), UDim2.new(0.5, 4, 0, 230))
	lockBtn.Activated:Connect(function()
		doAction("Lock", id)
	end)
	local delBtn = button(frame, state.confirmDelete and "Really delete?" or "Delete", Color3.fromRGB(190, 60, 60), UDim2.new(1, -16, 0, 28), UDim2.fromOffset(8, 264))
	delBtn.Activated:Connect(function()
		if not state.confirmDelete then
			state.confirmDelete = true
			buildDetails()
			task.delay(3, function()
				if state.confirmDelete then
					state.confirmDelete = false
					if ui.window.Visible then
						buildDetails()
					end
				end
			end)
			return
		end
		state.confirmDelete = false
		doAction("Delete", id)
	end)
end

local function buildGrid()
	for _, child in ui.grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local query = string.lower(state.search)
	local order = 0
	for _, entry in PetUtil.sortedList(state.pets, SORT_MODES[state.sortIndex]) do
		local data = entry.Data
		if query == "" or string.find(string.lower(data.Name), query, 1, true) then
			order += 1
			local def = Pets[data.Name]
			local rarity = Rarities[def.Rarity]

			local tile = Instance.new("TextButton")
			tile.Text = ""
			tile.AutoButtonColor = true
			tile.BackgroundColor3 = Color3.fromRGB(35, 50, 130)
			tile.LayoutOrder = order
			tile.Parent = ui.grid
			corner(tile, 8)
			stroke(tile, rarity.Color, entry.Id == state.selected and 4 or 2)

			makeIcon(tile, data)

			local power = label(tile, NumberFormat.short(PetUtil.getPower(data)), 14, Color3.fromRGB(255, 225, 100))
			power.Size = UDim2.new(1, 0, 0, 18)
			power.Position = UDim2.new(0, 0, 1, -18)

			local marks = (isEquipped(entry.Id) and "✓" or "") .. (data.Favorite and "★" or "") .. (data.Locked and "🔒" or "")
			if marks ~= "" then
				local m = label(tile, marks, 14, Color3.fromRGB(150, 255, 150))
				m.Size = UDim2.new(1, -4, 0, 16)
				m.Position = UDim2.fromOffset(2, 2)
				m.TextXAlignment = Enum.TextXAlignment.Left
			end

			tile.Activated:Connect(function()
				state.selected = entry.Id
				state.confirmDelete = false
				refresh()
			end)
		end
	end
end

refresh = function()
	if not ui.window then
		return
	end
	if state.selected and not state.pets[state.selected] then
		state.selected = nil
	end
	ui.capacity.Text = `Pets {petCount()}/{state.capacity}`
	ui.equipped.Text = `Equipped {#state.equipped}/{state.slots}`
	ui.sort.Text = "Sort: " .. SORT_MODES[state.sortIndex]
	if ui.window.Visible then
		buildGrid()
		buildDetails()
	end
end

function InventoryController.toggle()
	ui.window.Visible = not ui.window.Visible
	state.confirmDelete = false
	refresh()
end

function InventoryController.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "PetInventory"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Open button (left side)
	local open = button(gui, "🐾\nPets", Color3.fromRGB(120, 70, 220), UDim2.fromOffset(80, 80), UDim2.new(0, 12, 0.5, -40))
	open.TextSize = 20
	corner(open, 14)
	open.Activated:Connect(InventoryController.toggle)

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.Visible = false
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.62, 0.78)
	window.BackgroundColor3 = Color3.fromRGB(30, 45, 125)
	window.Parent = gui
	corner(window, 16)
	stroke(window, Color3.fromRGB(255, 255, 255), 3)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(420, 340)
	constraint.MaxSize = Vector2.new(820, 560)
	constraint.Parent = window
	ui.window = window

	local title = label(window, "Pet Inventory", 24)
	title.Size = UDim2.new(0.5, 0, 0, 36)
	title.Position = UDim2.fromOffset(12, 6)
	title.TextXAlignment = Enum.TextXAlignment.Left

	ui.capacity = label(window, "", 16, Color3.fromRGB(255, 225, 100))
	ui.capacity.Size = UDim2.new(0, 100, 0, 18)
	ui.capacity.Position = UDim2.new(0, 14, 0, 40)
	ui.capacity.TextXAlignment = Enum.TextXAlignment.Left
	ui.equipped = label(window, "", 16, Color3.fromRGB(150, 255, 150))
	ui.equipped.Size = UDim2.new(0, 120, 0, 18)
	ui.equipped.Position = UDim2.new(0, 120, 0, 40)
	ui.equipped.TextXAlignment = Enum.TextXAlignment.Left

	local close = button(window, "X", Color3.fromRGB(220, 60, 60), UDim2.fromOffset(34, 34), UDim2.new(1, -44, 0, 8))
	close.Activated:Connect(InventoryController.toggle)

	local search = Instance.new("TextBox")
	search.PlaceholderText = "Search..."
	search.Text = ""
	search.ClearTextOnFocus = false
	search.Font = Enum.Font.FredokaOne
	search.TextSize = 16
	search.TextColor3 = Color3.fromRGB(255, 255, 255)
	search.PlaceholderColor3 = Color3.fromRGB(170, 180, 230)
	search.BackgroundColor3 = Color3.fromRGB(20, 30, 90)
	search.Size = UDim2.new(0.32, 0, 0, 28)
	search.Position = UDim2.new(0.34, 0, 0, 10)
	search.Parent = window
	corner(search, 8)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		state.search = search.Text
		refresh()
	end)

	ui.sort = button(window, "Sort: Power", Color3.fromRGB(70, 100, 200), UDim2.new(0, 100, 0, 28), UDim2.new(0.34, 0, 0, 42))
	ui.sort.Activated:Connect(function()
		state.sortIndex = state.sortIndex % #SORT_MODES + 1
		refresh()
	end)

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundColor3 = Color3.fromRGB(20, 30, 90)
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(0.6, -12, 1, -130)
	grid.Position = UDim2.fromOffset(10, 76)
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = window
	corner(grid, 10)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(78, 82)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.Parent = grid
	ui.grid = grid

	local details = Instance.new("Frame")
	details.BackgroundColor3 = Color3.fromRGB(20, 30, 90)
	details.Size = UDim2.new(0.4, -18, 1, -130)
	details.Position = UDim2.new(0.6, 6, 0, 76)
	details.Parent = window
	corner(details, 10)
	ui.details = details

	local bestBtn = button(window, "Equip Best", Color3.fromRGB(70, 190, 90), UDim2.new(0.3, 0, 0, 36), UDim2.new(0, 10, 1, -46))
	bestBtn.Activated:Connect(function()
		doAction("EquipBest")
	end)
	local noneBtn = button(window, "Unequip All", Color3.fromRGB(200, 80, 80), UDim2.new(0.3, 0, 0, 36), UDim2.new(0.3, 16, 1, -46))
	noneBtn.Activated:Connect(function()
		doAction("UnequipAll")
	end)

	DataController.observe("Pets", function(value)
		state.pets = value
		refresh()
	end)
	DataController.observe("Equipped", function(value)
		state.equipped = value
		refresh()
	end)
	DataController.observe("PetSlots", function(value)
		state.slots = value
		refresh()
	end)
	DataController.observe("InventoryCapacity", function(value)
		state.capacity = value
		refresh()
	end)
	refresh()
end

return InventoryController
