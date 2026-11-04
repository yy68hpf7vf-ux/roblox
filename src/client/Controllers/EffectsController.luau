--!nonstrict
-- Visual feedback: damage numbers, break bursts, and Coin pop-ups.
-- (Sounds are added in the polish phase once audio assets are chosen.)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local NumberFormat = require(Shared.Util.NumberFormat)

local EffectsController = {}

local function floatingText(position: Vector3, text: string, color: Color3, size: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = Workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size * 4, size)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(30, 20, 40)
	stroke.Parent = label

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { Position = position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.9), { Transparency = 1 }):Play()
	Debris:AddItem(anchor, 1)
end

local function burst(position: Vector3, color: Color3, size: number)
	for _ = 1, 14 do
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.one * (0.4 + math.random() * 0.5)
		chunk.Color = color
		chunk.Material = Enum.Material.Neon
		chunk.Anchored = true
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.Position = position
		chunk.Parent = Workspace
		local direction = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		local target = position + direction * (3 + math.random() * size)
		TweenService:Create(chunk, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = target,
			Size = Vector3.zero,
			Transparency = 1,
		}):Play()
		Debris:AddItem(chunk, 0.7)
	end
end

function EffectsController.init()
	Remotes.event("BreakableHit").OnClientEvent:Connect(function(_, damage, _, position)
		floatingText(position + Vector3.new((math.random() - 0.5) * 3, 3, (math.random() - 0.5) * 3), NumberFormat.short(damage), Color3.fromRGB(255, 255, 255), 22)
	end)
	Remotes.event("BreakableBroken").OnClientEvent:Connect(function(position, color, size)
		burst(position, color, size)
	end)
	Remotes.event("CoinReward").OnClientEvent:Connect(function(position, amount)
		floatingText(position + Vector3.new(0, 2, 0), "+" .. NumberFormat.short(amount), Color3.fromRGB(255, 215, 60), 34)
	end)
end

return EffectsController
