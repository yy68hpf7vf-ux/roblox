--!strict
-- Default save data for a brand-new player. Bump `Version` and add a migration
-- in DataService when the shape changes.

local Economy = require(script.Parent.Economy)

return {
	Version = 1,
	Coins = Economy.StarterCoins,
	Pets = {}, -- list of { Id = string, PetName = string, Variant = string, Locked = bool, Favorite = bool }
	Equipped = {}, -- list of pet Ids
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
