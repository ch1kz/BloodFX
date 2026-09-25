const Grid = require(script.Parent.Grid)
const Types = require(script.Parent.Types)

type Bond = {
	surface: BasePart,
	weld: WeldConstraint,
	watch: RBXScriptConnection,
}

type Mark = {
	part: BasePart,
	position: Vector3,
	normal: Vector3,
	radius: number,
	shape: number,
	stretch: number,
	opened: number,
	age: number,
	bond: Bond?,
}

const START_SCALE = 0.35
const MIN_RADIUS = 0.02
const MERGE_ALIGNMENT = 0.7
const PLANE_TOLERANCE = 0.25
const RIM_POINTS = 8
const MAX_ELONGATION = 3
const DRIP_RADIUS = NumberRange.new(0.1, 0.15)
const NO_MARKS: { Mark } = table.freeze({})

const RIM: { Vector3 } = table.create(RIM_POINTS)
for index = 1, RIM_POINTS do
	const angle = index * 2 * math.pi / RIM_POINTS
	RIM[index] = Vector3.new(0, math.cos(angle), math.sin(angle))
end

const random = Random.new()

const function poolingOn(normal: Vector3, wall: number, ceiling: number): number
	-- normal.Y is the cosine of the surface's tilt: 1 on the floor, 0 on a wall, -1 on a ceiling.
	-- Slopes blend between the floor and the wall, overhangs between the wall and the ceiling.
	const up = normal.Y

	if up >= 0 then return wall + (1 - wall) * up end

	return wall + (wall - ceiling) * up
end

local Marks = {}
Marks.__index = Marks

function Marks.new(pool, settings: Types.Config, params: RaycastParams, debugger)
	return setmetatable({
		pool = pool,
		settings = settings,
		params = params,
		debugger = debugger,
		list = {} :: { Mark },
		attached = {} :: { [BasePart]: { Mark } },

		-- A cell as wide as the farthest reach of any pool keeps every mark a drop could join
		-- within the 27 cells around the spot where it lands.
		grid = Grid.new(settings.MarkMaxRadius * settings.MergeReach),
	}, Marks)
end

function Marks:add(position: Vector3, normal: Vector3, velocity: Vector3, radius: number, surface: BasePart?)
	const settings = self.settings
	const pooling = poolingOn(normal, settings.WallPooling, settings.CeilingPooling)
	const reach = settings.MergeReach * pooling

	const joins = @native function(mark: Mark): boolean
		const gap = position - mark.position
		const aligned = mark.normal:Dot(normal) >= MERGE_ALIGNMENT

		-- gap projected on the normal is how far the new drop sits off the mark's plane.
		const coplanar = aligned and math.abs(gap:Dot(mark.normal)) <= PLANE_TOLERANCE

		return coplanar and gap.Magnitude <= mark.radius * reach
	end

	const target = if pooling == 0 then nil
		elseif surface then self:findOn(surface, joins)
		else self.grid:find(position, joins)

	if target then
		self:grow(target, radius, pooling)
	else
		self:create(position, normal, velocity, radius, surface)
	end
end

function Marks:findOn(surface: BasePart, joins: (Mark) -> boolean): Mark?
	for _, mark in self.attached[surface] or NO_MARKS do
		mark.position = mark.part.Position
		mark.normal = mark.part.CFrame.RightVector

		if joins(mark) then return mark end
	end

	return nil
end

function Marks:create(position: Vector3, normal: Vector3, velocity: Vector3, radius: number, surface: BasePart?)
	const settings = self.settings

	-- The velocity without its part into the surface is the way the drop skids. Head-on there is no
	-- skid, so any tangent will do: the normal crossed with a random direction.
	const skid = velocity - normal * velocity:Dot(normal)
	const along = if skid.Magnitude > 1e-3 then skid.Unit else normal:Cross(random:NextUnitVector()).Unit

	-- A stain's width over its length is the sine of the angle the drop came in at; that sine is the
	-- share of the speed that went into the surface.
	const sine = math.abs(velocity:Dot(normal)) / velocity.Magnitude
	const elongation = 1 + (math.min(1 / sine, MAX_ELONGATION) - 1) * settings.SlantStretch

	const shape = random:NextNumber(settings.MarkStretch.Min, settings.MarkStretch.Max)
	const part = self.pool:take()

	-- A mark is flat along X and long along Z. With X on the normal and Y across the skid,
	-- Z = X x Y follows the skid.
	part.CFrame = CFrame.fromMatrix(position, normal, along:Cross(normal))

	const mark: Mark = {
		part = part,
		position = position,
		normal = normal,
		radius = math.min(radius, settings.MarkMaxRadius),
		shape = shape,
		stretch = elongation * shape,
		opened = START_SCALE,
		age = 0,
	}

	while mark.radius > MIN_RADIUS and not self:supports(mark, mark.radius, mark.stretch) do
		mark.radius /= 2
	end

	self:resize(mark)
	table.insert(self.list, mark)

	if surface then
		self:attach(mark, surface)
	else
		self.grid:insert(mark)
	end

	self:trim()
end

function Marks:attach(mark: Mark, surface: BasePart)
	mark.part.Anchored = false

	const weld = Instance.new("WeldConstraint")
	weld.Part0 = mark.part
	weld.Part1 = surface
	weld.Parent = mark.part

	const watch = surface.AncestryChanged:Connect(function()
		const index = table.find(self.list, mark)
		if index and not surface:IsDescendantOf(workspace) then self:remove(index) end
	end)

	mark.bond = { surface = surface, weld = weld, watch = watch }

	const marks = self.attached[surface]

	if marks then
		table.insert(marks, mark)
	else
		self.attached[surface] = { mark }
	end
end

function Marks:detach(mark: Mark, bond: Bond)
	const marks = self.attached[bond.surface]

	table.remove(marks, table.find(marks, mark))
	if #marks == 0 then self.attached[bond.surface] = nil end

	bond.watch:Disconnect()
	bond.weld:Destroy()
	mark.part.Anchored = true
end

function Marks:grow(mark: Mark, radius: number, pooling: number)
	const settings = self.settings

	-- Areas add up, so the radii combine as the root of their squares.
	const grown = math.sqrt(mark.radius ^ 2 + (radius * settings.MergeGrowth) ^ 2)
	const capped = math.min(grown, settings.MarkMaxRadius * pooling)

	-- The length a slanted landing added on top of the mark's own shape stays as it was, so the
	-- streak keeps its length while the pool grows into that shape around it.
	const stretch = mark.shape + (mark.stretch - mark.shape) * mark.radius / capped

	if capped > mark.radius and self:supports(mark, capped, stretch) then
		mark.radius = capped
		mark.stretch = stretch
	end

	mark.age = 0
	mark.part.Transparency = 0
	self:resize(mark)
end

@native function Marks:supports(mark: Mark, radius: number, stretch: number): boolean
	const frame = mark.part.CFrame
	const lift = mark.normal * PLANE_TOLERANCE

	-- Each side is a unit direction across the mark; scaling it by the two radii lands it on the
	-- oval's rim. A short ray through the plane there tells whether anything holds that edge up.
	for _, side in RIM do
		const edge = frame:PointToWorldSpace(side * Vector3.new(0, radius, radius * stretch))
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
	const bond = mark.bond

	if bond then
		self:detach(mark, bond)
	else
		self.grid:remove(mark)
	end

	self.pool:give(mark.part)
end

function Marks:trim()
	const list = self.list
	const limit = self.settings.MaxMarks

	while #list > limit do
		local oldest = 1

		for index, mark in list do
			if mark.age > list[oldest].age then oldest = index end
		end

		self.debugger:fire({ kind = "MarkLimit", age = list[oldest].age, limit = limit })
		self:remove(oldest)
	end
end

function Marks:drip(mark: Mark, drops)
	const settings = self.settings
	const radius = random:NextNumber(DRIP_RADIUS.Min, DRIP_RADIUS.Max)
	const stain = radius * settings.MarkScale.Min

	if mark.radius <= stain then return end

	-- Dripping undoes a merge: the pool gives back the area a drop this size adds when it joins.
	mark.radius = math.max(math.sqrt(mark.radius ^ 2 - (stain * settings.MergeGrowth) ^ 2), stain)
	self:resize(mark)

	-- Gravity without its part into the surface points down the slope, so the drop leaves from the
	-- low side of the pool. On a flat ceiling nothing is left of it and the drop leaves the middle.
	const frame = mark.part.CFrame
	const normal = frame.RightVector
	const downhill = normal * normal.Y - Vector3.yAxis
	const start = frame.Position + downhill * mark.radius + normal * (radius + settings.MarkThickness)

	drops:launch(start, Vector3.zero, radius)
end

function Marks:regrid()
	const settings = self.settings
	const loose = {}

	for _, mark in self.list do
		if not mark.bond then table.insert(loose, mark) end
	end

	self.grid:rebuild(settings.MarkMaxRadius * settings.MergeReach, loose)
end

function Marks:fade()
	const lifetime = self.settings.MarkLifetime
	for _, mark in self.list do mark.age = math.max(mark.age, lifetime) end
end

function Marks:clear()
	for index = #self.list, 1, -1 do self:remove(index) end
end

@native function Marks:step(dt: number, drops)
	const settings = self.settings

	-- normal.Y is the cosine of a surface's tilt. Pools drip where it falls below the cosine of
	-- CeilingDripAngle, and the chance climbs linearly from nothing there to the full rate at -1,
	-- a flat ceiling.
	const edge = math.cos(math.rad(settings.CeilingDripAngle))
	const chance = if settings.CeilingDrip then settings.CeilingDripRate * dt / math.max(edge + 1, 1e-3) else 0

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
		elseif mark.normal.Y < edge and random:NextNumber() < (edge - mark.normal.Y) * chance then
			self:drip(mark, drops)
		end
	end
end

return Marks
