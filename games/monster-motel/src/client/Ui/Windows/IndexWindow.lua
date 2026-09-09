--!strict
--[[
	IndexWindow

	Every guest in the game, and whether you have ever owned one.

	Collection is the quietest and most durable motivator in this genre, and it was
	missing entirely: forty-five guests existed and there was no way to see which
	ones you had met. It also does a second job -- an undiscovered row still shows
	its rarity and its rent, so the index doubles as the game's price list. A player
	deciding whether Five Star is worth seventy million can look up what a Legendary
	actually pays.

	Discovery is permanent. Renovating does not clear it and neither does losing a
	guest to a thief, because a collection you can be robbed of is not a collection.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Guests = require(Shared.Config.Guests)

local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local IndexWindow = {}

function IndexWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Index", "Every guest in the game.", close)
	window.root.Parent = parent

	type RowHandle = { row: Widgets.Row, guest: Guests.Guest }
	local rows: { RowHandle } = {}
	local headers: { [string]: TextLabel } = {}

	local order = 0
	for _, rarity in Guests.RarityOrder do
		local pool = Guests.ByRarity[rarity]
		if pool and #pool > 0 then
			order += 1
			local color = Guests.RarityColor[rarity] or Theme.Color.TextDim

			headers[rarity] = Widgets.label({
				LayoutOrder = order,
				Text = rarity,
				Font = Theme.Font.Heading,
				TextSize = 15,
				TextColor3 = color,
				Size = UDim2.new(1, 0, 0, 26),
				Parent = window.body,
			})

			for _, guest in pool do
				order += 1
				local row = Widgets.row(order, window.body)
				-- The action button is a static badge here, not a button.
				row.action.AutoButtonColor = false
				row.action.Active = false
				table.insert(rows, { row = row, guest = guest })
			end
		end
	end

	local function refresh(state)
		local discovered = state.discovered or {}
		local found = 0

		for _, handle in rows do
			local guest = handle.guest
			local row = handle.row
			local color = Guests.RarityColor[guest.rarity] or Theme.Color.TextDim
			local known = discovered[guest.id] == true

			if known then
				found += 1
				row.swatch.BackgroundColor3 = guest.color
				row.title.Text = guest.name
				row.title.TextColor3 = Theme.Color.Text
				row.desc.Text = `${Format.short(guest.rent)}/s  ·  <font color='#8A93A6'>{guest.quip}</font>`
				row.action.Text = "Found"
				row.action.BackgroundColor3 = Theme.Color.PanelRaised
				row.action.TextColor3 = color
			else
				-- Still shows rarity and rent. An index that hides the numbers is
				-- a locked door; one that shows them is a shopping list.
				row.swatch.BackgroundColor3 = Theme.Color.PanelSunken
				row.title.Text = "? ? ?"
				row.title.TextColor3 = Theme.Color.TextFaint
				row.desc.Text = `${Format.short(guest.rent)}/s  ·  <font color='#5A6172'>not met yet</font>`
				row.action.Text = "—"
				row.action.BackgroundColor3 = Theme.Color.PanelSunken
				row.action.TextColor3 = Theme.Color.TextFaint
			end
		end

		-- Per-rarity progress in the section headers.
		for rarity, label in headers do
			local pool = Guests.ByRarity[rarity] or {}
			local count = 0
			for _, guest in pool do
				if discovered[guest.id] then
					count += 1
				end
			end
			local color = Guests.RarityColor[rarity] or Theme.Color.TextDim
			label.Text = `{rarity}  <font color='#8A93A6'>{count}/{#pool}</font>`
				.. (if count == #pool then `  <font color='#{color:ToHex()}'>complete</font>` else "")
		end

		window.setSubtitle(`{found}/{#rows} guests found`)
	end

	return { root = window.root, refresh = refresh }
end

return IndexWindow
