--!strict
--[[
	FeedService

	The ticker of what just happened to somebody else.

	This exists because the server was silent. You could play for twenty minutes
	next to eleven other motels and never learn that anyone else was there --
	which in a game whose whole point is other players is a strange thing to have
	built. Now a Mythic changing hands, a celebrity going home or somebody hitting
	Six Star is announced to everyone.

	It is deliberately picky. A feed that reports every check-in is wallpaper
	nobody reads; one that only fires for things worth looking up for keeps its
	meaning. Common and Uncommon thefts do not appear at all.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Guests = require(Shared.Config.Guests)

local Remote = require(script.Parent.Remote)

local FeedService = {}

-- Thefts below this rarity are not worth the whole server's attention.
local MIN_THEFT_RANK = 4

local function post(text: string, kind: string)
	Remote.effectAll("feed", { text = text, kind = kind })
end

function FeedService.theft(thief: Player, victim: Player, guestId: string)
	local guest = Guests.get(guestId)
	if not guest or Guests.rarityRank(guest.rarity) < MIN_THEFT_RANK then
		return
	end
	post(
		`{thief.DisplayName} took {victim.DisplayName}'s {guest.name} (${Format.short(guest.rent)}/s)`,
		"bad"
	)
end

function FeedService.celebrity(player: Player, guestId: string)
	local guest = Guests.get(guestId)
	post(
		`{player.DisplayName} got {if guest then guest.name else "the celebrity"} home`,
		"good"
	)
end

function FeedService.renovation(player: Player, renovations: number, stars: number)
	post(
		`{player.DisplayName} renovated for the {renovations}{if renovations == 1 then "st" else "th"} time (+{stars}★)`,
		"star"
	)
end

--[[ Only the ratings worth announcing. "Reached Two Star" is not news. ]]
function FeedService.rating(player: Player, level: number, name: string)
	if level < 5 then
		return
	end
	post(`{player.DisplayName} reached {name}`, "info")
end

function FeedService.discovery(player: Player, guestId: string)
	local guest = Guests.get(guestId)
	if not guest or Guests.rarityRank(guest.rarity) < 6 then
		return
	end
	post(`{player.DisplayName} found a {guest.rarity}: {guest.name}`, "good")
end

return FeedService
