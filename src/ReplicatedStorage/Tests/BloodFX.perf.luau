const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Stats = game:GetService("Stats")

const Package = ReplicatedStorage.BloodFX

const BloodFX = require(Package)
const Config = require(Package.Config)
const Debugger = require(Package.Debugger)
const Drops = require(Package.Drops)
const Emitter = require(Package.Emitter)
const Grid = require(Package.Grid)
const Marks = require(Package.Marks)
const Pool = require(Package.Pool)
const Presets = require(Package.Presets)

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

type Case = {
	name: string,
	run: (number) -> (),
}

type Frames = {
	name: string,
	wall: number,
	physics: number,
	render: number,
	moving: number,
	script: number,
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

const function flushEngine()
	workspace:Raycast(Vector3.new(0, HEIGHT + 5, 0), DOWN * 10)
end

const function contrast(timings: { Timing }, calls: number, cases: { Case })
	for _, case in cases do
		RunService.Heartbeat:Wait()

		const started = os.clock()
		for index = 1, calls do case.run(index) end
		flushEngine()

		table.insert(timings, { name = case.name, calls = calls, micros = (os.clock() - started) / calls * 1e6 })
	end
end

const function destroyTimed(timings: { Timing }, part: BasePart, name: string)
	local handled: number? = nil
	const started = os.clock()

	part:Destroy()
	task.defer(function() handled = os.clock() end)
	task.wait()

	table.insert(timings, { name = name, calls = 1, micros = ((handled or math.huge) - started) * 1e6 })
end

const function sample(name: string, frames: number, each: ((number) -> ())?): Frames
	local wall, physics, render, moving, script = 0, 0, 0, 0, 0
	local last = os.clock()

	for frame = 1, frames do
		if each then
			const started = os.clock()
			each(frame)
			script += os.clock() - started
		end

		RunService.Heartbeat:Wait()

		const now = os.clock()
		wall += now - last
		physics += Stats.PhysicsStepTime
		render += Stats.RenderCPUFrameTime
		moving += Stats.MovingPrimitivesCount
		last = now
	end

	return {
		name = name,
		wall = wall / frames * 1e3,
		physics = physics / frames * 1e3,
		render = render / frames * 1e3,
		moving = moving / frames,
		script = script / frames * 1e6,
	}
end

const function tabulate(timings: { Timing }): string
	const rows = { "| Function | Calls | µs per call |", "| --- | ---: | ---: |" }

	for _, timing in timings do
		table.insert(rows, string.format("| %s | %d | %.2f |", timing.name, timing.calls, timing.micros))
	end

	return table.concat(rows, "\n")
end

const function tabulateFrames(scenes: { Frames }): string
	const rows = {
		"| Scene | Frame ms | Physics ms | Render CPU ms | Moving primitives | Script µs a frame |",
		"| --- | ---: | ---: | ---: | ---: | ---: |",
	}

	for _, frames in scenes do
		table.insert(rows, string.format(
			"| %s | %.2f | %.3f | %.3f | %.0f | %.1f |",
			frames.name,
			frames.wall,
			frames.physics,
			frames.render,
			frames.moving,
			frames.script
		))
	end

	return table.concat(rows, "\n")
end

const function block(parent: Instance, size: Vector3, position: Vector3): BasePart
	const part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Parent = parent

	return part
end

const function buildWorld(): Folder
	const world = Instance.new("Folder")
	world.Name = "BloodFXPerformance"

	const floor = block(world, Vector3.new(400, 1, 400), Vector3.new(0, HEIGHT - 0.5, 0))
	floor.Name = "Floor"

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

	const debugger = Debugger.new(settings)
	const pool = Pool.new(world, settings.PoolSize, settings.Color, settings.Material, debugger)
	const marks = Marks.new(pool, settings, params, debugger)
	const drops = Drops.new(pool, marks, settings, params, debugger)

	const parts = table.create(500)
	measure(timings, "Pool:take", 500, function(index) parts[index] = pool:take() end)
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
		marks:add(Vector3.new(index % 20 * 6 - 60, HEIGHT, index // 20 * 6 - 60), UP, -UP, 0.3)
	end)
	measure(timings, "Marks:add, joins a pool", 500, function()
		marks:add(Vector3.new(0, HEIGHT, 100), UP, -UP, 0.12)
	end)

	const sample = marks.list[1]
	measure(timings, "Marks:supports, 8 rays", 1000, function() marks:supports(sample, sample.radius, sample.stretch) end)
	measure(timings, "Marks:resize", 2000, function(index)
		sample.opened = if index % 2 == 1 then 0.9 else 1
		marks:resize(sample)
	end)

	for _ = 1, 20 do marks:step(FRAME, drops) end

	measure(timings, `Marks:step, {#marks.list} open marks`, 200, function() marks:step(FRAME, drops) end)
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

	measure(timings, "Drops:spray, Hit", 20, function() drops:spray(sky, UP, Presets.Hit, 1) end)
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

	const onPart = Emitter.new(origin, Presets.Fountain, sprayer, emitters)
	const onAttachment = Emitter.new(attachment, Presets.Fountain, sprayer, emitters)
	const onFrame = Emitter.new(CFrame.new(sky), Presets.Fountain, sprayer, emitters)

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

	return tabulate(timings)
end

function Performance.attachment(): string
	const timings: { Timing } = {}
	const scenes: { Frames } = {}
	const notes: { string } = {}
	const random = Random.new(1)
	const world = buildWorld()
	const floor = world:FindFirstChild("Floor") :: BasePart

	const settings = table.clone(Config)
	settings.MaxMarks = math.huge

	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true

	const debugger = Debugger.new(settings)
	const pool = Pool.new(world, 5000, settings.Color, settings.Material, debugger)
	const marks = Marks.new(pool, settings, params, debugger)
	const drops = Drops.new(pool, marks, settings, params, debugger)
	const never = function() return false end

	const function lined(index: number, z: number): Vector3
		return Vector3.new(index % 25 * 4 - 50, HEIGHT, index // 25 * 4 + z)
	end

	contrast(timings, 500, {
		{ name = "Marks:create, anchored", run = function(index) marks:create(lined(index, -100), UP, -UP, 0.3) end },
		{ name = "Marks:create, welded", run = function(index) marks:create(lined(index, 0), UP, -UP, 0.3, floor) end },
	})
	contrast(timings, 500, {
		{ name = "Marks:remove, welded", run = function() marks:remove(#marks.list) end },
		{ name = "Marks:remove, anchored", run = function() marks:remove(#marks.list) end },
	})

	const crate = block(world, Vector3.new(50, 1, 50), Vector3.new(-600, HEIGHT - 0.5, 0))
	for index = 0, 249 do
		marks:create(Vector3.new(index % 16 * 3 - 622.5, HEIGHT, index // 16 * 3 - 22.5), UP, -UP, 0.3, crate)
	end

	destroyTimed(timings, crate, "destroying a part with 250 welded marks")

	const slab = block(world, Vector3.new(200, 1, 200), Vector3.new(600, HEIGHT - 0.5, 0))
	const across = Vector3.new(600, 0, 0)

	const function spread(index: number): Vector3
		return Vector3.new(index % 50 * 3.5 - 87.5, HEIGHT, index // 50 * 3.5 - 87.5)
	end

	local placed = 0

	for _, count in { 250, 1000, 2000 } do
		const first = placed + 1

		contrast(timings, count - placed, {
			{
				name = `Marks:create, marks {first}-{count} on one part, anchored`,
				run = function(index) marks:create(spread(placed + index), UP, -UP, 0.3) end,
			},
			{
				name = `Marks:create, marks {first}-{count} on one part, welded`,
				run = function(index) marks:create(spread(placed + index) + across, UP, -UP, 0.3, slab) end,
			},
		})

		placed = count

		const middle = spread(count // 2)
		measure(timings, `landing search among {count} marks on one part, anchored`, 200, function() marks.grid:find(middle, never) end)
		measure(timings, `landing search among {count} marks on one part, welded`, 200, function() marks:findOn(slab, never) end)
	end

	measure(timings, `landing search among {placed} marks on one part, welded, one more welded before each`, 20, function()
		marks:findOn(slab, never)
	end, function(index)
		marks:create(spread(index) + across, UP, -UP, 0.3, slab)
	end)

	const welded = #marks.attached[slab]
	destroyTimed(timings, slab, `destroying a part with {welded} welded marks`)

	table.insert(notes, `{#marks.list} of {#marks.list + welded} marks were left after the part holding {welded} of them was destroyed.`)
	marks:clear()

	for _, attach in { false, true } do
		if attach then floor:AddTag(settings.AttachTag) end

		measure(timings, `Drops:step, 160 landing at once, {if attach then "welded" else "anchored"}`, 10, function()
			drops:step(FRAME)
			flushEngine()
		end, function()
			drops:clear()
			marks:clear()

			for _ = 1, 160 do
				const spot = Vector3.new(random:NextNumber(-150, 150), HEIGHT + 0.5, random:NextNumber(-150, 150))
				drops:launch(spot, Vector3.new(0, -60, 0), 0.1)
			end
		end)

		floor:RemoveTag(settings.AttachTag)
	end

	drops:clear()
	marks:clear()

	const camera = workspace.CurrentCamera
	const level = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	const ahead = if level.Magnitude > 0.1 then level.Unit else -Vector3.zAxis
	const center = camera.CFrame.Position + ahead * 40 - UP * 8
	const stage = block(world, Vector3.new(60, 1, 60), center - UP * 0.5)

	const function fillStage(surface: BasePart?)
		for index = 0, 999 do
			marks:create(center + Vector3.new(index % 32 * 1.8 - 28, 0, index // 32 * 1.8 - 28), UP, -UP, 0.3, surface)
		end
	end

	for _ = 1, 2 do
		table.insert(scenes, sample("no marks", 240))

		fillStage(nil)
		table.insert(scenes, sample("1000 anchored marks in view", 240))
		marks:clear()

		fillStage(stage)
		table.insert(scenes, sample("1000 welded marks in view, part at rest", 240))
		marks:clear()
	end

	const home = CFrame.new(center + UP * 8)
	const lift = block(world, Vector3.new(20, 1, 20), home.Position)

	const function onLift(index: number): Vector3
		return home.Position + Vector3.new(index % 32 * 0.6 - 9.3, 0.5, index // 32 * 0.6 - 9.3)
	end

	for _, count in { 0, 100, 1000 } do
		for index = 0, count - 1 do marks:create(onLift(index), UP, -UP, 0.3, lift) end

		table.insert(scenes, sample(`part turned by CFrame, {count} welded marks`, 240, function(frame)
			lift.CFrame = home * CFrame.Angles(0, frame * 0.02, 0)
		end))

		marks:clear()
		lift.CFrame = home

		for index = 0, count - 1 do marks:create(onLift(index), UP, -UP, 0.3) end

		const parts: { BasePart } = {}
		const offsets: { CFrame } = {}

		for index, mark in marks.list do
			parts[index] = mark.part
			offsets[index] = home:ToObjectSpace(mark.part.CFrame)
		end

		table.insert(scenes, sample(`part turned by CFrame, {count} anchored marks moved by BulkMoveTo`, 240, function(frame)
			const turned = home * CFrame.Angles(0, frame * 0.02, 0)
			const targets = table.create(#parts)

			lift.CFrame = turned
			for index, offset in offsets do targets[index] = turned * offset end
			workspace:BulkMoveTo(parts, targets, Enum.BulkMoveMode.FireCFrameChanged)
		end))

		marks:clear()
		lift.CFrame = home
	end

	const pivot = block(world, Vector3.new(2, 1, 2), center + Vector3.new(0, 4, 30))
	const disc = block(world, Vector3.new(20, 1, 20), center + Vector3.new(0, 6, 30))
	disc.Anchored = false

	const upright = CFrame.Angles(0, 0, math.rad(90))

	const below = Instance.new("Attachment")
	below.CFrame = CFrame.new(0, 0.5, 0) * upright
	below.Parent = pivot

	const above = Instance.new("Attachment")
	above.CFrame = CFrame.new(0, -1.5, 0) * upright
	above.Parent = disc

	const hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = below
	hinge.Attachment1 = above
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = 2
	hinge.MotorMaxTorque = 1e9
	hinge.Parent = disc

	task.wait(0.5)

	for _, count in { 0, 100, 1000 } do
		const turned = disc.CFrame

		for index = 0, count - 1 do
			const spot = turned:PointToWorldSpace(Vector3.new(index % 32 * 0.6 - 9.3, 0.5, index // 32 * 0.6 - 9.3))
			marks:create(spot, turned.UpVector, -UP, 0.3, disc)
		end

		table.insert(scenes, sample(`part spun by a hinge motor, {count} welded marks`, 240))
		marks:clear()
	end

	world:Destroy()

	return table.concat({ tabulate(timings), tabulateFrames(scenes), table.concat(notes, "\n") }, "\n\n")
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
	track(Debugger, "Debugger:")

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
