--!strict
--[[
	Signal
	A small BindableEvent-free signal. Server services use it to talk to each
	other without a hard require cycle, and without paying the serialisation cost
	of a BindableEvent for in-process calls.
]]

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

local Connection = {}
Connection.__index = Connection

local Signal = {}
Signal.__index = Signal

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

function Signal.new<T...>(): Signal<T...>
	return (setmetatable({ _handlers = {} }, Signal) :: any) :: Signal<T...>
end

function Signal:Connect(handler)
	assert(type(handler) == "function", "Signal:Connect expects a function")
	local connection = setmetatable({ Connected = true, _signal = self, _handler = handler }, Connection)
	table.insert(self._handlers, connection)
	return connection
end

function Signal:Once(handler)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

--[[ Handlers run in their own thread so one erroring listener cannot stop the
     rest, and a yielding listener cannot stall the caller. ]]
function Signal:Fire(...)
	for _, connection in table.clone(self._handlers) do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal:DisconnectAll()
	for _, connection in self._handlers do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local handlers = self._signal._handlers
	local index = table.find(handlers, self)
	if index then
		table.remove(handlers, index)
	end
end

return Signal
