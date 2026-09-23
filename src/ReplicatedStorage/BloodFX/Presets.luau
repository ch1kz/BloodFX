return table.freeze({
	Hit = table.freeze({
		count = NumberRange.new(4, 8),
		speed = NumberRange.new(16, 34),
		spread = 42,
		radius = NumberRange.new(0.07, 0.16),
	}),

	Burst = table.freeze({
		count = NumberRange.new(10, 18),
		speed = NumberRange.new(18, 40),
		spread = 65,
		radius = NumberRange.new(0.06, 0.15),
	}),

	Drip = table.freeze({
		count = NumberRange.new(1, 2),
		speed = NumberRange.new(1, 4),
		spread = 30,
		radius = NumberRange.new(0.08, 0.18),
		direction = -Vector3.yAxis,
		rate = 5,
		rateJitter = 0.35,
	}),

	Jet = table.freeze({
		count = NumberRange.new(2, 5),
		speed = NumberRange.new(30, 46),
		spread = 10,
		radius = NumberRange.new(0.09, 0.19),
		direction = Vector3.new(0, 0.28, -1),
		rate = 12,
		rateJitter = 0.35,
	}),

	Fountain = table.freeze({
		count = NumberRange.new(2, 5),
		speed = NumberRange.new(14, 26),
		spread = 14,
		radius = NumberRange.new(0.09, 0.19),
		direction = Vector3.new(0, 1, -0.4),
		rate = 20,
		rateJitter = 0.35,
		pulseRate = 1.2,
		pulseDepth = 0.6,
	}),
})
