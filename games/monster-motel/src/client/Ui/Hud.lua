--!strict
--[[
	Hud

	Wallet, the safe meter, the night clock, and the two things that need to shout:
	the Celebrity Arrival and the fact that you are currently carrying somebody
	else's guest across open ground.

	The night clock is the most important element on the screen. Everything a
	player does -- when to upgrade, when to go out, when to come home -- keys off
	how long is left, so it is large, central and never hidden behind a menu.

	The objective chip under the wallet is the other one that earns its space. This
	game is not self-explanatory: a new player spawns facing an empty building, a
	road of monsters they have to pay for, and a night cycle nobody warned them
	about. The chip gives them exactly one thing to do next, and it goes away for
	good once they have seen the whole loop.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Guests = require(Shared.Config.Guests)

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Hud = {}

--[[ Each tab carries its own colour. Seven identical slabs is the shape every
     generated interface lands on, and it also costs you the thing a nav bar is
     for: after a day of playing you should be reaching for the green one, not
     reading the labels. Store is the odd one out on purpose -- Robux green. ]]
local NAV = {
	{ id = "arrivals", label = "Arrivals", color = Color3.fromRGB(255, 138, 92) },
	{ id = "guests", label = "Guests", color = Color3.fromRGB(122, 176, 255) },
	{ id = "index", label = "Index", color = Color3.fromRGB(186, 132, 255) },
	{ id = "motel", label = "Motel", color = Color3.fromRGB(86, 216, 190) },
	{ id = "renovate", label = "Renovate", color = Color3.fromRGB(255, 202, 64) },
	{ id = "daily", label = "Daily", color = Color3.fromRGB(255, 122, 176) },
	{ id = "store", label = "Store", color = Color3.fromRGB(0, 196, 124) },
}

export type Handle = {
	refresh: (state: { [string]: any }) -> (),
	setBreakProgress: (elapsed: number, needed: number) -> (),
}

function Hud.build(parent: ScreenGui, openWindow: (string) -> ()): Handle
	-- ------------------------------------------------------------ wallet
	local wallet = Widgets.panel({
		Name = "Wallet",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(280, 168),
		BackgroundColor3 = Theme.Color.Panel,
		Parent = parent,
	})
	Widgets.padding(12).Parent = wallet

	--[[ Cash and Stars are chips rather than lines of text. They are the two
	     numbers a player checks constantly, and a chip gives each one a fixed
	     shape and a token that never moves, so the eye finds it without reading. ]]
	local cashPill = Widgets.pill({
		Size = UDim2.new(1, 0, 0, 46),
		Parent = wallet,
	}, Theme.Color.Cash, "$")
	local cash = cashPill.value

	local starPill = Widgets.pill({
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 34),
		Parent = wallet,
	}, Theme.Color.Star, "★")
	local stars = starPill.value

	local safeLabel = Widgets.label({
		Text = "Safe",
		TextSize = 12.5,
		TextColor3 = Theme.Color.TextDim,
		Position = UDim2.fromOffset(2, 92),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = wallet,
	})

	local _, safeFill = Widgets.bar({
		Position = UDim2.fromOffset(0, 112),
		Size = UDim2.new(1, 0, 0, 12),
		Parent = wallet,
	}, Theme.Color.Safe)

	local rentLabel = Widgets.label({
		Text = "$0/s",
		Font = Theme.Font.Heading,
		TextSize = 16,
		TextColor3 = Theme.Color.Cash,
		Position = UDim2.fromOffset(2, 128),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = wallet,
	})

	local roomsLabel = Widgets.label({
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.Color.TextFaint,
		Position = UDim2.fromOffset(2, 148),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = wallet,
	})

	-- ------------------------------------------------------------ objective
	local objective = Widgets.panel({
		Name = "Objective",
		Position = UDim2.fromOffset(14, 194),
		Size = UDim2.fromOffset(280, 80),
		BackgroundColor3 = Theme.Color.Panel,
		Visible = false,
		Parent = parent,
	})
	Widgets.padding(11).Parent = objective

	local objectiveStep = Widgets.label({
		Text = "",
		TextSize = 11,
		TextColor3 = Theme.Color.TextFaint,
		Size = UDim2.new(1, 0, 0, 14),
		Parent = objective,
	})

	local objectiveName = Widgets.label({
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = 14,
		TextColor3 = Theme.Color.Accent,
		Position = UDim2.fromOffset(0, 15),
		Size = UDim2.new(1, 0, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = objective,
	})

	local objectiveHint = Widgets.label({
		Text = "",
		TextSize = 11.5,
		TextColor3 = Theme.Color.TextDim,
		Position = UDim2.fromOffset(0, 33),
		Size = UDim2.new(1, 0, 0, 30),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = objective,
	})

	local _, objectiveFill = Widgets.bar({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 4),
		Parent = objective,
	}, Theme.Color.Accent)

	-- ------------------------------------------------------------ night clock
	local clock = Widgets.panel({
		Name = "Clock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(250, 62),
		BackgroundColor3 = Theme.Color.Panel,
		Parent = parent,
	})

	local phaseLabel = Widgets.label({
		Text = "DAY",
		Font = Theme.Font.Heading,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = clock,
	})

	local phaseTimer = Widgets.label({
		Text = "",
		TextSize = 14,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = clock,
	})

	local _, phaseFill = Widgets.bar({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Size = UDim2.new(1, -24, 0, 5),
		Parent = clock,
	}, Theme.Color.Night)

	-- ------------------------------------------------------------ celebrity
	local event = Widgets.panel({
		Name = "Celebrity",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(380, 52),
		BackgroundColor3 = Theme.Color.Panel,
		Visible = false,
		Parent = parent,
	})
	local eventTitle = Widgets.label({
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = 16,
		TextColor3 = Theme.Rarity.Celebrity,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 7),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = event,
	})
	local eventSub = Widgets.label({
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 27),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = event,
	})

	-- ------------------------------------------------------------ carrying
	local carrying = Widgets.panel({
		Name = "Carrying",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -128),
		Size = UDim2.fromOffset(420, 56),
		BackgroundColor3 = Theme.Color.Panel,
		Visible = false,
		Parent = parent,
	})
	local carryTitle = Widgets.label({
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = 17,
		TextColor3 = Theme.Color.Warn,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = carrying,
	})
	Widgets.label({
		Text = "Get to your own front desk. You are slowed while carrying.",
		TextSize = 12.5,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = carrying,
	})

	-- ------------------------------------------------------------ break bar
	local breaking = Widgets.panel({
		Name = "Breaking",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -190),
		Size = UDim2.fromOffset(320, 46),
		BackgroundColor3 = Theme.Color.Panel,
		Visible = false,
		Parent = parent,
	})
	local breakLabel = Widgets.label({
		Text = "Breaking in...",
		Font = Theme.Font.Heading,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = breaking,
	})
	local _, breakFill = Widgets.bar({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, 8),
		Parent = breaking,
	}, Theme.Color.Bad)

	-- ------------------------------------------------------------ warning
	local warning = Widgets.panel({
		Name = "Warning",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -78),
		Size = UDim2.fromOffset(430, 32),
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
		Size = UDim2.fromOffset(#NAV * 102, 52),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Widgets.list({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})

	for index, entry in NAV do
		Widgets.button({
			Text = entry.label,
			LayoutOrder = index,
			Size = UDim2.fromOffset(94, 52),
			TextSize = 16,
			BackgroundColor3 = entry.color,
			TextColor3 = Theme.Color.Ink,
			Parent = nav,
		}, function()
			openWindow(entry.id)
		end)
	end

	-- ------------------------------------------------------------ refresh
	local function refresh(state: { [string]: any })
		if state.cash == nil then
			return
		end

		cash.Text = `${Format.short(state.cash)}`
		stars.Text = Format.comma(state.stars or 0)

		local capacity = math.max(1, state.safeCapacity or 1)
		local held = state.safe or 0
		local ratio = math.clamp(held / capacity, 0, 1)
		safeFill.Size = UDim2.fromScale(ratio, 1)

		if state.autoCollect then
			safeFill.Size = UDim2.fromScale(1, 1)
			safeFill.BackgroundColor3 = Theme.Color.Good
			safeLabel.Text = `Safe  ·  <font color='{Theme.Hex.Good}'>Auto Collect</font>`
		else
			safeFill.BackgroundColor3 = if ratio >= 1 then Theme.Color.Warn else Theme.Color.Safe
			safeLabel.Text = `Safe  ${Format.short(held)} / ${Format.short(capacity)}`
				.. (if ratio >= 1 then `  ·  <font color='{Theme.Hex.Warn}'>FULL</font>` else "")
		end

		rentLabel.Text = `${Format.short(state.rentPerSecond or 0)}/s  ·  {Format.multiplier(state.rentMultiplier or 1)}`
		local renovations = (state.prestige or {}).renovations or 0
		roomsLabel.Text = `{state.housed or 0}/{state.capacity or 0} rooms  ·  {(state.motel or {}).ratingName or ""}`
			.. (if renovations > 0 then `  ·  {renovations} renovations` else "")

		-- Night clock
		local night = state.night or {}
		local isNight = night.night == true
		phaseLabel.Text = if isNight then "LIGHTS OUT" else "DAY"
		phaseLabel.TextColor3 = if isNight then Theme.Color.Bad else Theme.Color.Good
		phaseTimer.Text = if isNight
			then `Doors can be broken  ·  {Format.duration(night.secondsLeft or 0)} left`
			else `Everyone is sealed in  ·  {Format.duration(night.secondsLeft or 0)} to nightfall`

		local length = math.max(1, night.phaseLength or 1)
		phaseFill.Size = UDim2.fromScale(math.clamp((night.secondsLeft or 0) / length, 0, 1), 1)
		phaseFill.BackgroundColor3 = if isNight then Theme.Color.Bad else Theme.Color.Night

		-- Celebrity
		local eventState = state.event or {}
		if eventState.active then
			local guest = Guests.get(eventState.guest)
			event.Visible = true
			eventTitle.Text = if guest then string.upper(guest.name) else "CELEBRITY IN TOWN"
			if eventState.carriedBy then
				eventSub.Text = `{eventState.carriedBy} is carrying them. Catch them!`
			else
				eventSub.Text = `On the stage in the square  ·  {Format.duration(eventState.claimSecondsLeft or 0)} left`
			end
		else
			event.Visible = (eventState.nextEventIn or 0) > 0 and (eventState.nextEventIn or 0) < 60
			eventTitle.Text = "A CELEBRITY IS ARRIVING"
			eventSub.Text = `Get to the town square  ·  {Format.duration(eventState.nextEventIn or 0)}`
		end

		-- Carrying
		if state.carrying then
			local guest = Guests.get(state.carrying)
			carrying.Visible = true
			carryTitle.Text = `CARRYING {if guest then string.upper(guest.name) else "A GUEST"}`
		else
			carrying.Visible = false
		end

		-- Objective chip. Absent once the list is finished, which is the point --
		-- it stops giving instructions rather than inventing errands forever.
		local goal = state.objective
		if goal then
			objective.Visible = true
			objectiveStep.Text = `NEXT  ·  {goal.index}/{goal.total}`
			objectiveName.Text = goal.name
			objectiveHint.Text = goal.hint
			objectiveFill.Size = UDim2.fromScale(
				math.clamp((goal.progress or 0) / math.max(1, goal.target or 1), 0, 1),
				1
			)
		else
			objective.Visible = false
		end

		warning.Visible = state.volatile == true
	end

	local function setBreakProgress(elapsed: number, needed: number)
		if needed <= 0 then
			breaking.Visible = false
			return
		end
		breaking.Visible = true
		breakFill.Size = UDim2.fromScale(math.clamp(elapsed / needed, 0, 1), 1)
		breakLabel.Text = `Breaking in...  {string.format("%.1f", math.max(0, needed - elapsed))}s`
	end

	return { refresh = refresh, setBreakProgress = setBreakProgress }
end

return Hud
