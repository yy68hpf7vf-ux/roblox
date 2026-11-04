--!strict
-- Pet Dynasty client bootstrap.

local Controllers = script:WaitForChild("Controllers")
local DataController = require(Controllers.DataController)
local HUDController = require(Controllers.HUDController)

DataController.init()
HUDController.init()

print("[PetDynasty] Client started")
