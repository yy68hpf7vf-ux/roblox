--!nonstrict
-- Main HUD. Phase 1: Coin display. More buttons are added in later phases.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NumberFormat = require(Shared.Util.NumberFormat)

local DataController = require(script.Parent.DataController)

local HUDController = {}
local toastGui: ScreenGui? = nil

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- Small message that fades after a couple of seconds.
function HUDController.toast(text: string)
	if not toastGui then
		return
	end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0.85, 0)
	label.Size = UDim2.new(0, 360, 0, 36)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 20
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Text = text
	label.Parent = toastGui
	corner(label, 10)
	TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, 0, 0.8, 0) }):Play()
	task.delay(2.2, function()
		local fade = TweenService:Create(label, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
end

function HUDController.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "PetDynastyHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	toastGui = gui

	local panel = Instance.new("Frame")
	panel.Name = "CoinPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 10)
	panel.Size = UDim2.new(0, 190, 0, 44)
	panel.BackgroundColor3 = Color3.fromRGB(40, 60, 150)
	panel.Parent = gui
	corner(panel, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.Parent = panel

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(90, 120, 235), Color3.fromRGB(45, 55, 150))
	gradient.Rotation = 90
	gradient.Parent = panel

	local icon = Instance.new("Frame")
	icon.Name = "CoinIcon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 8, 0.5, 0)
	icon.Size = UDim2.new(0, 28, 0, 28)
	icon.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	icon.Parent = panel
	corner(icon, 14)
	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.fromRGB(200, 130, 0)
	iconStroke.Thickness = 2
	iconStroke.Parent = icon

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 44, 0, 0)
	label.Size = UDim2.new(1, -52, 1, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "0"
	label.Parent = panel
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 2
	textStroke.Color = Color3.fromRGB(20, 20, 60)
	textStroke.Parent = label

	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local first = true
	DataController.observe("Coins", function(coins: number)
		label.Text = NumberFormat.short(coins)
		if first then
			first = false
			return
		end
		-- Small "pop" when the amount changes.
		scale.Scale = 1.12
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

return HUDController
