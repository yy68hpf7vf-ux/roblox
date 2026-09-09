--!strict
--[[
	GuestsWindow

	Everyone you own, housed or in storage.

	Rebuilt on each refresh rather than diffed: the list is at most a couple of
	hundred rows and it only rebuilds while the tab is open. The three bulk buttons
	at the top exist because a renovation leaves twenty guests in storage, and
	re-housing them one at a time would be twenty clicks for a decision nobody
	actually wants to make individually.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Guests = require(Shared.Config.Guests)

local Actions = require(script.Parent.Parent.Parent.Actions)
local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local GuestsWindow = {}

function GuestsWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Guests", "Only guests in a room pay rent.", close)
	window.root.Parent = parent

	local controls = Widgets.panel({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 52), Parent = window.body })
	Widgets.padding(8).Parent = controls

	Widgets.button({
		Text = "Fill rooms",
		Size = UDim2.fromOffset(112, 36),
		TextSize = 13,
		Parent = controls,
	}, function()
		Actions.invoke("houseBest")
	end)

	Widgets.button({
		Text = "Best in rooms",
		Position = UDim2.fromOffset(120, 0),
		Size = UDim2.fromOffset(132, 36),
		TextSize = 13,
		Parent = controls,
	}, function()
		Actions.invoke("optimise")
	end)

	Widgets.button({
		Text = "Release stored Commons",
		Position = UDim2.fromOffset(260, 0),
		Size = UDim2.fromOffset(196, 36),
		TextSize = 13,
		BackgroundColor3 = Theme.Color.PanelRaised,
		TextColor3 = Theme.Color.TextDim,
		Parent = controls,
	}, function()
		Actions.invoke("releaseBelow", { rarity = "Uncommon" })
	end)

	local list = Widgets.new("Frame", {
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = window.body,
	}) :: Frame
	Widgets.list().Parent = list

	local function refresh(state)
		Widgets.clear(list)

		local guests = state.guests or {}
		if #guests == 0 then
			Widgets.label({
				Text = "No guests yet. Check somebody in from the Arrivals window.",
				TextColor3 = Theme.Color.TextDim,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 40),
				Parent = list,
			})
			window.setSubtitle("Only guests in a room pay rent.")
			return
		end

		-- Housed first, then storage; best-paying first within each group.
		local sorted = table.clone(guests)
		table.sort(sorted, function(a, b)
			local aHoused = (a.room or 0) > 0
			local bHoused = (b.room or 0) > 0
			if aHoused ~= bHoused then
				return aHoused
			end
			if a.rent == b.rent then
				return a.uid < b.uid
			end
			return a.rent > b.rent
		end)

		local storedCount = 0
		for _, entry in sorted do
			if (entry.room or 0) == 0 then
				storedCount += 1
			end
		end

		for index, entry in sorted do
			local row = Widgets.row(index, list)
			local color = Theme.Rarity[entry.rarity] or Theme.Color.TextDim
			local housed = (entry.room or 0) > 0

			row.swatch.BackgroundColor3 = color
			row.title.Text = `{entry.name}  <font color='#{color:ToHex()}'>{entry.rarity}</font>`
			row.desc.Text = if housed
				then `Room {entry.room}  ·  paying ${Format.short(entry.rent)}/s`
				else `<font color='{Theme.Hex.TextDim}'>In storage  ·  would pay ${Format.short(entry.rent)}/s</font>`

			if housed then
				row.action.Text = "To storage"
				row.action.BackgroundColor3 = Theme.Color.PanelRaised
				row.action.TextColor3 = Theme.Color.Text
				row.action.Activated:Connect(function()
					Actions.invoke("storeGuest", { uid = entry.uid }, true)
				end)
			else
				row.action.Text = "Give a room"
				row.action.BackgroundColor3 = Theme.Color.Cash
				row.action.TextColor3 = Theme.Color.Ink
				row.action.Activated:Connect(function()
					Actions.invoke("houseGuest", { uid = entry.uid }, true)
				end)
			end
		end

		window.setSubtitle(
			`{state.housed or 0}/{state.capacity or 0} rooms filled  ·  {storedCount} in storage  ·  `
				.. `${Format.short(state.rentPerSecond or 0)}/s`
		)
	end

	return { root = window.root, refresh = refresh }
end

return GuestsWindow
