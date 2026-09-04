--!strict
--[[
	LeaderboardService

	Two global boards -- most Crystals and most Rebirths -- backed by
	OrderedDataStores and rendered on physical signs in the starting plaza.

	Entries are written on save rather than on every change, and read on a timer
	shared by the whole server, so the boards cost a handful of requests a minute
	no matter how many people are playing.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

-- OrderedDataStore values must fit in a signed 64-bit integer. Crystals will not
-- realistically get there, but a clamp is cheaper than a failed write.
local MAX_ORDERED = 9e15

local boards = {
	{
		id = "crystals",
		title = "Most Crystals",
		store = DataStoreService:GetOrderedDataStore("RiftMiner_Top_Crystals_v1"),
		read = function(profile): number
			return profile.crystals
		end,
		format = function(value: number): string
			return Format.short(value)
		end,
		offset = Vector3.new(-30, 0, -104),
		color = Color3.fromRGB(120, 214, 232),
	},
	{
		id = "rebirths",
		title = "Most Rebirths",
		store = DataStoreService:GetOrderedDataStore("RiftMiner_Top_Rebirths_v1"),
		read = function(profile): number
			return profile.rebirths
		end,
		format = function(value: number): string
			return Format.comma(value)
		end,
		offset = Vector3.new(30, 0, -104),
		color = Color3.fromRGB(255, 186, 74),
	},
}

local nameCache: { [number]: string } = {}

local function displayName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = if ok and name then name else `User {userId}`
	nameCache[userId] = resolved
	return resolved
end

local function buildSign(board, zone: Zones.Zone): TextLabel
	local post = Instance.new("Part")
	post.Name = `Leaderboard_{board.id}`
	post.Anchored = true
	post.CanCollide = true
	post.Size = Vector3.new(26, 30, 1)
	post.Position = zone.origin + board.offset + Vector3.new(0, 15, 0)
	post.Color = Color3.fromRGB(32, 34, 44)
	post.Material = Enum.Material.SmoothPlastic
	post.Parent = workspace:WaitForChild("World"):WaitForChild(zone.id)

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Board"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(520, 600)
	surface.LightInfluence = 0
	surface.Parent = post

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 70)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 40
	title.TextColor3 = board.color
	title.Text = board.title
	title.Parent = surface

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 20, 0, 76)
	body.Size = UDim2.new(1, -40, 1, -90)
	body.Font = Enum.Font.Code
	body.TextSize = 22
	body.TextColor3 = Color3.fromRGB(228, 234, 242)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = "Loading..."
	body.Parent = surface

	return body
end

local function refresh(board, body: TextLabel)
	local ok, pages = pcall(function()
		return board.store:GetSortedAsync(false, GameConfig.LeaderboardSize)
	end)
	if not ok then
		warn(`[LeaderboardService] could not read {board.id}: {pages}`)
		return
	end

	local lines = {}
	for rank, entry in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(lines, string.format("%2d. %-18s %s", rank, displayName(userId), board.format(entry.value)))
		end
	end

	if #lines == 0 then
		body.Text = "Nobody yet. Could be you."
	else
		body.Text = table.concat(lines, "\n")
	end
end

local function publish(player: Player)
	local profile = DataService.get(player)
	if not profile or DataService.isVolatile(player) then
		return
	end

	for _, board in boards do
		local value = math.floor(math.clamp(board.read(profile), 0, MAX_ORDERED))
		if value > 0 then
			local ok, err = pcall(function()
				board.store:SetAsync(tostring(player.UserId), value)
			end)
			if not ok then
				warn(`[LeaderboardService] could not write {board.id} for {player.Name}: {err}`)
			end
		end
	end
end

function LeaderboardService.start()
	local zone = Zones.get(Zones.Starter)

	task.spawn(function()
		local bodies = {}
		for _, board in boards do
			bodies[board.id] = buildSign(board, zone)
		end

		while true do
			for _, board in boards do
				refresh(board, bodies[board.id])
				task.wait(1)
			end
			task.wait(GameConfig.LeaderboardRefreshInterval)
		end
	end)

	DataService.Releasing:Connect(function(player)
		publish(player)
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for _, player in Players:GetPlayers() do
				task.spawn(publish, player)
			end
		end
	end)
end

return LeaderboardService
