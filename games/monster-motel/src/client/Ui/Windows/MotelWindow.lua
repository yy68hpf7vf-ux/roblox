--!strict
--[[
	MotelWindow

	The four things Cash buys. Each row states what the upgrade does in the units
	the game already uses, so nothing here needs working out.

	The lock row deliberately names the exact number of seconds a thief will need,
	because that is the number the defender is buying and the number the thief sees
	on the door. Both sides read the same figure.
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

	local function makeRow(order: number, action: string, color: Color3): Widgets.Row
		local row = Widgets.row(order, window.body)
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

	Widgets.label({
		LayoutOrder = 10,
		Text = "About your door",
		Font = Theme.Font.Heading,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = window.body,
	})

	local doorNote = Widgets.panel({
		LayoutOrder = 11,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = window.body,
	})
	Widgets.padding(12).Parent = doorNote

	local doorLabel = Widgets.label({
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.Color.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = doorNote,
	})

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

	local function refresh(state)
		local motel = state.motel or {}
		local cash = state.cash or 0

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

		doorLabel.Text = `Your door can only be broken during Lights Out, and never in your first ten `
			.. `minutes in a server. Nobody can rob you while you have three guests or fewer.\n\n`
			.. `Break time depends only on your lock and your Deadbolt level -- never on what the `
			.. `thief owns or has bought. Nothing in the Store changes it in either direction.`

		window.setSubtitle(
			`${Format.short(state.cash or 0)}  ·  {motel.rooms or 0} rooms  ·  {motel.ratingName or ""}`
		)
	end

	return { root = window.root, refresh = refresh }
end

return MotelWindow
