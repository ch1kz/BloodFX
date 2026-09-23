const Types = require(script.Parent.Parent.Types)

const Jet: Types.Preset = table.freeze({
	count = NumberRange.new(2, 5),
	speed = NumberRange.new(30, 46),
	spread = 10,
	radius = NumberRange.new(0.09, 0.19),
	direction = Vector3.new(0, 0.28, -1),
	rate = 12,
	rateJitter = 0.35,
})

return Jet
