const Types = require(script.Parent.Types)

const Config: Types.Config = {
	-- Lets the settings below change while the game runs, through the attributes of
	-- workspace.BloodFX.Config or BloodFX.set. Off, they stay as written here. Default: true.
	DynamicSettings = true,

	-- Spare parts made at start and kept for reuse. Default: 600.
	PoolSize = 600,

	-- Colour of drops and marks. Default: 124, 10, 10.
	Color = Color3.fromRGB(124, 10, 10),

	-- Material of drops and marks. Default: SmoothPlastic.
	Material = Enum.Material.SmoothPlastic,

	-- Most drops in flight at once; the oldest makes room for a new one. Default: 160.
	MaxDrops = 160,

	-- Most marks at once; the one left alone longest makes room for a new one. Default: 240.
	MaxMarks = 240,

	-- Downward pull on drops, in studs per second squared. Default: 60.
	Gravity = 60,

	-- Air resistance: every second a drop keeps e^-Drag of its speed. Default: 0.35.
	Drag = 0.35,

	-- Seconds before a drop that hit nothing is removed. Default: 3.
	DropLifetime = 3,

	-- Seconds a mark lasts before it fades; each drop that joins it starts the count again. Default: 25.
	MarkLifetime = 25,

	-- Seconds a mark takes to fade out. Default: 3.
	MarkFadeTime = 3,

	-- Seconds a new mark takes to spread to full size. Default: 0.16.
	MarkOpenTime = 0.16,

	-- Thickness of a mark, in studs. Default: 0.06.
	MarkThickness = 0.06,

	-- Mark radius as a multiple of the radius of the drop that made it. Default: 2 to 3.
	MarkScale = NumberRange.new(2, 3),

	-- Length of a mark against its width, so marks come out oval. Default: 0.7 to 1.35.
	MarkStretch = NumberRange.new(0.7, 1.35),

	-- Largest radius a pool grows to, in studs. Default: 3.
	MarkMaxRadius = 3,

	-- A drop landing within this many radii of a mark joins it instead of making its own. Default: 1.35.
	MergeReach = 1.35,

	-- Share of a joining drop's radius that the pool grows by. Default: 0.3.
	MergeGrowth = 0.3,
}

return table.freeze(Config)
