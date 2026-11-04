--!strict
-- Default save data for a brand-new player. Bump `Version` and add a migration
-- in DataService when the shape changes.

local Economy = require(script.Parent.Economy)

return {
	Version = 1,
	Coins = Economy.StarterCoins,
	Pets = {}, -- dictionary: [petId] = { Name = string, Variant = string, Locked = bool, Favorite = bool, Obtained = number }
	Equipped = {}, -- array of pet ids
	Flags = {
		StarterGiven = false,
	},
	PetSlots = Economy.StartingPetSlots,
	InventoryCapacity = Economy.StartingInventoryCapacity,
	UnlockedWorlds = { "DynastyMeadows" },
	Settings = {
		Music = true,
		SoundEffects = true,
	},
	Stats = {
		TotalCoinsEarned = 0,
		ObjectsBroken = 0,
		PetsHatched = 0,
		JoinCount = 0,
	},
}
