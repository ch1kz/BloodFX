const ReplicatedStorage = game:GetService("ReplicatedStorage")

const BloodFX = require(ReplicatedStorage:WaitForChild("BloodFX"))

const QUIET_TIME = 5

const lastWarned: { [string]: number } = {}

const function describe(event: BloodFX.DebugEvent): string
	if event.kind == "PoolExpanded" then
		return `ran out of spare parts and grew to {event.parts}, PoolSize is {event.limit}`
	elseif event.kind == "DropLimit" then
		return string.format("removed a drop %.2f s into its flight, MaxDrops is %d", event.age, event.limit)
	end

	return string.format("removed a mark left alone for %.1f s, MaxMarks is %d", event.age, event.limit)
end

BloodFX.debugger:Connect(function(event: BloodFX.DebugEvent)
	const now = os.clock()
	if now - (lastWarned[event.kind] or -math.huge) < QUIET_TIME then return end

	lastWarned[event.kind] = now
	warn(`[BloodFX] {describe(event)}`)
end)
