export type Config = {
	DynamicSettings: boolean,
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
	MarkMaxRadius: number,
	MergeReach: number,
	MergeGrowth: number,
	WallPooling: number,
	IgnoreTag: string,
	AbsorbTag: string,
	AttachTag: string,
	CharacterTag: string,
}

export type SettingName = keyof<Config>

export type Origin = PVInstance | Attachment | CFrame

export type Spray = {
	count: NumberRange,
	speed: NumberRange,
	spread: number,
	radius: NumberRange,
}

export type Preset = Spray & {
	direction: Vector3?,
	rate: number?,
	rateJitter: number?,
	pulseRate: number?,
	pulseDepth: number?,
}

export type Emitter = Spray & {
	origin: Origin,
	enabled: boolean,
	direction: Vector3,
	rate: number,
	rateJitter: number,
	pulseRate: number,
	pulseDepth: number,

	frame: (self: Emitter) -> CFrame,
	emit: (self: Emitter) -> (),
	destroy: (self: Emitter) -> (),
}

export type Stats = {
	drops: number,
	marks: number,
	emitters: number,
	parts: number,
}

return {}
