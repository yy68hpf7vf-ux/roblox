--!strict
--[[
	Theme
	One palette and one type scale. Every window reads from here so a colour change
	is a one-line edit rather than a search across eight files.
]]

local Theme = {}

Theme.Color = {
	Panel = Color3.fromRGB(24, 26, 34),
	PanelRaised = Color3.fromRGB(33, 36, 46),
	PanelSunken = Color3.fromRGB(18, 20, 26),
	Stroke = Color3.fromRGB(52, 57, 72),

	Text = Color3.fromRGB(236, 240, 246),
	TextDim = Color3.fromRGB(158, 166, 182),
	TextFaint = Color3.fromRGB(112, 120, 136),

	Accent = Color3.fromRGB(120, 214, 232),
	Crystal = Color3.fromRGB(132, 220, 240),
	Core = Color3.fromRGB(255, 186, 74),
	Ore = Color3.fromRGB(180, 190, 206),

	Good = Color3.fromRGB(96, 220, 138),
	Warn = Color3.fromRGB(255, 176, 92),
	Bad = Color3.fromRGB(255, 108, 116),
	Locked = Color3.fromRGB(74, 80, 96),

	Robux = Color3.fromRGB(126, 217, 138),
}

Theme.Font = {
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.Gotham,
	Mono = Enum.Font.Code,
}

Theme.Size = {
	Corner = UDim.new(0, 10),
	CornerSmall = UDim.new(0, 6),
	Gutter = 10,
	RowHeight = 66,
}

Theme.Rarity = {
	Common = Color3.fromRGB(170, 178, 186),
	Uncommon = Color3.fromRGB(118, 206, 120),
	Rare = Color3.fromRGB(96, 168, 255),
	Epic = Color3.fromRGB(188, 116, 246),
	Legendary = Color3.fromRGB(255, 186, 74),
	Mythic = Color3.fromRGB(255, 96, 132),
}

return Theme
