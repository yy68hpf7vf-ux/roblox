--!strict
--[[
	RebirthWindow

	The prestige screen. It states plainly what a rebirth takes away as well as
	what it gives -- a player should never press this button and be surprised.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local Actions = require(script.Parent.Parent.Parent.Actions)
local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local RebirthWindow = {}

function RebirthWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Rebirth", "Trade the map for a permanent multiplier.", close)
	window.root.Parent = parent

	-- ------------------------------------------------------------ summary
	local summary = Widgets.panel({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 172),
		Parent = window.body,
	})
	Widgets.padding(14).Parent = summary

	local headline = Widgets.label({
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = summary,
	})

	local detail = Widgets.label({
		Text = "",
		TextColor3 = Theme.Color.TextDim,
		TextSize = 13,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 40),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = summary,
	})

	Widgets.label({
		Text = "<b>You keep:</b> pets, Cores, Core Shop upgrades, quests and rewards."
			.. "\n<b>You lose:</b> Crystals, ore, picks, backpacks and zone unlocks.",
		TextColor3 = Theme.Color.TextFaint,
		TextSize = 12.5,
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 36),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = summary,
	})

	local _, progressFill = Widgets.bar({
		Position = UDim2.new(0, 0, 0, 114),
		Size = UDim2.new(1, 0, 0, 8),
		Parent = summary,
	}, Theme.Color.Core)

	local rebirthButton = Widgets.button({
		Position = UDim2.fromOffset(0, 130),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 15,
		Parent = summary,
	}, function()
		Actions.invoke("rebirth")
	end)

	-- ------------------------------------------------------------ core shop
	Widgets.label({
		LayoutOrder = 1,
		Text = "Core Shop",
		Font = Theme.Font.Heading,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = window.body,
	})

	Widgets.label({
		LayoutOrder = 2,
		Text = "Cores only come from rebirths. Nothing here is for sale.",
		TextColor3 = Theme.Color.TextFaint,
		TextSize = 12.5,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = window.body,
	})

	local upgradeRows: { [string]: Widgets.Row } = {}
	local upgradeList = Widgets.new("Frame", {
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = window.body,
	}) :: Frame
	Widgets.list().Parent = upgradeList

	local function rowFor(upgrade, order: number): Widgets.Row
		local existing = upgradeRows[upgrade.id]
		if existing then
			return existing
		end

		local row = Widgets.row(order, upgradeList)
		row.swatch.BackgroundColor3 = Theme.Color.Core
		row.title.Text = upgrade.name
		row.action.Activated:Connect(function()
			Actions.invoke("buyUpgrade", { id = upgrade.id })
		end)

		upgradeRows[upgrade.id] = row
		return row
	end

	local function refresh(state)
		local cost = state.rebirthCost or 0
		local crystals = state.crystals or 0
		local ready = crystals >= cost

		headline.Text = `Rebirth {(state.rebirths or 0) + 1}  ·  {Format.multiplier(state.rebirthMultiplier or 1)} to {Format.multiplier(state.nextRebirthMultiplier or 2)}`
		detail.Text = `Costs {Format.comma(cost)} Crystals and pays {state.rebirthCores or 1} Cores.`
			.. `\nYou have {Format.comma(crystals)}.`

		progressFill.Size = UDim2.fromScale(math.clamp(if cost > 0 then crystals / cost else 0, 0, 1), 1)

		if ready then
			rebirthButton.Text = "Rebirth now"
			rebirthButton.BackgroundColor3 = Theme.Color.Core
			rebirthButton.TextColor3 = Theme.Color.Panel
		else
			rebirthButton.Text = `{Format.short(cost - crystals)} Crystals to go`
			rebirthButton.BackgroundColor3 = Theme.Color.PanelRaised
			rebirthButton.TextColor3 = Theme.Color.TextFaint
		end

		window.setSubtitle(`{Format.comma(state.cores or 0)} Cores available`)

		for index, upgrade in state.coreUpgrades or {} do
			local row = rowFor(upgrade, index)
			row.title.Text = `{upgrade.name}  <font color='#8A93A6'>level {upgrade.level}/{upgrade.maxLevel}</font>`

			local bonus = upgrade.perLevel * upgrade.level
			local shown = if upgrade.suffix == "pet slot"
				then `+{math.floor(bonus)} {upgrade.suffix}{if bonus == 1 then "" else "s"}`
				else `+{math.floor(bonus * 100)}% {upgrade.suffix}`
			row.desc.Text = `{upgrade.desc}  <font color='#8A93A6'>({shown} now)</font>`

			if upgrade.maxed then
				row.action.Text = "Maxed"
				row.action.BackgroundColor3 = Theme.Color.PanelRaised
				row.action.TextColor3 = Theme.Color.Good
			else
				local affordable = (state.cores or 0) >= upgrade.cost
				row.action.Text = `{upgrade.cost} Cores`
				row.action.BackgroundColor3 = if affordable then Theme.Color.Core else Theme.Color.PanelRaised
				row.action.TextColor3 = if affordable then Theme.Color.Panel else Theme.Color.TextFaint
			end
		end
	end

	return { root = window.root, refresh = refresh }
end

return RebirthWindow
