--!strict
--[[
	Toast
	The message strip in the top-centre of the screen. Newest at the top, four at
	a time, each one fading out on its own timer.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Toast = {}

local MAX_VISIBLE = 4
local LIFETIME = 3.4

local container: Frame? = nil
local active: { Frame } = {}

local COLORS = {
	info = Theme.Color.Accent,
	good = Theme.Color.Good,
	warn = Theme.Color.Warn,
	bad = Theme.Color.Bad,
}

function Toast.mount(parent: ScreenGui)
	container = Widgets.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(400, 200),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Widgets.list({ HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }),
	})
end

function Toast.push(message: string, kind: string?)
	if not container or #message == 0 then
		return
	end

	local color = COLORS[kind or "info"] or Theme.Color.Accent

	local frame = Widgets.new("Frame", {
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = container,
	}) :: Frame
	Widgets.corner(Theme.Size.CornerSmall).Parent = frame
	Widgets.stroke(color, 1.2).Parent = frame

	local label = Widgets.label({
		Text = message,
		TextColor3 = Theme.Color.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	table.insert(active, 1, frame)
	frame.LayoutOrder = -os.clock() * 1000

	-- Retire the oldest rather than letting a burst of messages fill the screen.
	while #active > MAX_VISIBLE do
		local oldest = table.remove(active)
		if oldest then
			oldest:Destroy()
		end
	end

	task.delay(LIFETIME, function()
		if not frame.Parent then
			return
		end
		local index = table.find(active, frame)
		if index then
			table.remove(active, index)
		end

		local fade = TweenInfo.new(0.25)
		TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		end

		task.delay(0.3, function()
			frame:Destroy()
		end)
	end)
end

return Toast
