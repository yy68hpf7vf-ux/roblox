--!strict
--[[
	RaidController

	One context-sensitive interact key, and the prompt that explains what it will
	do right now.

	Everything the player can do out in the world runs through E (or the on-screen
	button on touch devices): break a door, grab a guest, claim the celebrity. The
	prompt reads the world and says which one is currently on offer, so nobody has
	to learn a control scheme -- they walk up to something and the game tells them.

	The client picks the target and sends the request. The server decides whether it
	counts, and every rule that matters -- night, distance, grace, cooldown -- is
	re-checked there.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Guests = require(Shared.Config.Guests)

local Actions = require(script.Parent.Parent.Actions)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Ui.Theme)
local Widgets = require(script.Parent.Parent.Ui.Widgets)

local RaidController = {}

local player = Players.LocalPlayer

local DOOR_RANGE = 14
local GUEST_RANGE = 12
local CELEBRITY_RANGE = 16

type Target =
	{ kind: "door", plot: number, part: BasePart }
	| { kind: "guest", plot: number, uid: string, part: BasePart }
	| { kind: "celebrity", part: BasePart }
	| { kind: "deliver" }
	| nil

local openDoors: { [number]: boolean } = {}
local currentTarget: Target = nil
local holding = false
local promptLabel: TextLabel
local promptPanel: Frame

--[[ Set by the server's doorOpen effect. Cleared at sunrise, when the server
     revokes access anyway -- this is only the client's copy for the prompt. ]]
function RaidController.setDoorOpen(plotIndex: number, open: boolean)
	openDoors[plotIndex] = open or nil
end

function RaidController.clearDoors()
	table.clear(openDoors)
end

--[[ Night Porter level 2: outline whoever is on your door so you can actually
     find them in the dark. Purely a client-side highlight -- the server has
     already decided the alert is warranted. ]]
function RaidController.markThief(thiefName: string, seconds: number)
	local thief = Players:FindFirstChild(thiefName)
	if not thief or not thief:IsA("Player") then
		return
	end

	local character = thief.Character
	if not character then
		return
	end

	local existing = character:FindFirstChild("PorterMark")
	if existing then
		existing:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "PorterMark"
	highlight.FillColor = Color3.fromRGB(255, 96, 132)
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.fromRGB(255, 140, 160)
	highlight.Parent = character

	task.delay(math.max(5, seconds + 10), function()
		if highlight.Parent then
			highlight:Destroy()
		end
	end)
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function worldFolder(): Folder?
	return workspace:FindFirstChild("World") :: Folder?
end

--[[ Works out what E would do from where the player is standing, in priority
     order: deliver what you are carrying, claim the celebrity, grab from a door
     you have already opened, then break a door. ]]
local function findTarget(): Target
	local origin = rootPosition()
	local world = worldFolder()
	if not origin or not world then
		return nil
	end

	local state = State.get()

	if state.carrying then
		return { kind = "deliver" }
	end

	local myPlot = player:GetAttribute("Plot")
	local isNight = (state.night or {}).night == true

	-- Celebrity on the stage.
	local celebrity = world:FindFirstChild("Celebrity")
	if celebrity and celebrity:IsA("Model") and celebrity.PrimaryPart then
		if (celebrity.PrimaryPart.Position - origin).Magnitude <= CELEBRITY_RANGE then
			return { kind = "celebrity", part = celebrity.PrimaryPart }
		end
	end

	if not isNight then
		return nil
	end

	local bestGuest: Target = nil
	local bestGuestDistance = GUEST_RANGE
	local bestDoor: Target = nil
	local bestDoorDistance = DOOR_RANGE

	for _, island in world:GetChildren() do
		local plotIndex = tonumber(string.match(island.Name, "^Plot(%d+)$"))
		if not plotIndex or plotIndex == myPlot then
			continue
		end

		local door = island:FindFirstChild("Door") :: BasePart?
		if door then
			local distance = (door.Position - origin).Magnitude
			if openDoors[plotIndex] then
				-- Door already open: look for something to carry out.
				for _, child in island:GetChildren() do
					if child:IsA("Model") and child:GetAttribute("Uid") and child.PrimaryPart then
						local guestDistance = (child.PrimaryPart.Position - origin).Magnitude
						if guestDistance < bestGuestDistance then
							bestGuestDistance = guestDistance
							bestGuest = {
								kind = "guest",
								plot = plotIndex,
								uid = child:GetAttribute("Uid") :: string,
								part = child.PrimaryPart,
							}
						end
					end
				end
			elseif distance < bestDoorDistance then
				bestDoorDistance = distance
				bestDoor = { kind = "door", plot = plotIndex, part = door }
			end
		end
	end

	return bestGuest or bestDoor
end

local function promptFor(target: Target): string?
	if not target then
		return nil
	end
	if target.kind == "deliver" then
		local carried = Guests.get(State.get().carrying or "")
		return `Carrying {if carried then carried.name else "a guest"} -- get to your own front desk`
	elseif target.kind == "celebrity" then
		return "[E]  Grab the celebrity"
	elseif target.kind == "guest" then
		return "[E]  Take this guest"
	elseif target.kind == "door" then
		return "[Hold E]  Break in"
	end
	return nil
end

local function press()
	local target = currentTarget
	if not target then
		return
	end

	if target.kind == "door" then
		holding = true
		Actions.invoke("startBreak", { plot = target.plot }, true)
	elseif target.kind == "guest" then
		Actions.invoke("grabGuest", { plot = target.plot, uid = target.uid })
	elseif target.kind == "celebrity" then
		Actions.invoke("claimCelebrity")
	end
end

local function release()
	if holding then
		holding = false
		Actions.invoke("stopBreak", nil, true)
	end
end

function RaidController.start(parent: ScreenGui)
	promptPanel = Widgets.panel({
		Name = "Prompt",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -240),
		Size = UDim2.fromOffset(360, 40),
		BackgroundColor3 = Theme.Color.Panel,
		Visible = false,
		Parent = parent,
	})

	promptLabel = Widgets.label({
		Text = "",
		Font = Theme.Font.Heading,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = promptPanel,
	})

	ContextActionService:BindAction("MotelInteract", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			press()
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			release()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.E)

	ContextActionService:SetTitle("MotelInteract", "E")

	-- Releasing the key anywhere ends a break, even if focus moved to a window.
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.E then
			release()
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.15 then
			return
		end
		accumulator = 0

		local target = findTarget()
		local changedAway = currentTarget ~= nil
			and (target == nil or (target :: any).kind ~= (currentTarget :: any).kind)
		currentTarget = target

		if changedAway then
			release()
		end

		local text = promptFor(target)
		promptPanel.Visible = text ~= nil
		if text then
			promptLabel.Text = text
			promptLabel.TextColor3 = if target and target.kind == "deliver"
				then Theme.Color.Warn
				else Theme.Color.Text
		end
	end)
end

return RaidController
