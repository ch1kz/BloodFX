const AssetService = game:GetService("AssetService")

const STORAGE = CFrame.new(0, -1e4, 0)
const RESIZE_BUDGET = 1e-3

local Pool = {}
Pool.__index = Pool

const function prepare(part: BasePart, color: Color3, material: Enum.Material): BasePart
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Color = color
	part.Material = material
	part.CFrame = STORAGE

	return part
end

function Pool.new(parent: Instance, size: number, color: Color3, material: Enum.Material, mesh: string, debugger)
	const container = Instance.new("Folder")
	container.Name = "Parts"
	container.Parent = parent

	const template = prepare(Instance.new("Part"), color, material)

	const sphere = Instance.new("SpecialMesh")
	sphere.MeshType = Enum.MeshType.Sphere
	sphere.Parent = template

	const self = setmetatable({
		container = container,
		template = template,
		debugger = debugger,
		size = math.floor(size),
		total = 0,
		idle = {} :: { BasePart },
		retired = {} :: { BasePart },
		outdated = {} :: { [BasePart]: true },
	}, Pool)

	for _ = 1, self.size do
		table.insert(self.idle, self:create())
	end

	if mesh ~= "" then task.spawn(self.load, self, mesh) end

	return self
end

function Pool:load(mesh: string)
	const ok, part = pcall(AssetService.CreateMeshPartAsync, AssetService, Content.fromUri(mesh), {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Performance,
	})

	if not ok then
		warn(`[BloodFX] could not load Mesh {mesh}, so blood keeps the engine's sphere: {part}`)
		return
	end

	self:retemplate(prepare(part, self.template.Color, self.template.Material))
end

function Pool:retemplate(template: BasePart)
	self.template:Destroy()
	self.template = template

	for _, part in self.container:GetChildren() do self.outdated[part] = true end

	table.move(self.idle, 1, #self.idle, #self.retired + 1, self.retired)
	table.clear(self.idle)
end

function Pool:create(): BasePart
	const part = self.template:Clone()
	part.Parent = self.container
	self.total += 1

	return part
end

function Pool:discard(part: BasePart)
	self.outdated[part] = nil
	part:Destroy()
	self.total -= 1
end

function Pool:take(): BasePart
	const part = table.remove(self.idle) or table.remove(self.retired) or self:expand()
	part.Transparency = 0

	return part
end

function Pool:expand(): BasePart
	const part = self:create()
	self.debugger:fire({ kind = "PoolExpanded", parts = self.total, limit = self.size })

	return part
end

function Pool:give(part: BasePart)
	if self:spare() >= self.size then
		self:discard(part)
	else
		part.CFrame = STORAGE
		table.insert(if self.outdated[part] then self.retired else self.idle, part)
	end
end

function Pool:spare(): number
	return #self.idle + #self.retired
end

function Pool:resize(size: number)
	self.size = math.floor(size)
end

function Pool:step()
	const idle, retired = self.idle, self.retired
	const deadline = os.clock() + RESIZE_BUDGET

	while os.clock() < deadline do
		if self:spare() > self.size then
			self:discard(table.remove(retired) or table.remove(idle))
		elseif #retired > 0 then
			self:discard(table.remove(retired))
			table.insert(idle, self:create())
		elseif self.total < self.size then
			table.insert(idle, self:create())
		else
			return
		end
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
