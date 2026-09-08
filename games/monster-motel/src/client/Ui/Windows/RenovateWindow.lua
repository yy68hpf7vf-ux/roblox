--!strict
--[[
	RenovateWindow

	The prestige screen. It says plainly what a renovation takes as well as what it
	gives, because nobody should press this button and then be surprised.

	The line that matters most is the one about keeping your guests -- it is the
	difference between a reset players opt into and one they dread.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local Actions = require(script.Parent.Parent.Parent.Actions)
local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local RenovateWindow = {}

function RenovateWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Renovate", "Trade the building for a permanent multiplier.", close)
	window.root.Parent = parent

	local summary = Widgets.panel({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 186), Parent = window.body })
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
		Text = "<b>You keep:</b> every guest you own, every Star, every Star Shop level."
			.. "\n<b>You lose:</b> your cash, your rooms, your rating, your lock and your safe."
			.. "\n<font color='#8A93A6'>Guests move to storage and go straight back in as you rebuild.</font>",
		TextColor3 = Theme.Color.TextFaint,
		TextSize = 12.5,
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 52),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = summary,
	})

	local _, progressFill = Widgets.bar({
		Position = UDim2.new(0, 0, 0, 128),
		Size = UDim2.new(1, 0, 0, 8),
		Parent = summary,
	}, Theme.Color.Star)

	local renovateButton = Widgets.button({
		Position = UDim2.fromOffset(0, 144),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 15,
		Parent = summary,
	}, function()
		Actions.invoke("renovate")
	end)

	Widgets.label({
		LayoutOrder = 1,
		Text = "Star Shop",
		Font = Theme.Font.Heading,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = window.body,
	})

	Widgets.label({
		LayoutOrder = 2,
		Text = "Stars only come from renovating. Nothing here is for sale.",
		TextColor3 = Theme.Color.TextFaint,
		TextSize = 12.5,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = window.body,
	})

	local upgradeList = Widgets.new("Frame", {
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = window.body,
	}) :: Frame
	Widgets.list().Parent = upgradeList

	local upgradeRows: { [string]: Widgets.Row } = {}

	local function rowFor(upgrade, order: number): Widgets.Row
		local existing = upgradeRows[upgrade.id]
		if existing then
			return existing
		end
		local row = Widgets.row(order, upgradeList)
		row.swatch.BackgroundColor3 = Theme.Color.Star
		row.action.Activated:Connect(function()
			Actions.invoke("buyUpgrade", { id = upgrade.id })
		end)
		upgradeRows[upgrade.id] = row
		return row
	end

	local function refresh(state)
		local prestige = state.prestige or {}
		local pending = prestige.pendingStars or 0

		headline.Text = `Renovation {(prestige.renovations or 0) + 1}  ·  `
			.. `{Format.multiplier(prestige.multiplier or 1)} to {Format.multiplier(prestige.nextMultiplier or 1.25)}`

		detail.Text = `Worth {pending} Star{if pending == 1 then "" else "s"} right now.`
			.. `\nEarned this run: ${Format.short(prestige.earnedThisRun or 0)}`
			.. `  ·  next Star at ${Format.short(prestige.nextStarAt or 0)}`

		local target = math.max(1, prestige.nextStarAt or 1)
		progressFill.Size = UDim2.fromScale(math.clamp((prestige.earnedThisRun or 0) / target, 0, 1), 1)

		if prestige.canRenovate then
			renovateButton.Text = `Renovate for {pending} Star{if pending == 1 then "" else "s"}`
			renovateButton.BackgroundColor3 = Theme.Color.Star
			renovateButton.TextColor3 = Theme.Color.Panel
		else
			renovateButton.Text = prestige.blockedReason or "Not yet"
			renovateButton.BackgroundColor3 = Theme.Color.PanelRaised
			renovateButton.TextColor3 = Theme.Color.TextFaint
		end

		window.setSubtitle(`{Format.comma(state.stars or 0)} Stars available`)

		for index, upgrade in prestige.upgrades or {} do
			local row = rowFor(upgrade, index)
			row.title.Text = `{upgrade.name}  <font color='#8A93A6'>level {upgrade.level}/{upgrade.maxLevel}</font>`

			local bonus = upgrade.perLevel * upgrade.level
			local shown
			if upgrade.suffix == "rent" then
				shown = `+{math.floor(bonus * 100)}% rent`
			elseif upgrade.suffix == "max room" then
				shown = `+{math.floor(bonus)} rooms`
			else
				shown = `+{string.format("%.1f", bonus)}s on your lock`
			end
			row.desc.Text = `{upgrade.desc}  <font color='#8A93A6'>({shown} now)</font>`

			if upgrade.maxed then
				row.action.Text = "Maxed"
				row.action.BackgroundColor3 = Theme.Color.PanelRaised
				row.action.TextColor3 = Theme.Color.Good
			else
				local affordable = (state.stars or 0) >= upgrade.cost
				row.action.Text = `{upgrade.cost} Stars`
				row.action.BackgroundColor3 = if affordable then Theme.Color.Star else Theme.Color.PanelRaised
				row.action.TextColor3 = if affordable then Theme.Color.Panel else Theme.Color.TextFaint
			end
		end
	end

	return { root = window.root, refresh = refresh }
end

return RenovateWindow
