--!nonstrict
-- Builds simple blocky pet models from a pet definition. Used for the pets that follow
-- players and for the inventory icons. The model faces -Z (front) and is fully anchored.
-- When real pet models exist, replace `build` and nothing else needs to change.

local Config = script.Parent.Config
local Pets = require(Config.Pets)

local PetModels = {}

local function makePart(model, name, size, offset, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = CFrame.new(offset)
	part.Parent = model
	return part
end

local function variantColors(variant: string, body: Color3, accent: Color3)
	if variant == "Golden" then
		return Color3.fromRGB(255, 205, 60), Color3.fromRGB(255, 240, 160), Enum.Material.Metal
	elseif variant == "Rainbow" then
		return Color3.fromRGB(255, 90, 140), Color3.fromRGB(120, 220, 255), Enum.Material.Neon
	elseif variant == "Cosmic" then
		return Color3.fromRGB(70, 30, 140), Color3.fromRGB(120, 220, 255), Enum.Material.Neon
	end
	return body, accent, Enum.Material.SmoothPlastic
end

function PetModels.build(petName: string, variant: string?): Model?
	local def = Pets[petName]
	if not def then
		return nil
	end
	variant = variant or "Normal"
	local body, accent, material = variantColors(variant, def.Body, def.Accent)

	local model = Instance.new("Model")
	model.Name = petName

	local main = makePart(model, "Body", Vector3.new(1.6, 1.2, 2.2), Vector3.new(0, 0.6, 0), body, material)
	makePart(model, "Head", Vector3.new(1.3, 1.2, 1.2), Vector3.new(0, 1.0, -1.5), body, material)
	makePart(model, "Snout", Vector3.new(0.65, 0.45, 0.4), Vector3.new(0, 0.85, -2.2), accent, material)
	makePart(model, "EyeL", Vector3.new(0.22, 0.22, 0.1), Vector3.new(-0.38, 1.2, -2.1), Color3.fromRGB(20, 20, 30))
	makePart(model, "EyeR", Vector3.new(0.22, 0.22, 0.1), Vector3.new(0.38, 1.2, -2.1), Color3.fromRGB(20, 20, 30))
	makePart(model, "Belly", Vector3.new(1.0, 0.5, 1.4), Vector3.new(0, 0.3, 0), accent, material)

	for _, x in { -0.55, 0.55 } do
		makePart(model, "LegF", Vector3.new(0.45, 0.5, 0.45), Vector3.new(x, 0.0, -0.7), accent, material)
		makePart(model, "LegB", Vector3.new(0.45, 0.5, 0.45), Vector3.new(x, 0.0, 0.7), accent, material)
	end

	if def.Ears == "Floppy" then
		for _, x in { -0.75, 0.75 } do
			makePart(model, "Ear", Vector3.new(0.3, 0.7, 0.35), Vector3.new(x, 0.85, -1.45), accent, material)
		end
	elseif def.Ears == "Pointy" then
		for _, x in { -0.4, 0.4 } do
			makePart(model, "Ear", Vector3.new(0.35, 0.6, 0.3), Vector3.new(x, 1.8, -1.35), body, material)
		end
	elseif def.Ears == "Long" then
		for _, x in { -0.3, 0.3 } do
			makePart(model, "Ear", Vector3.new(0.3, 1.2, 0.3), Vector3.new(x, 2.1, -1.35), body, material)
		end
	elseif def.Ears == "Round" then
		for _, x in { -0.5, 0.5 } do
			makePart(model, "Ear", Vector3.new(0.45, 0.45, 0.3), Vector3.new(x, 1.75, -1.35), body, material)
		end
	end

	if def.Tail then
		makePart(model, "Tail", Vector3.new(0.35, 0.35, 0.9), Vector3.new(0, 0.9, 1.45), accent, material)
	end

	model.PrimaryPart = main
	if variant == "Huge" then
		model:ScaleTo(2.5)
	end
	return model
end

return PetModels
