--!nonstrict
-- Draws every player's equipped pets on this client only (no server physics).
-- Pets follow their owner in an arc behind them and swarm the owner's current target.
-- Source of truth: each player's "EquippedPets" and "TargetId" attributes set by the server.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetModels = require(Shared.PetModels)

local PetController = {}

local GROUND_OFFSET = 3.0 -- distance from HumanoidRootPart center to the ground
local PET_CENTER_HEIGHT = 0.85 -- body center above the ground for an unscaled pet

local folder: Folder
local states = {} -- [Player] = { key = string, pets = { {Model, Scale, Pos, Look} } }

local function clear(player: Player)
	local state = states[player]
	if state then
		for _, pet in state.pets do
			pet.Model:Destroy()
		end
		states[player] = nil
	end
end

local function rebuild(player: Player)
	local raw = player:GetAttribute("EquippedPets")
	if states[player] and states[player].key == raw then
		return
	end
	clear(player)
	if type(raw) ~= "string" then
		return
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(list) ~= "table" then
		return
	end
	local state = { key = raw, pets = {} }
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for _, info in list do
		local model = PetModels.build(info.Name, info.Variant)
		if model then
			model.Parent = folder
			local scale = model:GetScale()
			local start = root and root.Position or Vector3.zero
			table.insert(state.pets, { Model = model, Scale = scale, Pos = start, Look = Vector3.new(0, 0, -1) })
		end
	end
	states[player] = state
end

local function track(player: Player)
	rebuild(player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
end

function PetController.init()
	folder = Instance.new("Folder")
	folder.Name = "ClientPets"
	folder.Parent = Workspace

	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(clear)

	local breakables = Workspace:WaitForChild("Breakables")

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local alpha = 1 - math.exp(-dt * 9)
		for player, state in states do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then
				continue
			end
			local count = #state.pets
			local targetId = player:GetAttribute("TargetId")
			local targetModel = targetId and breakables:FindFirstChild(targetId)
			local groundY = root.Position.Y - GROUND_OFFSET
			local moving = root.AssemblyLinearVelocity.Magnitude > 2

			for i, pet in state.pets do
				local desired: Vector3
				local face: Vector3
				local y = groundY + PET_CENTER_HEIGHT * pet.Scale

				if targetModel then
					local center = targetModel:GetPivot().Position
					local angle = (i / count) * math.pi * 2 + now * 0.3
					local radius = 4.5 + pet.Scale
					local lunge = math.sin(now * 10 + i * 1.7) * 0.9
					local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
					desired = Vector3.new(center.X, y, center.Z) + offset * (radius - lunge)
					face = Vector3.new(center.X, y, center.Z) - desired
				else
					local spread = (i - (count + 1) / 2) * 0.7
					local back = 5 + pet.Scale
					local look = root.CFrame.LookVector
					local right = root.CFrame.RightVector
					local flat = Vector3.new(look.X, 0, look.Z)
					flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
					local rightFlat = Vector3.new(right.X, 0, right.Z)
					local bob = (moving and math.abs(math.sin(now * 8 + i)) * 0.35 or math.sin(now * 2 + i) * 0.08)
					desired = Vector3.new(root.Position.X, y + bob, root.Position.Z)
						- flat * (back * math.cos(spread))
						+ rightFlat * (back * math.sin(spread))
					face = flat
				end

				if (pet.Pos - desired).Magnitude > 80 then
					pet.Pos = desired
				else
					pet.Pos = pet.Pos:Lerp(desired, alpha)
				end
				local flatFace = Vector3.new(face.X, 0, face.Z)
				if flatFace.Magnitude > 0.05 then
					pet.Look = pet.Look:Lerp(flatFace.Unit, alpha)
				end
				if pet.Look.Magnitude > 0.01 then
					pet.Model:PivotTo(CFrame.lookAt(pet.Pos, pet.Pos + pet.Look))
				end
			end
		end
	end)
end

return PetController
