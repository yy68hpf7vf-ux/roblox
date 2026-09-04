--!strict
--[[
	State
	The client's copy of the server's view of the player. Read-only: nothing here
	is ever written locally, because the server would only overwrite it on the next
	push and the two would disagree in between.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local State = {}

export type View = { [string]: any }

State.Changed = Signal.new() :: Signal.Signal<View>

local current: View = {}
local received = false

function State.get(): View
	return current
end

function State.ready(): boolean
	return received
end

--[[ Waits for the first push. Used by anything that would otherwise render an
     empty HUD for a second while the profile loads. ]]
function State.await(timeout: number?): View
	local deadline = os.clock() + (timeout or 15)
	while not received and os.clock() < deadline do
		task.wait(0.05)
	end
	return current
end

function State.start()
	Net.event("State").OnClientEvent:Connect(function(view)
		if type(view) ~= "table" then
			return
		end
		current = view
		received = true
		State.Changed:Fire(view)
	end)
end

return State
