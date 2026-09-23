const Types = require(script.Parent.Parent.Types)

return table.freeze({
	count = NumberRange.new(2, 5),
	speed = NumberRange.new(14, 26),
	spread = 14,
	radius = NumberRange.new(0.09, 0.19),
	direction = Vector3.new(0, 1, -0.4),
	rate = 20,
	rateJitter = 0.35,
	pulseRate = 1.2,
	pulseDepth = 0.6,
}) :: Types.Preset
