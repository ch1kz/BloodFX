const CollectionService = game:GetService("CollectionService")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const Config = require(script.Config)
const Drops = require(script.Drops)
const Emitter = require(script.Emitter)
const Marks = require(script.Marks)
const Pool = require(script.Pool)
const Presets = require(script.Presets)
const Types = require(script.Types)

export type Config = Types.Config
export type Emitter = Types.Emitter
export type Origin = Types.Origin
export type Overrides = Types.Overrides
export type Preset = Types.Preset
export type PresetName = keyof<typeof(Presets)>
export type SettingName = Types.SettingName
export type Spray = Types.Spray
export type Stats = Types.Stats

const STATIC = table.freeze({
	DynamicSettings = true,
	PoolSize = true,
	IgnoreTag = true,
	AbsorbTag = true,
	AttachTag = true,
	CharacterTag = true,
})

const settings: Config = table.clone(Config)

const params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
params.IgnoreWater = true

const root = Instance.new("Folder")
root.Name = "BloodFX"

const pool = Pool.new(root, settings.PoolSize, settings.Color, settings.Material)
const marks = Marks.new(pool, settings, params)
const drops = Drops.new(pool, marks, settings, params)
const configuration = if settings.DynamicSettings then Instance.new("Configuration") else nil

const emitters: { Emitter } = {}

const function resolve(preset: PresetName | Preset, overrides: (Overrides | number)?): Preset
	const base = if typeof(preset) == "string" then Presets[preset] else preset

	if not base then error(`[BloodFX] unknown preset "{preset}"`, 3) end
	if not overrides then return base end

	const merged = table.clone(base)

	if typeof(overrides) == "number" then
		merged.count = overrides
	else
		for key, value in overrides do merged[key] = value end
	end

	return merged
end

const function spray(position: Vector3, direction: Vector3, shape: Spray, strength: number)
	if settings.Frozen then return end

	drops:spray(position, direction, shape, strength)
end

const function clear()
	drops:clear()
	marks:clear()
end

const function refreshFilter()
	params.FilterDescendantsInstances = CollectionService:GetTagged(settings.IgnoreTag)
end

const function tagCharacter(character: Model)
	if settings.CharacterTag ~= "" then character:AddTag(settings.CharacterTag) end
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
	Frozen = function() if settings.Frozen then clear() end end,
}

const function apply(key: string, value: any)
	if settings[key] == value then return end

	settings[key] = value
	if reactions[key] then reactions[key]() end
end

const function setFrozen(frozen: boolean)
	if configuration then configuration:SetAttribute("Frozen", frozen) end

	apply("Frozen", frozen)
end

const BloodFX = {}

function BloodFX.spray(position: Vector3, direction: Vector3, preset: (PresetName | Preset)?, overrides: (Overrides | number)?)
	spray(position, direction, resolve(preset or "Hit", overrides), 1)
end

function BloodFX.mark(position: Vector3, normal: Vector3, radius: number?)
	if settings.Frozen then return end

	const unit = normal.Unit
	marks:add(position, unit, -unit, radius or 0.25)
end

function BloodFX.emitter(origin: Origin, preset: (PresetName | Preset)?, overrides: (Overrides | number)?): Emitter
	return Emitter.new(origin, resolve(preset or "Drip", overrides), spray, emitters)
end

function BloodFX.get(key: SettingName): any
	return settings[key]
end

function BloodFX.set(key: SettingName, value: any)
	if not configuration then error("[BloodFX] settings are fixed, turn on Config.DynamicSettings to change them", 2) end
	if not accepts(key, value) then error(`[BloodFX] {key} cannot be set to {value}`, 2) end

	configuration:SetAttribute(key, value)
	apply(key, value)
end

function BloodFX.clear()
	clear()
end

function BloodFX.fade()
	marks:fade()
end

function BloodFX.freeze()
	setFrozen(true)
end

function BloodFX.unfreeze()
	setFrozen(false)
end

function BloodFX.isFrozen(): boolean
	return settings.Frozen
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
	if settings.Frozen then return end

	for _, emitter in emitters do emitter:step(dt) end

	drops:step(dt)
	marks:step(dt, drops)
end

-- init

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

CollectionService:GetInstanceAddedSignal(settings.IgnoreTag):Connect(refreshFilter)
CollectionService:GetInstanceRemovedSignal(settings.IgnoreTag):Connect(refreshFilter)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(tagCharacter)
end)

for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(tagCharacter)
	if player.Character then tagCharacter(player.Character) end
end

refreshFilter()

return BloodFX
