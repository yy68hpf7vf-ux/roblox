--!strict
-- Formats big numbers for the UI: 1234 -> "1.23K", 12500000 -> "12.5M".

local NumberFormat = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function NumberFormat.short(n: number): string
	if n ~= n then
		return "0"
	end
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local text = string.format("%.2f", n)
	text = text:gsub("%.?0+$", "")
	return text .. SUFFIXES[index]
end

return NumberFormat
