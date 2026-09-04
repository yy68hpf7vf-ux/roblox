--!strict
--[[
	ShopWindow
	Picks and backpacks. Rows are built once and repainted on every state push, so
	scroll position survives a purchase.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Backpacks = require(Shared.Config.Backpacks)
local Tools = require(Shared.Config.Tools)
local Format = require(Shared.Util.Format)

local Actions = require(script.Parent.Parent.Parent.Actions)
local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local ShopWindow = {}

type RowBinding = {
	row: Widgets.Row,
	paint: (state: { [string]: any }) -> (),
}

function ShopWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Shop", "Better picks mine faster. Bigger packs mean fewer walks.", close)
	window.root.Parent = parent

	local bindings: { RowBinding } = {}
	local activeTab = "Picks"

	local function makeToolRow(tool: Tools.Tool, order: number): RowBinding
		local row = Widgets.row(order, window.body)
		row.swatch.BackgroundColor3 = tool.color
		row.title.Text = tool.name
		row.root.Name = "tool_" .. tool.id

		row.action.Activated:Connect(function()
			Actions.invoke("buyTool", { id = tool.id })
		end)

		local function paint(state)
			row.root.Visible = activeTab == "Picks"

			local owned = (state.ownedTools or {})[tool.id] == true or tool.id == Tools.Starter
			local equipped = state.tool == tool.id
			local locked = (state.rebirths or 0) < tool.rebirths

			row.desc.Text = `{tool.desc}  <font color='#8A93A6'>(power {Format.comma(tool.power)})</font>`

			if equipped then
				row.action.Text = "Equipped"
				row.action.BackgroundColor3 = Theme.Color.PanelRaised
				row.action.TextColor3 = Theme.Color.Good
			elseif owned then
				row.action.Text = "Equip"
				row.action.BackgroundColor3 = Theme.Color.Good
				row.action.TextColor3 = Theme.Color.Panel
			elseif locked then
				row.action.Text = `{tool.rebirths} rebirths`
				row.action.BackgroundColor3 = Theme.Color.Locked
				row.action.TextColor3 = Theme.Color.TextDim
			else
				local affordable = (state.crystals or 0) >= tool.price
				row.action.Text = Format.short(tool.price)
				row.action.BackgroundColor3 = if affordable then Theme.Color.Accent else Theme.Color.PanelRaised
				row.action.TextColor3 = if affordable then Theme.Color.Panel else Theme.Color.TextFaint
			end
		end

		return { row = row, paint = paint }
	end

	local function makePackRow(pack: Backpacks.Backpack, order: number): RowBinding
		local row = Widgets.row(order, window.body)
		row.swatch.BackgroundColor3 = pack.color
		row.title.Text = pack.name
		row.root.Name = "pack_" .. pack.id

		row.action.Activated:Connect(function()
			Actions.invoke("buyBackpack", { id = pack.id })
		end)

		local function paint(state)
			row.root.Visible = activeTab == "Backpacks"

			local owned = (state.ownedBackpacks or {})[pack.id] == true or pack.id == Backpacks.Starter
			local equipped = state.backpack == pack.id
			local locked = (state.rebirths or 0) < pack.rebirths

			row.desc.Text = `{pack.desc}  <font color='#8A93A6'>(holds {Format.short(pack.capacity)})</font>`

			if equipped then
				row.action.Text = "Equipped"
				row.action.BackgroundColor3 = Theme.Color.PanelRaised
				row.action.TextColor3 = Theme.Color.Good
			elseif owned then
				row.action.Text = "Equip"
				row.action.BackgroundColor3 = Theme.Color.Good
				row.action.TextColor3 = Theme.Color.Panel
			elseif locked then
				row.action.Text = `{pack.rebirths} rebirths`
				row.action.BackgroundColor3 = Theme.Color.Locked
				row.action.TextColor3 = Theme.Color.TextDim
			else
				local affordable = (state.crystals or 0) >= pack.price
				row.action.Text = Format.short(pack.price)
				row.action.BackgroundColor3 = if affordable then Theme.Color.Accent else Theme.Color.PanelRaised
				row.action.TextColor3 = if affordable then Theme.Color.Panel else Theme.Color.TextFaint
			end
		end

		return { row = row, paint = paint }
	end

	for index, tool in Tools.List do
		table.insert(bindings, makeToolRow(tool, index))
	end
	for index, pack in Backpacks.List do
		table.insert(bindings, makePackRow(pack, 100 + index))
	end

	local lastState: { [string]: any } = {}

	local function refresh(state)
		lastState = state
		for _, binding in bindings do
			binding.paint(state)
		end
	end

	Widgets.tabs(window, { "Picks", "Backpacks" }, function(name)
		activeTab = name
		refresh(lastState)
	end)("Picks")

	return { root = window.root, refresh = refresh }
end

return ShopWindow
