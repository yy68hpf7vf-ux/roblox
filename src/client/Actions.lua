--!strict
--[[
	Actions
	Client side of the Invoke remote. Every call reports its result through the
	toast strip, so no button in the game can fail silently.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Toast = require(script.Parent.Ui.Toast)

local Actions = {}

local inFlight = 0
local MAX_IN_FLIGHT = 4

--[[ Fires and reports. Returns the response so a caller can branch on it, but
     most callers just want the toast. ]]
function Actions.invoke(action: string, payload: { [string]: any }?, quiet: boolean?): Net.Response
	if inFlight >= MAX_IN_FLIGHT then
		return { ok = false, message = "One moment." }
	end

	inFlight += 1
	local ok, response = pcall(function()
		return Net.func("Invoke"):InvokeServer(action, payload or {})
	end)
	inFlight -= 1

	if not ok or type(response) ~= "table" then
		Toast.push("Lost connection to the server.", "bad")
		return { ok = false, message = "No response." }
	end

	local typed = response :: Net.Response
	if typed.message and #typed.message > 0 and not quiet then
		Toast.push(typed.message, if typed.ok then "good" else "warn")
	end

	return typed
end

function Actions.swing(node: BasePart)
	Net.event("Swing"):FireServer(node)
end

return Actions
