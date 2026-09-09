--!strict
--[[
	Feed

	A short list of what just happened to somebody else, top-right.

	Deliberately separate from the toast strip. Toasts are about *you* and appear
	centre-screen where you cannot miss them; the feed is about the server, sits out
	of the way, and can be ignored entirely. Mixing the two means either your own
	messages get lost in other people's news, or other people's news interrupts you.

	Bottom-right rather than top-right, which is where a news ticker wants to be but
	is also where Roblox puts the player list -- and a feed fighting the player list
	for the same corner is a feed nobody can read.

	Six lines, oldest dropped, newest nearest the corner. Nothing here is clickable
	and nothing demands a response -- it exists so the town feels inhabited.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Feed = {}

local MAX_LINES = 6
local LIFETIME = 22

local COLORS = {
	info = Theme.Color.TextDim,
	good = Theme.Color.Good,
	bad = Theme.Color.Bad,
	star = Theme.Color.Star,
}

local container: Frame? = nil
local lines: { Frame } = {}
local pushed = 0

function Feed.mount(parent: ScreenGui)
	container = Widgets.new("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(1, 1),
		-- Lifted clear of the nav row, which is centred but wide enough to reach
		-- into this corner on a narrow window.
		Position = UDim2.new(1, -14, 1, -96),
		Size = UDim2.fromOffset(320, 200),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Widgets.list({
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			-- Bottom-aligned so the stack grows upward out of the corner and the
			-- newest line is always in the same place.
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 4),
		}),
	})
end

function Feed.push(text: string, kind: string?)
	if not container or #text == 0 then
		return
	end

	local color = COLORS[kind or "info"] or Theme.Color.TextDim
	pushed += 1

	local frame = Widgets.new("Frame", {
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 26),
		-- Ascending, so the newest line sorts to the bottom of a bottom-aligned
		-- list without renumbering the ones already there.
		LayoutOrder = pushed,
		Parent = container,
	}) :: Frame
	Widgets.corner(Theme.Size.CornerSmall).Parent = frame

	local stripe = Widgets.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 3, 1, 0),
		Parent = frame,
	}) :: Frame
	Widgets.corner(Theme.Size.CornerSmall).Parent = stripe

	local label = Widgets.label({
		Text = text,
		TextColor3 = Theme.Color.Text,
		TextSize = 12.5,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(9, 0),
		Size = UDim2.new(1, -18, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	table.insert(lines, 1, frame)
	while #lines > MAX_LINES do
		local oldest = table.remove(lines)
		if oldest then
			oldest:Destroy()
		end
	end

	task.delay(LIFETIME, function()
		if not frame.Parent then
			return
		end
		local index = table.find(lines, frame)
		if index then
			table.remove(lines, index)
		end

		local fade = TweenInfo.new(0.5)
		TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stripe, fade, { BackgroundTransparency = 1 }):Play()

		task.delay(0.6, function()
			frame:Destroy()
		end)
	end)
end

return Feed
