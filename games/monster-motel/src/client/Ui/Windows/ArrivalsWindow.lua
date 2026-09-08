--!strict
--[[
	ArrivalsWindow

	The queue of monsters currently willing to check in, and the exact odds behind
	it.

	The odds table is rendered from the same weights the server rolls against, for
	the player's current rating and the next one, so "what does upgrading actually
	get me" is answered on the screen instead of in a wiki.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local Actions = require(script.Parent.Parent.Parent.Actions)
local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local ArrivalsWindow = {}

local MAX_ROWS = 8

function ArrivalsWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Arrivals", "Whoever is pulling off the highway right now.", close)
	window.root.Parent = parent

	local rows: { Widgets.Row } = {}
	for index = 1, MAX_ROWS do
		local row = Widgets.row(index, window.body)
		row.root.Visible = false
		row.action.Activated:Connect(function()
			-- The slot index is stamped on the row each refresh, so the button
			-- always acts on whatever is currently in that position.
			local slot = row.root:GetAttribute("Slot")
			if slot then
				Actions.invoke("checkIn", { slot = slot })
			end
		end)
		table.insert(rows, row)
	end

	local empty = Widgets.label({
		LayoutOrder = MAX_ROWS + 1,
		Text = "The road is quiet. Someone will turn up in a moment.",
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Visible = false,
		Parent = window.body,
	})

	Widgets.label({
		LayoutOrder = 100,
		Text = "Who shows up",
		Font = Theme.Font.Heading,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = window.body,
	})

	local oddsPanel = Widgets.panel({
		LayoutOrder = 101,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = window.body,
	})
	Widgets.padding(12).Parent = oddsPanel

	local oddsLabel = Widgets.label({
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.Color.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = oddsPanel,
	})

	local function oddsText(odds: { any }?, heading: string): string
		if not odds or #odds == 0 then
			return ""
		end
		local lines = { `<b>{heading}</b>` }
		for _, entry in odds do
			local color = Theme.Rarity[entry.rarity] or Theme.Color.TextDim
			table.insert(
				lines,
				`  <font color='#{color:ToHex()}'>{string.format("%5s", Format.percent(entry.chance))}</font>  {entry.rarity}`
			)
		end
		return table.concat(lines, "\n")
	end

	local function refresh(state)
		local arrivals = state.arrivals or {}
		local slots = arrivals.slots or {}
		local cash = state.cash or 0
		local full = (state.housed or 0) >= (state.capacity or 0)

		for index, row in rows do
			local slot = slots[index]
			if not slot then
				row.root.Visible = false
			else
				row.root.Visible = true
				row.root:SetAttribute("Slot", slot.index)

				local color = Theme.Rarity[slot.rarity] or Theme.Color.TextDim
				row.swatch.BackgroundColor3 = color
				row.title.Text = `{slot.name}  <font color='#{color:ToHex()}'>{slot.rarity}</font>`
				row.desc.Text = `${Format.short(slot.rent)}/s  ·  <font color='#8A93A6'>{slot.quip}</font>`

				if full then
					row.action.Text = "No rooms"
					row.action.BackgroundColor3 = Theme.Color.Locked
					row.action.TextColor3 = Theme.Color.TextDim
				else
					local affordable = cash >= slot.price
					row.action.Text = `$` .. Format.short(slot.price)
					row.action.BackgroundColor3 = if affordable then Theme.Color.Cash else Theme.Color.PanelRaised
					row.action.TextColor3 = if affordable then Theme.Color.Panel else Theme.Color.TextFaint
				end
			end
		end

		empty.Visible = #slots == 0

		local motel = state.motel or {}
		local text = oddsText(arrivals.odds, `At {motel.ratingName or "your rating"}`)
		if arrivals.nextOdds and motel.nextRatingName then
			text ..= "\n\n" .. oddsText(arrivals.nextOdds, `At {motel.nextRatingName}`)
		end
		text ..= `\n\nA new guest every {string.format("%.0f", arrivals.interval or 12)}s.`
			.. " Slots stay put if you leave -- rejoining will not reroll them."
		oddsLabel.Text = text

		window.setSubtitle(
			`{#slots}/{arrivals.maxSlots or 4} on the road  ·  {state.housed or 0}/{state.capacity or 0} rooms filled`
		)
	end

	return { root = window.root, refresh = refresh }
end

return ArrivalsWindow
