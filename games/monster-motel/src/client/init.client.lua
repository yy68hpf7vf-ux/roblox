--!strict
--[[
	Monster Motel -- client entry point

	Builds the interface, wires the remotes, starts the raid controller. Every
	number on screen came from the server; this script decides where it goes.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local State = require(script.State)

local Feed = require(script.Ui.Feed)
local Hud = require(script.Ui.Hud)
local Toast = require(script.Ui.Toast)

local ArrivalsWindow = require(script.Ui.Windows.ArrivalsWindow)
local DailyWindow = require(script.Ui.Windows.DailyWindow)
local GuestsWindow = require(script.Ui.Windows.GuestsWindow)
local IndexWindow = require(script.Ui.Windows.IndexWindow)
local MotelWindow = require(script.Ui.Windows.MotelWindow)
local RenovateWindow = require(script.Ui.Windows.RenovateWindow)
local StoreWindow = require(script.Ui.Windows.StoreWindow)

local FeedbackController = require(script.Controllers.FeedbackController)
local RaidController = require(script.Controllers.RaidController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "MonsterMotelUi"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

Toast.mount(screen)
Feed.mount(screen)
FeedbackController.start(screen)

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

windows.arrivals = ArrivalsWindow.build(screen, closeAll)
windows.guests = GuestsWindow.build(screen, closeAll)
windows.index = IndexWindow.build(screen, closeAll)
windows.motel = MotelWindow.build(screen, closeAll)
windows.renovate = RenovateWindow.build(screen, closeAll)
windows.daily = DailyWindow.build(screen, closeAll)
windows.store = StoreWindow.build(screen, closeAll)

local hud = Hud.build(screen, openWindow)

-- ---------------------------------------------------------------- state

State.start()

State.Changed:Connect(function(view)
	hud.refresh(view)
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

Net.event("Effect").OnClientEvent:Connect(function(name, payload)
	local body = if type(payload) == "table" then payload else {}

	if name == "breakProgress" then
		hud.setBreakProgress(body.elapsed or 0, body.needed or 0)
	elseif name == "breakCancelled" then
		hud.setBreakProgress(0, 0)
	elseif name == "doorOpen" then
		hud.setBreakProgress(0, 0)
		if body.plot then
			RaidController.setDoorOpen(body.plot, true)
		end
	elseif name == "phase" then
		-- Sunrise revokes every door the server had opened for us.
		if body.night == false then
			RaidController.clearDoors()
		end
		hud.setBreakProgress(0, 0)
	elseif name == "carrying" then
		hud.setBreakProgress(0, 0)
	elseif name == "stoleGuest" then
		hud.setBreakProgress(0, 0)
		FeedbackController.onStole(body.guest)

	-- Everything below is feel only: floating numbers, particles, screen flashes.
	-- None of it changes state, so a missing or malformed field is harmless.
	elseif name == "collected" then
		FeedbackController.onCollected(body.amount or 0)
	elseif name == "checkedIn" then
		FeedbackController.onCheckedIn(body.guest)
	elseif name == "discovered" then
		FeedbackController.onDiscovered(body.guest)
	elseif name == "beingRobbed" then
		FeedbackController.onBeingRobbed(body.guest)
	elseif name == "lostGuest" then
		FeedbackController.onRobbed(body.guest)
	elseif name == "renovated" then
		FeedbackController.onRenovated(body.stars or 0)
	elseif name == "celebrity" then
		FeedbackController.onCelebrity(body.active == true)
	elseif name == "feed" then
		Feed.push(if type(body.text) == "string" then body.text else "", body.kind)
	elseif name == "porterAlert" then
		-- Night Porter. Level 1 is the toast the server already sent; level 2
		-- also marks them.
		if body.mark and type(body.thief) == "string" then
			RaidController.markThief(body.thief, body.seconds or 10)
		end
	elseif name == "objectiveComplete" then
		-- The toast carries the detail; this is the punctuation.
		hud.setBreakProgress(0, 0)
	end
end)

-- ---------------------------------------------------------------- controllers

RaidController.start(screen)

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
