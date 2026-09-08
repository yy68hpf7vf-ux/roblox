--!strict
--[[
	DataService

	Profile load/save with a session lock, retries, autosave and a shutdown flush.

	The session lock is the part worth reading. Two servers can hold the same
	player at once (rejoin during a teleport, a server that has not finished dying
	yet), and if both save, one of them writes stale data over the other. So a
	load takes a lock keyed by JobId, refuses to load while someone else's lock is
	fresh, and steals a lock that has gone stale -- which is the only safe reading
	of "the server holding this profile is gone".

	If DataStores are unavailable (Studio without API access, an outage), the
	player still gets a working profile in memory and a clear warning. Nothing
	saves, but nothing crashes either, and the state is flagged so the rest of the
	game can tell the player their run will not persist. That matters more here
	than in most games: a player who loses a guest to a thief and then finds the
	whole session was never being saved has had two bad experiences, not one.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Schema = require(Shared.Schema)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)

type Profile = Schema.Profile

local DataService = {}

DataService.Loaded = Signal.new() :: Signal.Signal<Player, Profile>
DataService.Releasing = Signal.new() :: Signal.Signal<Player, Profile>

local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(os.clock())

local profiles: { [Player]: Profile } = {}
local volatile: { [Player]: boolean } = {}
local loading: { [Player]: boolean } = {}

local function keyFor(player: Player): string
	return "player_" .. tostring(player.UserId)
end

local function newProfile(): Profile
	local profile = TableUtil.deepCopy(Schema.Template)
	profile.firstJoinAt = os.time()
	return profile
end

local function prepare(raw: any): Profile
	local profile = raw :: Profile
	Schema.migrate(profile)
	TableUtil.reconcile(profile :: any, Schema.Template :: any)
	Schema.sanitise(profile)
	return profile
end

--[[ Retries with backoff.

     Returns the stored envelope on success. On failure the second return says
     *why*, because the two failure modes need opposite handling: "locked" means
     another live server still owns this profile and the data is fine, so the
     player must not be given a blank one; "error" means DataStores are
     unreachable, and a throwaway profile is better than a locked-out player. ]]
local function acquire(player: Player): (any?, string?)
	local key = keyFor(player)
	local backoff = 1
	local sawError = false

	for attempt = 1, GameConfig.DataRetryAttempts do
		if player.Parent == nil then
			return nil, "left"
		end

		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(old)
				local envelope = old or { lock = nil, data = nil }
				local lock = envelope.lock
				local now = os.time()

				local heldElsewhere = lock ~= nil
					and lock.jobId ~= jobId
					and (now - (lock.at or 0)) < GameConfig.SessionLockStaleAfter

				if heldElsewhere then
					-- Cancel the write and let the caller back off; the other
					-- server is still alive and owns this profile.
					return nil
				end

				envelope.lock = { jobId = jobId, at = now }
				return envelope
			end)
		end)

		if ok and result ~= nil then
			return result, nil
		end

		if not ok then
			sawError = true
			warn(`[DataService] load attempt {attempt} failed for {player.Name}: {result}`)
		end

		task.wait(backoff)
		backoff = math.min(backoff * 2, 8)
	end

	return nil, if sawError then "error" else "locked"
end

local function writeAsync(player: Player, releaseLock: boolean): boolean
	local profile = profiles[player]
	if not profile or volatile[player] then
		return false
	end

	profile.lastSeenAt = os.time()
	local snapshot = TableUtil.deepCopy(profile)
	local key = keyFor(player)

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old)
			local envelope = old or {}
			local lock = envelope.lock

			-- Never write over a profile another server has taken from us. If our
			-- lock was stolen, this session's data is the stale one.
			if lock and lock.jobId ~= jobId and (os.time() - (lock.at or 0)) < GameConfig.SessionLockStaleAfter then
				return nil
			end

			envelope.data = snapshot
			envelope.lock = if releaseLock then nil else { jobId = jobId, at = os.time() }
			return envelope
		end)
	end)

	if not ok then
		warn(`[DataService] save failed for {player.Name}: {err}`)
	end
	return ok
end

function DataService.load(player: Player)
	if profiles[player] or loading[player] then
		return
	end
	loading[player] = true

	local envelope, reason = acquire(player)

	if player.Parent == nil then
		loading[player] = nil
		return
	end

	local profile: Profile
	if envelope then
		profile = if envelope.data then prepare(envelope.data) else newProfile()
	elseif reason == "locked" then
		-- Another server still holds this profile, usually because the player only
		-- just left it. Handing them an empty one here is how a save "disappears":
		-- they would play on a blank profile and we would eventually write it over
		-- the real one. Send them away instead, with a reason.
		loading[player] = nil
		player:Kick(
			"Your save is still open in another server. Please rejoin in a few seconds -- your progress is safe."
		)
		return
	else
		-- DataStores are unreachable (Studio without API access, or an outage).
		-- Playable, but not persisted, and the HUD says so plainly rather than
		-- letting anyone grind an hour into nothing.
		warn(`[DataService] running {player.Name} without persistence: {reason}`)
		volatile[player] = true
		profile = newProfile()
	end

	profile.stats.joins += 1
	profile.lastSeenAt = os.time()

	profiles[player] = profile
	loading[player] = nil

	DataService.Loaded:Fire(player, profile)
end

function DataService.release(player: Player)
	local profile = profiles[player]
	if not profile then
		loading[player] = nil
		return
	end

	DataService.Releasing:Fire(player, profile)
	writeAsync(player, true)

	profiles[player] = nil
	volatile[player] = nil
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

--[[ Waits for a profile that is mid-load. Services that run on CharacterAdded
     can beat the DataStore round trip, and they need the profile, not nil. ]]
function DataService.await(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 20)
	while os.clock() < deadline do
		local profile = profiles[player]
		if profile then
			return profile
		end
		if player.Parent == nil then
			return nil
		end
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.isVolatile(player: Player): boolean
	return volatile[player] == true
end

function DataService.save(player: Player): boolean
	return writeAsync(player, false)
end

function DataService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(DataService.load, player)
	end
	Players.PlayerAdded:Connect(function(player)
		DataService.load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		DataService.release(player)
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for player in profiles do
				task.spawn(DataService.save, player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.release(player)
				pending -= 1
			end)
		end
		-- Roblox gives a closing server ~30s. Spend it waiting on writes.
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
