const Types = require(script.Parent.Parent.Types)

const Hit: Types.Preset = table.freeze({
	count = NumberRange.new(4, 8),
	speed = NumberRange.new(16, 34),
	spread = 42,
	radius = NumberRange.new(0.07, 0.16),
})

return Hit
