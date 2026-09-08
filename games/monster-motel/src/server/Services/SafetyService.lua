--!strict
--[[
	SafetyService

	The things a published Roblox game needs that no design document mentions.

	  * **Nobody falls out of the world.** The map is a ring of islands over
	    nothing; a player who walks off the edge would otherwise fall forever, and
	    a thief mid-carry would take a guest with them. Anyone below the kill plane
	    is put back at their own motel, and TheftService already returns a carried
	    guest when they die.
	  * **A character never spawns holding nothing to do.** Respawns land at your
	    own motel rather than in the square, which is where you left off.

	None of this is glamorous and all of it is the difference between a game that
	feels finished and one that feels like a prototype.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlotService = require(script.Parent.PlotService)

local SafetyService = {}

-- Anything below this has left the map.
local KILL_PLANE = -120
local CHECK_INTERVAL = 1

local function rescue(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local home = PlotService.spawnCFrame(player)
	if home then
		-- Teleport rather than kill: dying would drop a carried guest, and falling
		-- off a ledge should not cost somebody their raid.
		root.CFrame = home
		root.AssemblyLinearVelocity = Vector3.zero
	else
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end
end

function SafetyService.start()
	local accumulator = 0

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < CHECK_INTERVAL then
			return
		end
		accumulator = 0

		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.Y < KILL_PLANE then
				rescue(player)
			end
		end
	end)
end

return SafetyService
