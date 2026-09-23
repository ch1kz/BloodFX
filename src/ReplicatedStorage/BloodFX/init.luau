const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const Config = require(script.Config)
const Types = require(script.Types)

export type Config = Types.Config
export type Origin = Types.Origin
export type Preset = Types.Preset
export type Source = Types.Source
export type Stats = Types.Stats

type Drop = {
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	radius: number,
	age: number,
}

type Stain = {
	part: BasePart,
	position: Vector3,
	normal: Vector3,
	radius: number,
	stretch: number,
	opened: number,
	age: number,
}

type SourceState = Source & {
	due: number,
	connection: RBXScriptConnection?,
}

const TAU = 2 * math.pi
const STORAGE = CFrame.new(0, -1e4, 0)
const STATIC = table.freeze({ Dynamic = true, PoolSize = true })
const STAIN_START_SCALE = 0.35
const MERGE_ALIGNMENT = 0.7
const NO_STAINS: { Stain } = table.freeze({})
const NEIGHBOURS: { Vector3 } = table.create(27)
for index = 0, 26 do
	NEIGHBOURS[index + 1] = Vector3.new(index % 3, index // 3 % 3, index // 9) - Vector3.one
end

const settings: Config = table.clone(Config)
const random = Random.new()

const presets: { [string]: Preset } = {}
for _, module in script.Presets:GetChildren() do
	presets[module.Name] = require(module)
end

const root = Instance.new("Folder")
root.Name = "BloodFX"

const container = Instance.new("Folder")
container.Name = "Parts"
container.Parent = root

const template = Instance.new("Part")
template.Anchored = true
template.CanCollide = false
template.CanQuery = false
template.CanTouch = false
template.CastShadow = false
template.Color = settings.Color
template.Material = settings.Material
template.CFrame = STORAGE

const idle: { BasePart } = {}
for _ = 1, settings.PoolSize do
	const part = template:Clone()
	part.Parent = container
	table.insert(idle, part)
end

const configuration = if settings.Dynamic then Instance.new("Configuration") else nil
if configuration then
	configuration.Name = "Config"
	for key, value in settings do
		if not STATIC[key] then configuration:SetAttribute(key, value) end
	end
	configuration.Parent = root
end

const ignored: { Instance } = { root }
const params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
params.IgnoreWater = true

const drops: { Drop } = {}
const stains: { Stain } = {}
const cells: { [Vector3]: { Stain } } = {}
const sources: { SourceState } = {}
const movedParts: { BasePart } = {}
const movedFrames: { CFrame } = {}
local frozen = false

root.Parent = workspace

const function pick(range: NumberRange): number
	return random:NextNumber(range.Min, range.Max)
end

const function resolve(preset: Preset | string): Preset
	if typeof(preset) ~= "string" then return preset end
	return presets[preset] or error(`[BloodFX] unknown preset "{preset}"`, 3)
end

const function accepts(key: string, value: any): boolean
	const current = settings[key]
	if current == nil or STATIC[key] or typeof(value) ~= typeof(current) then return false end
	if typeof(value) == "number" then return value >= 0 end
	if typeof(value) == "EnumItem" then return value.EnumType == current.EnumType end
	return true
end

const function take(shape: Enum.PartType): BasePart
	const part = table.remove(idle) or template:Clone()
	part.Shape = shape
	part.Transparency = 0
	part.Parent = container
	return part
end

const function release(part: BasePart)
	if #idle < settings.PoolSize then
		part.CFrame = STORAGE
		table.insert(idle, part)
	else
		part:Destroy()
	end
end

const function repaint()
	template.Color = settings.Color
	template.Material = settings.Material
	for _, part in container:GetChildren() do
		part.Color = settings.Color
		part.Material = settings.Material
	end
end

const function refreshFilter()
	const filter = table.clone(ignored)
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(filter, player.Character) end
	end
	params.FilterDescendantsInstances = filter
end

const function cellOf(position: Vector3): Vector3
	return position // math.max(settings.StainMaxRadius * settings.MergeReach, 0.1)
end

const function addToGrid(stain: Stain)
	const cell = cellOf(stain.position)
	const bucket = cells[cell]
	if bucket then table.insert(bucket, stain) else cells[cell] = { stain } end
end

const function removeFromGrid(stain: Stain)
	const cell = cellOf(stain.position)
	const bucket = cells[cell]
	table.remove(bucket, table.find(bucket, stain))
	if #bucket == 0 then cells[cell] = nil end
end

const function regrid()
	table.clear(cells)
	for _, stain in stains do addToGrid(stain) end
end

const function mergeTarget(position: Vector3, normal: Vector3): Stain?
	const cell = cellOf(position)
	for _, offset in NEIGHBOURS do
		for _, stain in cells[cell + offset] or NO_STAINS do
			const close = (stain.position - position).Magnitude <= stain.radius * settings.MergeReach
			if close and stain.normal:Dot(normal) >= MERGE_ALIGNMENT then return stain end
		end
	end
	return nil
end

const function resizeStain(stain: Stain)
	const diameter = stain.radius * stain.opened * 2
	stain.part.Size = Vector3.new(settings.StainThickness, diameter, diameter * stain.stretch)
end

const function removeStain(index: number)
	const stain = table.remove(stains, index)
	removeFromGrid(stain)
	release(stain.part)
end

const function trimStains()
	while #stains > settings.MaxStains do
		local oldest = 1
		for index, stain in stains do
			if stain.age > stains[oldest].age then oldest = index end
		end
		removeStain(oldest)
	end
end

const function addStain(position: Vector3, normal: Vector3, radius: number)
	const target = mergeTarget(position, normal)
	if target then
		const grown = math.sqrt(target.radius ^ 2 + (radius * settings.MergeGrowth) ^ 2)
		target.radius = math.min(grown, settings.StainMaxRadius)
		target.age = 0
		target.part.Transparency = 0
		resizeStain(target)
		return
	end

	const part = take(Enum.PartType.Cylinder)
	part.CFrame = CFrame.fromMatrix(position, normal, normal:Cross(random:NextUnitVector()).Unit)

	const stain: Stain = {
		part = part,
		position = position,
		normal = normal,
		radius = math.min(radius, settings.StainMaxRadius),
		stretch = pick(settings.StainStretch),
		opened = STAIN_START_SCALE,
		age = 0,
	}
	resizeStain(stain)
	addToGrid(stain)
	table.insert(stains, stain)
	trimStains()
end

const function removeDrop(index: number)
	const drop = table.remove(drops, index)
	release(drop.part)
end

const function trimDrops()
	while #drops > settings.MaxDrops do removeDrop(1) end
end

const function addDrop(position: Vector3, velocity: Vector3, radius: number)
	const part = take(Enum.PartType.Ball)
	part.Size = Vector3.one * radius * 2
	part.CFrame = CFrame.new(position)
	table.insert(drops, { part = part, position = position, velocity = velocity, radius = radius, age = 0 })
	trimDrops()
end

const function sprayDrops(position: Vector3, direction: Vector3, shape: Preset | Source, strength: number)
	if frozen then return end
	const aim = CFrame.lookAlong(Vector3.zero, if direction.Magnitude > 1e-3 then direction else Vector3.yAxis)
	const cosSpread = math.cos(math.rad(shape.spread))
	for _ = 1, random:NextInteger(shape.count.Min, shape.count.Max) do
		const turn = CFrame.Angles(0, 0, random:NextNumber(0, TAU))
		const tilt = CFrame.Angles(math.acos(random:NextNumber(cosSpread, 1)), 0, 0)
		addDrop(position, (aim * turn * tilt).LookVector * pick(shape.speed) * strength, pick(shape.radius))
	end
end

const Source = {}
Source.__index = Source

function Source.emit(self: Source)
	const origin = self.origin
	const frame = if typeof(origin) == "CFrame" then origin
		elseif origin:IsA("Attachment") then origin.WorldCFrame
		else origin:GetPivot()
	const strength = 1 + self.pulseDepth * math.sin(os.clock() * self.pulseRate * TAU)
	sprayDrops(frame.Position, frame:VectorToWorldSpace(self.direction), self, strength)
end

function Source.destroy(self: SourceState)
	const index = table.find(sources, self)
	if index then table.remove(sources, index) end
	if self.connection then self.connection:Disconnect() end
end

const onChange: { [string]: () -> () } = {
	Color = repaint,
	Material = repaint,
	MaxDrops = trimDrops,
	MaxStains = trimStains,
	StainMaxRadius = regrid,
	MergeReach = regrid,
	StainThickness = function()
		for _, stain in stains do resizeStain(stain) end
	end,
}

const function apply(key: string, value: any)
	if settings[key] == value then return end
	settings[key] = value
	if onChange[key] then onChange[key]() end
end

const BloodFX = {}

function BloodFX.spray(position: Vector3, direction: Vector3, preset: (Preset | string)?)
	sprayDrops(position, direction, resolve(preset or "Hit"), 1)
end

function BloodFX.stain(position: Vector3, normal: Vector3, radius: number?)
	if frozen then return end
	addStain(position, normal.Unit, radius or 0.25)
end

function BloodFX.source(origin: Origin, preset: (Preset | string)?): Source
	const shape = resolve(preset or "Drip")
	const source = setmetatable({
		origin = origin,
		enabled = true,
		count = shape.count,
		speed = shape.speed,
		spread = shape.spread,
		radius = shape.radius,
		direction = shape.direction or Vector3.yAxis,
		rate = shape.rate or 1,
		rateJitter = shape.rateJitter or 0,
		pulseRate = shape.pulseRate or 0,
		pulseDepth = shape.pulseDepth or 0,
		due = 0,
	}, Source)
	if typeof(origin) == "Instance" then
		source.connection = origin.Destroying:Once(function() source:destroy() end)
	end
	table.insert(sources, source)
	return source
end

function BloodFX.get(key: string): any
	return settings[key]
end

function BloodFX.set(key: string, value: any)
	if not configuration then error("[BloodFX] settings are static, turn on Config.Dynamic to change them", 2) end
	if not accepts(key, value) then error(`[BloodFX] {key} cannot be set to {value}`, 2) end
	configuration:SetAttribute(key, value)
	apply(key, value)
end

function BloodFX.ignore(instance: Instance)
	table.insert(ignored, instance)
	refreshFilter()
end

function BloodFX.clear()
	for _, drop in drops do release(drop.part) end
	for _, stain in stains do release(stain.part) end
	table.clear(drops)
	table.clear(stains)
	table.clear(cells)
end

function BloodFX.fade()
	for _, stain in stains do stain.age = math.max(stain.age, settings.StainLifetime) end
end

function BloodFX.freeze()
	frozen = true
	BloodFX.clear()
end

function BloodFX.unfreeze()
	frozen = false
end

function BloodFX.isFrozen(): boolean
	return frozen
end

function BloodFX.stats(): Stats
	return { drops = #drops, stains = #stains, sources = #sources, parts = #drops + #stains + #idle }
end

const function stepSources(dt: number)
	for _, source in sources do
		if not source.enabled or source.rate <= 0 then continue end
		const jitter = math.clamp(source.rateJitter, 0, 0.9)
		source.due -= dt
		while source.due <= 0 do
			source.due += (1 + random:NextNumber(-jitter, jitter)) / source.rate
			source:emit()
		end
	end
end

const function stepDrops(dt: number)
	const fall = Vector3.yAxis * settings.Gravity * dt
	const keep = math.exp(-settings.Drag * dt)
	for index = #drops, 1, -1 do
		const drop = drops[index]
		drop.velocity = (drop.velocity - fall) * keep
		drop.age += dt
		const travel = drop.velocity * dt
		const hit = workspace:Raycast(drop.position, travel, params)
		if hit or drop.age > settings.DropLifetime then
			removeDrop(index)
			if hit then addStain(hit.Position, hit.Normal, drop.radius * pick(settings.StainScale)) end
		else
			drop.position += travel
			table.insert(movedParts, drop.part)
			table.insert(movedFrames, CFrame.new(drop.position))
		end
	end
	workspace:BulkMoveTo(movedParts, movedFrames, Enum.BulkMoveMode.FireCFrameChanged)
	table.clear(movedParts)
	table.clear(movedFrames)
end

const function stepStains(dt: number)
	for index = #stains, 1, -1 do
		const stain = stains[index]
		stain.age += dt
		if stain.opened < 1 then
			stain.opened = math.min(stain.opened + dt / settings.StainOpenTime, 1)
			resizeStain(stain)
		end
		const faded = (stain.age - settings.StainLifetime) / settings.StainFadeTime
		if faded >= 1 then
			removeStain(index)
		elseif faded > 0 then
			stain.part.Transparency = faded
		end
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	if frozen then return end
	stepSources(dt)
	stepDrops(dt)
	stepStains(dt)
end)

if configuration then
	configuration.AttributeChanged:Connect(function(key: string)
		const value = configuration:GetAttribute(key)
		if accepts(key, value) then
			apply(key, value)
		elseif not STATIC[key] then
			configuration:SetAttribute(key, settings[key])
		end
	end)
end

Players.PlayerAdded:Connect(function(player: Player) player.CharacterAdded:Connect(refreshFilter) end)
for _, player in Players:GetPlayers() do player.CharacterAdded:Connect(refreshFilter) end
refreshFilter()

return BloodFX
