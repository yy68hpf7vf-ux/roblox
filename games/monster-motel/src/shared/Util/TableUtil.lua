--!strict
--[[
	TableUtil
	Deep copy and reconcile, used by the data layer. Kept tiny and dependency-free
	because it runs on every profile load.
]]

local TableUtil = {}

function TableUtil.deepCopy<T>(source: T): T
	if type(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in source :: any do
		copy[key] = TableUtil.deepCopy(value)
	end
	return (copy :: any) :: T
end

--[[ Fills in keys the template has and the saved data does not, recursing into
     nested tables. Extra keys in `data` are left alone so a rollback to an older
     server build does not delete a newer field. ]]
function TableUtil.reconcile(data: { [any]: any }, template: { [any]: any }): { [any]: any }
	for key, templateValue in template do
		local currentValue = data[key]
		if currentValue == nil then
			data[key] = TableUtil.deepCopy(templateValue)
		elseif type(templateValue) == "table" and type(currentValue) == "table" then
			-- Arrays in this schema are owned wholesale by the save (pet lists,
			-- equipped lists); only reconcile dictionaries.
			if next(templateValue) == nil or type(next(templateValue)) == "string" then
				TableUtil.reconcile(currentValue, templateValue)
			end
		end
	end
	return data
end

function TableUtil.count(source: { [any]: any }): number
	local total = 0
	for _ in source do
		total += 1
	end
	return total
end

function TableUtil.keys<K, V>(source: { [K]: V }): { K }
	local out = {}
	for key in source do
		table.insert(out, key)
	end
	return out
end

return TableUtil
