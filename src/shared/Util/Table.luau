--!strict
-- Small table helpers shared by server and client.

local Table = {}

function Table.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy: any = {}
	for k, v in pairs(value :: any) do
		copy[k] = Table.deepCopy(v)
	end
	return copy
end

-- Adds any keys from `template` that are missing in `target` (recursively).
-- Never overwrites values the player already has.
function Table.reconcile(target: any, template: any)
	for k, v in pairs(template) do
		if target[k] == nil then
			target[k] = Table.deepCopy(v)
		elseif type(target[k]) == "table" and type(v) == "table" then
			Table.reconcile(target[k], v)
		end
	end
end

return Table
