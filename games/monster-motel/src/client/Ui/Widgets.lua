--!strict
--[[
	Widgets
	Deliberately the same widget layer as the Rift Miner project -- each game is
	its own Rojo build, so they keep their own copies rather than sharing a folder
	neither could resolve.

	Small constructors for the handful of shapes this UI actually uses. Nothing
	clever -- it exists so window code reads as layout instead of forty lines of
	Instance.new per panel.

	It is also where the game's look lives. Every raised surface gets three things
	here and nowhere else: a fat Ink outline, a top-down gradient, and a corner
	radius you could sit on. Because every window builds through these functions,
	restyling the whole interface is this file and Theme.lua -- no window code
	knows what a border looks like.
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
		Color = color or Theme.Color.Ink,
		Thickness = thickness or Theme.Size.Outline,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

--[[ A vertical tint. UIGradient multiplies the instance's own BackgroundColor3,
     which is the whole reason this works here: windows repaint their buttons on
     every state push, and a gradient that multiplies survives a repaint where a
     second hard-coded colour would be overwritten by it. ]]
function Widgets.gradient(sequence: ColorSequence?): UIGradient
	return Widgets.new("UIGradient", {
		Color = sequence or Theme.Sheen,
		Rotation = 90,
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

--[[ Heading and display text gets an Ink outline; body text does not, because a
     stroke on 12px copy just fills in the letters. Applied by looking at the font
     the caller asked for, so no window has to remember the rule. ]]
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

	local label = Widgets.new("TextLabel", base) :: TextLabel
	if base.Font == Theme.Font.Display or base.Font == Theme.Font.Heading then
		Widgets.new("UIStroke", {
			Color = Theme.Color.Ink,
			Thickness = if base.Font == Theme.Font.Display then 2.5 else 1.8,
			-- Contextual so the outline follows the glyphs, not the label box.
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = label,
		})
	end
	return label
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
	Widgets.gradient().Parent = frame
	return frame
end

--[[ A button that looks like something you could push: fat Ink outline, top-down
     gradient, and a scale-down on press.

     Two decisions worth keeping.

     The press uses a UIScale rather than nudging Position or Size. Half these
     buttons are positioned by a UIListLayout and half are placed by hand, and a
     UIScale is the only one of the three that behaves identically under both --
     it also cannot be clobbered by a caller that sets Size on every repaint.

     The tint is a translucent overlay rather than a tween of BackgroundColor3.
     Every window repaints its buttons on each state push, so anything animating
     the colour itself would fight those repaints, and would leave the hover shade
     stuck as the button's real colour if a repaint landed mid-tween. ]]
function Widgets.button(props: Props, onClick: (() -> ())?): TextButton
	local base: Props = {
		BackgroundColor3 = Theme.Color.Accent,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.Ink,
		TextSize = 16,
	}
	for key, value in props do
		base[key] = value
	end

	local button = Widgets.new("TextButton", base) :: TextButton
	Widgets.corner(Theme.Size.CornerSmall).Parent = button
	Widgets.stroke(Theme.Color.Ink, Theme.Size.Outline).Parent = button
	Widgets.gradient(Theme.SheenStrong).Parent = button

	local scale = Widgets.new("UIScale", { Scale = 1, Parent = button }) :: UIScale

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

	local function press(down: boolean)
		local info = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(scale, info, { Scale = if down then 0.94 else 1 }):Play()
	end

	button.MouseEnter:Connect(function()
		shade(Color3.new(1, 1, 1), 0.86)
	end)
	button.MouseLeave:Connect(function()
		shade(Color3.new(1, 1, 1), 1)
		press(false)
	end)
	button.MouseButton1Down:Connect(function()
		shade(Color3.new(0, 0, 0), 0.8)
		press(true)
	end)
	button.MouseButton1Up:Connect(function()
		shade(Color3.new(1, 1, 1), 0.86)
		press(false)
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
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.Accent,
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
	Widgets.stroke(Theme.Color.Ink, Theme.Size.OutlineThin).Parent = track

	local fill = Widgets.new("Frame", {
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	}) :: Frame
	Widgets.corner(UDim.new(1, 0)).Parent = fill
	Widgets.gradient().Parent = fill

	return track, fill
end

--[[ A currency chip: round token on the left, big value on the right.

     This is the shape the genre uses for money and it is worth copying exactly,
     because it does something a text label cannot -- the token is a constant
     visual anchor, so a number changing reads as *your money going up* rather
     than as text being replaced. Returns the value label for the caller to set. ]]
export type Pill = { root: Frame, value: TextLabel, token: Frame }

function Widgets.pill(props: Props, color: Color3, glyph: string): Pill
	local base: Props = {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44),
	}
	for key, value in props do
		base[key] = value
	end

	local root = Widgets.new("Frame", base) :: Frame
	Widgets.corner(UDim.new(1, 0)).Parent = root
	Widgets.stroke(Theme.Color.Ink, Theme.Size.Outline).Parent = root
	Widgets.gradient().Parent = root

	-- The token and the type scale off the chip's pixel height, so a caller that
	-- sizes one purely in scale would get a zero-height token. Guarded rather than
	-- typed away, since a chip is only ever a fixed height in practice.
	local height = math.max(24, base.Size.Y.Offset)
	local inset = math.floor(height * 0.12)
	local tokenSize = height - inset * 2

	local token = Widgets.new("Frame", {
		Name = "Token",
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.fromOffset(tokenSize, tokenSize),
		Parent = root,
	}) :: Frame
	Widgets.corner(UDim.new(1, 0)).Parent = token

	Widgets.label({
		Text = glyph,
		Font = Theme.Font.Heading,
		TextSize = math.floor(tokenSize * 0.6),
		TextColor3 = Theme.Color.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = token,
	})

	local value = Widgets.label({
		Text = "",
		Font = Theme.Font.Display,
		TextSize = math.floor(height * 0.62),
		TextColor3 = Theme.Color.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(inset * 2 + tokenSize, 0),
		Size = UDim2.new(1, -(inset * 3 + tokenSize), 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})

	return { root = root, value = value, token = token }
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
	Widgets.corner(UDim.new(0, 20)).Parent = root
	Widgets.stroke(Theme.Color.Ink, 4).Parent = root
	Widgets.gradient().Parent = root

	--[[ A solid accent band behind the title rather than a title floating on the
	     panel. It gives the window a top edge, and it is the cheapest way to stop
	     seven windows in the same shell reading as seven copies of one screen. ]]
	local header = Widgets.new("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.Color.PanelSunken,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 66),
		Parent = root,
	}) :: Frame
	Widgets.corner(UDim.new(0, 20)).Parent = header
	Widgets.gradient().Parent = header

	-- Squares off the band's bottom corners so it reads as a bar, not a pill.
	Widgets.new("Frame", {
		BackgroundColor3 = Theme.Color.PanelSunken,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = header,
	})

	Widgets.new("Frame", {
		Name = "Underline",
		BackgroundColor3 = Theme.Color.Accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 3),
		Parent = header,
	})

	Widgets.label({
		Text = title,
		Font = Theme.Font.Display,
		TextSize = 30,
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -70, 0, 30),
		Parent = header,
	})

	local subtitleLabel = Widgets.label({
		Text = subtitle,
		TextColor3 = Theme.Color.TextDim,
		TextSize = 13,
		Position = UDim2.fromOffset(18, 38),
		Size = UDim2.new(1, -70, 0, 18),
		Parent = header,
	})

	Widgets.button({
		Text = "X",
		BackgroundColor3 = Theme.Color.Bad,
		TextColor3 = Theme.Color.Text,
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(38, 38),
		Parent = header,
	}, onClose)

	local tabs = Widgets.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 74),
		Size = UDim2.new(1, -28, 0, 0),
		Parent = root,
	}) :: Frame
	Widgets.list({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }).Parent = tabs

	local body = Widgets.scroller({
		Name = "Body",
		Position = UDim2.fromOffset(14, 76),
		Size = UDim2.new(1, -28, 1, -90),
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

	-- The swatch carries the row's colour, so it gets the same outline treatment
	-- as a button. A flat square of colour is what a mockup looks like.
	local swatch = Widgets.new("Frame", {
		BackgroundColor3 = Theme.Color.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(13, 13),
		Size = UDim2.fromOffset(46, 46),
		Parent = root,
	}) :: Frame
	Widgets.corner(Theme.Size.CornerSmall).Parent = swatch
	Widgets.stroke(Theme.Color.Ink, Theme.Size.OutlineThin).Parent = swatch
	Widgets.gradient().Parent = swatch

	local title = Widgets.label({
		Font = Theme.Font.Heading,
		TextSize = 17,
		Position = UDim2.fromOffset(70, 13),
		Size = UDim2.new(1, -224, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})

	local desc = Widgets.label({
		TextColor3 = Theme.Color.TextDim,
		TextSize = 13,
		Position = UDim2.fromOffset(70, 36),
		Size = UDim2.new(1, -224, 0, 24),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})

	local action = Widgets.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -13, 0.5, 0),
		Size = UDim2.fromOffset(136, 42),
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
	container.Size = UDim2.new(1, -28, 0, 34)
	window.body.Position = UDim2.fromOffset(14, 116)
	window.body.Size = UDim2.new(1, -28, 1, -130)

	local buttons: { [string]: TextButton } = {}
	local function select(name: string)
		for key, button in buttons do
			local active = key == name
			button.BackgroundColor3 = if active then Theme.Color.Accent else Theme.Color.PanelRaised
			button.TextColor3 = if active then Theme.Color.Ink else Theme.Color.TextDim
		end
		onSelect(name)
	end

	for index, name in names do
		buttons[name] = Widgets.button({
			Text = name,
			LayoutOrder = index,
			Size = UDim2.fromOffset(112, 34),
			TextSize = 15,
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
