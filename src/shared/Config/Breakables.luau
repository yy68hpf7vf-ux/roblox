--!nonstrict
-- Breakable object types. Health is "damage needed"; Reward is Coins for the whole object
-- (split between everyone who hit it). Tune freely.
-- Planned for later phases: Crystal deposits, Giant vaults, world-specific objects.

return {
	CoinPile = { DisplayName = "Coin Pile", Health = 50, Reward = 10, RespawnTime = 8, Weight = 6 },
	WoodenCrate = { DisplayName = "Wooden Crate", Health = 150, Reward = 35, RespawnTime = 12, Weight = 4 },
	TreasureChest = { DisplayName = "Treasure Chest", Health = 600, Reward = 150, RespawnTime = 25, Weight = 2 },
}
