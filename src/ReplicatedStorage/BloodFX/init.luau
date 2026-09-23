const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const Config = require(script.Config)
const Drops = require(script.Drops)
const Emitter = require(script.Emitter)
const Marks = require(script.Marks)
const Pool = require(script.Pool)
const Types = require(script.Types)

export type Config = Types.Config
export type Emitter = Types.Emitter
export type Origin = Types.Origin
export type Preset = Types.Preset
export type Spray = Types.Spray
export type Stats = Types.Stats

const STATIC = table.freeze({ DynamicSettings = true, PoolSize = true })

const settings: Config = table.clone(Config)
const presets: { [string]: Preset } = {}
const emitters: { Emitter } = {}
const root = Instance.new("Folder")
const ignored: { Instance } = { root }
const params = RaycastParams.new()
const pool = Pool.new(root, settings.PoolSize, settings.Color, settings.Material)
const marks = Marks.new(pool, settings, params)
const drops = Drops.new(pool, marks, settings, params)
const configuration = if settings.DynamicSettings then Instance.new("Configuration") else nil

local frozen = false

const function resolve(preset: Preset | string): Preset
	if typeof(preset) ~= "string" then return preset end

	return presets[preset] or error(`[BloodFX] unknown preset "{preset}"`, 3)
end

const function spray(position: Vector3, direction: Vector3, shape: Spray, strength: number)
	if frozen then return end

	drops:spray(position, direction, shape, strength)
end

const function refreshFilter()
	const filter = table.clone(ignored)

	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(filter, player.Character) end
	end

	params.FilterDescendantsInstances = filter
end

const function accepts(key: string, value: any): boolean
	const current = settings[key]

	if current == nil or STATIC[key] or typeof(value) ~= typeof(current) then return false end
	if typeof(value) == "number" then return value >= 0 end
	if typeof(value) == "EnumItem" then return value.EnumType == current.EnumType end

	return true
end

const reactions: { [string]: () -> () } = {
	Color = function() pool:paint(settings.Color, settings.Material) end,
	Material = function() pool:paint(settings.Color, settings.Material) end,
	MaxDrops = function() drops:trim() end,
	MaxMarks = function() marks:trim() end,
	MarkThickness = function() marks:resizeAll() end,
	MarkMaxRadius = function() marks:regrid() end,
	MergeReach = function() marks:regrid() end,
}

const function apply(key: string, value: any)
	if settings[key] == value then return end

	settings[key] = value
	if reactions[key] then reactions[key]() end
end

const BloodFX = {}

function BloodFX.spray(position: Vector3, direction: Vector3, preset: (Preset | string)?)
	spray(position, direction, resolve(preset or "Hit"), 1)
end

function BloodFX.mark(position: Vector3, normal: Vector3, radius: number?)
	if frozen then return end

	marks:add(position, normal.Unit, radius or 0.25)
end

function BloodFX.emitter(origin: Origin, preset: (Preset | string)?): Emitter
	return Emitter.new(origin, resolve(preset or "Drip"), spray, emitters)
end

function BloodFX.get(key: string): any
	return settings[key]
end

function BloodFX.set(key: string, value: any)
	if not configuration then error("[BloodFX] settings are fixed, turn on Config.DynamicSettings to change them", 2) end
	if not accepts(key, value) then error(`[BloodFX] {key} cannot be set to {value}`, 2) end

	configuration:SetAttribute(key, value)
	apply(key, value)
end

function BloodFX.ignore(instance: Instance)
	table.insert(ignored, instance)
	refreshFilter()
end

function BloodFX.clear()
	drops:clear()
	marks:clear()
end

function BloodFX.fade()
	marks:fade()
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
	return {
		drops = #drops.list,
		marks = #marks.list,
		emitters = #emitters,
		parts = pool.total,
	}
end

const function step(dt: number)
	if frozen then return end

	for _, emitter in emitters do emitter:step(dt) end

	drops:step(dt)
	marks:step(dt)
end

-- init

root.Name = "BloodFX"

for _, module in script.Presets:GetChildren() do
	presets[module.Name] = require(module)
end

params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
params.IgnoreWater = true

if configuration then
	configuration.Name = "Config"

	for key, value in settings do
		if not STATIC[key] then configuration:SetAttribute(key, value) end
	end

	configuration.AttributeChanged:Connect(function(key: string)
		const value = configuration:GetAttribute(key)

		if accepts(key, value) then
			apply(key, value)
		elseif not STATIC[key] then
			configuration:SetAttribute(key, settings[key])
		end
	end)

	configuration.Parent = root
end

root.Parent = workspace

RunService.Heartbeat:Connect(step)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(refreshFilter)
end)

for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(refreshFilter)
end

refreshFilter()

return BloodFX
