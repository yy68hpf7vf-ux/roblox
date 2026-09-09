--!strict
--[[
	StoreWindow

	Gamepasses and cash drops.

	Every row says exactly what it does before the Robux prompt opens, and a cash
	drop shows the real figure this player will receive, computed from their own
	rent. Items whose asset id has not been filled in are hidden rather than shown
	as buttons that open a prompt for nothing.

	No timer on this screen, no crossed-out price, no bundle whose contents are a
	surprise, and nothing random for sale.

	The footer is not decoration. In a game built on robbing other players, the
	single most valuable thing the store can say is which numbers it does not
	touch -- and the fairness note at the bottom lists them.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Guests = require(Shared.Config.Guests)
local Monetization = require(Shared.Config.Monetization)
local Format = require(Shared.Util.Format)

local Actions = require(script.Parent.Parent.Parent.Actions)
local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local StoreWindow = {}

function StoreWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Store", "Optional. Nothing here touches raiding -- see the note at the bottom.", close)
	window.root.Parent = parent

	local painters: { (state: { [string]: any }) -> () } = {}

	Widgets.label({
		LayoutOrder = 0,
		Text = "Passes",
		Font = Theme.Font.Heading,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = window.body,
	})

	for index, pass in Monetization.Gamepasses do
		if Monetization.isConfigured(pass.assetId) and not pass.signatureGuest then
			local row = Widgets.row(index, window.body)
			row.swatch.BackgroundColor3 = Theme.Color.Robux
			row.title.Text = pass.name
			row.desc.Text = pass.desc

			row.action.Activated:Connect(function()
				Actions.invoke("promptGamepass", { id = pass.id })
			end)

			table.insert(painters, function(state)
				local owned = (state.passes or {})[pass.id] == true
				if owned then
					row.action.Text = "Owned"
					row.action.BackgroundColor3 = Theme.Color.PanelRaised
					row.action.TextColor3 = Theme.Color.Good
				else
					row.action.Text = "Get"
					row.action.BackgroundColor3 = Theme.Color.Robux
					row.action.TextColor3 = Theme.Color.Ink
				end
			end)
		end
	end

	-- ---------------------------------------------------------- signature guests
	Widgets.label({
		LayoutOrder = 20,
		Text = "Signature guests",
		Font = Theme.Font.Heading,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = window.body,
	})

	Widgets.label({
		LayoutOrder = 21,
		Text = "Yours permanently. They can still be stolen like any other guest --"
			.. " if that happens you get them back at sunrise and the thief keeps the"
			.. " one they carried home.",
		TextColor3 = Theme.Color.TextFaint,
		TextSize = 12.5,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = window.body,
	})

	for index, pass in Monetization.Gamepasses do
		if Monetization.isConfigured(pass.assetId) and pass.signatureGuest then
			local guest = Guests.get(pass.signatureGuest)
			local row = Widgets.row(22 + index, window.body)
			row.swatch.BackgroundColor3 = if guest then guest.color else Theme.Color.Robux
			row.title.Text = pass.name

			row.action.Activated:Connect(function()
				Actions.invoke("promptGamepass", { id = pass.id })
			end)

			table.insert(painters, function(state)
				local owned = (state.passes or {})[pass.id] == true
				if guest then
					row.desc.Text = `${Format.short(guest.rent)}/s  ·  <font color='{Theme.Hex.TextDim}'>{guest.quip}</font>`
				else
					row.desc.Text = pass.desc
				end

				if owned then
					row.action.Text = "Owned"
					row.action.BackgroundColor3 = Theme.Color.PanelRaised
					row.action.TextColor3 = Theme.Color.Good
				else
					row.action.Text = "Get"
					row.action.BackgroundColor3 = Theme.Color.Robux
					row.action.TextColor3 = Theme.Color.Ink
				end
			end)
		end
	end

	Widgets.label({
		LayoutOrder = 50,
		Text = "Cash drops",
		Font = Theme.Font.Heading,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = window.body,
	})

	Widgets.label({
		LayoutOrder = 51,
		Text = "Cash drops are sized against your own rent, so they stay useful as you progress.",
		TextColor3 = Theme.Color.TextFaint,
		TextSize = 12.5,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = window.body,
	})

	for index, product in Monetization.Products do
		if Monetization.isConfigured(product.assetId) then
			local row = Widgets.row(52 + index, window.body)
			row.swatch.BackgroundColor3 = if product.kind == "boost" then Theme.Color.Warn else Theme.Color.Cash
			row.title.Text = product.name

			row.action.Activated:Connect(function()
				Actions.invoke("promptProduct", { id = product.id })
			end)

			table.insert(painters, function(state)
				if product.kind == "cash" then
					local amount = (state.productAmounts or {})[product.id] or 0
					row.desc.Text = `{product.desc}  <font color='{Theme.Hex.TextDim}'>(${Format.comma(amount)} right now)</font>`
					row.action.Text = "Buy"
				else
					row.desc.Text = product.desc
					local remaining = state.boostRemaining or 0
					row.action.Text = if remaining > 0 then "Extend" else "Buy"
				end
				row.action.BackgroundColor3 = Theme.Color.Robux
				row.action.TextColor3 = Theme.Color.Ink
			end)
		end
	end

	Widgets.label({
		LayoutOrder = 200,
		Text = "<b>Nothing here affects raiding.</b>",
		Font = Theme.Font.Heading,
		TextSize = 14,
		TextColor3 = Theme.Color.Good,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = window.body,
	})

	Widgets.label({
		LayoutOrder = 201,
		Text = "The best guests in the game are not for sale either -- the top Mythic"
			.. " out-earns every Signature, and Celebrities are worth several times more"
			.. " again and can only be caught in the square."
			.. "\n\nCarry speed, lock break time, catch range, the new-player grace window and the"
			.. " length of the night are the same numbers for everyone in the server, whether"
			.. " they have bought everything on this page or nothing at all."
			.. "\n\nYou can buy a richer motel. You cannot buy your way into someone else's,"
			.. " or out of your own being entered.",
		TextColor3 = Theme.Color.TextDim,
		TextSize = 12.5,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = window.body,
	})

	if #painters == 0 then
		Widgets.label({
			LayoutOrder = 100,
			Text = "Nothing is on sale yet. Fill in the asset ids in Config/Monetization.lua"
				.. "\nafter you publish the place and the store fills itself in.",
			TextColor3 = Theme.Color.TextDim,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 60),
			Parent = window.body,
		})
	end

	local function refresh(state)
		for _, paint in painters do
			paint(state)
		end
	end

	return { root = window.root, refresh = refresh }
end

return StoreWindow
