const Grid = require(script.Parent.Grid)
const Types = require(script.Parent.Types)

type Mark = {
	part: BasePart,
	position: Vector3,
	normal: Vector3,
	radius: number,
	stretch: number,
	opened: number,
	age: number,
}

const START_SCALE = 0.35
const MIN_RADIUS = 0.02
const MERGE_ALIGNMENT = 0.7
const PLANE_TOLERANCE = 0.25
const RIM_POINTS = 8

const RIM: { Vector3 } = table.create(RIM_POINTS)
for index = 1, RIM_POINTS do
	const angle = index * 2 * math.pi / RIM_POINTS
	RIM[index] = Vector3.new(0, math.cos(angle), math.sin(angle))
end

const random = Random.new()

local Marks = {}
Marks.__index = Marks

function Marks.new(pool, settings: Types.Config, params: RaycastParams)
	return setmetatable({
		pool = pool,
		settings = settings,
		params = params,
		list = {} :: { Mark },

		-- A cell as wide as the farthest reach of any pool keeps every mark a drop could join
		-- within the 27 cells around the spot where it lands.
		grid = Grid.new(settings.MarkMaxRadius * settings.MergeReach),
	}, Marks)
end

function Marks:add(position: Vector3, normal: Vector3, radius: number)
	const reach = self.settings.MergeReach

	const target = self.grid:find(position, function(mark: Mark)
		const gap = position - mark.position
		const aligned = mark.normal:Dot(normal) >= MERGE_ALIGNMENT

		-- gap projected on the normal is how far the new drop sits off the mark's plane.
		const coplanar = aligned and math.abs(gap:Dot(mark.normal)) <= PLANE_TOLERANCE

		return coplanar and gap.Magnitude <= mark.radius * reach
	end)

	if target then
		self:grow(target, radius)
	else
		self:create(position, normal, radius)
	end
end

function Marks:create(position: Vector3, normal: Vector3, radius: number)
	const settings = self.settings

	const part = self.pool:take(Enum.PartType.Cylinder)

	-- A cylinder's round faces sit on its X axis: point X along the normal and turn Y to a random
	-- tangent, which is the normal crossed with any random direction.
	part.CFrame = CFrame.fromMatrix(position, normal, normal:Cross(random:NextUnitVector()).Unit)

	const mark: Mark = {
		part = part,
		position = position,
		normal = normal,
		radius = math.min(radius, settings.MarkMaxRadius),
		stretch = random:NextNumber(settings.MarkStretch.Min, settings.MarkStretch.Max),
		opened = START_SCALE,
		age = 0,
	}

	while mark.radius > MIN_RADIUS and not self:supports(mark, mark.radius) do
		mark.radius /= 2
	end

	self:resize(mark)
	self.grid:insert(mark)
	table.insert(self.list, mark)

	self:trim()
end

function Marks:grow(mark: Mark, radius: number)
	const settings = self.settings

	-- Areas add up, so the radii combine as the root of their squares.
	const grown = math.sqrt(mark.radius ^ 2 + (radius * settings.MergeGrowth) ^ 2)
	const capped = math.min(grown, settings.MarkMaxRadius)

	if capped > mark.radius and self:supports(mark, capped) then mark.radius = capped end

	mark.age = 0
	mark.part.Transparency = 0
	self:resize(mark)
end

function Marks:supports(mark: Mark, radius: number): boolean
	const frame = mark.part.CFrame
	const lift = mark.normal * PLANE_TOLERANCE

	-- Each side is a unit direction across the mark; scaling it by the two radii lands it on the
	-- oval's rim. A short ray through the plane there tells whether anything holds that edge up.
	for _, side in RIM do
		const edge = frame:PointToWorldSpace(side * Vector3.new(0, radius, radius * mark.stretch))
		if not workspace:Raycast(edge + lift, lift * -2, self.params) then return false end
	end

	return true
end

function Marks:resize(mark: Mark)
	const diameter = mark.radius * mark.opened * 2
	mark.part.Size = Vector3.new(self.settings.MarkThickness, diameter, diameter * mark.stretch)
end

function Marks:resizeAll()
	for _, mark in self.list do self:resize(mark) end
end

function Marks:remove(index: number)
	const mark = table.remove(self.list, index)

	self.grid:remove(mark)
	self.pool:give(mark.part)
end

function Marks:trim()
	const list = self.list

	while #list > self.settings.MaxMarks do
		local oldest = 1

		for index, mark in list do
			if mark.age > list[oldest].age then oldest = index end
		end

		self:remove(oldest)
	end
end

function Marks:regrid()
	const settings = self.settings
	self.grid:rebuild(settings.MarkMaxRadius * settings.MergeReach, self.list)
end

function Marks:fade()
	const lifetime = self.settings.MarkLifetime
	for _, mark in self.list do mark.age = math.max(mark.age, lifetime) end
end

function Marks:clear()
	for _, mark in self.list do self.pool:give(mark.part) end

	table.clear(self.list)
	self.grid:clear()
end

function Marks:step(dt: number)
	const settings = self.settings

	for index = #self.list, 1, -1 do
		const mark = self.list[index]
		mark.age += dt

		if mark.opened < 1 then
			mark.opened = math.min(mark.opened + dt / settings.MarkOpenTime, 1)
			self:resize(mark)
		end

		const faded = (mark.age - settings.MarkLifetime) / settings.MarkFadeTime

		if faded >= 1 then
			self:remove(index)
		elseif faded > 0 then
			mark.part.Transparency = faded
		end
	end
end

return Marks
