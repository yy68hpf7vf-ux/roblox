--!strict
-- The only code allowed to change a player's Coins. Everything is server-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local CoinService = {}

local function push(player: Player, data: { [string]: any })
	Remotes.event("DataUpdate"):FireClient(player, { Coins = data.Coins })
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Coins")
	if value and value:IsA("NumberValue") then
		value.Value = data.Coins
	end
end

local function validAmount(amount: any): boolean
	return type(amount) == "number" and amount == amount and amount > 0 and amount < math.huge
end

function CoinService.get(player: Player): number
	local data = DataService.get(player)
	return data and data.Coins or 0
end

function CoinService.add(player: Player, amount: number): boolean
	if not validAmount(amount) then
		return false
	end
	local data = DataService.get(player)
	if not data then
		return false
	end
	amount = math.floor(amount)
	data.Coins = math.min(data.Coins + amount, Economy.MaxCoins)
	data.Stats.TotalCoinsEarned += amount
	DataService.markDirty(player)
	push(player, data)
	return true
end

-- Returns true only if the player had enough Coins and they were deducted.
function CoinService.spend(player: Player, amount: number): boolean
	if not validAmount(amount) then
		return false
	end
	local data = DataService.get(player)
	if not data then
		return false
	end
	amount = math.floor(amount)
	if data.Coins < amount then
		return false
	end
	data.Coins -= amount
	DataService.markDirty(player)
	push(player, data)
	return true
end

function CoinService.init()
	local function setup(player: Player)
		local data = DataService.waitFor(player)
		if not data then
			return
		end
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local coins = Instance.new("NumberValue")
		coins.Name = "Coins"
		coins.Value = data.Coins
		coins.Parent = stats
		stats.Parent = player
	end
	DataService.PlayerLoaded:Connect(setup)
end

return CoinService
