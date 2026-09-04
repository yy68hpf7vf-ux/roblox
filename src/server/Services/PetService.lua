--!strict
--[[
	PetService

	Hatching, equipping and deleting pets.

	The roll happens here, on the server, against the same weight table the client
	renders odds from. There is no per-player luck value, no pity counter, no
	first-hatch boost -- what the hatch screen says is what the RNG does, for
	everyone, every time.

	Bulk hatching exists (up to 10) because the alternative is a player clicking a
	button four hundred times, which is not engagement, it is friction.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Eggs = require(Shared.Config.Eggs)
local Pets = require(Shared.Config.Pets)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Util.Format)
local Schema = require(Shared.Schema)

local EconomyService = require(script.Parent.EconomyService)
local QuestService = require(script.Parent.QuestService)
local Remote = require(script.Parent.Remote)

type Profile = Schema.Profile

local PetService = {}

PetService.MaxBulkHatch = 10

-- One server-owned Random. Nothing about a player feeds into the seed.
local rng = Random.new()

local function nextUid(profile: Profile): string
	local uid = tostring(profile.nextPetUid)
	profile.nextPetUid += 1
	return uid
end

local function isEquipped(profile: Profile, uid: string): boolean
	return table.find(profile.equipped, uid) ~= nil
end

--[[ Trims the equipped list if the player's slot count shrank (a gamepass check
     that came back false, a profile from before an update). ]]
local function clampEquipped(player: Player, profile: Profile)
	local slots = EconomyService.petSlots(player, profile)
	while #profile.equipped > slots do
		table.remove(profile.equipped)
	end
end

function PetService.hatch(player: Player, profile: Profile, eggId: string, count: number): (boolean, string)
	local egg = Eggs.get(eggId)
	if not egg then
		return false, "No such egg."
	end

	local zone = Zones.get(egg.zone)
	if not EconomyService.hasZone(player, profile, zone) then
		return false, `{egg.name} is in {zone.name}, which you have not unlocked yet.`
	end

	count = math.clamp(math.floor(tonumber(count) or 1), 1, PetService.MaxBulkHatch)

	if #profile.pets + count > GameConfig.MaxPetsOwned then
		return false, `You are carrying too many pets. Delete a few first (limit {GameConfig.MaxPetsOwned}).`
	end

	local totalCost = egg.price * count
	if not EconomyService.spendCrystals(player, profile, totalCost) then
		local short = totalCost - profile.crystals
		return false, `You need {Format.short(short)} more Crystals for {count}x {egg.name}.`
	end

	local hatched: { string } = {}
	for _ = 1, count do
		local petId = Eggs.roll(egg, rng)
		table.insert(profile.pets, { uid = nextUid(profile), pet = petId })
		table.insert(hatched, petId)
	end

	profile.stats.hatches += count
	QuestService.addProgress(player, profile, "hatch_eggs", count)

	PetService.autoEquipBest(player, profile)
	EconomyService.markDirty(player)

	Remote.effect(player, "hatched", { egg = eggId, pets = hatched })

	if count == 1 then
		local pet = Pets.get(hatched[1])
		return true, `{if pet then pet.name else "Something"} hatched.`
	end
	return true, `{count} eggs hatched.`
end

--[[ Equips the strongest pets the player owns, up to their slot count. Called
     after a hatch so a new best pet is not sitting unused in the inventory
     because nobody noticed. ]]
function PetService.autoEquipBest(player: Player, profile: Profile)
	local slots = EconomyService.petSlots(player, profile)

	local uidsByPower = {}
	for _, entry in profile.pets do
		table.insert(uidsByPower, entry)
	end
	table.sort(uidsByPower, function(a, b)
		local petA, petB = Pets.get(a.pet), Pets.get(b.pet)
		local multA = if petA then petA.mult else 0
		local multB = if petB then petB.mult else 0
		if multA == multB then
			return a.uid < b.uid
		end
		return multA > multB
	end)

	local equipped = {}
	for index = 1, math.min(slots, #uidsByPower) do
		table.insert(equipped, uidsByPower[index].uid)
	end
	profile.equipped = equipped
end

function PetService.equip(player: Player, profile: Profile, uid: string): (boolean, string)
	local owned = false
	for _, entry in profile.pets do
		if entry.uid == uid then
			owned = true
			break
		end
	end
	if not owned then
		return false, "You do not own that pet."
	end
	if isEquipped(profile, uid) then
		return true, "Already equipped."
	end

	local slots = EconomyService.petSlots(player, profile)
	if #profile.equipped >= slots then
		return false, `All {slots} pet slots are full. Unequip one first.`
	end

	table.insert(profile.equipped, uid)
	EconomyService.markDirty(player)
	return true, "Equipped."
end

function PetService.unequip(player: Player, profile: Profile, uid: string): (boolean, string)
	local index = table.find(profile.equipped, uid)
	if not index then
		return false, "That pet is not equipped."
	end
	table.remove(profile.equipped, index)
	EconomyService.markDirty(player)
	return true, "Unequipped."
end

--[[ Deletes every unequipped pet below a rarity threshold. Equipped pets are
     never touched, and the client confirms the count before this is called. ]]
function PetService.deleteBelow(player: Player, profile: Profile, rarity: string): (boolean, string)
	local threshold = table.find(Pets.RarityOrder, rarity)
	if not threshold then
		return false, "Unknown rarity."
	end

	local kept: { Schema.OwnedPet } = {}
	local removed = 0

	for _, entry in profile.pets do
		local pet = Pets.get(entry.pet)
		local rank = if pet then table.find(Pets.RarityOrder, pet.rarity) else nil
		local droppable = rank ~= nil and rank < threshold and not isEquipped(profile, entry.uid)
		if droppable then
			removed += 1
		else
			table.insert(kept, entry)
		end
	end

	if removed == 0 then
		return false, "Nothing matched."
	end

	profile.pets = kept
	clampEquipped(player, profile)
	EconomyService.markDirty(player)
	return true, `Released {removed} pets.`
end

function PetService.deleteOne(player: Player, profile: Profile, uid: string): (boolean, string)
	if isEquipped(profile, uid) then
		return false, "Unequip it first."
	end
	for index, entry in profile.pets do
		if entry.uid == uid then
			table.remove(profile.pets, index)
			EconomyService.markDirty(player)
			return true, "Released."
		end
	end
	return false, "You do not own that pet."
end

function PetService.onLoaded(player: Player, profile: Profile)
	clampEquipped(player, profile)
end

return PetService
