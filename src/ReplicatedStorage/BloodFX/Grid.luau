const MIN_CELL = 0.1
const EMPTY = table.freeze({})

-- The digits of 0..26 in base 3, shifted down by one, are every offset from -1 to 1 on each axis.
const NEIGHBOURS: { Vector3 } = table.create(27)
for index = 0, 26 do
	NEIGHBOURS[index + 1] = Vector3.new(index % 3, index // 3 % 3, index // 9) - Vector3.one
end

local Grid = {}
Grid.__index = Grid

function Grid.new(cell: number)
	return setmetatable({
		cell = math.max(cell, MIN_CELL),
		buckets = {} :: { [Vector3]: { any } },
	}, Grid)
end

function Grid:insert(item)
	const key = item.position // self.cell
	const bucket = self.buckets[key]

	if bucket then
		table.insert(bucket, item)
	else
		self.buckets[key] = { item }
	end
end

function Grid:remove(item)
	const key = item.position // self.cell
	const bucket = self.buckets[key]

	table.remove(bucket, table.find(bucket, item))
	if #bucket == 0 then self.buckets[key] = nil end
end

function Grid:find(position: Vector3, accepts: (any) -> boolean): any?
	const key = position // self.cell

	for _, offset in NEIGHBOURS do
		for _, item in self.buckets[key + offset] or EMPTY do
			if accepts(item) then return item end
		end
	end

	return nil
end

function Grid:rebuild(cell: number, items: { any })
	self.cell = math.max(cell, MIN_CELL)
	table.clear(self.buckets)

	for _, item in items do self:insert(item) end
end

function Grid:clear()
	table.clear(self.buckets)
end

return Grid
