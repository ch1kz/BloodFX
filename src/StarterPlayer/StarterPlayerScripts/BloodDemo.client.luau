const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

const BloodFX = require(ReplicatedStorage:WaitForChild("BloodFX"))

const CLICK_REACH = 500
const TRAIL_RADIUS = 5
const TRAIL_SPEED = 0.9

const player = Players.LocalPlayer
const sources = workspace:WaitForChild("Sources")
const clickParams = RaycastParams.new()
clickParams.FilterType = Enum.RaycastFilterType.Exclude

const function trail(part: BasePart)
	const wound = Instance.new("Attachment")
	wound.Name = "Wound"
	wound.Parent = part
	BloodFX.source(wound, "Trail")

	const motion = RunService.Heartbeat:Connect(function()
		const angle = os.clock() * TRAIL_SPEED
		wound.Position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * TRAIL_RADIUS
	end)
	wound.Destroying:Once(function() motion:Disconnect() end)
end

const STATIONS: { (BasePart) -> () } = {
	function(part) BloodFX.source(part, "Hit").direction = Vector3.new(0, 0.6, -1) end,
	function(part) BloodFX.source(part, "Drip") end,
	function(part) BloodFX.source(part, "Jet") end,
	function(part) BloodFX.source(part, "Fountain") end,
	trail,
}

const function attach(part: Instance)
	const station = part:GetAttribute("Station")
	const setup = typeof(station) == "number" and STATIONS[station]
	if setup and part:IsA("BasePart") then setup(part) end
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
