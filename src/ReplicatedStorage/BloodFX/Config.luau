const Types = require(script.Parent.Types)

const Config: Types.Config = {
	Dynamic = true,
	PoolSize = 600,

	Color = Color3.fromRGB(124, 10, 10),
	Material = Enum.Material.SmoothPlastic,

	MaxDrops = 160,
	MaxMarks = 240,

	Gravity = 60,
	Drag = 0.35,
	DropLifetime = 3,

	MarkLifetime = 25,
	MarkFadeTime = 3,
	MarkOpenTime = 0.16,
	MarkThickness = 0.06,
	MarkScale = NumberRange.new(2, 3),
	MarkStretch = NumberRange.new(0.7, 1.35),
	MarkMaxRadius = 3,

	MergeReach = 1.35,
	MergeGrowth = 0.3,
}

return table.freeze(Config)
