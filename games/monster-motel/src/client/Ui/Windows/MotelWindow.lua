--!strict
--[[
	MotelWindow

	Everything Cash buys, in two tabs.

	**Motel** is the four step purchases: rooms, rating, lock, safe. Each has one
	ceiling and one price.

	**Upgrades** is the levelled ones, which are what stop rent from becoming
	pointless once the step purchases are made. Each row shows what the level you
	own does *now* and what the next one would make it, in real units -- "walk speed
	18 to 19", not "+1 to a stat".

	The lock row names the exact number of seconds a thief will need, because that
	is the number the defender is buying and the number the thief reads off the
	door. Both sides see the same figure.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local Actions = require(script.Parent.Parent.Parent.Actions)
local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local MotelWindow = {}

function MotelWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Motel", "Rooms hold guests. Rating decides who turns up.", close)
	window.root.Parent = parent

	local activeTab = "Motel"
	local lastState: { [string]: any } = {}

	-- ------------------------------------------------------------ step purchases
	local steps = Widgets.new("Frame", {
		LayoutOrder = 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = window.body,
	}) :: Frame
	Widgets.list().Parent = steps

	local function makeRow(order: number, action: string, color: Color3): Widgets.Row
		local row = Widgets.row(order, steps)
		row.swatch.BackgroundColor3 = color
		row.action.Activated:Connect(function()
			Actions.invoke(action)
		end)
		return row
	end

	local roomRow = makeRow(1, "buyRoom", Theme.Color.Cash)
	local ratingRow = makeRow(2, "buyRating", Theme.Color.Accent)
	local lockRow = makeRow(3, "buyLock", Theme.Color.Bad)
	local safeRow = makeRow(4, "buySafe", Theme.Color.Safe)

	local doorNote = Widgets.panel({
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = steps,
	})
	Widgets.padding(12).Parent = doorNote
	Widgets.label({
		Text = "Your door can only be broken during Lights Out, never in your first ten minutes"
			.. " in a server, and never while you have three guests or fewer.\n\n"
			.. "Break time depends only on your lock and your Deadbolt level -- never on what the"
			.. " thief owns or has bought.",
		TextSize = 12.5,
		TextColor3 = Theme.Color.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = doorNote,
	})

	-- ------------------------------------------------------------ levelled upgrades
	local upgradesPane = Widgets.new("Frame", {
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = window.body,
	}) :: Frame
	Widgets.list().Parent = upgradesPane

	local upgradeRows: { [string]: Widgets.Row } = {}

	local function upgradeRow(id: string, order: number): Widgets.Row
		local existing = upgradeRows[id]
		if existing then
			return existing
		end
		local row = Widgets.row(order, upgradesPane)
		row.swatch.BackgroundColor3 = Theme.Color.Accent
		row.action.Activated:Connect(function()
			Actions.invoke("buyMotelUpgrade", { id = id })
		end)
		upgradeRows[id] = row
		return row
	end

	local carryNote = Widgets.panel({
		LayoutOrder = 100,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = upgradesPane,
	})
	Widgets.padding(12).Parent = carryNote
	Widgets.label({
		Text = "<b>Running Shoes never apply while you are carrying a guest.</b>"
			.. "\nEveryone in the server moves at the same speed with somebody else's guest on"
			.. " their back, however many upgrades or passes they own. Shoes get you to a door"
			.. " and home again -- they never help you outrun the person chasing you.",
		TextSize = 12.5,
		TextColor3 = Theme.Color.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = carryNote,
	})

	-- ------------------------------------------------------------ helpers
	local function priceButton(row: Widgets.Row, cost: number, cash: number, label: string?)
		local affordable = cash >= cost
		row.action.Text = label or ("$" .. Format.short(cost))
		row.action.BackgroundColor3 = if affordable then Theme.Color.Cash else Theme.Color.PanelRaised
		row.action.TextColor3 = if affordable then Theme.Color.Panel else Theme.Color.TextFaint
	end

	local function maxedButton(row: Widgets.Row, text: string)
		row.action.Text = text
		row.action.BackgroundColor3 = Theme.Color.PanelRaised
		row.action.TextColor3 = Theme.Color.Good
	end

	--[[ Turns an upgrade's raw bonus into the sentence a player wants: what the
	     number is now, and what one more level would make it. ]]
	local function describe(upgrade, motel): string
		local now, next = upgrade.bonus, upgrade.nextBonus

		if upgrade.id == "shoes" then
			local base = (motel.walkSpeed or 16) - now
			return `Walk speed {Format.short(base + now)}`
				.. (if upgrade.maxed then "" else ` -> {Format.short(base + next)}`)
		elseif upgrade.id == "service" then
			return `+{math.floor(now * 100)}% rent`
				.. (if upgrade.maxed then "" else ` -> +{math.floor(next * 100)}%`)
		elseif upgrade.id == "sign" then
			local interval = motel.arrivalInterval or 12
			return `A guest every {string.format("%.1f", interval)}s`
				.. (if upgrade.maxed then "" else ` -> every {string.format("%.1f", math.max(2, interval - 1))}s`)
		elseif upgrade.id == "porter" then
			if now >= 2 then
				return "Alerted when a thief starts on your door, and they are marked"
			elseif now >= 1 then
				return "Alerted when a thief starts on your door -> plus a marker on them"
			end
			return "Right now you only find out once the door is already open"
		end
		return upgrade.desc
	end

	-- ------------------------------------------------------------ refresh
	local function refresh(state)
		lastState = state
		local motel = state.motel or {}
		local cash = state.cash or 0

		steps.Visible = activeTab == "Motel"
		upgradesPane.Visible = activeTab == "Upgrades"

		-- Rooms
		roomRow.title.Text = `Rooms  <font color='#8A93A6'>{motel.rooms or 0} / {motel.maxRooms or 0}</font>`
		roomRow.desc.Text = "One more guest can pay rent at the same time."
		if (motel.rooms or 0) >= (motel.maxRooms or 0) then
			maxedButton(roomRow, "At the cap")
			roomRow.desc.Text = "At your ceiling. Extra Wing in the Star Shop raises it."
		else
			priceButton(roomRow, motel.roomCost or 0, cash)
		end

		-- Rating
		ratingRow.title.Text = `Rating  <font color='#8A93A6'>{motel.ratingName or ""}</font>`
		if motel.nextRatingName then
			ratingRow.desc.Text = `Next: {motel.nextRatingName} -- {motel.nextRatingDesc or ""}`
			priceButton(ratingRow, motel.ratingCost or 0, cash)
		else
			ratingRow.desc.Text = motel.ratingDesc or ""
			maxedButton(ratingRow, "Maxed")
		end

		-- Lock
		lockRow.title.Text = `Door lock  <font color='#8A93A6'>{motel.lockName or "No Lock"}</font>`
		lockRow.desc.Text = `Thieves need {motel.breakSeconds or 0}s on your door.`
		if motel.nextLockName then
			priceButton(lockRow, motel.lockCost or 0, cash)
		else
			maxedButton(lockRow, "Best lock")
		end

		-- Safe
		safeRow.title.Text = `Safe  <font color='#8A93A6'>{Format.duration(motel.safeSeconds or 0)} of rent</font>`
		if motel.nextSafeSeconds then
			safeRow.desc.Text = `Holds {Format.duration(motel.nextSafeSeconds)} before it stops filling.`
			priceButton(safeRow, motel.safeCost or 0, cash)
		else
			safeRow.desc.Text = "As big as safes get."
			maxedButton(safeRow, "Maxed")
		end

		-- Levelled upgrades
		for index, upgrade in motel.upgrades or {} do
			local row = upgradeRow(upgrade.id, index)
			row.title.Text = `{upgrade.name}  <font color='#8A93A6'>level {upgrade.level}/{upgrade.maxLevel}</font>`
			row.desc.Text = describe(upgrade, motel)

			if upgrade.maxed then
				maxedButton(row, "Maxed")
			else
				priceButton(row, upgrade.cost, cash)
			end
		end

		window.setSubtitle(
			`${Format.short(cash)}  ·  {motel.rooms or 0} rooms  ·  {motel.ratingName or ""}  ·  `
				.. `walk {Format.short(motel.walkSpeed or 16)}`
		)
	end

	Widgets.tabs(window, { "Motel", "Upgrades" }, function(name)
		activeTab = name
		refresh(lastState)
	end)("Motel")

	return { root = window.root, refresh = refresh }
end

return MotelWindow
