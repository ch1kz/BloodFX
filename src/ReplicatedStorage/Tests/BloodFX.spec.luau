const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const BloodFX = require(ReplicatedStorage.BloodFX)
const Config = require(ReplicatedStorage.BloodFX.Config)
const Presets = require(ReplicatedStorage.BloodFX.Presets)

type Case = {
	name: string,
	run: () -> (),
}

const HEIGHT = 1000
const ABOVE = Vector3.new(0, HEIGHT + 3, 0)
const DOWN = -Vector3.yAxis
const UP = Vector3.yAxis

const cases: { Case } = {}

const function test(name: string, run: () -> ())
	table.insert(cases, { name = name, run = run })
end

const function expect(condition: any, message: string)
	if not condition then error(message, 2) end
end

const function block(size: Vector3, position: Vector3): BasePart
	const part = Instance.new("Part")
	part.Name = "BloodFXTestBlock"
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Parent = workspace

	return part
end

const function flat(part: BasePart): boolean
	return part.Size.X < part.Size.Y
end

const function raisedMarks(): { BasePart }
	const found = {}

	for _, part in workspace.BloodFX.Parts:GetChildren() do
		if flat(part) and part.Position.Y > HEIGHT + 1 then table.insert(found, part) end
	end

	return found
end

const function markNear(position: Vector3): BasePart?
	for _, part in workspace.BloodFX.Parts:GetChildren() do
		if flat(part) and (part.Position - position).Magnitude < 0.01 then return part end
	end

	return nil
end

const function settle(parts: number): number
	const deadline = os.clock() + 5
	while BloodFX.stats().parts ~= parts and os.clock() < deadline do task.wait() end

	return BloodFX.stats().parts
end

const function carried(plate: BasePart, move: () -> ()): (number, number)
	BloodFX.spray(plate.Position + UP * (plate.Size.Y / 2 + 2), DOWN, "Hit")
	task.wait(1)

	const marks = raisedMarks()
	const offsets = {}
	for _, mark in marks do offsets[mark] = plate.CFrame:PointToObjectSpace(mark.Position) end

	move()
	task.wait()

	local followed = 0
	for mark, offset in offsets do
		if (plate.CFrame:PointToObjectSpace(mark.Position) - offset).Magnitude <= 0.01 then followed += 1 end
	end

	return #marks, followed
end

const function slantedMark(): BasePart?
	BloodFX.spray(ABOVE, Vector3.new(1, -0.2, 0), {
		count = NumberRange.new(1, 1),
		speed = NumberRange.new(30, 30),
		spread = 0,
		radius = NumberRange.new(0.1, 0.1),
	})

	task.wait(1)

	for _, part in workspace.BloodFX.Parts:GetChildren() do
		if flat(part) and part.Position.Y > 0 then return part end
	end

	return nil
end

test("the pool draws with Mesh once it has loaded, and with the engine's sphere without one", function()
	const want = if Config.Mesh ~= "" then "MeshPart" else "Part"
	const deadline = os.clock() + 5
	local wrong = -1

	while wrong ~= 0 and os.clock() < deadline do
		wrong = 0

		for _, part in workspace.BloodFX.Parts:GetChildren() do
			const right = part.ClassName == want and (want == "Part" or (part :: MeshPart).MeshId == Config.Mesh)
			if not right then wrong += 1 end
		end

		if wrong > 0 then task.wait(0.1) end
	end

	expect(wrong == 0, `{wrong} pooled parts are not {want}s drawn with the Mesh setting`)
end)

test("every preset sprays", function()
	for name in Presets do
		BloodFX.spray(ABOVE, DOWN, name)
	end

	expect(BloodFX.stats().drops > 0, "no drops were thrown")
end)

test("an unknown preset is an error", function()
	const ok, message = pcall(BloodFX.spray, ABOVE, DOWN, "Nope")

	expect(not ok and string.find(message, "unknown preset"), "spraying a missing preset did not fail")
end)

test("overrides change a preset for one call and leave it as it was", function()
	BloodFX.spray(ABOVE, DOWN, "Hit", { count = NumberRange.new(30, 30) })
	const thrown = BloodFX.stats().drops

	expect(thrown == 30, `{thrown} drops instead of the 30 the override asked for`)
	expect(Presets.Hit.count.Max < 30, "the override changed the Hit preset itself")
end)

test("a number after the preset is the drop count, and ranges take plain numbers", function()
	BloodFX.spray(ABOVE, DOWN, "Hit", 10)
	const counted = BloodFX.stats().drops
	BloodFX.clear()

	BloodFX.spray(ABOVE, DOWN, "Hit", { count = 7, speed = 20, radius = 0.1 })
	const fixed = BloodFX.stats().drops

	local sized = 0
	for _, part in workspace.BloodFX.Parts:GetChildren() do
		if part.Position.Y > HEIGHT and math.abs(part.Size.X - 0.2) < 1e-4 then sized += 1 end
	end

	const emitter = BloodFX.emitter(CFrame.new(0, HEIGHT + 50, 0), "Drip", { rate = 0 })
	BloodFX.clear()
	emitter.count = 3
	emitter:emit()
	const emitted = BloodFX.stats().drops
	emitter:destroy()

	expect(counted == 10, `{counted} drops instead of 10`)
	expect(fixed == 7 and sized == 7, `{fixed} drops, {sized} of them 0.2 across, instead of 7`)
	expect(emitted == 3, `an emitter with a count of 3 threw {emitted}`)
end)

test("DropMultiplier scales every spray and keeps the average right", function()
	BloodFX.set("DropMultiplier", 0.5)

	BloodFX.spray(ABOVE, DOWN, "Hit", 10)
	const halved = BloodFX.stats().drops
	BloodFX.clear()

	local total, fewest, most = 0, math.huge, 0

	for _ = 1, 200 do
		BloodFX.spray(ABOVE, DOWN, "Hit", 7)
		const thrown = BloodFX.stats().drops
		BloodFX.clear()

		total += thrown
		fewest = math.min(fewest, thrown)
		most = math.max(most, thrown)
	end

	const emitter = BloodFX.emitter(CFrame.new(0, HEIGHT + 50, 0), "Drip", { rate = 0, count = 4 })
	emitter:emit()
	const emitted = BloodFX.stats().drops
	emitter:destroy()

	BloodFX.set("DropMultiplier", 1)
	expect(halved == 5, `a spray of 10 threw {halved} drops at 0.5`)
	expect(fewest == 3 and most == 4, `a spray of 7 at 0.5 threw between {fewest} and {most} drops`)
	expect(math.abs(total / 200 - 3.5) < 0.2, `a spray of 7 at 0.5 threw {total / 200} drops on average`)
	expect(emitted == 2, `an emitter with a count of 4 threw {emitted} at 0.5`)
end)

test("drops land and leave marks", function()
	BloodFX.spray(ABOVE, DOWN, "Hit")
	expect(BloodFX.stats().drops > 0, "the spray threw nothing")

	task.wait(1)

	const stats = BloodFX.stats()
	expect(stats.drops == 0, `{stats.drops} drops are still in flight`)
	expect(stats.marks > 0, "no marks were left")
end)

test("marks on one spot merge into one pool", function()
	const spot = Vector3.new(30, HEIGHT, 30)

	for _ = 1, 5 do BloodFX.mark(spot, UP, 0.2) end
	task.wait(0.3)

	const pool = markNear(spot)
	expect(BloodFX.stats().marks == 1, `{BloodFX.stats().marks} marks instead of one`)
	expect(pool and pool.Size.Y > 0.4, "the pool did not grow")
end)

test("marks on different planes stay apart", function()
	const shelf = block(Vector3.new(4, 0.1, 4), Vector3.new(-30, HEIGHT + 0.4, 30))

	BloodFX.mark(Vector3.new(-30, HEIGHT + 0.45, 30), UP, 0.5)
	BloodFX.mark(Vector3.new(-30, HEIGHT, 30.1), UP, 0.5)

	shelf:Destroy()
	expect(BloodFX.stats().marks == 2, "a mark on the floor merged into one on the shelf above")
end)

test("a pool stays on the part it lies on", function()
	const top = Vector3.new(-40, HEIGHT + 1, -40)
	const pedestal = block(Vector3.new(2, 1, 2), top - Vector3.new(0, 0.5, 0))

	for _ = 1, 80 do BloodFX.mark(top, UP, 0.5) end
	task.wait(0.3)

	const pool = markNear(top)
	pedestal:Destroy()
	expect(pool, "the pool is missing")

	-- Walk the oval's rim and find how far it reaches past the edges of the 2x2 top.
	local overhang = 0

	for step = 1, 64 do
		const angle = step * 2 * math.pi / 64
		const onRim = Vector3.new(0, math.cos(angle) * pool.Size.Y, math.sin(angle) * pool.Size.Z) / 2
		const offset = pool.CFrame:PointToWorldSpace(onRim) - top

		overhang = math.max(overhang, math.abs(offset.X) - 1, math.abs(offset.Z) - 1)
	end

	expect(overhang <= 0.1, `the pool hangs {overhang} studs past the top`)
end)

test("a wall pools, but less than the floor", function()
	const wall = block(Vector3.new(0.4, 10, 10), Vector3.new(-60, HEIGHT + 5, -30))
	const onWall = Vector3.new(-59.8, HEIGHT + 5, -30)
	const onFloor = Vector3.new(-40, HEIGHT, -40)

	for _ = 1, 80 do
		BloodFX.mark(onWall, Vector3.xAxis, 1)
		BloodFX.mark(onFloor, UP, 1)
	end

	task.wait(0.3)

	const wallPool = markNear(onWall)
	const floorPool = markNear(onFloor)
	const count = BloodFX.stats().marks
	wall:Destroy()

	expect(count == 2, `{count} marks instead of one pool on the wall and one on the floor`)
	expect(wallPool and floorPool, "a pool is missing")
	expect(wallPool.Size.Y < floorPool.Size.Y, `the wall pool ({wallPool.Size.Y}) is not smaller than the floor pool ({floorPool.Size.Y})`)
end)

test("a pool on a slope stays smaller than one on level ground", function()
	const ramp = block(Vector3.new(10, 1, 10), Vector3.zero)
	ramp.CFrame = CFrame.new(-40, HEIGHT + 5, 40) * CFrame.Angles(math.rad(60), 0, 0)

	const up = ramp.CFrame.UpVector
	const onRamp = ramp.Position + up * 0.5
	const onFloor = Vector3.new(40, HEIGHT, 40)

	for _ = 1, 80 do
		BloodFX.mark(onRamp, up, 1)
		BloodFX.mark(onFloor, UP, 1)
	end

	task.wait(0.3)

	const rampPool = markNear(onRamp)
	const floorPool = markNear(onFloor)
	ramp:Destroy()

	expect(rampPool and floorPool, "a pool is missing")
	expect(rampPool.Size.Y < floorPool.Size.Y, `the ramp pool ({rampPool.Size.Y}) is not smaller than the floor pool ({floorPool.Size.Y})`)
end)

test("a ceiling pools, but less than a wall", function()
	const wall = block(Vector3.new(0.4, 10, 10), Vector3.new(-60, HEIGHT + 5, 30))
	const ceiling = block(Vector3.new(10, 0.4, 10), Vector3.new(-40, HEIGHT + 10, 30))
	const onWall = Vector3.new(-59.8, HEIGHT + 5, 30)
	const onCeiling = Vector3.new(-40, HEIGHT + 9.8, 30)

	for _ = 1, 80 do
		BloodFX.mark(onWall, Vector3.xAxis, 1)
		BloodFX.mark(onCeiling, DOWN, 1)
	end

	task.wait(0.3)

	const wallPool = markNear(onWall)
	const ceilingPool = markNear(onCeiling)
	const count = BloodFX.stats().marks
	wall:Destroy()
	ceiling:Destroy()

	expect(count == 2, `{count} marks instead of one pool on the wall and one on the ceiling`)
	expect(wallPool and ceilingPool, "a pool is missing")
	expect(ceilingPool.Size.Y < wallPool.Size.Y, `the ceiling pool ({ceilingPool.Size.Y}) is not smaller than the wall pool ({wallPool.Size.Y})`)
end)

test("a slanted drop leaves a mark stretched along its path", function()
	BloodFX.set("SlantStretch", 1)
	BloodFX.set("MarkStretch", NumberRange.new(1, 1))

	const mark = slantedMark()

	BloodFX.set("SlantStretch", Config.SlantStretch)
	BloodFX.set("MarkStretch", Config.MarkStretch)

	expect(mark, "the drop left no mark")
	expect(math.abs(mark.CFrame.LookVector.X) > 0.9, "the mark does not point the way the drop flew")
	expect(mark.Size.Z > mark.Size.Y * 1.3, `the mark is {mark.Size.Y} wide and only {mark.Size.Z} long`)
end)

test("SlantStretch at 0 keeps slanted marks round", function()
	BloodFX.set("SlantStretch", 0)
	BloodFX.set("MarkStretch", NumberRange.new(1, 1))

	const mark = slantedMark()

	BloodFX.set("SlantStretch", Config.SlantStretch)
	BloodFX.set("MarkStretch", Config.MarkStretch)

	expect(mark, "the drop left no mark")
	expect(math.abs(mark.Size.Z - mark.Size.Y) < 0.01, `the mark is {mark.Size.Y} wide and {mark.Size.Z} long`)
end)

test("a pool on a ceiling drips and shrinks", function()
	const ceiling = block(Vector3.new(6, 0.4, 6), Vector3.new(-20, HEIGHT + 6.2, -60))
	const onCeiling = Vector3.new(-20, HEIGHT + 6, -60)

	BloodFX.set("CeilingDripRate", 0)
	BloodFX.mark(onCeiling, DOWN, 0.5)
	task.wait(0.3)

	const pool = markNear(onCeiling)
	const before = pool and pool.Size.Y

	BloodFX.set("CeilingDripRate", 20)
	task.wait(1)
	BloodFX.set("CeilingDripRate", Config.CeilingDripRate)

	local below = 0
	for _, part in workspace.BloodFX.Parts:GetChildren() do
		if flat(part) and (part.Position - Vector3.new(-20, HEIGHT, -60)).Magnitude < 2 then below += 1 end
	end

	const after = pool and pool.Size.Y
	ceiling:Destroy()

	expect(pool, "the pool on the ceiling is missing")
	expect(after < before, `the pool stayed {after} across while it dripped`)
	expect(below > 0, "nothing that dripped reached the floor")
end)

test("pools drip only past CeilingDripAngle and with CeilingDrip on", function()
	const wall = block(Vector3.new(0.4, 6, 6), Vector3.new(-20, HEIGHT + 3, -80))
	const ceiling = block(Vector3.new(6, 0.4, 6), Vector3.new(0, HEIGHT + 6.2, -80))

	BloodFX.set("CeilingDripRate", 50)
	BloodFX.mark(Vector3.new(-19.8, HEIGHT + 3, -80), Vector3.xAxis, 0.5)
	task.wait(0.5)
	const fromWall = BloodFX.stats().drops

	BloodFX.set("CeilingDrip", false)
	BloodFX.mark(Vector3.new(0, HEIGHT + 6, -80), DOWN, 0.5)
	task.wait(0.5)
	const switchedOff = BloodFX.stats().drops

	BloodFX.set("CeilingDrip", Config.CeilingDrip)
	BloodFX.set("CeilingDripRate", Config.CeilingDripRate)
	wall:Destroy()
	ceiling:Destroy()

	expect(fromWall == 0, `a pool on a wall dripped {fromWall} drops`)
	expect(switchedOff == 0, `a ceiling pool dripped {switchedOff} drops with CeilingDrip off`)
end)

test("the ignore tag lets drops fall through", function()
	const plate = block(Vector3.new(10, 0.2, 10), Vector3.new(60, HEIGHT + 2, 60))
	plate:AddTag(Config.IgnoreTag)
	task.wait()

	BloodFX.spray(Vector3.new(60, HEIGHT + 4, 60), DOWN, "Hit")
	task.wait(1)

	const raised = #raisedMarks()
	plate:Destroy()

	expect(BloodFX.stats().marks > 0, "nothing reached the floor under the plate")
	expect(raised == 0, `{raised} marks landed on the ignored plate`)
end)

test("the absorb tag swallows drops", function()
	const plate = block(Vector3.new(10, 0.2, 10), Vector3.new(60, HEIGHT + 2, 60))
	plate:AddTag(Config.AbsorbTag)

	BloodFX.spray(Vector3.new(60, HEIGHT + 4, 60), DOWN, "Hit")
	task.wait(1)

	const stats = BloodFX.stats()
	plate:Destroy()

	expect(stats.drops + stats.marks == 0, `{stats.marks} marks were left on an absorbing plate`)
end)

test("the attach tag carries marks with their part", function()
	const plate = block(Vector3.new(10, 0.2, 10), Vector3.new(60, HEIGHT + 2, 60))
	plate:AddTag(Config.AttachTag)

	BloodFX.spray(Vector3.new(60, HEIGHT + 4, 60), DOWN, "Hit")
	task.wait(1)

	const marks = raisedMarks()
	const offsets = {}

	for _, mark in marks do offsets[mark] = plate.CFrame:PointToObjectSpace(mark.Position) end

	plate.CFrame *= CFrame.new(0, 5, 0) * CFrame.Angles(0, math.rad(90), 0)
	task.wait()

	local stayed = 0
	for mark, offset in offsets do
		if (plate.CFrame:PointToObjectSpace(mark.Position) - offset).Magnitude > 0.01 then stayed += 1 end
	end

	plate:Destroy()
	task.wait()

	expect(#marks > 0, "no marks landed on the plate")
	expect(stayed == 0, `{stayed} of {#marks} marks stayed behind when the plate moved`)
	expect(BloodFX.stats().marks == 0, "marks outlived the part they were stuck to")
end)

test("marks stick on their own to a part that physics moves", function()
	const crate = block(Vector3.new(10, 2, 10), Vector3.new(60, HEIGHT + 1, -60))
	crate.Anchored = false

	const count, followed = carried(crate, function() crate.CFrame *= CFrame.new(0, 5, 0) end)
	crate:Destroy()

	expect(count > 0, "no marks landed on the crate")
	expect(followed == count, `{count - followed} of {count} marks stayed behind when the crate moved`)
end)

test("a part welded to an anchored one keeps plain marks", function()
	const base = block(Vector3.new(2, 2, 2), Vector3.new(70, HEIGHT + 1, -80))
	const crate = block(Vector3.new(10, 2, 10), Vector3.new(60, HEIGHT + 1, -80))
	crate.Anchored = false

	const weld = Instance.new("WeldConstraint")
	weld.Part0 = crate
	weld.Part1 = base
	weld.Parent = crate

	const count, followed = carried(crate, function() base.CFrame *= CFrame.new(0, 5, 0) end)
	base:Destroy()
	crate:Destroy()

	expect(count > 0, "no marks landed on the crate")
	expect(followed == 0, `{followed} of {count} marks were welded to a crate held by an anchored part`)
end)

test("AutoAttach off leaves loose parts to the attach tag", function()
	const crate = block(Vector3.new(10, 2, 10), Vector3.new(60, HEIGHT + 1, -60))
	crate.Anchored = false

	BloodFX.set("AutoAttach", false)
	const count, followed = carried(crate, function() crate.CFrame *= CFrame.new(0, 5, 0) end)
	BloodFX.set("AutoAttach", Config.AutoAttach)
	crate:Destroy()

	expect(count > 0, "no marks landed on the crate")
	expect(followed == 0, `{followed} of {count} marks stuck to a loose crate with AutoAttach off`)
end)

test("a part leaving the world takes its own welded marks and no others", function()
	const plate = block(Vector3.new(10, 0.2, 10), Vector3.new(60, HEIGHT + 2, 60))
	plate:AddTag(Config.AttachTag)

	for index = 1, 3 do BloodFX.mark(Vector3.new(index * 10, HEIGHT, -30), UP, 0.3) end
	BloodFX.spray(Vector3.new(60, HEIGHT + 4, 60), DOWN, "Hit")
	task.wait(1)

	const before = BloodFX.stats().marks
	plate:Destroy()
	task.wait()
	const after = BloodFX.stats().marks

	expect(before > 3, "no marks landed on the plate")
	expect(after == 3, `{after} marks left instead of the 3 on the floor`)
end)

test("a welded pool still takes drops in after its part moved and turned", function()
	const plate = block(Vector3.new(10, 0.2, 10), Vector3.new(-60, HEIGHT + 2, 60))
	plate:AddTag(Config.AttachTag)

	const oneDrop = { count = 1, speed = 20, spread = 0, radius = 0.15 }
	BloodFX.spray(Vector3.new(-60, HEIGHT + 4, 60), DOWN, oneDrop)
	task.wait(0.5)

	const pool = raisedMarks()[1]
	plate.CFrame = CFrame.new(-50, HEIGHT + 6, 70) * CFrame.Angles(0, math.rad(90), 0)
	BloodFX.set("MergeReach", 1.5)
	task.wait()

	const before = if pool then pool.Size.Y else 0
	if pool then BloodFX.spray(pool.Position + UP * 2, DOWN, oneDrop) end
	task.wait(0.5)

	const after = if pool then pool.Size.Y else 0
	const count = BloodFX.stats().marks
	BloodFX.set("MergeReach", Config.MergeReach)
	plate:Destroy()

	expect(pool, "the first drop left no mark on the plate")
	expect(count == 1, `{count} marks instead of one pool after the second drop`)
	expect(after > before, `the pool stayed {after} across after taking in a drop`)
end)

test("player characters carry the character tag", function()
	const character = Players:GetPlayers()[1].Character

	expect(character and character:HasTag(Config.CharacterTag), "the player's character has no character tag")
end)

test("MaxMarks caps the count", function()
	BloodFX.set("MaxMarks", 3)

	for index = 1, 6 do BloodFX.mark(Vector3.new(index * 10, HEIGHT, -60), UP, 0.3) end
	const count = BloodFX.stats().marks

	BloodFX.set("MaxMarks", Config.MaxMarks)
	expect(count == 3, `{count} marks with MaxMarks at 3`)
end)

test("set checks the key and the value", function()
	expect(not pcall(BloodFX.set, "Gravity", "fast"), "a string was accepted for Gravity")
	expect(not pcall(BloodFX.set, "Gravity", -1), "a negative Gravity was accepted")
	expect(not pcall(BloodFX.set, "AttachTag", "Other"), "a tag changed at runtime")
	expect(not pcall(BloodFX.set, "Nope", 1), "an unknown key was accepted")
	expect(not pcall(BloodFX.set, "Material", Enum.PartType.Ball), "a PartType was accepted as a Material")

	BloodFX.set("Gravity", 80)
	const applied = BloodFX.get("Gravity")
	const mirrored = workspace.BloodFX.Config:GetAttribute("Gravity")

	BloodFX.set("Gravity", Config.Gravity)
	expect(applied == 80, "Gravity did not change")
	expect(mirrored == 80, "the Gravity attribute did not follow")
end)

test("attributes apply live and bad values are put back", function()
	const configuration = workspace.BloodFX.Config

	configuration:SetAttribute("Drag", 0.5)
	task.wait()
	const applied = BloodFX.get("Drag")

	configuration:SetAttribute("Drag", "thick")
	task.wait()
	const restored = configuration:GetAttribute("Drag")

	BloodFX.set("Drag", Config.Drag)
	expect(applied == 0.5, "the Drag attribute did not apply")
	expect(restored == 0.5, `a bad Drag value was left as {restored}`)
end)

test("a colour change repaints every part", function()
	const green = Color3.new(0, 1, 0)

	BloodFX.spray(ABOVE, DOWN, "Hit")
	BloodFX.set("Color", green)

	local stale = 0
	for _, part in workspace.BloodFX.Parts:GetChildren() do
		if part.Color ~= green then stale += 1 end
	end

	BloodFX.set("Color", Config.Color)
	expect(stale == 0, `{stale} parts kept the old colour`)
end)

test("an emitter bleeds, pauses and dies with its origin", function()
	const before = BloodFX.stats().emitters
	const origin = block(Vector3.one, Vector3.new(0, HEIGHT + 4, 20))
	origin.CanCollide = false
	origin.CanQuery = false

	const emitter = BloodFX.emitter(origin, "Drip")
	expect(BloodFX.stats().emitters == before + 1, "the emitter was not registered")

	task.wait(0.5)
	expect(BloodFX.stats().drops + BloodFX.stats().marks > 0, "the emitter produced nothing")

	emitter.enabled = false
	BloodFX.clear()
	task.wait(0.5)

	const stats = BloodFX.stats()
	expect(stats.drops + stats.marks == 0, "a disabled emitter kept bleeding")

	origin:Destroy()
	task.wait()
	expect(BloodFX.stats().emitters == before, "the emitter outlived its origin")
end)

test("an emitter takes overrides and runs its preset's update every frame", function()
	local calls, seen = 0, 0

	const emitter = BloodFX.emitter(CFrame.new(0, HEIGHT + 50, 0), "Drip", {
		rate = 0,
		mood = "custom",
		update = function(_, time: number)
			calls += 1
			seen = time
		end,
	})

	task.wait(0.3)
	emitter:destroy()

	expect(emitter.rate == 0, "the rate override did not reach the emitter")
	expect((emitter :: any).mood == "custom", "a field of the preset's own did not reach the emitter")
	expect(calls > 3 and seen > 0.1, `update ran {calls} times and last saw {seen} seconds`)
end)

test("the Fountain's heartbeat lives in its preset and takes its values", function()
	const pulsing = BloodFX.emitter(CFrame.new(0, HEIGHT + 50, 0), "Fountain", { rate = 0 })
	const steady = BloodFX.emitter(CFrame.new(0, HEIGHT + 50, 0), "Fountain", { rate = 0, swing = 0 })
	local low, high = math.huge, -math.huge

	for _ = 1, 20 do
		task.wait()
		low = math.min(low, pulsing.strength)
		high = math.max(high, pulsing.strength)
	end

	const flat = steady.strength
	pulsing:destroy()
	steady:destroy()

	expect(high - low > 0.3, `strength only swung between {low} and {high}`)
	expect(flat == 1, `swing 0 still gave a strength of {flat}`)
end)

test("destroy removes an emitter", function()
	const before = BloodFX.stats().emitters
	const emitter = BloodFX.emitter(CFrame.new(0, HEIGHT + 4, -20), "Hit")

	emitter:destroy()
	expect(BloodFX.stats().emitters == before, "the emitter is still registered")
end)

test("freeze clears blood and silences emitters until unfreeze", function()
	const emitter = BloodFX.emitter(CFrame.new(20, HEIGHT + 4, 0), "Fountain")

	BloodFX.spray(ABOVE, DOWN, "Burst")
	BloodFX.freeze()

	local stats = BloodFX.stats()
	expect(BloodFX.isFrozen(), "isFrozen is false after freeze")
	expect(stats.drops + stats.marks == 0, "freeze left blood behind")

	BloodFX.spray(ABOVE, DOWN, "Hit")
	BloodFX.mark(Vector3.new(0, HEIGHT, 0), UP)
	emitter:emit()
	task.wait(0.3)

	stats = BloodFX.stats()
	expect(stats.drops + stats.marks == 0, "blood appeared while frozen")

	BloodFX.unfreeze()
	task.wait(0.3)

	const resumed = BloodFX.stats().drops > 0
	emitter:destroy()
	expect(resumed, "the emitter did not resume after unfreeze")
end)

test("the Frozen attribute switches blood off and on, and freeze shows on it", function()
	const configuration = workspace.BloodFX.Config
	BloodFX.mark(Vector3.new(0, HEIGHT, 20), UP, 0.3)

	configuration:SetAttribute("Frozen", true)
	task.wait()
	const frozen = BloodFX.isFrozen()
	const left = BloodFX.stats().marks

	configuration:SetAttribute("Frozen", false)
	task.wait()
	const thawed = not BloodFX.isFrozen()

	BloodFX.freeze()
	const shown = configuration:GetAttribute("Frozen")
	BloodFX.unfreeze()
	const cleared = configuration:GetAttribute("Frozen")

	expect(frozen, "setting the Frozen attribute did not freeze blood")
	expect(left == 0, `{left} marks were left after freezing through the attribute`)
	expect(thawed, "clearing the Frozen attribute did not unfreeze blood")
	expect(shown == true and cleared == false, "freeze and unfreeze did not show on the Frozen attribute")
end)

test("fade takes marks away over the fade time", function()
	BloodFX.set("MarkFadeTime", 0.2)
	BloodFX.mark(Vector3.new(0, HEIGHT, 40), UP, 0.3)
	BloodFX.fade()
	task.wait(0.5)

	const count = BloodFX.stats().marks
	BloodFX.set("MarkFadeTime", Config.MarkFadeTime)
	expect(count == 0, `{count} marks survived the fade`)
end)

test("PoolSize resizes the pool while the game runs and leaves parts in use alone", function()
	const larger = Config.PoolSize + 300

	BloodFX.set("PoolSize", larger)
	const grown = settle(larger)

	for index = 1, 5 do BloodFX.mark(Vector3.new(index * 10, HEIGHT, 50), UP, 0.3) end
	BloodFX.set("PoolSize", 0)
	const shrunk = settle(5)
	const spare = BloodFX.stats().spare
	const marks = BloodFX.stats().marks

	BloodFX.set("PoolSize", Config.PoolSize)
	BloodFX.clear()
	const restored = settle(Config.PoolSize)

	expect(grown == larger, `{grown} parts after PoolSize went up to {larger}`)
	expect(shrunk == 5 and spare == 0 and marks == 5, `{shrunk} parts, {spare} spare and {marks} marks at PoolSize 0`)
	expect(restored == Config.PoolSize, `{restored} parts after PoolSize went back to {Config.PoolSize}`)
end)

test("the debugger reports a pool that runs out and limits that are hit", function()
	const heard: { [string]: BloodFX.DebugEvent } = {}
	const connection = BloodFX.debugger:Connect(function(event) heard[event.kind] = event end)

	BloodFX.set("PoolSize", 0)
	settle(0)
	BloodFX.mark(Vector3.new(0, HEIGHT, 70), UP, 0.3)
	BloodFX.set("PoolSize", Config.PoolSize)
	BloodFX.clear()
	settle(Config.PoolSize)

	BloodFX.set("MaxDrops", 5)
	BloodFX.spray(ABOVE, DOWN, "Hit", 10)
	BloodFX.set("MaxDrops", Config.MaxDrops)

	BloodFX.set("MaxMarks", 2)
	for index = 1, 3 do BloodFX.mark(Vector3.new(index * 10, HEIGHT, 70), UP, 0.3) end
	BloodFX.set("MaxMarks", Config.MaxMarks)

	task.wait()
	connection:Disconnect()

	const expanded, drop, mark = heard.PoolExpanded, heard.DropLimit, heard.MarkLimit
	expect(expanded and expanded.parts == 1 and expanded.limit == 0, "no PoolExpanded for a part made on the spot")
	expect(drop and drop.limit == 5 and drop.age == 0, "no DropLimit when MaxDrops pushed out a drop")
	expect(mark and mark.limit == 2 and mark.age == 0, "no MarkLimit when MaxMarks pushed out a mark")
end)

test("the debugger stays quiet with Debug off and after a listener disconnects", function()
	local calls = 0
	const connection = BloodFX.debugger:Connect(function() calls += 1 end)
	const pushOut = function()
		BloodFX.clear()
		BloodFX.set("MaxMarks", 1)
		for index = 1, 2 do BloodFX.mark(Vector3.new(index * 10, HEIGHT, 80), UP, 0.3) end
		BloodFX.set("MaxMarks", Config.MaxMarks)
		task.wait()
	end

	BloodFX.set("Debug", false)
	pushOut()
	BloodFX.set("Debug", true)
	const whileOff = calls

	pushOut()
	const whileOn = calls

	connection:Disconnect()
	pushOut()
	const afterDisconnect = calls

	BloodFX.set("Debug", Config.Debug)
	expect(whileOff == 0, `{whileOff} events reached a listener with Debug off`)
	expect(whileOn == 1, `{whileOn} events instead of 1 with Debug on`)
	expect(afterDisconnect == 1 and not connection.Connected, "a disconnected listener still heard events")
end)

test("clear hands every part back to the pool", function()
	BloodFX.spray(ABOVE, DOWN, "Burst")
	task.wait(0.2)
	BloodFX.clear()

	const stats = BloodFX.stats()
	expect(stats.drops + stats.marks == 0, "clear left blood behind")
	expect(stats.parts == Config.PoolSize, `{stats.parts} parts instead of {Config.PoolSize}`)
end)

return function(): string
	const floor = block(Vector3.new(200, 1, 200), Vector3.new(0, HEIGHT - 0.5, 0))
	const report = {}
	local failed = 0

	BloodFX.set("DropMultiplier", 1)

	for _, case in cases do
		BloodFX.unfreeze()
		BloodFX.clear()

		const ok, message = pcall(case.run)
		if not ok then failed += 1 end

		table.insert(report, if ok then `PASS  {case.name}` else `FAIL  {case.name}: {message}`)
	end

	BloodFX.set("DropMultiplier", Config.DropMultiplier)
	floor:Destroy()
	BloodFX.clear()

	table.insert(report, `{#cases - failed}/{#cases} passed`)

	return table.concat(report, "\n")
end
