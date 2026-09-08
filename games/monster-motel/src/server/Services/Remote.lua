--!strict
--[[
	Remote

	Thin wrapper over the Notify and Effect remotes.

	It exists so gameplay services can talk to a client without requiring
	StateService, which needs to require *them* to build the state payload. Keeping
	the two directions in separate modules is what stops that from being a cycle.
]]

local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Net)

local Remote = {}

local notifyRemote: RemoteEvent? = nil
local effectRemote: RemoteEvent? = nil

local function notifyChannel(): RemoteEvent
	if not notifyRemote then
		notifyRemote = Net.folder():FindFirstChild("Notify") :: RemoteEvent
	end
	return notifyRemote :: RemoteEvent
end

local function effectChannel(): RemoteEvent
	if not effectRemote then
		effectRemote = Net.folder():FindFirstChild("Effect") :: RemoteEvent
	end
	return effectRemote :: RemoteEvent
end

--[[ kind is one of "info", "good", "warn" -- it only picks a colour. ]]
function Remote.notify(player: Player, message: string, kind: string?)
	notifyChannel():FireClient(player, message, kind or "info")
end

--[[ Server-wide announcement. Used by the night cycle and the Celebrity Arrival,
     which are events everybody in the server is on the same clock for. ]]
function Remote.notifyAll(message: string, kind: string?)
	notifyChannel():FireAllClients(message, kind or "info")
end

function Remote.effect(player: Player, name: string, payload: { [string]: any }?)
	effectChannel():FireClient(player, name, payload)
end

function Remote.effectAll(name: string, payload: { [string]: any }?)
	effectChannel():FireAllClients(name, payload)
end

return Remote
