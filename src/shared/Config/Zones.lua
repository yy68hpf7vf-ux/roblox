--!strict
--[[
	Zones

	Each zone is an island with its own seam. The economy model is deliberately
	small so it can be reasoned about instead of guessed at:

	    ore per swing  = tool.power * zone.orePerPower * yieldUpgrade
	    crystals       = ore * zone.oreValue * sellMultiplier
	    trip length    = backpack capacity / ore per second

	`orePerPower` is held at 0.6 across the map on purpose. It means a zone never
	makes your pick feel worse than it did in the last one -- deeper zones pay more
	because `oreValue` climbs, not because the rock got stingy. Node health is
	tuned to the pick a player is expected to arrive with, so a node breaks roughly
	every five swings anywhere in the game and the rhythm stays the same.

	Unlock costs are set so that a zone, plus the pick and backpack a player buys
	on the way to it, is about eleven minutes of play on a first run -- and much
	less on every run after a rebirth. `tools/balance.py` simulates this against
	the real config; docs/BALANCE.md has its current output.

	Only the VIP Vault is attached to a gamepass. It sits between Voidshelf and
	Nova Reach in value, so it is a shortcut for people who buy it and never a wall
	for people who don't -- and Nova Reach overtakes it shortly after.
]]

export type Zone = {
	id: string,
	name: string,
	desc: string,
	unlockCost: number,
	rebirths: number,
	gamepass: string?,
	-- Crystals per ore, before multipliers. This is the progression curve.
	oreValue: number,
	-- Ore per point of tool power per swing.
	orePerPower: number,
	-- Tool power a node absorbs before it breaks and respawns.
	nodeHealth: number,
	nodeCount: number,
	origin: Vector3,
	groundColor: Color3,
	nodeColor: Color3,
}

local Zones = {}

-- Islands sit in a line so the walk between them reads as progress.
local SPACING = 460

Zones.List = {
	{
		id = "hollow",
		name = "Green Hollow",
		desc = "Soft rock, good light, nothing that bites. Everyone starts here.",
		unlockCost = 0,
		rebirths = 0,
		gamepass = nil,
		oreValue = 1,
		orePerPower = 0.6,
		nodeHealth = 5,
		nodeCount = 26,
		origin = Vector3.new(0, 0, 0),
		groundColor = Color3.fromRGB(106, 152, 92),
		nodeColor = Color3.fromRGB(140, 216, 132),
	},
	{
		id = "amber",
		name = "Amber Cavern",
		desc = "Fossil light in the walls. Warmer, denser, worth four times as much.",
		unlockCost = 750,
		rebirths = 0,
		gamepass = nil,
		oreValue = 4,
		orePerPower = 0.6,
		nodeHealth = 15,
		nodeCount = 26,
		origin = Vector3.new(SPACING, 0, 0),
		groundColor = Color3.fromRGB(154, 118, 72),
		nodeColor = Color3.fromRGB(240, 176, 88),
	},
	{
		id = "frost",
		name = "Frostline",
		desc = "The rock rings when you hit it. Bring a coat you don't mind chipping.",
		unlockCost = 12000,
		rebirths = 0,
		gamepass = nil,
		oreValue = 15,
		orePerPower = 0.6,
		nodeHealth = 40,
		nodeCount = 24,
		origin = Vector3.new(SPACING * 2, 0, 0),
		groundColor = Color3.fromRGB(178, 202, 216),
		nodeColor = Color3.fromRGB(150, 224, 240),
	},
	{
		id = "ember",
		name = "Emberdeep",
		desc = "Everything down here glows a little. Including, eventually, you.",
		unlockCost = 120000,
		rebirths = 0,
		gamepass = nil,
		oreValue = 60,
		orePerPower = 0.6,
		nodeHealth = 100,
		nodeCount = 24,
		origin = Vector3.new(SPACING * 3, 0, 0),
		groundColor = Color3.fromRGB(122, 74, 62),
		nodeColor = Color3.fromRGB(248, 122, 74),
	},
	{
		id = "storm",
		name = "Stormvault",
		desc = "Charge builds in the nodes between swings. Mind the hair.",
		unlockCost = 1300000,
		rebirths = 0,
		gamepass = nil,
		oreValue = 260,
		orePerPower = 0.6,
		nodeHealth = 275,
		nodeCount = 22,
		origin = Vector3.new(SPACING * 4, 0, 0),
		groundColor = Color3.fromRGB(84, 92, 122),
		nodeColor = Color3.fromRGB(146, 186, 255),
	},
	{
		id = "void",
		name = "Voidshelf",
		desc = "A ledge over nothing at all, studded with something very valuable.",
		unlockCost = 15000000,
		rebirths = 0,
		gamepass = nil,
		oreValue = 1200,
		orePerPower = 0.6,
		nodeHealth = 750,
		nodeCount = 22,
		origin = Vector3.new(SPACING * 5, 0, 0),
		groundColor = Color3.fromRGB(52, 46, 72),
		nodeColor = Color3.fromRGB(168, 120, 246),
	},
	{
		id = "vipvault",
		name = "VIP Vault",
		desc = "A private seam kept in good condition. Included with VIP.",
		unlockCost = 0,
		rebirths = 0,
		gamepass = "vip",
		oreValue = 2400,
		orePerPower = 0.6,
		nodeHealth = 750,
		nodeCount = 18,
		origin = Vector3.new(SPACING * 5, 0, -SPACING),
		groundColor = Color3.fromRGB(122, 104, 60),
		nodeColor = Color3.fromRGB(255, 214, 122),
	},
	{
		id = "nova",
		name = "Nova Reach",
		desc = "Close enough to the star that the ore arrives pre-heated.",
		unlockCost = 200000000,
		rebirths = 2,
		gamepass = nil,
		oreValue = 5500,
		orePerPower = 0.6,
		nodeHealth = 2100,
		nodeCount = 20,
		origin = Vector3.new(SPACING * 6, 0, 0),
		groundColor = Color3.fromRGB(132, 96, 60),
		nodeColor = Color3.fromRGB(255, 186, 96),
	},
	{
		id = "riftcore",
		name = "Rift Core",
		desc = "The seam everything else is a rumour about.",
		unlockCost = 2600000000,
		rebirths = 5,
		gamepass = nil,
		oreValue = 26000,
		orePerPower = 0.6,
		nodeHealth = 6000,
		nodeCount = 18,
		origin = Vector3.new(SPACING * 7, 0, 0),
		groundColor = Color3.fromRGB(64, 54, 96),
		nodeColor = Color3.fromRGB(244, 128, 200),
	},
	{
		id = "singularity",
		name = "The Singularity",
		desc = "Nine rebirths and a very good pick. Nothing here is subtle.",
		unlockCost = 36000000000,
		rebirths = 9,
		gamepass = nil,
		oreValue = 130000,
		orePerPower = 0.6,
		nodeHealth = 17500,
		nodeCount = 16,
		origin = Vector3.new(SPACING * 8, 0, 0),
		groundColor = Color3.fromRGB(38, 40, 62),
		nodeColor = Color3.fromRGB(255, 248, 210),
	},
} :: { Zone }

Zones.ById = {} :: { [string]: Zone }
Zones.OrderById = {} :: { [string]: number }

for index, zone in Zones.List do
	Zones.ById[zone.id] = zone
	Zones.OrderById[zone.id] = index
end

Zones.Starter = Zones.List[1].id

function Zones.get(id: string?): Zone
	if id and Zones.ById[id] then
		return Zones.ById[id]
	end
	return Zones.ById[Zones.Starter]
end

--[[ Ore a single swing produces in this zone, before the Deep Yield upgrade. ]]
function Zones.orePerSwing(zone: Zone, toolPower: number): number
	return toolPower * zone.orePerPower
end

return Zones
