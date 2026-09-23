const Types = require(script.Parent.Types)

type Drop = {
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	radius: number,
	age: number,
}

const random = Random.new()

local Drops = {}
Drops.__index = Drops

function Drops.new(pool, marks, settings: Types.Config, params: RaycastParams)
	return setmetatable({
		pool = pool,
		marks = marks,
		settings = settings,
		params = params,
		list = {} :: { Drop },
		movedParts = {} :: { BasePart },
		movedFrames = {} :: { CFrame },
	}, Drops)
end

function Drops:spray(position: Vector3, direction: Vector3, spray: Types.Spray, strength: number)
	const aim = CFrame.lookAlong(Vector3.zero, if direction.Magnitude > 1e-3 then direction else Vector3.yAxis)
	const cosSpread = math.cos(math.rad(spray.spread))

	for _ = 1, random:NextInteger(spray.count.Min, spray.count.Max) do
		-- Spin around the aim, then tilt off it. Drawing cos(tilt) uniformly from [cos(spread), 1]
		-- spreads the drops evenly over the cone's cap instead of bunching them at its centre.
		const turn = CFrame.Angles(0, 0, random:NextNumber(0, 2 * math.pi))
		const tilt = CFrame.Angles(math.acos(random:NextNumber(cosSpread, 1)), 0, 0)
		const speed = random:NextNumber(spray.speed.Min, spray.speed.Max) * strength
		const radius = random:NextNumber(spray.radius.Min, spray.radius.Max)

		self:launch(position, (aim * turn * tilt).LookVector * speed, radius)
	end
end

function Drops:launch(position: Vector3, velocity: Vector3, radius: number)
	const part = self.pool:take(Enum.PartType.Ball)
	part.Size = Vector3.one * radius * 2
	part.CFrame = CFrame.new(position)

	table.insert(self.list, {
		part = part,
		position = position,
		velocity = velocity,
		radius = radius,
		age = 0,
	})

	self:trim()
end

function Drops:remove(index: number)
	const drop = table.remove(self.list, index)
	self.pool:give(drop.part)
end

function Drops:trim()
	while #self.list > self.settings.MaxDrops do self:remove(1) end
end

function Drops:clear()
	for _, drop in self.list do self.pool:give(drop.part) end
	table.clear(self.list)
end

function Drops:step(dt: number)
	const settings = self.settings
	const fall = Vector3.yAxis * settings.Gravity * dt

	-- Exact decay of dv/dt = -Drag * v over the step, so drag does not change with the frame rate.
	const keep = math.exp(-settings.Drag * dt)

	for index = #self.list, 1, -1 do
		const drop = self.list[index]
		drop.velocity = (drop.velocity - fall) * keep
		drop.age += dt

		const travel = drop.velocity * dt
		const hit = workspace:Raycast(drop.position, travel, self.params)

		if hit then
			const scale = random:NextNumber(settings.MarkScale.Min, settings.MarkScale.Max)

			self:remove(index)
			self.marks:add(hit.Position, hit.Normal, drop.radius * scale)
		elseif drop.age > settings.DropLifetime then
			self:remove(index)
		else
			drop.position += travel
			table.insert(self.movedParts, drop.part)
			table.insert(self.movedFrames, CFrame.new(drop.position))
		end
	end

	workspace:BulkMoveTo(self.movedParts, self.movedFrames, Enum.BulkMoveMode.FireCFrameChanged)
	table.clear(self.movedParts)
	table.clear(self.movedFrames)
end

return Drops
