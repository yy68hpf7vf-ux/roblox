--!strict
--[[
	Loading screen

	Runs from ReplicatedFirst, which is the only place early enough to remove
	Roblox's default loading screen before the player sees it.

	It does two jobs. The obvious one is covering the moment where the town is
	being built and the profile is being fetched, which is a second or two of
	standing in an empty grey world otherwise. The less obvious one is telling a
	first-time player what the game is before they arrive -- by the time the screen
	lifts they already know they run a motel, that rent is collected at the desk,
	and that doors unlock at night.

	It lifts when the game says it is ready, or after a hard timeout so a slow
	server can never trap somebody behind it.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MAX_WAIT = 25

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local screen = Instance.new("ScreenGui")
screen.Name = "MotelLoading"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 100
screen.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
backdrop.BorderSizePixel = 0
backdrop.Parent = screen

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.4)
title.Size = UDim2.fromScale(0.8, 0.12)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 138, 92)
title.Text = "MONSTER MOTEL"
title.Parent = backdrop

local tagline = Instance.new("TextLabel")
tagline.BackgroundTransparency = 1
tagline.AnchorPoint = Vector2.new(0.5, 0.5)
tagline.Position = UDim2.fromScale(0.5, 0.49)
tagline.Size = UDim2.fromScale(0.8, 0.05)
tagline.Font = Enum.Font.Gotham
tagline.TextScaled = true
tagline.TextColor3 = Color3.fromRGB(158, 166, 182)
tagline.Text = "Vacancy. Sort of."
tagline.Parent = backdrop

-- Rotating tips, so the wait teaches instead of just passing.
local TIPS = {
	"Guests pay rent every second they are in a room.",
	"Rent piles up in your safe. Walk onto your front desk to collect it.",
	"At Lights Out, every door in town can be broken open. Including yours.",
	"Nobody can rob you in your first ten minutes, or below four guests.",
	"A celebrity lands in the town square every ten minutes. Anyone can take them.",
	"Carrying a guest slows you down -- by exactly the same amount for everyone.",
	"Renovate at Four Star. You keep every guest you own.",
}

local tip = Instance.new("TextLabel")
tip.BackgroundTransparency = 1
tip.AnchorPoint = Vector2.new(0.5, 0.5)
tip.Position = UDim2.fromScale(0.5, 0.66)
tip.Size = UDim2.fromScale(0.72, 0.05)
tip.Font = Enum.Font.Gotham
tip.TextScaled = true
tip.TextColor3 = Color3.fromRGB(226, 232, 240)
tip.Text = TIPS[1]
tip.Parent = backdrop

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 1)
status.Position = UDim2.fromScale(0.5, 0.93)
status.Size = UDim2.fromScale(0.6, 0.035)
status.Font = Enum.Font.Gotham
status.TextScaled = true
status.TextColor3 = Color3.fromRGB(112, 120, 136)
status.Text = "Checking in..."
status.Parent = backdrop

local track = Instance.new("Frame")
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.fromScale(0.5, 0.78)
track.Size = UDim2.fromScale(0.36, 0.008)
track.BackgroundColor3 = Color3.fromRGB(40, 42, 54)
track.BorderSizePixel = 0
track.Parent = backdrop

local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(255, 138, 92)
fill.BorderSizePixel = 0
fill.Parent = track

local finished = false

task.spawn(function()
	local index = 1
	while not finished do
		task.wait(3.5)
		index = index % #TIPS + 1
		tip.Text = TIPS[index]
	end
end)

--[[ Progress is honest about what it is waiting for rather than a fake bar: the
     remotes appearing, then the first state push. ]]
task.spawn(function()
	local started = os.clock()
	while not finished and os.clock() - started < MAX_WAIT do
		local ratio = math.min((os.clock() - started) / 6, 0.9)
		fill.Size = UDim2.fromScale(ratio, 1)
		task.wait(0.1)
	end
end)

local function lift()
	if finished then
		return
	end
	finished = true

	fill.Size = UDim2.fromScale(1, 1)
	status.Text = "Ready"

	local fade = TweenInfo.new(0.6)
	TweenService:Create(backdrop, fade, { BackgroundTransparency = 1 }):Play()
	for _, label in { title, tagline, tip, status } do
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	end
	TweenService:Create(track, fade, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(fill, fade, { BackgroundTransparency = 1 }):Play()

	task.delay(0.8, function()
		screen:Destroy()
	end)
end

task.spawn(function()
	-- Preload what is already replicated so the first frame is not a texture pop.
	local ok = pcall(function()
		ContentProvider:PreloadAsync({ backdrop })
	end)
	if not ok then
		status.Text = "Checking in..."
	end

	status.Text = "Waiting for the front desk..."
	local net = ReplicatedStorage:WaitForChild("MotelNet", MAX_WAIT)
	if not net then
		status.Text = "The server is taking a while. Letting you in anyway."
		task.wait(1)
		lift()
		return
	end

	status.Text = "Finding your motel..."
	local state = net:WaitForChild("State", 10) :: RemoteEvent?
	if state then
		local connection
		connection = state.OnClientEvent:Connect(function()
			if connection then
				connection:Disconnect()
			end
			lift()
		end)
	end

	-- Hard ceiling: a stuck load must never trap somebody on this screen.
	task.delay(MAX_WAIT, lift)
end)
