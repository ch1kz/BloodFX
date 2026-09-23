const Types = require(script.Parent.Parent.Types)

const Burst: Types.Preset = table.freeze({
	count = NumberRange.new(10, 18),
	speed = NumberRange.new(18, 40),
	spread = 65,
	radius = NumberRange.new(0.06, 0.15),
})

return Burst
