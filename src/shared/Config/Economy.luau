--!strict
-- All economy numbers live here so they can be balanced without touching game code.

return {
	StarterCoins = 0,
	MaxCoins = 1e15,

	-- Pet slots
	StartingPetSlots = 3,
	MaxPetSlots = 10,

	-- Inventory
	StartingInventoryCapacity = 50,

	-- Breaking objects
	DamageTickSeconds = 0.5, -- pets hit every tick; damage per tick = total equipped pet power
	TargetRange = 45, -- how far away a player may start targeting an object
	StopRange = 75, -- targeting is dropped beyond this distance
	AutoTargetRange = 25, -- client auto-targets the nearest object within this range

	-- Data saving
	AutosaveSeconds = 60,
}
