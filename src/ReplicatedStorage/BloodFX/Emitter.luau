const Types = require(script.Parent.Types)

type Sprayer = (position: Vector3, direction: Vector3, spray: Types.Spray, strength: number) -> ()

const TAU = 2 * math.pi
const MAX_JITTER = 0.9

const random = Random.new()

local Emitter = {}
Emitter.__index = Emitter

function Emitter.new(origin: Types.Origin, preset: Types.Preset, spray: Sprayer, emitters: { any })
	const self = setmetatable({
		origin = origin,
		enabled = true,
		count = preset.count,
		speed = preset.speed,
		spread = preset.spread,
		radius = preset.radius,
		direction = preset.direction or Vector3.yAxis,
		rate = preset.rate or 1,
		rateJitter = preset.rateJitter or 0,
		pulseRate = preset.pulseRate or 0,
		pulseDepth = preset.pulseDepth or 0,
		spray = spray,
		emitters = emitters,
		due = 0,
	}, Emitter)

	if typeof(origin) == "Instance" then
		self.connection = origin.Destroying:Once(function() self:destroy() end)
	end

	table.insert(emitters, self)

	return self
end

function Emitter:frame(): CFrame
	const origin = self.origin

	if typeof(origin) == "CFrame" then return origin end
	if origin:IsA("Attachment") then return origin.WorldCFrame end

	return origin:GetPivot()
end

function Emitter:emit()
	const frame = self:frame()
	const strength = 1 + self.pulseDepth * math.sin(os.clock() * self.pulseRate * TAU)

	self.spray(frame.Position, frame:VectorToWorldSpace(self.direction), self, strength)
end

function Emitter:step(dt: number)
	if not self.enabled or self.rate <= 0 then return end

	const jitter = math.clamp(self.rateJitter, 0, MAX_JITTER)
	self.due -= dt

	while self.due <= 0 do
		self.due += (1 + random:NextNumber(-jitter, jitter)) / self.rate
		self:emit()
	end
end

function Emitter:destroy()
	const index = table.find(self.emitters, self)

	if index then table.remove(self.emitters, index) end
	if self.connection then self.connection:Disconnect() end
end

return Emitter
