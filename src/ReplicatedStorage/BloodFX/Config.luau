const Types = require(script.Parent.Types)

return table.freeze({
	-- Lets the settings below change while the game runs, through the attributes of
	-- workspace.BloodFX.Config or BloodFX.set. Off, they stay as written here. Default: true.
	DynamicSettings = true,

	-- Spare parts made at start and kept for reuse. Default: 600.
	PoolSize = 600,

	-- Colour of drops and marks. Default: 124, 10, 10.
	Color = Color3.fromRGB(124, 10, 10),

	-- Material of drops and marks. Default: SmoothPlastic.
	Material = Enum.Material.SmoothPlastic,

	-- Most drops in flight at once; the oldest makes room for a new one. Default: 320.
	MaxDrops = 320,

	-- Most marks at once; the one left alone longest makes room for a new one. Default: 320.
	MaxMarks = 320,

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

	-- Largest radius a pool grows to, in studs. Default: 2.5.
	MarkMaxRadius = 2.5,

	-- A drop landing within this many radii of a mark joins it instead of making its own. Default: 1.35.
	MergeReach = 1.35,

	-- Share of a joining drop's radius that the pool grows by. Default: 0.3.
	MergeGrowth = 0.3,

	-- How much marks on walls merge compared with the floor: 0 keeps every drop apart, 1 lets them
	-- pool as on the floor. Slopes land between the floor and the wall. Default: 0.6.
	WallPooling = 0.6,

	-- The same for ceilings, where blood holds on worst. Overhangs land between the wall and the
	-- ceiling. Default: 0.2.
	CeilingPooling = 0.2,

	-- Drops fly through anything with this tag and everything inside it. Read once at start.
	-- Default: "BloodIgnore".
	IgnoreTag = "BloodIgnore",

	-- A drop landing on anything with this tag, or inside it, vanishes without a mark. Read once at start.
	-- Default: "BloodAbsorb".
	AbsorbTag = "BloodAbsorb",

	-- A mark landing on anything with this tag, or inside it, sticks to that part and moves with it.
	-- Read once at start. Default: "BloodAttach".
	AttachTag = "BloodAttach",

	-- Tag put on every player's character: one of the three above, or "" to leave characters alone.
	-- Read once at start. Default: "BloodIgnore".
	CharacterTag = "BloodIgnore",
}) :: Types.Config
