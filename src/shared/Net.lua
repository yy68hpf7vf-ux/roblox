--!strict
--[[
	Net
	Remote plumbing. The server builds the folder on boot; the client waits for it.

	Everything the client can ask for goes through a single `Invoke` RemoteFunction
	with a named action, which keeps every request behind one validated entry point
	instead of a dozen individually-guarded remotes. Swings get their own event
	because they are the one high-frequency message and do not need a reply.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.FolderName = "RiftNet"

Net.Events = { "State", "Notify", "Effect", "Swing" }
Net.Functions = { "Invoke" }

export type Response = {
	ok: boolean,
	message: string?,
	data: { [string]: any }?,
}

--[[ Server-side: create the folder and its children. Safe to call once on boot. ]]
function Net.build(): Folder
	assert(RunService:IsServer(), "Net.build is server-only")

	local existing = ReplicatedStorage:FindFirstChild(Net.FolderName)
	if existing then
		return existing :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = Net.FolderName

	for _, name in Net.Events do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end

	for _, name in Net.Functions do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end

	folder.Parent = ReplicatedStorage
	return folder
end

local cachedFolder: Folder? = nil

function Net.folder(): Folder
	if cachedFolder then
		return cachedFolder
	end
	local folder = ReplicatedStorage:WaitForChild(Net.FolderName, 30) :: Folder?
	assert(folder, "Net: remote folder never appeared -- is the server script running?")
	cachedFolder = folder
	return folder
end

function Net.event(name: string): RemoteEvent
	return Net.folder():WaitForChild(name, 15) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return Net.folder():WaitForChild(name, 15) :: RemoteFunction
end

function Net.ok(message: string?, data: { [string]: any }?): Response
	return { ok = true, message = message, data = data }
end

function Net.fail(message: string): Response
	return { ok = false, message = message }
end

return Net
