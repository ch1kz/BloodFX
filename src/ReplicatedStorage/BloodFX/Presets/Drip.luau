const Types = require(script.Parent.Parent.Types)

return table.freeze({
	count = NumberRange.new(1, 2),
	speed = NumberRange.new(1, 4),
	spread = 30,
	radius = NumberRange.new(0.08, 0.18),
	direction = -Vector3.yAxis,
	rate = 5,
	rateJitter = 0.35,
}) :: Types.Preset
