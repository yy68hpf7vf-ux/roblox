--!strict
-- Keeps a local, read-only copy of the player's data for the UI.
-- The server is the source of truth; this is only for display.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local DataController = {}

local data: { [string]: any } = {}
local listeners: { [string]: { (value: any) -> () } } = {}

function DataController.get(key: string): any
	return data[key]
end

-- Calls `callback` with the current value (if any) and every time it changes.
function DataController.observe(key: string, callback: (value: any) -> ()): () -> ()
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], callback)
	if data[key] ~= nil then
		task.spawn(callback, data[key])
	end
	return function()
		local list = listeners[key]
		local index = table.find(list, callback)
		if index then
			table.remove(list, index)
		end
	end
end

local function apply(changes: { [string]: any })
	for key, value in changes do
		data[key] = value
		for _, callback in listeners[key] or {} do
			task.spawn(callback, value)
		end
	end
end

function DataController.init()
	Remotes.event("DataUpdate").OnClientEvent:Connect(function(changes)
		if type(changes) == "table" then
			apply(changes)
		end
	end)
	task.spawn(function()
		local snapshot = Remotes.func("GetSnapshot"):InvokeServer()
		if type(snapshot) == "table" then
			apply(snapshot)
		end
	end)
end

return DataController
