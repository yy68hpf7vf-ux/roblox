--!strict
--[[
	Tools (pickaxes)

	`power` is damage per swing against a node's health. Swing speed is a fixed
	constant for every player (GameConfig.SwingCooldown) so that no purchase --
	Robux or otherwise -- makes another player's clicks worth less than yours.
	Progression here is bought with Crystals only.
]]

export type Tool = {
	id: string,
	name: string,
	desc: string,
	price: number,
	power: number,
	rebirths: number,
	color: Color3,
}

local Tools = {}

Tools.List = {
	{
		id = "rusty",
		name = "Rusty Pick",
		desc = "It has seen things. It has chipped on most of them.",
		price = 0,
		power = 1,
		rebirths = 0,
		color = Color3.fromRGB(129, 110, 92),
	},
	{
		id = "copper",
		name = "Copper Pick",
		desc = "Soft, warm, and three times better than nothing.",
		price = 150,
		power = 3,
		rebirths = 0,
		color = Color3.fromRGB(196, 118, 68),
	},
	{
		id = "iron",
		name = "Iron Pick",
		desc = "The first pick that feels like a tool instead of a stick.",
		price = 4000,
		power = 8,
		rebirths = 0,
		color = Color3.fromRGB(150, 156, 166),
	},
	{
		id = "steel",
		name = "Steel Pick",
		desc = "Holds an edge through a whole cavern.",
		price = 40000,
		power = 20,
		rebirths = 0,
		color = Color3.fromRGB(188, 196, 208),
	},
	{
		id = "crystal",
		name = "Crystal Pick",
		desc = "Cuts crystal with crystal. Nobody has explained why that works.",
		price = 400000,
		power = 55,
		rebirths = 0,
		color = Color3.fromRGB(120, 214, 232),
	},
	{
		id = "obsidian",
		name = "Obsidian Pick",
		desc = "Volcanic glass, honed to something unreasonable.",
		price = 4800000,
		power = 150,
		rebirths = 0,
		color = Color3.fromRGB(52, 44, 66),
	},
	{
		id = "prism",
		name = "Prism Pick",
		desc = "Splits a node into every colour it was hiding.",
		price = 60000000,
		power = 420,
		rebirths = 0,
		color = Color3.fromRGB(232, 140, 224),
	},
	{
		id = "void",
		name = "Void Pick",
		desc = "Swings quietly. Everything else gets loud.",
		price = 780000000,
		power = 1200,
		rebirths = 1,
		color = Color3.fromRGB(84, 58, 140),
	},
	{
		id = "nova",
		name = "Nova Pick",
		desc = "Carries a very small, very cooperative star.",
		price = 10500000000,
		power = 3500,
		rebirths = 2,
		color = Color3.fromRGB(255, 176, 74),
	},
	{
		id = "quantum",
		name = "Quantum Pick",
		desc = "Hits the node before and after you swing it.",
		price = 155000000000,
		power = 10000,
		rebirths = 3,
		color = Color3.fromRGB(96, 236, 190),
	},
	{
		id = "singularity",
		name = "Singularity Pick",
		desc = "The node falls toward the pick. Considerate of it.",
		price = 1600000000000,
		power = 30000,
		rebirths = 6,
		color = Color3.fromRGB(46, 62, 120),
	},
	{
		id = "riftbreaker",
		name = "Riftbreaker",
		desc = "The last pick. There is nothing left to upgrade to, and that is the point.",
		price = 17000000000000,
		power = 95000,
		rebirths = 10,
		color = Color3.fromRGB(255, 96, 132),
	},
} :: { Tool }

Tools.ById = {} :: { [string]: Tool }
Tools.OrderById = {} :: { [string]: number }

for index, tool in Tools.List do
	Tools.ById[tool.id] = tool
	Tools.OrderById[tool.id] = index
end

Tools.Starter = Tools.List[1].id

--[[ Returns the tool a player is holding, falling back to the starter pick if
     their saved id refers to a tool that no longer exists. ]]
function Tools.get(id: string?): Tool
	if id and Tools.ById[id] then
		return Tools.ById[id]
	end
	return Tools.ById[Tools.Starter]
end

function Tools.isOwned(owned: { [string]: boolean }, id: string): boolean
	return id == Tools.Starter or owned[id] == true
end

return Tools
