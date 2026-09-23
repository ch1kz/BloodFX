const Types = require(script.Parent.Types)

type Drop = {
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	radius: number,
	age: number,
}

const random = Random.new()

const function tagged(instance: Instance, tag: string): boolean
	if instance:HasTag(tag) then return true end

	const parent = instance.Parent
	return parent ~= nil and parent ~= workspace and tagged(parent, tag)
end

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

@native function Drops:spray(position: Vector3, direction: Vector3, spray: Types.Spray, strength: number)
	const aim = CFrame.lookAlong(Vector3.zero, if direction.Magnitude > 1e-3 then direction else Vector3.yAxis)
	const spread = math.rad(spray.spread)
	const sizes = spray.radius.Max - spray.radius.Min

	for _ = 1, random:NextInteger(spray.count.Min, spray.count.Max) do
		-- Spin around the aim, then tilt off it by an angle drawn evenly between 0 and the spread.
		-- Even in angle is not even in area, so drops crowd the aim and thin out towards the rim.
		const turn = CFrame.Angles(0, 0, random:NextNumber(0, 2 * math.pi))
		const tilt = CFrame.Angles(spread * random:NextNumber(), 0, 0)
		const speed = random:NextNumber(spray.speed.Min, spray.speed.Max) * strength

		-- Squaring the draw leans towards the small end: many fine drops and the odd big one.
		const radius = spray.radius.Min + sizes * random:NextNumber() ^ 2

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

function Drops:land(drop: Drop, hit: RaycastResult)
	const settings = self.settings
	const surface = hit.Instance

	if tagged(surface, settings.AbsorbTag) then return end

	const scale = random:NextNumber(settings.MarkScale.Min, settings.MarkScale.Max)
	const attached = if tagged(surface, settings.AttachTag) then surface else nil

	self.marks:add(hit.Position, hit.Normal, drop.radius * scale, attached)
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

@native function Drops:step(dt: number)
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
			self:remove(index)
			self:land(drop, hit)
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
