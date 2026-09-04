--!strict
--[[
	Widgets
	Small constructors for the handful of shapes this UI actually uses. Nothing
	clever -- it exists so window code reads as layout instead of forty lines of
	Instance.new per panel.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Widgets = {}

export type Props = { [string]: any }

--[[ Creates an instance, applies props, parents children. `Parent` is applied
     last so the instance is only shown once it is fully built. ]]
function Widgets.new(className: string, props: Props?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent: Instance? = nil

	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	instance.Parent = parent
	return instance
end

function Widgets.corner(radius: UDim?): UICorner
	return Widgets.new("UICorner", { CornerRadius = radius or Theme.Size.Corner })
end

function Widgets.stroke(color: Color3?, thickness: number?): UIStroke
	return Widgets.new("UIStroke", {
		Color = color or Theme.Color.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Widgets.padding(all: number?, overrides: Props?): UIPadding
	local value = UDim.new(0, all or Theme.Size.Gutter)
	local props: Props = {
		PaddingTop = value,
		PaddingBottom = value,
		PaddingLeft = value,
		PaddingRight = value,
	}
	if overrides then
		for key, override in overrides do
			props[key] = override
		end
	end
	return Widgets.new("UIPadding", props)
end

function Widgets.list(props: Props?): UIListLayout
	local base: Props = {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
	}
	if props then
		for key, value in props do
			base[key] = value
		end
	end
	return Widgets.new("UIListLayout", base)
end

function Widgets.label(props: Props): TextLabel
	local base: Props = {
		BackgroundTransparency = 1,
		Font = Theme.Font.Body,
		TextColor3 = Theme.Color.Text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = true,
	}
	for key, value in props do
		base[key] = value
	end
	return Widgets.new("TextLabel", base)
end

function Widgets.panel(props: Props?, children: { Instance }?): Frame
	local base: Props = {
		BackgroundColor3 = Theme.Color.PanelRaised,
		BorderSizePixel = 0,
	}
	if props then
		for key, value in props do
			base[key] = value
		end
	end
	local frame = Widgets.new("Frame", base, children)
	Widgets.corner().Parent = frame
	Widgets.stroke().Parent = frame
	return frame
end

--[[ A button with hover and press feedback. `onClick` may yield; it is wrapped
     so a slow server round trip cannot block input handling.

     Feedback is a translucent overlay rather than a tween of BackgroundColor3.
     Every window repaints its buttons on each state push, so anything that
     animated the colour itself would fight those repaints -- and would leave the
     hover shade stuck as the button's real colour if a repaint landed mid-tween. ]]
function Widgets.button(props: Props, onClick: (() -> ())?): TextButton
	local base: Props = {
		BackgroundColor3 = Theme.Color.Accent,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.Panel,
		TextSize = 15,
	}
	for key, value in props do
		base[key] = value
	end

	local button = Widgets.new("TextButton", base) :: TextButton
	Widgets.corner(Theme.Size.CornerSmall).Parent = button

	-- Active = false so the overlay never swallows the click meant for the button.
	local overlay = Widgets.new("Frame", {
		Name = "Feedback",
		Active = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = button,
	}) :: Frame
	Widgets.corner(Theme.Size.CornerSmall).Parent = overlay

	local function shade(color: Color3, transparency: number)
		overlay.BackgroundColor3 = color
		TweenService:Create(overlay, TweenInfo.new(0.12), { BackgroundTransparency = transparency }):Play()
	end

	button.MouseEnter:Connect(function()
		shade(Color3.new(1, 1, 1), 0.88)
	end)
	button.MouseLeave:Connect(function()
		shade(Color3.new(1, 1, 1), 1)
	end)
	button.MouseButton1Down:Connect(function()
		shade(Color3.new(0, 0, 0), 0.82)
	end)
	button.MouseButton1Up:Connect(function()
		shade(Color3.new(1, 1, 1), 0.88)
	end)

	if onClick then
		button.Activated:Connect(function()
			task.spawn(onClick)
		end)
	end

	return button
end

function Widgets.scroller(props: Props?): ScrollingFrame
	local base: Props = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Color.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	if props then
		for key, value in props do
			base[key] = value
		end
	end
	return Widgets.new("ScrollingFrame", base)
end

--[[ A thin progress bar. Returns the fill so callers can resize it. ]]
function Widgets.bar(props: Props, fillColor: Color3): (Frame, Frame)
	local track = Widgets.new("Frame", (function()
		local base: Props = {
			BackgroundColor3 = Theme.Color.PanelSunken,
			BorderSizePixel = 0,
		}
		for key, value in props do
			base[key] = value
		end
		return base
	end)()) :: Frame
	Widgets.corner(UDim.new(1, 0)).Parent = track

	local fill = Widgets.new("Frame", {
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}) :: Frame
	Widgets.corner(UDim.new(1, 0)).Parent = fill

	return track, fill
end

--[[ The shell every window shares: title bar, close button, scrolling body. ]]
export type Window = {
	root: Frame,
	body: ScrollingFrame,
	setSubtitle: (text: string) -> (),
	tabs: Frame,
}

function Widgets.window(title: string, subtitle: string, onClose: () -> ()): Window
	local root = Widgets.new("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 470),
		BackgroundColor3 = Theme.Color.Panel,
		BorderSizePixel = 0,
		Visible = false,
	}) :: Frame
	Widgets.corner(UDim.new(0, 14)).Parent = root
	Widgets.stroke(Theme.Color.Stroke, 1.5).Parent = root

	local header = Widgets.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 58),
		Parent = root,
	}) :: Frame
	Widgets.padding(14, { PaddingBottom = UDim.new(0, 0) }).Parent = header

	Widgets.label({
		Text = title,
		Font = Theme.Font.Heading,
		TextSize = 20,
		Size = UDim2.new(1, -46, 0, 24),
		Parent = header,
	})

	local subtitleLabel = Widgets.label({
		Text = subtitle,
		TextColor3 = Theme.Color.TextDim,
		TextSize = 13,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, -46, 0, 18),
		Parent = header,
	})

	Widgets.button({
		Text = "X",
		BackgroundColor3 = Theme.Color.PanelRaised,
		TextColor3 = Theme.Color.TextDim,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(32, 32),
		Parent = header,
	}, onClose)

	local tabs = Widgets.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 60),
		Size = UDim2.new(1, -28, 0, 0),
		Parent = root,
	}) :: Frame
	Widgets.list({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }).Parent = tabs

	local body = Widgets.scroller({
		Name = "Body",
		Position = UDim2.fromOffset(14, 66),
		Size = UDim2.new(1, -28, 1, -80),
		Parent = root,
	})
	Widgets.list().Parent = body

	return {
		root = root,
		body = body,
		tabs = tabs,
		setSubtitle = function(text: string)
			subtitleLabel.Text = text
		end,
	}
end

--[[ A standard shop row: icon swatch, name, description, and an action button. ]]
export type Row = {
	root: Frame,
	title: TextLabel,
	desc: TextLabel,
	action: TextButton,
	swatch: Frame,
}

function Widgets.row(order: number, parent: Instance): Row
	local root = Widgets.panel({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, Theme.Size.RowHeight),
		Parent = parent,
	})

	local swatch = Widgets.new("Frame", {
		BackgroundColor3 = Theme.Color.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 13),
		Size = UDim2.fromOffset(40, 40),
		Parent = root,
	}) :: Frame
	Widgets.corner(Theme.Size.CornerSmall).Parent = swatch

	local title = Widgets.label({
		Font = Theme.Font.Heading,
		TextSize = 15,
		Position = UDim2.fromOffset(64, 12),
		Size = UDim2.new(1, -220, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})

	local desc = Widgets.label({
		TextColor3 = Theme.Color.TextDim,
		TextSize = 12.5,
		Position = UDim2.fromOffset(64, 33),
		Size = UDim2.new(1, -220, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})

	local action = Widgets.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(132, 38),
		Text = "",
		Parent = root,
	})

	return { root = root, title = title, desc = desc, action = action, swatch = swatch }
end

--[[ Tab strip buttons that highlight the active tab. Returns a select function.
     Takes the whole window because adding tabs has to push the body down -- doing
     it here means no caller has to remember the offset. ]]
function Widgets.tabs(window: Window, names: { string }, onSelect: (string) -> ()): (string) -> ()
	local container = window.tabs
	container.Size = UDim2.new(1, -28, 0, 30)
	window.body.Position = UDim2.fromOffset(14, 100)
	window.body.Size = UDim2.new(1, -28, 1, -114)

	local buttons: { [string]: TextButton } = {}
	local function select(name: string)
		for key, button in buttons do
			local active = key == name
			button.BackgroundColor3 = if active then Theme.Color.Accent else Theme.Color.PanelRaised
			button.TextColor3 = if active then Theme.Color.Panel else Theme.Color.TextDim
		end
		onSelect(name)
	end

	for index, name in names do
		buttons[name] = Widgets.button({
			Text = name,
			LayoutOrder = index,
			Size = UDim2.fromOffset(110, 28),
			TextSize = 13,
			BackgroundColor3 = Theme.Color.PanelRaised,
			TextColor3 = Theme.Color.TextDim,
			Parent = container,
		}, function()
			select(name)
		end)
	end

	return select
end

function Widgets.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

return Widgets
