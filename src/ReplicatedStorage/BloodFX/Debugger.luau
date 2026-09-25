const Types = require(script.Parent.Types)

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then return end

	self.Connected = false

	const connections = self.debugger.connections
	table.remove(connections, table.find(connections, self))
end

const function deliver(connection, event: Types.DebugEvent)
	if connection.Connected then connection.listener(event) end
end

local Debugger = {}
Debugger.__index = Debugger

function Debugger.new(settings: Types.Config)
	return setmetatable({
		settings = settings,
		connections = {},
	}, Debugger)
end

function Debugger:Connect(listener: (event: Types.DebugEvent) -> ()): Types.Connection
	const connection = setmetatable({
		Connected = true,
		debugger = self,
		listener = listener,
	}, Connection)

	table.insert(self.connections, connection)

	return connection
end

function Debugger:fire(event: Types.DebugEvent)
	if not self.settings.Debug or #self.connections == 0 then return end

	table.freeze(event)
	for _, connection in self.connections do task.defer(deliver, connection, event) end
end

return Debugger
