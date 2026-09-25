# BloodFX

Part-based blood for Roblox. Drops fly under gravity and raycast their own path; where they land
they leave marks, stretched along the way they came in, and marks that land on each other merge
into pools that stay on the surface they lie on. Pools on ceilings and overhangs drip. 

Run it on the client: it is a local effect, and parts made on the server replicate to everyone.

## Getting started

With [Wally](https://wally.run), add it to the dependencies in `wally.toml` and run `wally install`:

```toml
[dependencies]
BloodFX = "ch1kz/bloodfx@0.1.0"
```

Without Wally, put the `BloodFX` module in `ReplicatedStorage`. Then require it from a `LocalScript`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BloodFX = require(ReplicatedStorage:WaitForChild("BloodFX"))
```

A module installed with Wally sits in the `Packages` folder instead, so the path there is
`ReplicatedStorage.Packages.BloodFX`.

Then call it wherever blood should appear, for example where a raycast hit something:

```lua
BloodFX.spray(result.Position, result.Normal, "Hit")
```

The module sets itself up on the first `require`: it builds its part pool, starts its loop on
`Heartbeat` and, with `DynamicSettings` on, puts its settings on `workspace.BloodFX.Config`. Every
side that requires it gets a copy of its own, with its own folder, settings and blood.

## Layout

```
src/ReplicatedStorage/BloodFX           the module
    init          entry point: initialisation, public API, runtime loop
    Config        every setting in one table
    Types         public types, re-exported by the module
    Pool          the parts drops and marks are drawn from
    Grid          spatial hash that finds the mark a drop landed in
    Marks         blood on surfaces: merging, fitting to the surface, dripping, fading
    Drops         blood in flight: spray cone, gravity, raycast, landing
    Emitter       a continuous source on a part, attachment or CFrame
    Presets       every preset in one table
src/ReplicatedStorage/Tests             BloodFX.spec, the tests; BloodFX.perf, benchmark and profiler
src/StarterPlayer/StarterPlayerScripts  BloodDemo, the demo for the test place
default.project.json                    the module alone, as Wally ships it
dev.project.json                        the test place: rojo serve dev.project.json
```

## API

```lua
local BloodFX = require(ReplicatedStorage.BloodFX)

BloodFX.spray(result.Position, result.Normal, "Hit")
BloodFX.spray(result.Position, result.Normal, "Hit", 10)
BloodFX.spray(result.Position, result.Normal, "Hit", { count = NumberRange.new(12, 20) })

local wound = BloodFX.emitter(character.UpperTorso, "Fountain", { beats = 2 })
wound:destroy()
```

| Call | Does |
| --- | --- |
| `spray(position, direction, preset?, overrides?)` | Throws a cone of drops. `preset` is a preset name, a table of the same shape, or nil for `Hit`; `overrides` replaces some of its values for this call, and a number there is the drop count. |
| `mark(position, normal, radius?)` | Puts a mark straight onto a surface, with a radius of 0.25 studs if none is given. |
| `emitter(origin, preset?, overrides?)` | Starts a continuous source and returns its `Emitter`. `origin` is a `PVInstance`, an `Attachment` or a `CFrame`; nil preset is `Drip`, and `overrides` works as for `spray`. |
| `get(key)` / `set(key, value)` | Reads or changes a setting by name. `set` needs `Config.DynamicSettings` and checks the type. |
| `clear()` / `fade()` | Removes all blood at once, or starts every mark fading out now. |
| `freeze()` / `unfreeze()` / `isFrozen()` | Switches blood off and back on. Freezing clears what is there and silences emitters without removing them. It is the `Frozen` setting, so the attribute on the Config shows it and can flip it too. |
| `stats()` | `drops`, `marks`, `emitters` and `parts` right now; `parts` counts every pooled part, in use or spare. |

An `Emitter` carries every field of its preset, plus `origin`, `enabled`, `strength` (a multiplier on
the speed of each emission) and `age` in seconds, and each can be changed while it runs. `emit()`
fires once regardless of the rate, `frame()` is where it sits now, and `destroy()` removes it. An
emitter on an instance is destroyed together with that instance.

Preset names and setting names are typed as `PresetName` and `SettingName`, so Studio offers them in
autocomplete wherever the API asks for one. The module exports those two alongside `Config`,
`Emitter`, `Origin`, `Overrides`, `Preset`, `Spray` and `Stats`.

## Presets

A preset is a spray shape - `count`, `speed`, `spread` in degrees, `radius` - and, for an emitter,
how it runs: `direction` in the origin's space, `rate` per second and `rateJitter`. `count`, `speed`
and `radius` take a number or a `NumberRange` to draw each value from. Every preset
works with both `spray` and `emitter`; an emitter fills what a preset leaves out (one emission a
second, upwards).

| One-off | | Emitter | |
| --- | --- | --- | --- |
| `Hit` | a round landing in something | `Drip` | slow drops straight down |
| `Burst` | more of it, thrown wider | `Jet` | a tight pressure jet |
| | | `Fountain` | an arterial jet with a pulse |

All of them live in one table in `Presets.luau`; to add a preset, add an entry there.

### Overrides

Any call that takes a preset also takes overrides: a table with some of the preset's fields, which
replace the preset's values for that call only. The preset itself never changes. A number in place of
the table is the drop count.

```lua
BloodFX.spray(position, normal, "Hit", 10)
BloodFX.spray(position, normal, "Burst", { spread = 90, speed = 30 })
BloodFX.emitter(wound, "Drip", { rate = 14 })
```

### Logic in a preset

A preset can carry its own logic and values. `update(emitter, time)` runs every frame for an emitter,
with the seconds since it started, and may change anything on it: rate, direction, strength, even
`enabled`. Any other field of the preset lands on the emitter for `update` to read, and overrides
reach those fields like any other.

`Fountain` keeps its heartbeat that way. It has `beats` a second and a `swing`, and its `update` turns
them into `strength` on a sine, so `{ beats = 2 }` gives a faster pulse and `{ swing = 0 }` none.
Because that `update` writes `strength` every frame, change the pulse through `beats` and `swing`
rather than through `strength` itself.

The same way a preset can do things no built-in field covers. This one is a bleed that slows to a stop
over `fade` seconds:

```lua
BloodFX.emitter(part, "Drip", {
	fade = 8,
	update = function(emitter, time)
		emitter.rate = 5 * math.max(0, 1 - time / emitter.fade)
	end,
})
```

## How it works

### Drops in flight

`spray` throws `count` drops from a point. Each leaves in a random direction inside a cone of `spread`
degrees around `direction`: turned at random around the aim, then tilted off it by an angle drawn
evenly between 0 and `spread`. Even in angle is not even in area, so drops crowd the middle of the
cone and thin out towards its rim, the way a real splash does. Speeds are drawn from `speed` and
multiplied by the emitter's `strength`; sizes are drawn from `radius`, leaning towards the small end,
so most drops are fine and the odd one is big.

Every frame a drop falls by `Gravity` and slows by `Drag`: it keeps e^-Drag of its speed each second,
worked out exactly for the length of the frame, so the flight does not change with the frame rate.
It then casts a ray along the stretch it is about to cover, and wherever that ray hits is where it
lands. A drop that hits nothing is removed after `DropLifetime` seconds.

`MaxDrops` caps how many drops are in the air at once, and the oldest makes room for a new one. Drops
that stay up longer - low `Gravity`, high sprays - fill the cap sooner, so when drops start vanishing
in mid-air, the cap is the first thing to raise.

### Landing

What a drop does when it lands depends on the [tags](#tags) of what it hit: an absorbing surface
swallows it, an attach-tagged part gets a mark welded to it, and anything else gets a plain anchored
mark. The mark's radius is the drop's radius times a random `MarkScale`, and it opens from about a
third of its size over `MarkOpenTime`.

A drop that comes in at a slant smears. A real stain's width over its length is the sine of the angle
it hit at, so BloodFX stretches the mark along the drop's path by that much, up to three times as
long as it is wide. `SlantStretch` scales that: 0 keeps marks round, 1 is true to life, more
overdoes it. On top of it every mark gets a random length against width from `MarkStretch`, so no
two are the same circle; `SlantStretch` 0 with `MarkStretch` 1 to 1 draws exact circles.

Marks are flattened sphere meshes rather than cylinders: a cylinder part is always round at the
smaller of its two widths, so it could never be oval.

### Merging into pools

When a drop lands, BloodFX first looks for a mark it can join instead of making a new one. A mark
qualifies if

- it faces the same way, within about 45 degrees,
- it lies in the same plane, within a quarter of a stud, so a drop on a shelf never joins the floor
  below it, and
- the drop lands close enough to its centre: within the mark's radius times `MergeReach`.

`MergeReach` is measured in pool radii. At 1 only drops that land on a pool join it. Above 1 a pool
also catches drops that land just past its rim - at 1.35, up to a third of its radius beyond - so
blood that lands next to a pool runs into it. Below 1 a drop has to land well inside the pool to
join, and drops near the rim start marks of their own that overlap it, which gives the pool a bumpy
edge. At 0 nothing merges.

A drop that joins makes the pool bigger. Areas add up, so a pool of radius R that takes in a drop
whose own mark would have had radius r grows to

```
√(R² + (r × MergeGrowth)²)
```

`MergeGrowth` is how much of the drop's stain the pool gains, as a share of its radius. At 1 the pool
gains the stain's whole area, as if the two lay side by side. Lower values stand for blood that sinks
into a deeper pool instead of spreading thin: at 0.3 the pool gains 0.3² = 9% of the stain's area, so
a pool of radius 1 needs about 70 drops with 0.4-stud stains to double its area. At 0 pools never grow
and joining drops only keep them fresh.

Every joining drop restarts the pool's lifetime, so a pool that is still being fed never fades. A pool
stops growing at `MarkMaxRadius` - less on walls and ceilings, below - or where its rim would hang
over an edge.

### Walls and ceilings

Blood runs down a wall and falls off a ceiling instead of pooling, so the tilt of a surface decides
how much blood merges on it. Each surface gets a pooling factor: 1 on level ground, `WallPooling` on
an upright wall and `CeilingPooling` on a ceiling. In between it blends by the cosine of the tilt, so
slopes land between the floor and the wall and overhangs between the wall and the ceiling. There is
no threshold: a 30° ramp pools almost like the floor and a 150° overhang almost like the ceiling.

The factor scales both halves of merging on that surface. The reach becomes `MergeReach × pooling` and
the largest pool `MarkMaxRadius × pooling`. At 0 every drop on that surface stays a splatter of its
own; at 1 it pools like the floor.

For example, with `WallPooling` 0.6, `CeilingPooling` 0.2, `MergeReach` 1.35 and `MarkMaxRadius` 2.5:

| Surface | Tilt | Pooling | Reach, in pool radii | Largest pool radius |
| --- | ---: | ---: | ---: | ---: |
| floor | 0° | 1 | 1.35 | 2.5 |
| ramp | 45° | 0.88 | 1.19 | 2.21 |
| wall | 90° | 0.6 | 0.81 | 1.5 |
| overhang | 135° | 0.32 | 0.43 | 0.79 |
| ceiling | 180° | 0.2 | 0.27 | 0.5 |

On that wall the reach is under 1, so drops merge only when they land well inside a pool, and a jet
leaves a few larger pools among separate splatters. On that ceiling pools barely grow at all.

### Fitting to the surface

Before a mark is placed, and every time a pool grows, eight short rays probe points around its rim.
If any of them finds nothing within a quarter of a stud of the surface, that edge would hang in the
air: a new mark halves its size until it fits, and a pool stops growing. That keeps blood on a
pedestal's top instead of floating past its edge. Eight probes keep the worst overshoot, along the
diagonals of a square top, to about 8% of the radius.

### Dripping from ceilings

With `CeilingDrip` on, pools on surfaces tilted past `CeilingDripAngle` let drops fall. The angle is
measured from the floor, so 90 is a wall and 180 a ceiling. A pool on a flat ceiling drips
`CeilingDripRate` drops a second on average; the less its surface overhangs, the slower it drips,
down to nothing at `CeilingDripAngle`. Drips come at random intervals, so neighbouring pools do not
tick in step.

Each drip is a merge in reverse: the pool gives back the area a joining drop of that size would have
added, which is where `MergeGrowth` comes in again. A pool shrinks as it drips and stops once it is
down to the stain one drip would leave, so small splatters never drip at all. On an overhang the drop
leaves from the low side of the pool, where the blood would run to, and it falls, lands and pools like
any other drop.

### Lifetime and limits

A mark lasts `MarkLifetime` seconds, restarted by every drop that joins it, and then fades out over
`MarkFadeTime`. `fade()` starts that fade for every mark at once. `MaxMarks` caps the number of marks;
past it, the mark left alone longest makes room.

Drops and marks draw their parts from a pool of `PoolSize` spare parts made at start. If more are
needed, extras are made on the spot and destroyed when they come back to a full pool. No part casts
a shadow or takes part in collisions, touches or raycasts, and all but the welded marks are anchored.

## Tags

Three CollectionService tags change what happens when a drop reaches something. A tag works on a
part or on a whole model, folder or character: whatever sits inside a tagged instance counts too.

| Tag | Drops that reach it |
| --- | --- |
| `BloodIgnore` | fly straight through, as if it was not there |
| `BloodAbsorb` | vanish without leaving a mark |
| `BloodAttach` | leave marks welded to the part they hit, so the marks move with it |

Only marks on attach-tagged parts are welded; everything else stays an anchored part that nothing
touches after it lands, so the rest of the map costs nothing extra. A welded mark merges only with
marks on the same part and goes away when that part leaves the world.

The tag names are settings too, `IgnoreTag`, `AbsorbTag` and `AttachTag`, and `CharacterTag` puts one
of them on every player's character as it spawns.

## Config

All settings, with their defaults and what they do, are described in
[`src/ReplicatedStorage/BloodFX/Config.luau`](src/ReplicatedStorage/BloodFX/Config.luau).

With `DynamicSettings` on, the live values are mirrored as attributes on `workspace.BloodFX.Config`.
Edit them in Studio's Properties while the game runs, or call `BloodFX.set(name, value)`, and the
change applies at once. A value of the wrong type, a negative number or an Enum of the wrong kind is
refused: `set` raises an error and an attribute is put back. `DynamicSettings`, `PoolSize` and the
tags are read once at start and only change in `Config.luau`.

The folder belongs to the copy of the module that made it. Blood runs on the client, so during a
playtest look for it in the client's view. If the server requires BloodFX as well, it has a folder of
its own, and editing that one from the client changes nothing.

## Performance

- Drops cost the most: each casts one ray a frame while it flies. `MaxDrops` is the lever.
- Settled marks are anchored parts that nothing touches, so a floor covered in blood costs little
  more than the parts themselves; each frame BloodFX only ages them and checks the ones overhead
  for drips.
- The pool a drop lands in is found through a spatial hash, so landing does not slow down as marks
  pile up.
- Parts come from the pool, so a spray reuses parts instead of creating them.
- The maths-heavy functions are marked `@native`. Roblox compiles native code only for server
  scripts, so on the client they run as ordinary Luau.
- `BloodFX.stats()` gives the live counts, and `Tests/BloodFX.perf` has a benchmark and an in-game
  profiler.
