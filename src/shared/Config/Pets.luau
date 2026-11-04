--!nonstrict
-- Pet definitions. Add a new pet by adding an entry here (and to an egg in Phase 3).
-- Phase 2 pets are built from simple blocky parts by PetModels using these fields.
--   Ears: "Floppy" | "Pointy" | "Long" | "Round"

return {
	Dog = {
		Name = "Dog", Rarity = "Common", Category = "Animals", BasePower = 5,
		Body = Color3.fromRGB(214, 150, 80), Accent = Color3.fromRGB(255, 255, 255),
		Ears = "Floppy", Tail = true,
	},
	Bunny = {
		Name = "Bunny", Rarity = "Common", Category = "Animals", BasePower = 6,
		Body = Color3.fromRGB(245, 245, 245), Accent = Color3.fromRGB(255, 170, 190),
		Ears = "Long", Tail = true,
	},
	Cat = {
		Name = "Cat", Rarity = "Uncommon", Category = "Animals", BasePower = 12,
		Body = Color3.fromRGB(150, 155, 170), Accent = Color3.fromRGB(235, 235, 245),
		Ears = "Pointy", Tail = true,
	},
	Fox = {
		Name = "Fox", Rarity = "Uncommon", Category = "Animals", BasePower = 14,
		Body = Color3.fromRGB(240, 120, 40), Accent = Color3.fromRGB(255, 255, 255),
		Ears = "Pointy", Tail = true,
	},
	Bear = {
		Name = "Bear", Rarity = "Rare", Category = "Animals", BasePower = 30,
		Body = Color3.fromRGB(120, 80, 50), Accent = Color3.fromRGB(190, 150, 110),
		Ears = "Round", Tail = false,
	},
}
