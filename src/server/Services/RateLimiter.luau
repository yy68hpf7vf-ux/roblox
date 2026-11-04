--!strict
-- Simple per-player rate limit for remotes. Usage:
--   if not RateLimiter.allow(player, "Hatch", 5, 1) then return end
-- allows at most 5 calls per 1 second for that player+key.

local Players = game:GetService("Players")

local RateLimiter = {}

local buckets: { [Player]: { [string]: { count: number, windowStart: number } } } = {}

function RateLimiter.allow(player: Player, key: string, maxCalls: number, perSeconds: number): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local bucket = playerBuckets[key]
	if not bucket or now - bucket.windowStart >= perSeconds then
		playerBuckets[key] = { count = 1, windowStart = now }
		return true
	end
	if bucket.count >= maxCalls then
		return false
	end
	bucket.count += 1
	return true
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return RateLimiter
