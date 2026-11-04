--!nonstrict
-- Owns everything about a player's pets: granting, equipping, favorites/locks, deleting.
-- The client can only *ask* (through PetAction); all checks happen here.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Pets = require(Shared.Config.Pets)
local Variants = require(Shared.Config.Variants)
local PetUtil = require(Shared.Util.PetUtil)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)

local STARTER_PET = "Dog"
local MAX_ID_LENGTH = 64

local PetService = {}

local function countPets(data): number
	local n = 0
	for _ in data.Pets do
		n += 1
	end
	return n
end

local function notify(player: Player, text: string)
	Remotes.event("Notify"):FireClient(player, text)
end

-- Pushes pets/equipped to the owner and publishes the equipped list so every client can
-- draw this player's pets (clients read the "EquippedPets" attribute).
local function sync(player: Player, data)
	Remotes.event("DataUpdate"):FireClient(player, { Pets = data.Pets, Equipped = data.Equipped })
	local equipped = {}
	for _, id in data.Equipped do
		local pet = data.Pets[id]
		if pet then
			table.insert(equipped, { Id = id, Name = pet.Name, Variant = pet.Variant })
		end
	end
	player:SetAttribute("EquippedPets", HttpService:JSONEncode(equipped))
	DataService.markDirty(player)
end

function PetService.getTotalPower(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, id in data.Equipped do
		local pet = data.Pets[id]
		if pet then
			total += PetUtil.getPower(pet)
		end
	end
	return total
end

-- Gives a pet. Returns the new pet id, or nil plus a reason ("full" / "invalid" / "nodata").
function PetService.grant(player: Player, petName: string, variant: string?): (string?, string?)
	local data = DataService.get(player)
	if not data then
		return nil, "nodata"
	end
	variant = variant or "Normal"
	if not Pets[petName] or not Variants[variant] then
		return nil, "invalid"
	end
	if countPets(data) >= data.InventoryCapacity then
		return nil, "full"
	end
	local id = HttpService:GenerateGUID(false)
	data.Pets[id] = { Name = petName, Variant = variant, Locked = false, Favorite = false, Obtained = os.time() }
	sync(player, data)
	return id
end

local function isEquipped(data, id: string): number?
	return table.find(data.Equipped, id)
end

local function equip(player, data, id)
	if not data.Pets[id] then
		return false, "You don't own that pet."
	end
	if isEquipped(data, id) then
		return true
	end
	if #data.Equipped >= data.PetSlots then
		return false, "All pet slots are full."
	end
	table.insert(data.Equipped, id)
	return true
end

local ACTIONS = {
	Equip = function(player, data, id)
		return equip(player, data, id)
	end,
	Unequip = function(player, data, id)
		local index = isEquipped(data, id)
		if index then
			table.remove(data.Equipped, index)
		end
		return true
	end,
	Favorite = function(player, data, id)
		local pet = data.Pets[id]
		if not pet then
			return false, "You don't own that pet."
		end
		pet.Favorite = not pet.Favorite
		return true
	end,
	Lock = function(player, data, id)
		local pet = data.Pets[id]
		if not pet then
			return false, "You don't own that pet."
		end
		pet.Locked = not pet.Locked
		return true
	end,
	Delete = function(player, data, id)
		local pet = data.Pets[id]
		if not pet then
			return false, "You don't own that pet."
		end
		if pet.Locked or pet.Favorite then
			return false, "Unlock or unfavorite the pet first."
		end
		if isEquipped(data, id) then
			return false, "Unequip the pet first."
		end
		data.Pets[id] = nil
		return true
	end,
	EquipBest = function(player, data)
		table.clear(data.Equipped)
		for _, entry in PetUtil.sortedList(data.Pets, "Power") do
			if #data.Equipped >= data.PetSlots then
				break
			end
			table.insert(data.Equipped, entry.Id)
		end
		return true
	end,
	UnequipAll = function(player, data)
		table.clear(data.Equipped)
		return true
	end,
}

local function handleAction(player: Player, action: any, petId: any)
	if type(action) ~= "string" or not RateLimiter.allow(player, "PetAction", 10, 1) then
		return false, "Slow down!"
	end
	local handler = ACTIONS[action]
	if not handler then
		return false, "Unknown action."
	end
	if petId ~= nil and (type(petId) ~= "string" or #petId > MAX_ID_LENGTH) then
		return false, "Invalid pet."
	end
	local data = DataService.get(player)
	if not data then
		return false, "Still loading."
	end
	local ok, message = handler(player, data, petId)
	if ok then
		sync(player, data)
	end
	return ok, message
end

function PetService.init()
	Remotes.func("PetAction").OnServerInvoke = handleAction

	DataService.PlayerLoaded:Connect(function(player)
		local data = DataService.get(player)
		if not data then
			return
		end
		-- Remove equipped ids that no longer exist (corrupt or deleted).
		for i = #data.Equipped, 1, -1 do
			if not data.Pets[data.Equipped[i]] then
				table.remove(data.Equipped, i)
			end
		end
		if not data.Flags.StarterGiven then
			local id = PetService.grant(player, STARTER_PET, "Normal")
			if id then
				data.Flags.StarterGiven = true
				equip(player, data, id)
			end
		end
		-- Studio testing aid: only for temporary (never saved) data, so no test pets
		-- ever reach a real save.
		if game:GetService("RunService"):IsStudio() and not DataService.canSave(player) then
			for _, name in { "Bunny", "Cat", "Fox", "Bear" } do
				PetService.grant(player, name, "Normal")
			end
			PetService.grant(player, "Dog", "Golden")
			notify(player, "Studio test mode: extra test pets added (not saved)")
		end
		sync(player, data)
	end)
end

return PetService
