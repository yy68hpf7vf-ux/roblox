--!strict
--[[
	LeaderboardService

	Two global boards on signs beside the town square: highest rent per second, and
	most renovations.

	Rent is the one everybody cares about, and putting it on a sign in the middle of
	the map is deliberate -- it is the flex that makes people keep building, and it
	tells raiders which motel is worth a night. A number nobody else can see is not
	worth chasing.

	Entries are written on save rather than on every change, and read on a timer
	shared by the whole server, so the boards cost a handful of requests a minute.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local LeaderboardService = {}

-- OrderedDataStore values must fit a signed 64-bit integer.
local MAX_ORDERED = 9e15

local boards = {
	{
		id = "rent",
		title = "Highest Rent",
		store = DataStoreService:GetOrderedDataStore("MonsterMotel_TopRent_v1"),
		offset = Vector3.new(-84, 0, 84),
		color = Color3.fromRGB(96, 220, 138),
		read = function(player: Player, profile: any): number
			return EconomyService.rentPerSecond(player, profile)
		end,
		format = function(value: number): string
			return "$" .. Format.short(value) .. "/s"
		end,
	},
	{
		id = "renovations",
		title = "Most Renovations",
		store = DataStoreService:GetOrderedDataStore("MonsterMotel_TopRenovations_v1"),
		offset = Vector3.new(84, 0, 84),
		color = Color3.fromRGB(255, 186, 74),
		read = function(_player: Player, profile: any): number
			return profile.renovations
		end,
		format = function(value: number): string
			return Format.comma(value) .. "★"
		end,
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

local function buildSign(board): TextLabel
	local post = Instance.new("Part")
	post.Name = `Leaderboard_{board.id}`
	post.Anchored = true
	post.CanCollide = true
	post.Size = Vector3.new(30, 34, 1)
	post.Position = board.offset + Vector3.new(0, 17, 0)
	post.Color = Color3.fromRGB(30, 32, 44)
	post.Material = Enum.Material.SmoothPlastic
	post.Parent = workspace:WaitForChild("World"):WaitForChild("TownSquare")

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Board"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(540, 620)
	surface.LightInfluence = 0
	surface.Parent = post

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 72)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 42
	title.TextColor3 = board.color
	title.Text = board.title
	title.Parent = surface

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 20, 0, 78)
	body.Size = UDim2.new(1, -40, 1, -92)
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
			table.insert(lines, string.format("%2d. %-17s %s", rank, displayName(userId), board.format(entry.value)))
		end
	end

	body.Text = if #lines == 0 then "Nobody yet. Could be you." else table.concat(lines, "\n")
end

local function publish(player: Player)
	local profile = DataService.get(player)
	if not profile or DataService.isVolatile(player) then
		return
	end

	for _, board in boards do
		local value = math.floor(math.clamp(board.read(player, profile), 0, MAX_ORDERED))
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
	task.spawn(function()
		local bodies = {}
		for _, board in boards do
			bodies[board.id] = buildSign(board)
		end

		while true do
			for _, board in boards do
				refresh(board, bodies[board.id])
				task.wait(1)
			end
			task.wait(GameConfig.LeaderboardRefreshInterval)
		end
	end)

	DataService.Releasing:Connect(publish)

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
