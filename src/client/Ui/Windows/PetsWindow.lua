--!strict
--[[
	PetsWindow

	Two tabs: hatching and the collection.

	The hatch tab prints the full drop table under every egg -- every pet in the
	pool, its rarity, its multiplier and its exact chance, read from the same
	weights the server rolls against. Percentages are computed from the config at
	render time, so they cannot drift away from the behaviour.

	The collection groups duplicates into one row with a count. A player with 300
	pets should be looking at twelve rows, not three hundred.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Eggs = require(Shared.Config.Eggs)
local Pets = require(Shared.Config.Pets)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Util.Format)

local Actions = require(script.Parent.Parent.Parent.Actions)
local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local PetsWindow = {}

local function oddsText(egg: Eggs.Egg): string
	local lines = {}
	for _, entry in Eggs.odds(egg) do
		local pet = Pets.get(entry.pet)
		if pet then
			local color = Theme.Rarity[pet.rarity] or Theme.Color.TextDim
			local hex = color:ToHex()
			table.insert(
				lines,
				`<font color='#{hex}'>{Format.percent(entry.chance)}</font>  {pet.name}  <font color='#8A93A6'>+{pet.mult} mult</font>`
			)
		end
	end
	return table.concat(lines, "\n")
end

function PetsWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Pets", "Equipped pets multiply every sale. Odds are printed on every egg.", close)
	window.root.Parent = parent

	local activeTab = "Hatch"
	local lastState: { [string]: any } = {}
	local hatchPainters: { (state: { [string]: any }) -> () } = {}

	-- ------------------------------------------------------------ hatch tab
	for index, egg in Eggs.List do
		local card = Widgets.panel({
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = window.body,
		})
		Widgets.padding(12).Parent = card

		local swatch = Widgets.new("Frame", {
			BackgroundColor3 = egg.color,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(40, 40),
			Parent = card,
		}) :: Frame
		Widgets.corner(UDim.new(1, 0)).Parent = swatch

		local title = Widgets.label({
			Text = egg.name,
			Font = Theme.Font.Heading,
			TextSize = 16,
			Position = UDim2.fromOffset(52, 0),
			Size = UDim2.new(1, -300, 0, 20),
			Parent = card,
		})

		local subtitle = Widgets.label({
			Text = egg.desc,
			TextColor3 = Theme.Color.TextDim,
			TextSize = 12.5,
			Position = UDim2.fromOffset(52, 21),
			Size = UDim2.new(1, -300, 0, 18),
			Parent = card,
		})

		local one = Widgets.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -104, 0, 2),
			Size = UDim2.fromOffset(96, 36),
			TextSize = 13,
			Parent = card,
		}, function()
			Actions.invoke("hatch", { egg = egg.id, count = 1 })
		end)

		local ten = Widgets.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 2),
			Size = UDim2.fromOffset(96, 36),
			TextSize = 13,
			Parent = card,
		}, function()
			Actions.invoke("hatch", { egg = egg.id, count = 10 })
		end)

		Widgets.label({
			Text = oddsText(egg),
			TextSize = 12,
			TextColor3 = Theme.Color.TextDim,
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = card,
		})

		table.insert(hatchPainters, function(state)
			card.Visible = activeTab == "Hatch"

			local zone = Zones.get(egg.zone)
			local unlocked = (state.unlockedZones or {})[egg.zone] == true
			local crystals = state.crystals or 0

			if not unlocked then
				subtitle.Text = `Found in {zone.name}, which you have not unlocked yet.`
				one.Text = "Locked"
				ten.Text = "Locked"
				one.BackgroundColor3 = Theme.Color.Locked
				ten.BackgroundColor3 = Theme.Color.Locked
				one.TextColor3 = Theme.Color.TextDim
				ten.TextColor3 = Theme.Color.TextDim
				return
			end

			subtitle.Text = egg.desc
			one.Text = `1x  {Format.short(egg.price)}`
			ten.Text = `10x  {Format.short(egg.price * 10)}`
			one.BackgroundColor3 = if crystals >= egg.price then Theme.Color.Accent else Theme.Color.PanelRaised
			ten.BackgroundColor3 = if crystals >= egg.price * 10 then Theme.Color.Accent else Theme.Color.PanelRaised
			one.TextColor3 = if crystals >= egg.price then Theme.Color.Panel else Theme.Color.TextFaint
			ten.TextColor3 = if crystals >= egg.price * 10 then Theme.Color.Panel else Theme.Color.TextFaint
		end)
	end

	-- ------------------------------------------------------------ collection tab
	local collection = Widgets.new("Frame", {
		Name = "Collection",
		LayoutOrder = 1000,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = window.body,
	}) :: Frame
	Widgets.list().Parent = collection

	local controls = Widgets.panel({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 52),
		Parent = collection,
	})
	Widgets.padding(8).Parent = controls

	Widgets.button({
		Text = "Equip best",
		Size = UDim2.fromOffset(120, 36),
		TextSize = 13,
		Parent = controls,
	}, function()
		Actions.invoke("autoEquipPets")
	end)

	Widgets.button({
		Text = "Release Commons",
		Position = UDim2.fromOffset(128, 0),
		Size = UDim2.fromOffset(150, 36),
		TextSize = 13,
		BackgroundColor3 = Theme.Color.PanelRaised,
		TextColor3 = Theme.Color.TextDim,
		Parent = controls,
	}, function()
		Actions.invoke("deletePetsBelow", { rarity = "Uncommon" })
	end)

	Widgets.button({
		Text = "Release under Rare",
		Position = UDim2.fromOffset(286, 0),
		Size = UDim2.fromOffset(164, 36),
		TextSize = 13,
		BackgroundColor3 = Theme.Color.PanelRaised,
		TextColor3 = Theme.Color.TextDim,
		Parent = controls,
	}, function()
		Actions.invoke("deletePetsBelow", { rarity = "Rare" })
	end)

	local list = Widgets.new("Frame", {
		Name = "Owned",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = collection,
	}) :: Frame
	Widgets.list().Parent = list

	--[[ Rebuilt on each refresh rather than diffed. The list is at most a few dozen
	     grouped rows and it only rebuilds while the tab is open. ]]
	local function paintCollection(state)
		collection.Visible = activeTab == "Collection"
		if not collection.Visible then
			return
		end

		Widgets.clear(list)

		local owned = state.pets or {}
		local equipped = state.equipped or {}
		local equippedSet: { [string]: boolean } = {}
		for _, uid in equipped do
			equippedSet[uid] = true
		end

		-- Group by pet id, tracking which uids are free to equip and which are
		-- currently equipped so the buttons can act on a concrete one.
		type Group = { pet: string, total: number, equippedUids: { string }, freeUids: { string } }
		local groups: { [string]: Group } = {}
		local order: { string } = {}

		for _, entry in owned do
			local group = groups[entry.pet]
			if not group then
				group = { pet = entry.pet, total = 0, equippedUids = {}, freeUids = {} }
				groups[entry.pet] = group
				table.insert(order, entry.pet)
			end
			group.total += 1
			if equippedSet[entry.uid] then
				table.insert(group.equippedUids, entry.uid)
			else
				table.insert(group.freeUids, entry.uid)
			end
		end

		table.sort(order, function(a, b)
			local petA, petB = Pets.get(a), Pets.get(b)
			local multA = if petA then petA.mult else 0
			local multB = if petB then petB.mult else 0
			if multA == multB then
				return a < b
			end
			return multA > multB
		end)

		local slots = state.petSlots or 0
		window.setSubtitle(
			`{#owned} pets  ·  {#equipped}/{slots} equipped  ·  pet multiplier {Format.multiplier((state.multipliers or {}).pets or 1)}`
		)

		if #order == 0 then
			Widgets.label({
				Text = "No pets yet. Hatch one from the Hatch tab.",
				TextColor3 = Theme.Color.TextDim,
				Size = UDim2.new(1, 0, 0, 40),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = list,
			})
			return
		end

		for index, petId in order do
			local group = groups[petId]
			local pet = Pets.get(petId)
			if pet then
				local row = Widgets.row(index, list)
				local rarityColor = Theme.Rarity[pet.rarity] or Theme.Color.TextDim
				row.swatch.BackgroundColor3 = pet.color

				local equippedCount = #group.equippedUids
				row.title.Text = `{pet.name}  <font color='#8A93A6'>x{group.total}</font>`
				row.desc.Text = `<font color='#{rarityColor:ToHex()}'>{pet.rarity}</font>  ·  +{pet.mult} multiplier`
					.. (if equippedCount > 0 then `  ·  <font color='#5FDC8A'>{equippedCount} equipped</font>` else "")

				local canEquip = #group.freeUids > 0 and #equipped < slots

				if equippedCount > 0 then
					row.action.Text = "Unequip"
					row.action.BackgroundColor3 = Theme.Color.PanelRaised
					row.action.TextColor3 = Theme.Color.Text
					row.action.Activated:Connect(function()
						Actions.invoke("unequipPet", { uid = group.equippedUids[#group.equippedUids] }, true)
					end)
				elseif canEquip then
					row.action.Text = "Equip"
					row.action.BackgroundColor3 = Theme.Color.Good
					row.action.TextColor3 = Theme.Color.Panel
					row.action.Activated:Connect(function()
						Actions.invoke("equipPet", { uid = group.freeUids[1] }, true)
					end)
				else
					row.action.Text = "Slots full"
					row.action.BackgroundColor3 = Theme.Color.Locked
					row.action.TextColor3 = Theme.Color.TextDim
				end
			end
		end
	end

	local function refresh(state)
		lastState = state
		for _, paint in hatchPainters do
			paint(state)
		end
		paintCollection(state)

		if activeTab == "Hatch" then
			window.setSubtitle("Equipped pets multiply every sale. Odds are printed on every egg.")
		end
	end

	Widgets.tabs(window, { "Hatch", "Collection" }, function(name)
		activeTab = name
		refresh(lastState)
	end)("Hatch")

	return { root = window.root, refresh = refresh }
end

return PetsWindow
