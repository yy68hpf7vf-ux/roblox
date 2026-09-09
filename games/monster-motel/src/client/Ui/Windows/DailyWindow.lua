--!strict
--[[
	DailyWindow
	Daily login, playtime ladder, today's quests, and the code box.

	Deliberately missing from this screen: any countdown telling you what you are
	about to lose. The daily reward says when the next one is available and the
	streak explains its own grace period, because a player who understands the
	system comes back on purpose.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local Actions = require(script.Parent.Parent.Parent.Actions)
local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local DailyWindow = {}

function DailyWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Daily", "Rewards for showing up and for sticking around.", close)
	window.root.Parent = parent

	-- ------------------------------------------------------------ login
	local login = Widgets.panel({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 96), Parent = window.body })
	Widgets.padding(12).Parent = login

	local loginTitle = Widgets.label({
		Text = "Daily reward",
		Font = Theme.Font.Heading,
		TextSize = 16,
		Size = UDim2.new(1, -160, 0, 20),
		Parent = login,
	})

	local loginDetail = Widgets.label({
		Text = "",
		TextColor3 = Theme.Color.TextDim,
		TextSize = 12.5,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -160, 0, 44),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = login,
	})

	local loginButton = Widgets.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(140, 42),
		Parent = login,
	}, function()
		Actions.invoke("claimDaily")
	end)

	-- ------------------------------------------------------------ playtime
	local playtime = Widgets.panel({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 96), Parent = window.body })
	Widgets.padding(12).Parent = playtime

	Widgets.label({
		Text = "Playtime today",
		Font = Theme.Font.Heading,
		TextSize = 16,
		Size = UDim2.new(1, -160, 0, 20),
		Parent = playtime,
	})

	local playDetail = Widgets.label({
		Text = "",
		TextColor3 = Theme.Color.TextDim,
		TextSize = 12.5,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -160, 0, 26),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = playtime,
	})

	local _, playFill = Widgets.bar({
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, -160, 0, 8),
		Parent = playtime,
	}, Theme.Color.Accent)

	local playButton = Widgets.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(140, 42),
		Parent = playtime,
	}, function()
		Actions.invoke("claimPlaytime")
	end)

	-- ------------------------------------------------------------ quests
	Widgets.label({
		LayoutOrder = 2,
		Text = "Today's quests",
		Font = Theme.Font.Heading,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = window.body,
	})

	local questList = Widgets.new("Frame", {
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = window.body,
	}) :: Frame
	Widgets.list().Parent = questList

	-- ------------------------------------------------------------ codes
	local codes = Widgets.panel({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 76), Parent = window.body })
	Widgets.padding(12).Parent = codes

	Widgets.label({
		Text = "Redeem a code",
		Font = Theme.Font.Heading,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = codes,
	})

	local codeBox = Widgets.new("TextBox", {
		BackgroundColor3 = Theme.Color.PanelSunken,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Theme.Font.Mono,
		PlaceholderText = "Type a code",
		PlaceholderColor3 = Theme.Color.TextFaint,
		Text = "",
		TextColor3 = Theme.Color.Text,
		TextSize = 14,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -120, 0, 34),
		Parent = codes,
	}) :: TextBox
	Widgets.corner(Theme.Size.CornerSmall).Parent = codeBox
	Widgets.padding(8, { PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 0) }).Parent = codeBox

	local function submitCode()
		local text = codeBox.Text
		if #text == 0 then
			return
		end
		codeBox.Text = ""
		Actions.invoke("redeemCode", { code = text })
	end

	Widgets.button({
		Text = "Redeem",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 24),
		Size = UDim2.fromOffset(110, 34),
		Parent = codes,
	}, submitCode)

	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submitCode()
		end
	end)

	-- ------------------------------------------------------------ refresh
	local questRows: { [string]: Widgets.Row } = {}

	local function refresh(state)
		local daily = state.daily or {}
		loginTitle.Text = `Daily reward  ·  {daily.label or "Day 1"}`
		if daily.available then
			loginDetail.Text = `Streak {daily.streak or 0} -> {daily.nextStreak or 1}.`
				.. `\nWorth {Format.short(daily.cash or 0)}`
				.. (if (daily.stars or 0) > 0 then ` and {daily.stars} Stars.` else ".")
			loginButton.Text = "Claim"
			loginButton.BackgroundColor3 = Theme.Color.Good
			loginButton.TextColor3 = Theme.Color.Ink
		else
			loginDetail.Text = `Claimed today. Streak is {daily.streak or 0}.`
				.. "\nMiss a day and the streak survives; miss two and it restarts."
			loginButton.Text = "Back tomorrow"
			loginButton.BackgroundColor3 = Theme.Color.PanelRaised
			loginButton.TextColor3 = Theme.Color.TextFaint
		end

		local play = state.playtime or {}
		local interval = play.interval or 300
		local claimed = play.claimed or 0
		local total = play.total or 12

		playFill.Size = UDim2.fromScale(math.clamp(claimed / total, 0, 1), 1)

		if play.finished then
			playDetail.Text = `All {total} playtime rewards collected today. Come back tomorrow.`
			playButton.Text = "All done"
			playButton.BackgroundColor3 = Theme.Color.PanelRaised
			playButton.TextColor3 = Theme.Color.TextFaint
		elseif play.canClaim then
			playDetail.Text = `{claimed}/{total} collected. Next up: {play.nextLabel} for ${Format.short(play.nextCash or 0)}.`
			playButton.Text = "Claim"
			playButton.BackgroundColor3 = Theme.Color.Good
			playButton.TextColor3 = Theme.Color.Ink
		else
			local into = (play.seconds or 0) % interval
			playDetail.Text = `{claimed}/{total} collected. Next reward in {Format.duration(interval - into)}.`
			playButton.Text = "Not yet"
			playButton.BackgroundColor3 = Theme.Color.PanelRaised
			playButton.TextColor3 = Theme.Color.TextFaint
		end

		for index, quest in state.quests or {} do
			local row = questRows[quest.id]
			if not row then
				row = Widgets.row(index, questList)
				row.swatch.BackgroundColor3 = Theme.Color.Accent
				questRows[quest.id] = row
				row.action.Activated:Connect(function()
					Actions.invoke("claimQuest", { id = quest.id })
				end)
			end

			row.title.Text = quest.name
			row.desc.Text = `{Format.short(quest.progress)} / {Format.short(quest.target)}  ·  pays ${Format.short(quest.reward)}`

			if quest.claimed then
				row.action.Text = "Claimed"
				row.action.BackgroundColor3 = Theme.Color.PanelRaised
				row.action.TextColor3 = Theme.Color.Good
			elseif quest.complete then
				row.action.Text = "Claim"
				row.action.BackgroundColor3 = Theme.Color.Good
				row.action.TextColor3 = Theme.Color.Ink
			else
				row.action.Text = `{math.floor((quest.progress / math.max(1, quest.target)) * 100)}%`
				row.action.BackgroundColor3 = Theme.Color.PanelRaised
				row.action.TextColor3 = Theme.Color.TextFaint
			end
		end
	end

	return { root = window.root, refresh = refresh }
end

return DailyWindow
