# BloodFX

Part-based blood for Roblox. Drops fly under gravity and raycast their own path; where they land
they leave marks, stretched along the way they came in, and marks that land on each other merge
into pools that stay on the surface they lie on. Pools on ceilings and overhangs drip. 

Run it on the client: it is a local effect, and parts made on the server replicate to everyone.

## Layout

```
src/ReplicatedStorage/BloodFX           the module
    init          entry point: initialisation, public API, runtime loop
    Config        every setting in one table
    Types         public types, re-exported by the module
    Pool          the parts drops and marks are drawn from
    Grid          spatial hash that finds the mark a drop landed in
    Marks         blood on surfaces: merging, fitting to the surface, fading
    Drops         blood in flight: spray cone, gravity, raycast, landing
    Emitter       a continuous source on a part, attachment or CFrame
    Presets       every preset in one table
src/ReplicatedStorage/Tests             BloodFX.spec, the tests; BloodFX.perf, benchmark and profiler
src/StarterPlayer/StarterPlayerScripts  BloodDemo, the demo for the test place
```

## API

The module sets itself up the first time it is required.

```lua
local BloodFX = require(ReplicatedStorage.BloodFX)

BloodFX.spray(result.Position, result.Normal, "Hit")
BloodFX.spray(result.Position, result.Normal, "Hit", { count = NumberRange.new(12, 20) })

local wound = BloodFX.emitter(character.UpperTorso, "Fountain", { beats = 2 })
wound:destroy()
```

| Call | Does |
| --- | --- |
| `spray(position, direction, preset?, overrides?)` | Throws a cone of drops. `preset` is a preset name, a table of the same shape, or nil for `Hit`; `overrides` replaces some of its values for this call, and a number there is the drop count. |
| `mark(position, normal, radius?)` | Puts a mark straight onto a surface. |
| `emitter(origin, preset?, overrides?)` | Starts a continuous source and returns its `Emitter`. `origin` is a `PVInstance`, an `Attachment` or a `CFrame`; nil preset is `Drip`, and `overrides` works as for `spray`. |
| `get(key)` / `set(key, value)` | Reads or changes a setting by name. `set` needs `Config.DynamicSettings` and checks the type. |
| `clear()` / `fade()` | Removes all blood at once, or lets every mark fade out. |
| `freeze()` / `unfreeze()` / `isFrozen()` | Switches blood off and back on. Freezing clears what is there and silences emitters without removing them. It is the `Frozen` setting, so the attribute on the Config shows it and can flip it too. |
| `stats()` | `drops`, `marks`, `emitters` and `parts` right now. |

An `Emitter` carries every field of its preset, plus `origin`, `enabled`, `strength` (a multiplier on
the speed of each emission) and `age` in seconds, and each can be changed while it runs. `emit()`
fires once regardless of the rate, `frame()` is where it sits now, and `destroy()` removes it. An
emitter on an instance is destroyed together with that instance.

Preset names and setting names are typed as `PresetName` and `SettingName`, so Studio offers them in
autocomplete wherever the API asks for one. The module exports those two alongside `Config`,
`Emitter`, `Origin`, `Overrides`, `Preset`, `Spray` and `Stats`.

## Config

All settings, with their defaults and what they do, are described in
[`src/ReplicatedStorage/BloodFX/Config.luau`](src/ReplicatedStorage/BloodFX/Config.luau).

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

## Presets

A preset is a spray shape - `count`, `speed`, `spread` in degrees, `radius` - and, for an emitter,
how it runs: `direction` in the origin's space, `rate` per second and `rateJitter`. `count`, `speed`
and `radius` take a number or a `NumberRange` to draw each value from. Every preset
works with both `spray` and `emitter`; an emitter fills what a preset leaves out (one emission a
second, upwards).

A preset can also carry its own logic and values. `update(emitter, time)` runs every frame for an
emitter and may change anything on it, and any other field of the preset lands on the emitter for
`update` to read. `Fountain` keeps its heartbeat that way: `beats` a second and `swing`, which its
`update` turns into `strength`. Overrides reach these fields like any other, so
`{ beats = 2 }` gives a faster pulse and `{ swing = 0 }` none.

| One-off | | Emitter | |
| --- | --- | --- | --- |
| `Hit` | a round landing in something | `Drip` | slow drops straight down |
| `Burst` | more of it, thrown wider | `Jet` | a tight pressure jet |
| | | `Fountain` | an arterial jet with a pulse |

All of them live in one table in `Presets.luau`; to add a preset, add an entry there.
