const Types = require(script.Parent.Types)

type Sprayer = (position: Vector3, direction: Vector3, spray: Types.Spray, strength: number) -> ()

const MAX_JITTER = 0.9

const random = Random.new()

local Emitter = {}
Emitter.__index = Emitter

function Emitter.new(origin: Types.Origin, preset: Types.Preset, spray: Sprayer, emitters: { any })
	const self = setmetatable(table.clone(preset) :: any, Emitter)

	self.origin = origin
	self.enabled = true
	self.direction = preset.direction or Vector3.yAxis
	self.rate = preset.rate or 1
	self.rateJitter = preset.rateJitter or 0
	self.strength = 1
	self.age = 0
	self.spray = spray
	self.emitters = emitters
	self.due = 0

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
	self.spray(frame.Position, frame:VectorToWorldSpace(self.direction), self, self.strength)
end

function Emitter:step(dt: number)
	self.age += dt
	if self.update then self.update(self, self.age) end

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
