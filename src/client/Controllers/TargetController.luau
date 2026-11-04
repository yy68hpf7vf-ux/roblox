--!nonstrict
-- Lets the player pick a breakable (click / tap) and auto-targets the nearest one.
-- The server decides whether the target is valid; this only sends requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Config.Economy)

local TargetController = {}

local player = Players.LocalPlayer
local targetEvent
local highlight: Highlight
local lastSent: string? = nil

local function breakablesFolder()
	return Workspace:FindFirstChild("Breakables")
end

local function setTarget(id: string?)
	if id == lastSent then
		return
	end
	lastSent = id
	targetEvent:FireServer(id)
end

local function modelFromHit(instance: Instance?): Model?
	local folder = breakablesFolder()
	while instance and instance.Parent ~= folder do
		instance = instance.Parent
	end
	return instance
end

local function onPointer(position: Vector2)
	local folder = breakablesFolder()
	local camera = Workspace.CurrentCamera
	if not folder or not camera then
		return
	end
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	local model = result and modelFromHit(result.Instance)
	if model then
		lastSent = nil -- force resend even if it's the same id (server may have dropped it)
		setTarget(model.Name)
	end
end

function TargetController.init()
	targetEvent = Remotes.event("TargetBreakable")

	highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0.1
	highlight.Parent = Workspace

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			onPointer(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.3)
			local folder = breakablesFolder()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local current = player:GetAttribute("TargetId")
			local currentModel = current and folder and folder:FindFirstChild(current)

			highlight.Adornee = currentModel
			if not current then
				lastSent = nil
			end

			if folder and root and not currentModel then
				local best, bestDistance = nil, Economy.AutoTargetRange
				for _, model in folder:GetChildren() do
					local d = (model:GetPivot().Position - root.Position).Magnitude
					if d < bestDistance then
						best, bestDistance = model, d
					end
				end
				if best then
					setTarget(best.Name)
				end
			end
		end
	end)
end

return TargetController
