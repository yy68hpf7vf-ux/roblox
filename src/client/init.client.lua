--!strict
--[[
	Rift Miner Simulator -- client entry point

	Builds the interface, wires the remotes, starts the controllers. Every number
	shown here came from the server; this script decides where it goes on screen
	and nothing else.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Actions = require(script.Actions)
local State = require(script.State)

local Hud = require(script.Ui.Hud)
local Toast = require(script.Ui.Toast)

local DailyWindow = require(script.Ui.Windows.DailyWindow)
local PetsWindow = require(script.Ui.Windows.PetsWindow)
local RebirthWindow = require(script.Ui.Windows.RebirthWindow)
local ShopWindow = require(script.Ui.Windows.ShopWindow)
local StoreWindow = require(script.Ui.Windows.StoreWindow)
local ZonesWindow = require(script.Ui.Windows.ZonesWindow)

local MiningController = require(script.Controllers.MiningController)
local PetRenderer = require(script.Controllers.PetRenderer)
local PickRenderer = require(script.Controllers.PickRenderer)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "RiftMinerUi"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

Toast.mount(screen)

-- ---------------------------------------------------------------- windows

type Window = { root: Frame, refresh: (state: { [string]: any }) -> () }

local windows: { [string]: Window } = {}
local openName: string? = nil

local function closeAll()
	for _, window in windows do
		window.root.Visible = false
	end
	openName = nil
end

local function openWindow(name: string)
	local window = windows[name]
	if not window then
		return
	end

	if openName == name then
		closeAll()
		return
	end

	closeAll()
	window.root.Visible = true
	openName = name
	window.refresh(State.get())
end

windows.shop = ShopWindow.build(screen, closeAll)
windows.zones = ZonesWindow.build(screen, closeAll)
windows.pets = PetsWindow.build(screen, closeAll)
windows.rebirth = RebirthWindow.build(screen, closeAll)
windows.daily = DailyWindow.build(screen, closeAll)
windows.store = StoreWindow.build(screen, closeAll)

local hud = Hud.build(screen, openWindow)

-- ---------------------------------------------------------------- state

State.start()

State.Changed:Connect(function(view)
	hud.refresh(view)
	-- Only the window on screen needs repainting; the rest repaint when opened.
	if openName then
		local window = windows[openName]
		if window then
			window.refresh(view)
		end
	end
end)

-- ---------------------------------------------------------------- remotes

Net.event("Notify").OnClientEvent:Connect(function(message, kind)
	if type(message) == "string" then
		Toast.push(message, if type(kind) == "string" then kind else "info")
	end
end)

-- Pads on the map ask the client to open a window; "eggs" is the hatch pad, which
-- lives in the Pets window rather than one of its own.
local PAD_WINDOWS = {
	shop = "shop",
	eggs = "pets",
	zones = "zones",
}

Net.event("Effect").OnClientEvent:Connect(function(name, payload)
	local body = if type(payload) == "table" then payload else {}

	if name == "swing" then
		MiningController.onSwingEffect(body)
	elseif name == "sold" then
		MiningController.onSoldEffect(body)
	elseif name == "openWindow" then
		local target = PAD_WINDOWS[body.window]
		if target and openName ~= target then
			openWindow(target)
		end
	elseif name == "hatched" then
		-- The action response already toasts what hatched; this just makes sure
		-- the collection is up to date if the player is staring at it.
		if openName == "pets" then
			windows.pets.refresh(State.get())
		end
	end
end)

-- ---------------------------------------------------------------- controllers

PickRenderer.start()
PetRenderer.start()
MiningController.onLocalSwing = PickRenderer.swingLocal
MiningController.start()

-- Escape closes whatever is open, which is what everyone tries first.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and openName then
		closeAll()
	end
end)

State.await(20)
hud.refresh(State.get())

if not State.ready() then
	Toast.push("Still waiting on the server. Try rejoining if this sticks.", "warn")
end
