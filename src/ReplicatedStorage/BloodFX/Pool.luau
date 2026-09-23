const STORAGE = CFrame.new(0, -1e4, 0)

local Pool = {}
Pool.__index = Pool

function Pool.new(parent: Instance, size: number, color: Color3, material: Enum.Material)
	const container = Instance.new("Folder")
	container.Name = "Parts"
	container.Parent = parent

	const template = Instance.new("Part")
	template.Anchored = true
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.CastShadow = false
	template.Massless = true
	template.Color = color
	template.Material = material
	template.CFrame = STORAGE

	const self = setmetatable({
		container = container,
		template = template,
		size = size,
		total = 0,
		idle = {} :: { BasePart },
	}, Pool)

	for _ = 1, size do
		table.insert(self.idle, self:create())
	end

	return self
end

function Pool:create(): BasePart
	const part = self.template:Clone()
	part.Parent = self.container
	self.total += 1

	return part
end

function Pool:take(shape: Enum.PartType): BasePart
	const part = table.remove(self.idle) or self:create()
	part.Shape = shape
	part.Transparency = 0

	return part
end

function Pool:give(part: BasePart)
	if #self.idle < self.size then
		part.CFrame = STORAGE
		table.insert(self.idle, part)
	else
		part:Destroy()
		self.total -= 1
	end
end

function Pool:paint(color: Color3, material: Enum.Material)
	self.template.Color = color
	self.template.Material = material

	for _, part in self.container:GetChildren() do
		part.Color = color
		part.Material = material
	end
end

return Pool
