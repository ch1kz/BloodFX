export type Config = {
	DynamicSettings: boolean,
	Frozen: boolean,
	Debug: boolean,
	PoolSize: number,
	Color: Color3,
	Material: Enum.Material,
	MaxDrops: number,
	MaxMarks: number,
	Gravity: number,
	Drag: number,
	DropLifetime: number,
	MarkLifetime: number,
	MarkFadeTime: number,
	MarkOpenTime: number,
	MarkThickness: number,
	MarkScale: NumberRange,
	MarkStretch: NumberRange,
	SlantStretch: number,
	MarkMaxRadius: number,
	MergeReach: number,
	MergeGrowth: number,
	WallPooling: number,
	CeilingPooling: number,
	CeilingDrip: boolean,
	CeilingDripRate: number,
	CeilingDripAngle: number,
	IgnoreTag: string,
	AbsorbTag: string,
	AttachTag: string,
	CharacterTag: string,
}

export type SettingName = keyof<Config>

export type Origin = PVInstance | Attachment | CFrame

export type Range = number | NumberRange

export type Spray = {
	count: Range,
	speed: Range,
	spread: number,
	radius: Range,
}

type Update = (emitter: Emitter, time: number) -> ()

export type Preset = Spray & {
	direction: Vector3?,
	rate: number?,
	rateJitter: number?,
	update: Update?,
}

export type Overrides = {
	count: Range?,
	speed: Range?,
	spread: number?,
	radius: Range?,
	direction: Vector3?,
	rate: number?,
	rateJitter: number?,
	update: Update?,
}

export type Emitter = Spray & {
	origin: Origin,
	enabled: boolean,
	direction: Vector3,
	rate: number,
	rateJitter: number,
	strength: number,
	age: number,
	update: Update?,

	frame: (self: Emitter) -> CFrame,
	emit: (self: Emitter) -> (),
	destroy: (self: Emitter) -> (),
}

export type Stats = {
	drops: number,
	marks: number,
	emitters: number,
	parts: number,
	spare: number,
}

export type DebugEvent = {
	kind: "PoolExpanded",
	parts: number,
	limit: number,
} | {
	kind: "DropLimit",
	age: number,
	limit: number,
} | {
	kind: "MarkLimit",
	age: number,
	limit: number,
}

export type Connection = {
	Connected: boolean,

	Disconnect: (self: Connection) -> (),
}

export type Debugger = {
	Connect: (self: Debugger, listener: (event: DebugEvent) -> ()) -> Connection,
}

return {}
