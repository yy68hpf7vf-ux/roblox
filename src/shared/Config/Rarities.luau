--!strict
-- Rarity tiers, lowest to highest. `Order` is used for sorting.

export type Rarity = {
	Name: string,
	Order: number,
	Color: Color3,
}

local Rarities: { [string]: Rarity } = {
	Common = { Name = "Common", Order = 1, Color = Color3.fromRGB(190, 190, 190) },
	Uncommon = { Name = "Uncommon", Order = 2, Color = Color3.fromRGB(110, 220, 110) },
	Rare = { Name = "Rare", Order = 3, Color = Color3.fromRGB(80, 160, 255) },
	Epic = { Name = "Epic", Order = 4, Color = Color3.fromRGB(180, 90, 255) },
	Legendary = { Name = "Legendary", Order = 5, Color = Color3.fromRGB(255, 190, 40) },
	Mythical = { Name = "Mythical", Order = 6, Color = Color3.fromRGB(255, 90, 160) },
	Divine = { Name = "Divine", Order = 7, Color = Color3.fromRGB(130, 255, 255) },
	Secret = { Name = "Secret", Order = 8, Color = Color3.fromRGB(30, 30, 30) },
}

return Rarities
