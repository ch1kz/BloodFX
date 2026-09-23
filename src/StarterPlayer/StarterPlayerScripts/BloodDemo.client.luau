const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

const BloodFX = require(ReplicatedStorage:WaitForChild("BloodFX"))

const CLICK_REACH = 500
const TRAIL_RADIUS = 4.5
const TRAIL_WANDER = 1.5
const TRAIL_SPEED = 0.9
const TRAIL_DRIFT = 0.53
const TARGET_TRAVEL = 7
const TARGET_PERIOD = 9
const MONITOR_INTERVAL = 0.25

const player = Players.LocalPlayer
const sources = workspace:WaitForChild("Sources")
const stations = workspace:WaitForChild("Stations")

const clickParams = RaycastParams.new()
clickParams.FilterType = Enum.RaycastFilterType.Exclude

const function trail(part: BasePart)
	const wound = Instance.new("Attachment")
	wound.Name = "Wound"
	wound.Parent = part

	BloodFX.emitter(wound, "Drip").rate = 14

	const motion = RunService.Heartbeat:Connect(function()
		const time = os.clock()
		const angle = time * TRAIL_SPEED
		const radius = TRAIL_RADIUS + math.sin(time * TRAIL_DRIFT) * TRAIL_WANDER

		wound.Position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
	end)

	wound.Destroying:Once(function() motion:Disconnect() end)
end

const STATIONS: { (BasePart) -> () } = {
	function(part) BloodFX.emitter(part, "Hit").direction = Vector3.new(0, 0.6, -1) end,
	function(part) BloodFX.emitter(part, "Drip") end,
	function(part) BloodFX.emitter(part, "Jet") end,
	function(part) BloodFX.emitter(part, "Fountain") end,
	trail,
}

const function attach(part: Instance)
	const station = part:GetAttribute("Station")
	const setup = typeof(station) == "number" and STATIONS[station]

	if setup and part:IsA("BasePart") then setup(part) end
end

const function sweep(target: Model)
	const home = target:GetPivot()

	RunService.Heartbeat:Connect(function()
		const offset = math.sin(os.clock() * 2 * math.pi / TARGET_PERIOD) * TARGET_TRAVEL
		target:PivotTo(home * CFrame.new(offset, 0, 0))
	end)
end

const function monitor(name: string, caption: string): TextLabel
	const screen = workspace
		:WaitForChild("Hall")
		:WaitForChild("Displays")
		:WaitForChild(name)
		:WaitForChild("Screen")
		:WaitForChild("SurfaceGui")
		:WaitForChild("Background")

	const title = screen:WaitForChild("Caption") :: TextLabel
	title.Text = caption

	return screen:WaitForChild("Value") :: TextLabel
end

sources.ChildAdded:Connect(attach)

for _, part in sources:GetChildren() do attach(part) end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	const ray = workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
	clickParams.FilterDescendantsInstances = { player.Character }

	const hit = workspace:Raycast(ray.Origin, ray.Direction * CLICK_REACH, clickParams)
	if hit then BloodFX.spray(hit.Position + hit.Normal * 0.25, hit.Normal, "Hit") end
end)

sweep(stations:WaitForChild("Station3"):WaitForChild("JetTarget") :: Model)

const dropsValue = monitor("MonitorLeft", "DROPS IN FLIGHT")
const marksValue = monitor("MonitorRight", "MARKS ON SURFACES")

while true do
	const stats = BloodFX.stats()

	dropsValue.Text = `{stats.drops} / {BloodFX.get("MaxDrops")}`
	marksValue.Text = `{stats.marks} / {BloodFX.get("MaxMarks")}`

	task.wait(MONITOR_INTERVAL)
end
