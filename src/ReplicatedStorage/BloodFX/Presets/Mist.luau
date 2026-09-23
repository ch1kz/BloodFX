const Types = require(script.Parent.Parent.Types)

const Mist: Types.Preset = table.freeze({
	count = NumberRange.new(12, 20),
	speed = NumberRange.new(22, 48),
	spread = 70,
	radius = NumberRange.new(0.03, 0.07),
})

return Mist
