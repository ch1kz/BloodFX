const Types = require(script.Parent.Types)

const Config: Types.Config = {
	Dynamic = true,
	PoolSize = 600,

	Color = Color3.fromRGB(124, 10, 10),
	Material = Enum.Material.SmoothPlastic,

	MaxDrops = 160,
	MaxStains = 240,

	Gravity = 60,
	Drag = 0.35,
	DropLifetime = 3,

	StainLifetime = 25,
	StainFadeTime = 3,
	StainOpenTime = 0.16,
	StainThickness = 0.06,
	StainScale = NumberRange.new(2, 3),
	StainStretch = NumberRange.new(0.7, 1.35),
	StainMaxRadius = 3,

	MergeReach = 1.35,
	MergeGrowth = 0.3,
}

return table.freeze(Config)
