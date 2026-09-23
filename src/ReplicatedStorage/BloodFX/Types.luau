export type Config = {
	Dynamic: boolean,
	PoolSize: number,
	Color: Color3,
	Material: Enum.Material,
	MaxDrops: number,
	MaxStains: number,
	Gravity: number,
	Drag: number,
	DropLifetime: number,
	StainLifetime: number,
	StainFadeTime: number,
	StainOpenTime: number,
	StainThickness: number,
	StainScale: NumberRange,
	StainStretch: NumberRange,
	StainMaxRadius: number,
	MergeReach: number,
	MergeGrowth: number,
}

export type Origin = PVInstance | Attachment | CFrame

export type Preset = {
	count: NumberRange,
	speed: NumberRange,
	spread: number,
	radius: NumberRange,
	direction: Vector3?,
	rate: number?,
	rateJitter: number?,
	pulseRate: number?,
	pulseDepth: number?,
}

export type Source = {
	origin: Origin,
	enabled: boolean,
	count: NumberRange,
	speed: NumberRange,
	spread: number,
	radius: NumberRange,
	direction: Vector3,
	rate: number,
	rateJitter: number,
	pulseRate: number,
	pulseDepth: number,
	emit: (self: Source) -> (),
	destroy: (self: Source) -> (),
}

export type Stats = {
	drops: number,
	stains: number,
	sources: number,
	parts: number,
}

return {}
