const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const Package = ReplicatedStorage.BloodFX

const BloodFX = require(Package)
const Config = require(Package.Config)
const Drops = require(Package.Drops)
const Emitter = require(Package.Emitter)
const Grid = require(Package.Grid)
const Marks = require(Package.Marks)
const Pool = require(Package.Pool)
const Fountain = require(Package.Presets.Fountain)
const Hit = require(Package.Presets.Hit)

type Timing = {
	name: string,
	calls: number,
	micros: number,
}

type Record = {
	name: string,
	calls: number,
	total: number,
	own: number,
}

const HEIGHT = 2000
const FRAME = 1 / 60
const UP = Vector3.yAxis
const DOWN = -Vector3.yAxis

const Performance = {}

const function measure(
	timings: { Timing },
	name: string,
	calls: number,
	run: (number) -> (),
	setup: ((number) -> ())?
)
	local elapsed = 0

	if setup then
		for index = 1, calls do
			setup(index)

			const started = os.clock()
			run(index)
			elapsed += os.clock() - started
		end
	else
		const started = os.clock()
		for index = 1, calls do run(index) end
		elapsed = os.clock() - started
	end

	table.insert(timings, { name = name, calls = calls, micros = elapsed / calls * 1e6 })
end

const function buildWorld(): Folder
	const world = Instance.new("Folder")
	world.Name = "BloodFXPerformance"

	const floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(400, 1, 400)
	floor.Position = Vector3.new(0, HEIGHT - 0.5, 0)
	floor.Parent = world

	world.Parent = workspace

	return world
end

function Performance.benchmark(): string
	const timings: { Timing } = {}
	const random = Random.new(1)
	const world = buildWorld()
	const sky = Vector3.new(0, HEIGHT + 500, 0)

	const settings = table.clone(Config)
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true

	const pool = Pool.new(world, settings.PoolSize, settings.Color, settings.Material)
	const marks = Marks.new(pool, settings, params)
	const drops = Drops.new(pool, marks, settings, params)

	const parts = table.create(500)
	measure(timings, "Pool:take", 500, function(index) parts[index] = pool:take(Enum.PartType.Ball) end)
	measure(timings, "Pool:give", 500, function(index) pool:give(parts[index]) end, function(index)
		parts[index].CFrame = CFrame.new(index % 25 * 2, HEIGHT + 5, index // 25 * 2)
	end)
	measure(timings, "Pool:create", 200, function(index) parts[index] = pool:create() end)
	measure(timings, "Pool:paint, 800 parts", 20, function(index)
		pool:paint(if index % 2 == 1 then Color3.new(1, 0, 0) else settings.Color, settings.Material)
	end)

	for index = 1, 200 do pool:give(parts[index]) end

	const grid = Grid.new(settings.MarkMaxRadius * settings.MergeReach)
	const items = table.create(settings.MaxMarks)
	const never = function() return false end

	for index = 1, settings.MaxMarks do
		items[index] = { position = Vector3.new(random:NextNumber(0, 20), 0, random:NextNumber(0, 14)) }
	end

	measure(timings, "Grid:insert", #items, function(index) grid:insert(items[index]) end)
	measure(timings, "Grid:find, 240 marks on one bay, no match", 1000, function(index)
		grid:find(items[index % #items + 1].position, never)
	end)
	measure(timings, "Grid:rebuild, 240 marks", 100, function()
		grid:rebuild(settings.MarkMaxRadius * settings.MergeReach, items)
	end)
	measure(timings, "Grid:remove", #items, function(index) grid:remove(items[index]) end)

	settings.MaxMarks = math.huge

	measure(timings, "Marks:add, new mark", 240, function(index)
		marks:add(Vector3.new(index % 20 * 6 - 60, HEIGHT, index // 20 * 6 - 60), UP, 0.3)
	end)
	measure(timings, "Marks:add, joins a pool", 500, function()
		marks:add(Vector3.new(0, HEIGHT, 100), UP, 0.12)
	end)

	const sample = marks.list[1]
	measure(timings, "Marks:supports, 8 rays", 1000, function() marks:supports(sample, sample.radius) end)
	measure(timings, "Marks:resize", 2000, function(index)
		sample.opened = if index % 2 == 1 then 0.9 else 1
		marks:resize(sample)
	end)

	for _ = 1, 20 do marks:step(FRAME) end

	measure(timings, `Marks:step, {#marks.list} open marks`, 200, function() marks:step(FRAME) end)
	measure(timings, `Marks:regrid, {#marks.list} marks`, 100, function() marks:regrid() end)

	settings.MaxMarks = #marks.list
	measure(timings, "Marks:trim, one over the cap", 50, function()
		settings.MaxMarks -= 1
		marks:trim()
	end)

	measure(timings, `Marks:clear, {#marks.list} marks`, 1, function() marks:clear() end)
	settings.MaxMarks = Config.MaxMarks

	settings.MaxDrops = math.huge
	measure(timings, "Drops:launch", 500, function() drops:launch(sky, Vector3.zero, 0.1) end)
	drops:clear()
	settings.MaxDrops = Config.MaxDrops

	measure(timings, "Drops:spray, Hit", 20, function() drops:spray(sky, UP, Hit, 1) end)
	drops:clear()

	for _ = 1, settings.MaxDrops do
		drops:launch(sky + Vector3.new(random:NextNumber(-50, 50), 0, random:NextNumber(-50, 50)), Vector3.zero, 0.1)
	end

	measure(timings, "Drops:step, 160 in flight", 100, function() drops:step(FRAME) end)
	drops:clear()

	measure(timings, "Drops:step, 160 landing at once", 10, function() drops:step(FRAME) end, function()
		drops:clear()
		marks:clear()

		for _ = 1, settings.MaxDrops do
			const spot = Vector3.new(random:NextNumber(-150, 150), HEIGHT + 0.5, random:NextNumber(-150, 150))
			drops:launch(spot, Vector3.new(0, -60, 0), 0.1)
		end
	end)

	drops:clear()
	marks:clear()

	const origin = Instance.new("Part")
	origin.Anchored = true
	origin.Position = sky
	origin.Parent = world

	const attachment = Instance.new("Attachment")
	attachment.Parent = origin

	const emitters = {}
	const sprayer = function(position: Vector3, direction: Vector3, shape, strength: number)
		drops:spray(position, direction, shape, strength)
	end

	const onPart = Emitter.new(origin, Fountain, sprayer, emitters)
	const onAttachment = Emitter.new(attachment, Fountain, sprayer, emitters)
	const onFrame = Emitter.new(CFrame.new(sky), Fountain, sprayer, emitters)

	measure(timings, "Emitter:frame, part", 5000, function() onPart:frame() end)
	measure(timings, "Emitter:frame, attachment", 5000, function() onAttachment:frame() end)
	measure(timings, "Emitter:frame, CFrame", 5000, function() onFrame:frame() end)

	onPart.due = math.huge
	measure(timings, "Emitter:step, nothing due", 10000, function() onPart:step(FRAME) end)
	measure(timings, "Emitter:emit, Fountain", 40, function() onPart:emit() end, function(index)
		if index % 20 == 1 then drops:clear() end
	end)

	drops:clear()
	world:Destroy()

	const ground = Vector3.new(150, HEIGHT, 150)
	const scratch = buildWorld()

	measure(timings, "BloodFX.spray, Hit", 20, function() BloodFX.spray(ground + UP * 3, DOWN, "Hit") end)
	measure(timings, "BloodFX.mark", 200, function(index)
		BloodFX.mark(ground + Vector3.new(index % 20, 0, index // 20), UP, 0.2)
	end)
	measure(timings, "BloodFX.emitter + destroy", 1000, function() BloodFX.emitter(CFrame.new(ground), "Drip"):destroy() end)
	measure(timings, "BloodFX.get", 10000, function() BloodFX.get("Gravity") end)
	measure(timings, "BloodFX.set, Gravity", 1000, function(index) BloodFX.set("Gravity", Config.Gravity + index % 2) end)
	measure(timings, "BloodFX.set, Color (repaints the pool)", 10, function(index)
		BloodFX.set("Color", if index % 2 == 1 then Color3.new(1, 0, 0) else Config.Color)
	end)
	measure(timings, "BloodFX.stats", 10000, function() BloodFX.stats() end)
	measure(timings, "BloodFX.freeze + unfreeze", 100, function()
		BloodFX.freeze()
		BloodFX.unfreeze()
	end)

	BloodFX.set("Gravity", Config.Gravity)
	BloodFX.set("Color", Config.Color)
	BloodFX.clear()
	scratch:Destroy()

	const rows = { "| Function | Calls | µs per call |", "| --- | ---: | ---: |" }

	for _, timing in timings do
		table.insert(rows, string.format("| %s | %d | %.2f |", timing.name, timing.calls, timing.micros))
	end

	return table.concat(rows, "\n")
end

function Performance.profile(seconds: number): string
	const records: { Record } = {}
	const restores: { () -> () } = {}
	const stack: { number } = {}

	const function track(owner: { [string]: any }, prefix: string)
		for name, original in owner do
			if typeof(original) ~= "function" then continue end

			const record: Record = { name = prefix .. name, calls = 0, total = 0, own = 0 }
			table.insert(records, record)
			table.insert(restores, function() owner[name] = original end)

			owner[name] = function(...)
				table.insert(stack, 0)

				const started = os.clock()
				const result = original(...)
				const elapsed = os.clock() - started

				const nested = stack[#stack]
				stack[#stack] = nil

				record.calls += 1
				record.total += elapsed
				record.own += elapsed - nested
				if #stack > 0 then stack[#stack] += elapsed end

				return result
			end
		end
	end

	track(BloodFX, "BloodFX.")
	track(Pool, "Pool:")
	track(Grid, "Grid:")
	track(Marks, "Marks:")
	track(Drops, "Drops:")
	track(Emitter, "Emitter:")

	local frames = 0
	const counter = RunService.Heartbeat:Connect(function() frames += 1 end)
	const started = os.clock()

	task.wait(seconds)

	const elapsed = os.clock() - started
	counter:Disconnect()

	for _, restore in restores do restore() end

	table.sort(records, function(a, b) return a.own > b.own end)

	local own = 0
	for _, record in records do own += record.own end

	const rows = {
		string.format(
			"%d frames in %.1f s. BloodFX spent %.2f ms a second, %.3f ms a frame.",
			frames,
			elapsed,
			own / elapsed * 1000,
			own / frames * 1000
		),
		"",
		"| Function | Calls/s | Own µs per call | Own ms/s | Share | With callees ms/s |",
		"| --- | ---: | ---: | ---: | ---: | ---: |",
	}

	for _, record in records do
		if record.calls == 0 then continue end

		table.insert(rows, string.format(
			"| %s | %.1f | %.2f | %.3f | %.1f%% | %.3f |",
			record.name,
			record.calls / elapsed,
			record.own / record.calls * 1e6,
			record.own / elapsed * 1000,
			record.own / own * 100,
			record.total / elapsed * 1000
		))
	end

	return table.concat(rows, "\n")
end

return Performance
