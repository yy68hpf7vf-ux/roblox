--!strict
--[[
	StoreWindow

	Gamepasses and Crystal packs.

	Every row says exactly what it does before the Robux prompt opens, and crystal
	packs show the real number of Crystals this player will receive, computed from
	their own income. Items whose asset id has not been filled in are hidden rather
	than shown as buttons that open a prompt for nothing.

	There is no timer on this screen, no crossed-out price, no bundle whose
	contents are a surprise, and nothing random for sale.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Format = require(Shared.Util.Format)

local Actions = require(script.Parent.Parent.Parent.Actions)
local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local StoreWindow = {}

function StoreWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Store", "Optional. The whole game is reachable without any of it.", close)
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
		if Monetization.isConfigured(pass.assetId) then
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
					row.action.TextColor3 = Theme.Color.Panel
				end
			end)
		end
	end

	Widgets.label({
		LayoutOrder = 50,
		Text = "Crystals",
		Font = Theme.Font.Heading,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = window.body,
	})

	Widgets.label({
		LayoutOrder = 51,
		Text = "Packs are sized against what you currently earn, so they stay useful as you progress.",
		TextColor3 = Theme.Color.TextFaint,
		TextSize = 12.5,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = window.body,
	})

	for index, product in Monetization.Products do
		if Monetization.isConfigured(product.assetId) then
			local row = Widgets.row(52 + index, window.body)
			row.swatch.BackgroundColor3 = if product.kind == "boost" then Theme.Color.Warn else Theme.Color.Crystal
			row.title.Text = product.name

			row.action.Activated:Connect(function()
				Actions.invoke("promptProduct", { id = product.id })
			end)

			table.insert(painters, function(state)
				if product.kind == "crystals" then
					local amount = (state.productAmounts or {})[product.id] or 0
					row.desc.Text = `{product.desc}  <font color='#8A93A6'>({Format.comma(amount)} Crystals right now)</font>`
					row.action.Text = "Buy"
				else
					row.desc.Text = product.desc
					local remaining = state.boostRemaining or 0
					row.action.Text = if remaining > 0 then "Extend" else "Buy"
				end
				row.action.BackgroundColor3 = Theme.Color.Robux
				row.action.TextColor3 = Theme.Color.Panel
			end)
		end
	end

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
