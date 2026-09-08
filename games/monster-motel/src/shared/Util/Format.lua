--!strict
--[[
	Format
	Number and time formatting shared by every UI surface so the same value never
	renders two different ways in two different windows.

	Deliberately identical to the copy in the Rift Miner project. Each game is a
	self-contained Rojo project that builds to its own place, so they keep their own
	copies rather than sharing a folder neither build could resolve.
]]

local Format = {}

local SUFFIXES = {
	"",
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
	"Ud",
	"Dd",
	"Td",
	"Qad",
	"Qid",
}

--[[ 1234567 -> "1.23M". Values under 1,000 keep their exact digits because that
     is the range where a new player is counting individual ore. ]]
function Format.short(value: number): string
	if value ~= value or value == math.huge then
		return "Inf"
	end

	local sign = if value < 0 then "-" else ""
	local amount = math.abs(value)

	if amount < 1000 then
		if amount % 1 == 0 then
			return sign .. tostring(math.floor(amount))
		end
		return sign .. string.format("%.1f", amount)
	end

	local tier = math.floor(math.log(amount, 1000))
	tier = math.clamp(tier, 1, #SUFFIXES - 1)

	local scaled = amount / (1000 ^ tier)
	local suffix = SUFFIXES[tier + 1]

	if scaled >= 100 then
		return string.format("%s%.0f%s", sign, scaled, suffix)
	elseif scaled >= 10 then
		return string.format("%s%.1f%s", sign, scaled, suffix)
	end
	return string.format("%s%.2f%s", sign, scaled, suffix)
end

--[[ 1234567 -> "1,234,567". Used where an exact figure matters, such as the
     price confirmation on a purchase. ]]
function Format.comma(value: number): string
	local whole = tostring(math.floor(math.abs(value)))
	local grouped = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	grouped = grouped:gsub("^,", "")
	return (if value < 0 then "-" else "") .. grouped
end

--[[ 3725 -> "1h 2m". Rounded down; the shortest reading that is still true. ]]
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

--[[ 0.035 -> "3.5%". Percentages below 0.1% keep enough digits to stay honest
     rather than rounding a real chance to "0%". ]]
function Format.percent(fraction: number): string
	local value = fraction * 100
	if value >= 10 then
		return string.format("%.0f%%", value)
	elseif value >= 1 then
		return string.format("%.1f%%", value)
	elseif value >= 0.1 then
		return string.format("%.2f%%", value)
	end
	return string.format("%.3f%%", value)
end

function Format.multiplier(value: number): string
	if value >= 100 or value % 1 == 0 then
		return string.format("x%s", Format.short(value))
	end
	return string.format("x%.2f", value)
end

return Format
