--!strict
--[[
	Backpacks

	Capacity is how much raw ore a player can hold before they have to walk back
	to a sell pad. It is the pacing dial for the core loop: bigger packs mean
	fewer trips, not more money per ore.
]]

export type Backpack = {
	id: string,
	name: string,
	desc: string,
	price: number,
	capacity: number,
	rebirths: number,
	color: Color3,
}

local Backpacks = {}

Backpacks.List = {
	{
		id = "satchel",
		name = "Canvas Satchel",
		desc = "Holds a snack and about thirty rocks.",
		price = 0,
		capacity = 35,
		rebirths = 0,
		color = Color3.fromRGB(154, 128, 96),
	},
	{
		id = "pack",
		name = "Miner's Pack",
		desc = "Straps that actually stay on your shoulders.",
		price = 250,
		capacity = 100,
		rebirths = 0,
		color = Color3.fromRGB(120, 140, 110),
	},
	{
		id = "bigpack",
		name = "Reinforced Pack",
		desc = "Double-stitched, for people who stopped walking back so often.",
		price = 2500,
		capacity = 280,
		rebirths = 0,
		color = Color3.fromRGB(96, 132, 148),
	},
	{
		id = "crate",
		name = "Hover Crate",
		desc = "Floats behind you and pretends it isn't heavy.",
		price = 25000,
		capacity = 700,
		rebirths = 0,
		color = Color3.fromRGB(108, 168, 200),
	},
	{
		id = "hauler",
		name = "Hauler Rig",
		desc = "Industrial. Faintly ridiculous. Extremely effective.",
		price = 250000,
		capacity = 1900,
		rebirths = 0,
		color = Color3.fromRGB(206, 158, 74),
	},
	{
		id = "container",
		name = "Cargo Container",
		desc = "You are now, technically, freight infrastructure.",
		price = 3000000,
		capacity = 5200,
		rebirths = 0,
		color = Color3.fromRGB(190, 96, 84),
	},
	{
		id = "vault",
		name = "Pocket Vault",
		desc = "Bigger inside. Nobody asks how.",
		price = 38000000,
		capacity = 15000,
		rebirths = 1,
		color = Color3.fromRGB(132, 118, 196),
	},
	{
		id = "riftvault",
		name = "Rift Vault",
		desc = "Stores ore in a room that is not, strictly, here.",
		price = 480000000,
		capacity = 42000,
		rebirths = 3,
		color = Color3.fromRGB(92, 84, 176),
	},
	{
		id = "singvault",
		name = "Singularity Vault",
		desc = "Compresses ore until it stops complaining.",
		price = 6500000000,
		capacity = 125000,
		rebirths = 6,
		color = Color3.fromRGB(58, 66, 128),
	},
	{
		id = "infvault",
		name = "Infinity Vault",
		desc = "Not actually infinite. Close enough that the difference is paperwork.",
		price = 95000000000,
		capacity = 400000,
		rebirths = 10,
		color = Color3.fromRGB(255, 214, 122),
	},
} :: { Backpack }

Backpacks.ById = {} :: { [string]: Backpack }
Backpacks.OrderById = {} :: { [string]: number }

for index, pack in Backpacks.List do
	Backpacks.ById[pack.id] = pack
	Backpacks.OrderById[pack.id] = index
end

Backpacks.Starter = Backpacks.List[1].id

function Backpacks.get(id: string?): Backpack
	if id and Backpacks.ById[id] then
		return Backpacks.ById[id]
	end
	return Backpacks.ById[Backpacks.Starter]
end

function Backpacks.isOwned(owned: { [string]: boolean }, id: string): boolean
	return id == Backpacks.Starter or owned[id] == true
end

return Backpacks
