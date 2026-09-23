const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const BloodFX = require(ReplicatedStorage.BloodFX)
const Config = require(ReplicatedStorage.BloodFX.Config)

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

const function raisedMarks(): { BasePart }
	const found = {}

	for _, part in workspace.BloodFX.Parts:GetChildren() do
		if part.Shape == Enum.PartType.Cylinder and part.Position.Y > HEIGHT + 1 then table.insert(found, part) end
	end

	return found
end

const function markNear(position: Vector3): BasePart?
	for _, part in workspace.BloodFX.Parts:GetChildren() do
		if part.Shape == Enum.PartType.Cylinder and (part.Position - position).Magnitude < 0.01 then return part end
	end

	return nil
end

test("every preset sprays", function()
	for _, preset in ReplicatedStorage.BloodFX.Presets:GetChildren() do
		BloodFX.spray(ABOVE, DOWN, preset.Name)
	end

	expect(BloodFX.stats().drops > 0, "no drops were thrown")
end)

test("an unknown preset is an error", function()
	const ok, message = pcall(BloodFX.spray, ABOVE, DOWN, "Nope")

	expect(not ok and string.find(message, "unknown preset"), "spraying a missing preset did not fail")
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
	expect(not pcall(BloodFX.set, "PoolSize", 10), "PoolSize changed at runtime")
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

test("fade takes marks away over the fade time", function()
	BloodFX.set("MarkFadeTime", 0.2)
	BloodFX.mark(Vector3.new(0, HEIGHT, 40), UP, 0.3)
	BloodFX.fade()
	task.wait(0.5)

	const count = BloodFX.stats().marks
	BloodFX.set("MarkFadeTime", Config.MarkFadeTime)
	expect(count == 0, `{count} marks survived the fade`)
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

	for _, case in cases do
		BloodFX.unfreeze()
		BloodFX.clear()

		const ok, message = pcall(case.run)
		if not ok then failed += 1 end

		table.insert(report, if ok then `PASS  {case.name}` else `FAIL  {case.name}: {message}`)
	end

	floor:Destroy()
	BloodFX.clear()

	table.insert(report, `{#cases - failed}/{#cases} passed`)

	return table.concat(report, "\n")
end
