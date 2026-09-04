--!strict
--[[
	ZonesWindow
	Travel and unlocks. Every zone is listed from the start, including the ones a
	long way off -- seeing the whole map is most of the reason to keep going, and
	hiding it just makes the game look smaller than it is.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Util.Format)

local Actions = require(script.Parent.Parent.Parent.Actions)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Widgets = require(script.Parent.Parent.Widgets)

local ZonesWindow = {}

function ZonesWindow.build(parent: ScreenGui, close: () -> ())
	local window = Widgets.window("Zones", "Deeper seams sell ore for more. Your pick works the same everywhere.", close)
	window.root.Parent = parent

	local painters: { (state: { [string]: any }) -> () } = {}

	for index, zone in Zones.List do
		local row = Widgets.row(index, window.body)
		row.swatch.BackgroundColor3 = zone.nodeColor
		row.title.Text = zone.name

		row.action.Activated:Connect(function()
			local state = State.get()
			local unlocked = (state.unlockedZones or {})[zone.id] == true
			local viaPass = zone.gamepass ~= nil and (state.passes or {})[zone.gamepass] == true

			if unlocked or viaPass then
				Actions.invoke("travel", { id = zone.id })
			elseif zone.gamepass then
				Actions.invoke("promptGamepass", { id = zone.gamepass })
			else
				Actions.invoke("unlockZone", { id = zone.id })
			end
		end)

		table.insert(painters, function(state)
			local unlocked = (state.unlockedZones or {})[zone.id] == true
			local viaPass = zone.gamepass ~= nil and (state.passes or {})[zone.gamepass] == true
			local rebirthsShort = (state.rebirths or 0) < zone.rebirths
			local here = state.zone == zone.id

			row.desc.Text = `{Format.short(zone.oreValue)} Crystals per ore  ·  <font color='#8A93A6'>{zone.desc}</font>`

			if here then
				row.action.Text = "You are here"
				row.action.BackgroundColor3 = Theme.Color.PanelRaised
				row.action.TextColor3 = Theme.Color.Good
			elseif unlocked or viaPass then
				row.action.Text = "Travel"
				row.action.BackgroundColor3 = Theme.Color.Good
				row.action.TextColor3 = Theme.Color.Panel
			elseif zone.gamepass then
				row.action.Text = "VIP pass"
				row.action.BackgroundColor3 = Theme.Color.Robux
				row.action.TextColor3 = Theme.Color.Panel
			elseif rebirthsShort then
				row.action.Text = `{zone.rebirths} rebirths`
				row.action.BackgroundColor3 = Theme.Color.Locked
				row.action.TextColor3 = Theme.Color.TextDim
			else
				local affordable = (state.crystals or 0) >= zone.unlockCost
				row.action.Text = `Unlock {Format.short(zone.unlockCost)}`
				row.action.BackgroundColor3 = if affordable then Theme.Color.Accent else Theme.Color.PanelRaised
				row.action.TextColor3 = if affordable then Theme.Color.Panel else Theme.Color.TextFaint
			end
		end)
	end

	local function refresh(state)
		for _, paint in painters do
			paint(state)
		end
	end

	return { root = window.root, refresh = refresh }
end

return ZonesWindow
