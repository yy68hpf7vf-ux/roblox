--!strict
--[[
	Hud
	Currency, backpack fill, the multiplier breakdown, and the button bar.

	The multiplier is broken into its sources rather than shown as one number.
	A player who can see that x18.4 is "x3 rebirth, x4.1 pets, x1.5 VIP" knows
	which of those to go and improve; a player looking at "x18.4" is just looking
	at a number that gets bigger.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Backpacks = require(Shared.Config.Backpacks)
local Tools = require(Shared.Config.Tools)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Hud = {}

local NAV = {
	{ id = "shop", label = "Shop" },
	{ id = "zones", label = "Zones" },
	{ id = "pets", label = "Pets" },
	{ id = "rebirth", label = "Rebirth" },
	{ id = "daily", label = "Daily" },
	{ id = "store", label = "Store" },
}

export type Handle = {
	refresh: (state: { [string]: any }) -> (),
}

function Hud.build(parent: ScreenGui, openWindow: (string) -> ()): Handle
	-- ------------------------------------------------------------ currency
	local top = Widgets.panel({
		Name = "Currency",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(258, 128),
		BackgroundColor3 = Theme.Color.Panel,
		Parent = parent,
	})
	Widgets.padding(12).Parent = top

	local crystals = Widgets.label({
		Text = "0",
		Font = Theme.Font.Heading,
		TextSize = 26,
		TextColor3 = Theme.Color.Crystal,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = top,
	})

	local cores = Widgets.label({
		Text = "0 Cores",
		TextSize = 13,
		TextColor3 = Theme.Color.Core,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = top,
	})

	local oreLabel = Widgets.label({
		Text = "Backpack",
		TextSize = 12.5,
		TextColor3 = Theme.Color.TextDim,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = top,
	})

	local _, oreFill = Widgets.bar({
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 8),
		Parent = top,
	}, Theme.Color.Ore)

	local multiplier = Widgets.label({
		Text = "x1",
		Font = Theme.Font.Heading,
		TextSize = 14,
		TextColor3 = Theme.Color.Good,
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = top,
	})

	local zoneLabel = Widgets.label({
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.Color.TextFaint,
		Position = UDim2.fromOffset(0, 106),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = top,
	})

	-- ------------------------------------------------------------ breakdown
	local breakdown = Widgets.panel({
		Name = "Breakdown",
		Position = UDim2.fromOffset(14, 150),
		Size = UDim2.fromOffset(258, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.Panel,
		Visible = false,
		Parent = parent,
	})
	Widgets.padding(10).Parent = breakdown
	Widgets.list({ Padding = UDim.new(0, 3) }).Parent = breakdown

	local breakdownRows: { [string]: TextLabel } = {}
	local BREAKDOWN_ORDER = {
		{ key = "rebirth", label = "Rebirths" },
		{ key = "pets", label = "Pets" },
		{ key = "refinery", label = "Refinery" },
		{ key = "passes", label = "Passes" },
		{ key = "boost", label = "Boost" },
		{ key = "ore", label = "Ore yield" },
	}
	for index, entry in BREAKDOWN_ORDER do
		breakdownRows[entry.key] = Widgets.label({
			LayoutOrder = index,
			Text = entry.label,
			TextSize = 12.5,
			TextColor3 = Theme.Color.TextDim,
			Size = UDim2.new(1, 0, 0, 16),
			Parent = breakdown,
		})
	end

	local toggle = Widgets.button({
		Text = "?",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(22, 22),
		TextSize = 13,
		BackgroundColor3 = Theme.Color.PanelRaised,
		TextColor3 = Theme.Color.TextDim,
		Parent = top,
	})
	toggle.Activated:Connect(function()
		breakdown.Visible = not breakdown.Visible
	end)

	-- ------------------------------------------------------------ boost
	local boost = Widgets.panel({
		Name = "Boost",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(230, 30),
		BackgroundColor3 = Theme.Color.Panel,
		Visible = false,
		Parent = parent,
	})
	local boostLabel = Widgets.label({
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.Color.Warn,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = boost,
	})

	-- ------------------------------------------------------------ warning
	local warning = Widgets.panel({
		Name = "Warning",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -78),
		Size = UDim2.fromOffset(430, 34),
		BackgroundColor3 = Theme.Color.Panel,
		Visible = false,
		Parent = parent,
	})
	Widgets.label({
		Text = "Your progress is NOT being saved right now. Try rejoining.",
		TextSize = 13,
		TextColor3 = Theme.Color.Bad,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = warning,
	})

	-- ------------------------------------------------------------ nav
	local nav = Widgets.new("Frame", {
		Name = "Nav",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(#NAV * 96, 46),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Widgets.list({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})

	for index, entry in NAV do
		Widgets.button({
			Text = entry.label,
			LayoutOrder = index,
			Size = UDim2.fromOffset(88, 46),
			TextSize = 14,
			BackgroundColor3 = Theme.Color.PanelRaised,
			TextColor3 = Theme.Color.Text,
			Parent = nav,
		}, function()
			openWindow(entry.id)
		end)
	end

	-- ------------------------------------------------------------ refresh
	local function refresh(state: { [string]: any })
		if not state.crystals then
			return
		end

		crystals.Text = `{Format.short(state.crystals)} Crystals`
		cores.Text = `{Format.comma(state.cores or 0)} Cores  ·  {state.rebirths or 0} rebirths`

		local capacity = math.max(1, state.capacity or 1)
		local ore = state.ore or 0
		local ratio = math.clamp(ore / capacity, 0, 1)
		oreFill.Size = UDim2.fromScale(ratio, 1)
		oreFill.BackgroundColor3 = if ratio >= 1 then Theme.Color.Warn else Theme.Color.Ore
		oreLabel.Text = `Backpack  {Format.short(ore)} / {Format.short(capacity)}`
			.. (if ratio >= 1 then "  ·  <font color='#FFB05C'>full, go sell</font>" else "")

		local multipliers = state.multipliers or {}
		multiplier.Text = `{Format.multiplier(multipliers.total or 1)} Crystals  ·  {Format.short(state.incomePerSecond or 0)}/sec`

		local zone = Zones.get(state.zone)
		local tool = Tools.get(state.tool)
		local pack = Backpacks.get(state.backpack)
		zoneLabel.Text = `{zone.name}  ·  {tool.name}  ·  {pack.name}`

		for _, entry in BREAKDOWN_ORDER do
			local value = multipliers[entry.key] or 1
			local row = breakdownRows[entry.key]
			row.Text = `{entry.label}  <font color='#8A93A6'>{Format.multiplier(value)}</font>`
			row.TextColor3 = if value > 1 then Theme.Color.Text else Theme.Color.TextFaint
		end

		local remaining = state.boostRemaining or 0
		boost.Visible = remaining > 0
		if remaining > 0 then
			boostLabel.Text = `{Format.multiplier(state.boostMultiplier or 2)} boost  ·  {Format.duration(remaining)} left`
		end

		warning.Visible = state.volatile == true
	end

	return { refresh = refresh }
end

return Hud
