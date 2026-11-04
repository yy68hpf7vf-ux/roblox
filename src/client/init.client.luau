--!nonstrict
-- Pet Dynasty client bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local Controllers = script:WaitForChild("Controllers")
local DataController = require(Controllers.DataController)
local HUDController = require(Controllers.HUDController)
local InventoryController = require(Controllers.InventoryController)
local TargetController = require(Controllers.TargetController)
local EffectsController = require(Controllers.EffectsController)
local PetController = require(Controllers.PetController)

DataController.init()
HUDController.init()
InventoryController.init()
EffectsController.init()

Remotes.event("Notify").OnClientEvent:Connect(function(text)
	if type(text) == "string" then
		HUDController.toast(text)
	end
end)

-- These wait for the server to create the Breakables folder.
task.spawn(function()
	workspace:WaitForChild("Breakables")
	TargetController.init()
	PetController.init()
end)

print("[PetDynasty] Client started")
