--!strict
--[[
	Theme

	One palette and one type scale. Every window reads from here, so the look of
	the whole game is this file plus Widgets.lua.

	The direction is a motel sign at night: deep purple dark, hot pink neon, acid
	green for money, gold for stars. Everything is outlined in Ink -- a black with
	purple in it, never a pure #000 -- because the heavy cartoon outline is the
	single thing that separates a Roblox game's interface from a settings screen.

	Two rules worth keeping if you retune this:

	  1. Saturated beats tasteful. Muted greys read as a dev tool. This is a game
	     about monsters robbing each other; it should look like one.
	  2. Every bright surface gets an Ink outline and a top-down gradient. Flat
	     rectangles on flat rectangles is what makes an interface look generated.
]]

local Theme = {}

Theme.Color = {
	--[[ The outline colour, and the text colour on any bright surface. Purple-black
	     rather than pure black so it sits in the palette instead of on top of it. ]]
	Ink = Color3.fromRGB(20, 12, 38),

	Panel = Color3.fromRGB(48, 30, 86),
	PanelRaised = Color3.fromRGB(72, 48, 122),
	PanelSunken = Color3.fromRGB(32, 19, 60),

	-- Kept for callers that ask for a border colour by name.
	Stroke = Color3.fromRGB(20, 12, 38),

	Text = Color3.fromRGB(255, 252, 248),
	TextDim = Color3.fromRGB(198, 180, 234),
	TextFaint = Color3.fromRGB(142, 122, 184),

	-- Neon sign pink. The colour the eye should land on first, so it is used for
	-- the one action a screen most wants you to take and nothing else.
	Accent = Color3.fromRGB(255, 88, 168),
	AccentDeep = Color3.fromRGB(198, 40, 122),

	Cash = Color3.fromRGB(86, 240, 148),
	CashDeep = Color3.fromRGB(28, 172, 94),
	Star = Color3.fromRGB(255, 202, 64),
	StarDeep = Color3.fromRGB(214, 146, 18),
	Safe = Color3.fromRGB(112, 200, 255),
	Night = Color3.fromRGB(158, 138, 255),

	Good = Color3.fromRGB(86, 240, 148),
	Warn = Color3.fromRGB(255, 178, 72),
	Bad = Color3.fromRGB(255, 88, 108),
	Locked = Color3.fromRGB(88, 74, 122),

	Robux = Color3.fromRGB(0, 176, 111),
}

Theme.Font = {
	--[[ Comic-book caps for the few things that should shout: window titles, the
	     cash counter, a celebrity landing. Bangers has no lowercase worth reading
	     at small sizes, so it is deliberately not the heading font. ]]
	Display = Enum.Font.Bangers,
	-- The workhorse. Round, heavy, and the house style of this whole genre.
	Heading = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
	Mono = Enum.Font.Code,
}

Theme.Size = {
	-- Fat corners. Tight radii read as "software".
	Corner = UDim.new(0, 16),
	CornerSmall = UDim.new(0, 10),
	Gutter = 12,
	RowHeight = 72,

	-- The cartoon outline. One number, so the whole interface stays consistent.
	Outline = 3,
	OutlineThin = 2,
}

Theme.Rarity = {
	Common = Color3.fromRGB(196, 200, 214),
	Uncommon = Color3.fromRGB(124, 226, 132),
	Rare = Color3.fromRGB(96, 176, 255),
	Epic = Color3.fromRGB(198, 120, 255),
	Legendary = Color3.fromRGB(255, 190, 72),
	Mythic = Color3.fromRGB(255, 88, 140),
	Celebrity = Color3.fromRGB(255, 240, 150),
	Signature = Color3.fromRGB(255, 138, 216),
}

--[[ The top-down sheen every raised surface gets. This is a UIGradient tint, so
     it multiplies whatever BackgroundColor3 the caller set -- which means a
     button repainted green on Tuesday still has the same lighting as one
     repainted pink, and a repaint can never fight the gradient. ]]
Theme.Sheen = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(238, 238, 238)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 196, 196)),
})

-- Stronger version for buttons, which should look like something you can push.
Theme.SheenStrong = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.48, Color3.fromRGB(242, 242, 242)),
	ColorSequenceKeypoint.new(0.52, Color3.fromRGB(214, 214, 214)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 168, 168)),
})

--[[ The same colours as hex strings, for RichText <font color='#...'> runs,
     which take a string and cannot take a Color3. Kept here so a palette change
     is still one file rather than a hunt through fourteen format strings. ]]
Theme.Hex = {
	Text = `#{Theme.Color.Text:ToHex()}`,
	TextDim = `#{Theme.Color.TextDim:ToHex()}`,
	TextFaint = `#{Theme.Color.TextFaint:ToHex()}`,
	Good = `#{Theme.Color.Good:ToHex()}`,
	Warn = `#{Theme.Color.Warn:ToHex()}`,
	Bad = `#{Theme.Color.Bad:ToHex()}`,
	Cash = `#{Theme.Color.Cash:ToHex()}`,
	Star = `#{Theme.Color.Star:ToHex()}`,
}

return Theme
