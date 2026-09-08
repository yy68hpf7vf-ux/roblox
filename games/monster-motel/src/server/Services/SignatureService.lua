--!strict
--[[
	SignatureService

	Keeps a Signature gamepass and the guest it entitles you to in sync.

	The design worth understanding is that a Signature pass sells an *entitlement*,
	not an object. The guest it puts in your motel is an ordinary guest in every
	respect -- it pays rent from a room, it takes up that room, and it can be
	carried off by a thief exactly like a Grubling. What it is not is gone: if you
	end a night without your Signature, this service hands it back at sunrise.

	That resolves the one problem selling guests creates in a game about robbing
	people. Making them un-stealable would be selling immunity, which is buying an
	advantage in a raid and is the line the whole design refuses to cross. Making
	them stealable and *permanent* means the thief still gets a real prize, the
	owner still has a real bad night, and nobody is ever out of pocket for it.

	There is no schema field for any of this. "Do you currently have one?" is
	answered by looking at the guests you own, which cannot drift out of sync with
	itself.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Guests = require(Shared.Config.Guests)
local Monetization = require(Shared.Config.Monetization)
local Schema = require(Shared.Schema)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GuestService = require(script.Parent.GuestService)
local NightService = require(script.Parent.NightService)
local PassService = require(script.Parent.PassService)
local Remote = require(script.Parent.Remote)

type Profile = Schema.Profile

local SignatureService = {}

--[[ Every Signature guest id the player has paid for. ]]
function SignatureService.entitlements(player: Player): { string }
	local out = {}
	for _, pass in Monetization.Gamepasses do
		if pass.signatureGuest and PassService.owns(player, pass.id) then
			table.insert(out, pass.signatureGuest)
		end
	end
	return out
end

local function ownsGuest(profile: Profile, guestId: string): boolean
	for _, owned in profile.guests do
		if owned.guest == guestId then
			return true
		end
	end
	return false
end

--[[ Hands back any entitled Signature the player is currently without.

     Deliberately refuses during Lights Out. A thief who takes one should get to
     keep it for the night they earned it in -- re-summoning immediately would
     make the raid meaningless and would quietly hand paying players an immunity
     after all. ]]
function SignatureService.reconcile(player: Player, profile: Profile): number
	if NightService.isNight() then
		return 0
	end

	local restored = 0

	for _, guestId in SignatureService.entitlements(player) do
		if not ownsGuest(profile, guestId) then
			local owned, housed = GuestService.give(player, profile, guestId)
			if owned then
				restored += 1
				local guest = Guests.get(guestId)
				local name = if guest then guest.name else "Your Signature guest"
				Remote.notify(
					player,
					if housed
						then `{name} is back at the desk.`
						else `{name} is back, but every room is full -- they are in storage.`,
					"good"
				)
			end
		end
	end

	if restored > 0 then
		EconomyService.markDirty(player)
	end
	return restored
end

local function reconcileAll()
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile then
			SignatureService.reconcile(player, profile)
		end
	end
end

function SignatureService.start()
	-- On load: a player who bought a pass while offline, or lost one last session.
	DataService.Loaded:Connect(function(player, profile)
		SignatureService.reconcile(player, profile)
	end)

	-- The moment a purchase completes.
	PassService.Changed:Connect(function(player)
		local profile = DataService.get(player)
		if profile then
			SignatureService.reconcile(player, profile)
		end
	end)

	-- Sunrise: everything taken last night comes back.
	NightService.Changed:Connect(function(night: boolean)
		if not night then
			reconcileAll()
		end
	end)
end

return SignatureService
