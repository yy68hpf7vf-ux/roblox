--!strict
-- Loads and saves player data.
--
-- Safety rules:
--  * Session locking: a player's data can only be open in one server at a time.
--  * If loading fails, we NEVER hand out default data that could overwrite the
--    real save. In a live game the player is kicked with a message instead.
--  * Saves go through UpdateAsync and are skipped if another server owns the lock.
--  * Data has a schema Version and a migration step.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local DataTemplate = require(Shared.Config.DataTemplate)
local Table = require(Shared.Util.Table)

local STORE_NAME = "PetDynastyData_v1"
local KEY_PREFIX = "Player_"
local LOAD_ATTEMPTS = 6
local SAVE_ATTEMPTS = 4
local LOCK_TIMEOUT = 180 -- seconds before another server's lock is considered dead
local RETRY_DELAY = 3

type Profile = {
	Data: { [string]: any },
	Dirty: boolean,
	CanSave: boolean, -- false in Studio when DataStores are unavailable
	Loaded: boolean,
}

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles: { [Player]: Profile } = {}
local loadedEvent = Instance.new("BindableEvent")

local DataService = {}
DataService.PlayerLoaded = loadedEvent.Event -- fires (player: Player)

-- Add one function per schema step: Migrations[1] upgrades version 1 -> 2, etc.
local Migrations: { [number]: (data: any) -> () } = {}

local function migrate(data: any)
	local version = data.Version or 1
	while Migrations[version] do
		Migrations[version](data)
		version += 1
		data.Version = version
	end
	Table.reconcile(data, DataTemplate)
end

local function lockedByOther(envelope: any): boolean
	if not envelope or not envelope.Lock then
		return false
	end
	if envelope.Lock.JobId == game.JobId then
		return false
	end
	return os.time() - (envelope.Lock.Time or 0) < LOCK_TIMEOUT
end

local function keyFor(player: Player): string
	return KEY_PREFIX .. player.UserId
end

-- Returns the data table, or nil if it could not be loaded safely.
local function loadData(player: Player): { [string]: any }?
	for attempt = 1, LOAD_ATTEMPTS do
		if player.Parent ~= Players then
			return nil
		end
		local blocked = false
		local ok, result = pcall(function()
			return store:UpdateAsync(keyFor(player), function(old: any)
				if lockedByOther(old) then
					blocked = true
					return nil -- cancel: another server owns this player
				end
				local envelope = old or {}
				envelope.Lock = { JobId = game.JobId, Time = os.time() }
				return envelope
			end)
		end)
		if ok and not blocked and result then
			local data = result.Data
			if data == nil then
				data = Table.deepCopy(DataTemplate)
			end
			migrate(data)
			return data
		end
		if not ok then
			warn(`[DataService] load attempt {attempt} failed for {player.Name}: {result}`)
			if RunService:IsStudio() then
				return nil -- Studio without API access: fail fast instead of retrying for a long time
			end
		else
			warn(`[DataService] {player.Name} is locked by another server (attempt {attempt})`)
		end
		task.wait(RETRY_DELAY)
	end
	return nil
end

local function saveProfile(player: Player, profile: Profile, release: boolean): boolean
	if not profile.CanSave or not profile.Loaded then
		return true
	end
	local snapshot = Table.deepCopy(profile.Data)
	for attempt = 1, SAVE_ATTEMPTS do
		local blocked = false
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old: any)
				if lockedByOther(old) then
					blocked = true
					return nil
				end
				return {
					Data = snapshot,
					Lock = if release then nil else { JobId = game.JobId, Time = os.time() },
				}
			end)
		end)
		if ok and not blocked then
			profile.Dirty = false
			return true
		end
		if blocked then
			warn(`[DataService] save for {player.Name} skipped: another server owns the lock`)
			return false
		end
		warn(`[DataService] save attempt {attempt} failed for {player.Name}: {err}`)
		task.wait(RETRY_DELAY)
	end
	return false
end

local function onPlayerAdded(player: Player)
	local data = loadData(player)
	local canSave = true

	if not data then
		if RunService:IsStudio() then
			-- DataStores are often off in Studio. Play with temporary data that is never saved.
			warn("[DataService] Using TEMPORARY data (not saved). Enable Studio API access in Game Settings > Security to test saving.")
			data = Table.deepCopy(DataTemplate)
			canSave = false
		else
			if player.Parent == Players then
				player:Kick("We couldn't load your data safely. Please rejoin in a minute. Your progress is safe.")
			end
			return
		end
	end

	if player.Parent ~= Players then
		-- Left while loading: release the lock we took.
		if canSave then
			saveProfile(player, { Data = data, Dirty = true, CanSave = true, Loaded = true }, true)
		end
		return
	end

	data.Stats.JoinCount += 1
	profiles[player] = { Data = data, Dirty = true, CanSave = canSave, Loaded = true }
	loadedEvent:Fire(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		saveProfile(player, profile, true)
		profiles[player] = nil
	end
end

function DataService.init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(Economy.AutosaveSeconds)
			for player, profile in profiles do
				task.spawn(saveProfile, player, profile, false)
			end
		end
	end)

	-- Save everyone when the server shuts down.
	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, profile, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

-- The live data table for a player, or nil if not loaded yet. Mutate it, then call markDirty.
function DataService.get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.Data or nil
end

-- Yields until the player's data is loaded. Returns nil if they left first.
function DataService.waitFor(player: Player): { [string]: any }?
	while player.Parent == Players do
		local data = DataService.get(player)
		if data then
			return data
		end
		task.wait(0.1)
	end
	return nil
end

-- False when the player is playing on temporary, never-saved data (Studio without API access).
function DataService.canSave(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.CanSave
end

function DataService.markDirty(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Dirty = true
	end
end

return DataService
