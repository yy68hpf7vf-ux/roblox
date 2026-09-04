--!strict
--[[
	MiningService

	Owns node health and every ore award in the game.

	The client asks to swing at a node; it never says how much ore it got. The
	server checks the cooldown, the distance, the zone the player is standing in
	and whether they have access to it, then does the arithmetic itself. A client
	that lies about any of it gets a dropped request, not free ore.

	Nodes are shared between everyone in the server. Breaking one is a small group
	event -- it drops for whoever landed the last hit and respawns a few seconds
	later, so a busy zone stays busy instead of turning into a race for spawns.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Tools = require(Shared.Config.Tools)
local Zones = require(Shared.Config.Zones)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local QuestService = require(script.Parent.QuestService)
local Remote = require(script.Parent.Remote)

local MiningService = {}

type NodeState = {
	part: BasePart,
	zone: Zones.Zone,
	health: number,
	alive: boolean,
}

local nodes: { [BasePart]: NodeState } = {}
local lastSwingAt: { [Player]: number } = {}

local function respawn(state: NodeState)
	task.delay(GameConfig.NodeRespawnTime, function()
		if not state.part.Parent then
			return
		end
		state.health = state.zone.nodeHealth
		state.alive = true
		state.part.Transparency = 0
		state.part.CanCollide = true
		local light = state.part:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = true
		end
	end)
end

local function breakNode(state: NodeState)
	state.alive = false
	state.part.Transparency = 1
	state.part.CanCollide = false
	local light = state.part:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = false
	end
	respawn(state)
end

--[[ The zone a player is physically standing in, which is not necessarily the
     zone they last travelled to -- they may have walked. Returns nil if they are
     not on any island. ]]
local function zoneAt(position: Vector3): Zones.Zone?
	for _, zone in Zones.List do
		local delta = position - zone.origin
		if math.abs(delta.X) <= 124 and math.abs(delta.Z) <= 124 then
			return zone
		end
	end
	return nil
end

local function handleSwing(player: Player, nodePart: unknown)
	if typeof(nodePart) ~= "Instance" or not nodePart:IsA("BasePart") then
		return
	end

	local state = nodes[nodePart]
	if not state or not state.alive then
		return
	end

	local now = os.clock()
	local previous = lastSwingAt[player]
	if previous and (now - previous) < (GameConfig.SwingCooldown - GameConfig.SwingRateGrace) then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	if (root.Position - nodePart.Position).Magnitude > GameConfig.MiningRange then
		return
	end

	local profile = DataService.get(player)
	if not profile then
		return
	end

	local zone = state.zone
	if zoneAt(root.Position) ~= zone then
		return
	end
	if not EconomyService.hasZone(player, profile, zone) then
		return
	end

	lastSwingAt[player] = now

	local tool = Tools.get(profile.tool)
	local perSwing = Zones.orePerSwing(zone, tool.power) * EconomyService.oreMultiplier(profile)

	state.health -= tool.power
	local broke = state.health <= 0

	local gained = perSwing
	if broke then
		gained += perSwing * GameConfig.NodeBreakBonusSwings
	end
	gained = math.min(gained, GameConfig.MaxOrePerBreak)

	local capacity = EconomyService.capacity(player, profile)
	local space = capacity - profile.ore
	local stored = math.max(0, math.min(gained, space))

	if stored > 0 then
		profile.ore += stored
		profile.stats.oreMined += stored
		QuestService.addProgress(player, profile, "mine_ore", stored)
	end

	if broke then
		profile.stats.nodesBroken += 1
		QuestService.addProgress(player, profile, "break_nodes", 1)
		breakNode(state)
	end

	Remote.effect(player, "swing", {
		node = nodePart,
		ore = stored,
		broke = broke,
		full = space <= 0,
	})

	EconomyService.markDirty(player)
end

function MiningService.register(nodesByZone: { [string]: { BasePart } })
	for zoneId, list in nodesByZone do
		local zone = Zones.get(zoneId)
		for _, nodePart in list do
			nodes[nodePart] = {
				part = nodePart,
				zone = zone,
				health = zone.nodeHealth,
				alive = true,
			}
		end
	end
end

function MiningService.zoneAt(position: Vector3): Zones.Zone?
	return zoneAt(position)
end

function MiningService.start()
	local swingRemote = Net.folder():FindFirstChild("Swing") :: RemoteEvent
	swingRemote.OnServerEvent:Connect(function(player, nodePart)
		local ok, err = pcall(handleSwing, player, nodePart)
		if not ok then
			warn(`[MiningService] swing failed for {player.Name}: {err}`)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSwingAt[player] = nil
	end)
end

return MiningService
