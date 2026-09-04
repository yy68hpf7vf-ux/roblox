--!strict
--[[
	MiningController

	Input, target selection and hit feedback.

	Holding the mouse (or touching the screen) swings at the nearest node in range.
	The client picks the target and paces the swings; the server decides whether
	each one counts and how much it is worth. Auto Mine holds the button for you at
	exactly the same rate -- it is the clicking it removes, not the waiting.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)

local MiningController = {}

local player = Players.LocalPlayer

local holding = false
local lastSwing = 0
local currentTarget: BasePart? = nil
local highlight: Highlight? = nil

--[[ Every node in the world, cached.

     The server builds the map once and never adds or removes a node -- breaking
     one hides it rather than destroying it -- so walking the tree on every frame
     would allocate a table per island per frame to rediscover the same list. The
     cache is built on first use, once the world has streamed in. ]]
local nodeCache: { BasePart }? = nil

local function allNodes(): { BasePart }
	if nodeCache then
		return nodeCache
	end

	local world = workspace:FindFirstChild("World")
	if not world then
		return {}
	end

	local found: { BasePart } = {}
	for _, island in world:GetChildren() do
		local nodes = island:FindFirstChild("Nodes")
		if nodes then
			for _, node in nodes:GetChildren() do
				if node:IsA("BasePart") then
					table.insert(found, node)
				end
			end
		end
	end

	if #found > 0 then
		nodeCache = found
	end
	return found
end

--[[ Nearest node the player can actually hit. A node mid-respawn is fully
     transparent, which is also how the client knows to skip it. ]]
local function findTarget(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end

	local origin = root.Position
	local best: BasePart? = nil
	local bestDistance = GameConfig.MiningRange

	for _, node in allNodes() do
		if node.Transparency < 1 then
			local distance = (node.Position - origin).Magnitude
			if distance < bestDistance then
				best = node
				bestDistance = distance
			end
		end
	end

	return best
end

local function setTarget(node: BasePart?)
	if currentTarget == node then
		return
	end
	currentTarget = node

	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.FillTransparency = 0.75
		highlight.OutlineTransparency = 0
		highlight.FillColor = Color3.fromRGB(255, 255, 255)
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.Parent = player:WaitForChild("PlayerGui")
	end

	highlight.Adornee = node
	highlight.Enabled = node ~= nil
end

--[[ A number that floats off the node and fades. Cheap, and it is the only
     feedback that tells a player their multiplier actually did something. ]]
local function floatText(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 2)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui

	TweenService:Create(anchor, TweenInfo.new(0.9), { Position = position + Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	task.delay(1, function()
		anchor:Destroy()
	end)
end

local function shake(node: BasePart)
	local original = node.CFrame
	local nudge = original * CFrame.new(0, -0.35, 0)
	TweenService:Create(node, TweenInfo.new(0.06), { CFrame = nudge }):Play()
	task.delay(0.07, function()
		if node.Parent then
			TweenService:Create(node, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				CFrame = original,
			}):Play()
		end
	end)
end

local function burst(node: BasePart)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = node.Position
	attachment.Parent = workspace.Terrain

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(node.Color)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(14, 24)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(22)

	task.delay(1.2, function()
		attachment:Destroy()
	end)
end

function MiningController.onSwingEffect(payload: { [string]: any })
	local node = payload.node
	if typeof(node) ~= "Instance" or not node:IsA("BasePart") then
		return
	end

	shake(node)

	if payload.broke then
		burst(node)
	end

	if payload.full then
		floatText(node.Position + Vector3.new(0, 4, 0), "Backpack full", Color3.fromRGB(255, 176, 92))
	elseif (payload.ore or 0) > 0 then
		floatText(node.Position + Vector3.new(0, 4, 0), `+{Format.short(payload.ore)}`, Color3.fromRGB(226, 236, 246))
	end
end

function MiningController.onSoldEffect(payload: { [string]: any })
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	floatText(
		root.Position + Vector3.new(0, 6, 0),
		`+{Format.short(payload.crystals or 0)} Crystals`,
		Color3.fromRGB(132, 220, 240)
	)
end

local function autoMineEnabled(): boolean
	local state = State.get()
	return (state.passes or {}).automine == true
end

function MiningController.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holding = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holding = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		local target = findTarget()
		setTarget(target)

		if not target then
			return
		end
		if not holding and not autoMineEnabled() then
			return
		end

		local now = os.clock()
		if now - lastSwing < GameConfig.SwingCooldown then
			return
		end
		lastSwing = now

		Actions.swing(target)
		MiningController.onLocalSwing()
	end)
end

--[[ Set by PickRenderer so the pick animates on the swing the client sent,
     rather than waiting for the server to confirm it. ]]
MiningController.onLocalSwing = function() end

return MiningController
