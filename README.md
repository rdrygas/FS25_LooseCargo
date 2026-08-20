# FS25 Loose Cargo

**FS25 Loose Cargo** is a script-based mod for Farming Simulator 25 that simulates the loss of uncovered loose cargo whilst driving at high speed.

The mod works automatically with standard trailers, semi-trailers and auger wagons. It does not require any modification of individual machines’ XML files.

## Design Principles

The mod has been designed according to the following principles:

- it works for the `TRAILERS`, `TRAILERSSEMI` and `AUGERWAGONS` categories;
- it applies to bulk materials belonging to the `BULK` category and compatible custom `fillType`s marked as `isBulkType`;
- it covers, amongst others, grain, root crops, wood chips, grass, hay, straw, chaff, silage, animal feed, seeds, solid fertiliser, lime, road salt, stones and manure;
- loss only occurs when travelling at a speed higher than the set threshold;
- a closed cover completely prevents cargo loss, provided the box in question has a cover;
- a vehicle without a cover is treated as permanently open;
- the higher the speed, the greater the loss;
- lighter materials are lost faster than heavier ones;
- as the fill level decreases, losses decrease;
- when the load level is 25 per cent or less, no further cargo is lost;
- this mod only applies to vehicles driven by the player;
- AI crew members do not cause cargo loss; taking control of the vehicle restarts the mechanism;
- no additional cargo loss is incurred during normal unloading.

## How it works

### Speed

The default threshold is:

```lua
FS25LooseCargo.MIN_SPEED_KMH = 25.0
```

Up to and including 25 km/h, no cargo is lost. Above this value, the loss rate increases quadratically with speed.

The reference point is 50 km/h:

```lua
FS25LooseCargo.REFERENCE_SPEED_KMH = 50.0
FS25LooseCargo.BASE_LOSS_PER_MINUTE = 0.01
```

For a material with a density similar to that of wheat and a trailer filled to 100% capacity, this corresponds to approximately 1% of the current load per minute at 50 km/h.

### Material density

The mod uses the `massPerLiter` value assigned to a given `fillType` by the game. The coefficient is calculated relative to wheat:

```text
sqrt(wheat density / material density)
```

As a result, light materials, such as straw and hay, are lost more quickly, whilst heavier materials, such as lime or stones, are lost more slowly.

For safety reasons, the factor is limited to the following range:

```lua
FS25LooseCargo.MIN_DENSITY_FACTOR = 0.50
FS25LooseCargo.MAX_DENSITY_FACTOR = 2.50
```

### Fill level

At a low fill level, the material is situated deeper inside the hold and is therefore less exposed to airflow.

Default:

```lua
FS25LooseCargo.MIN_EXPOSED_FILL_PERCENT = 0.25
```

Below this level, no losses occur. Between 25% and 100%, the exposure factor increases linearly.

| Fill level | Exposure factor |
|---:|---:|
| 25% or less | 0.00 |
| 40% | 0.20 |
| 50% | 0.33 |
| 75% | 0.67 |
| 100% | 1.00 |

### Lid

If a given `fillUnit` has a cover assigned to it, the mod checks its status. A closed cover completely eliminates losses regardless of speed, material density and fill level.

If the vehicle has no cover, the load is treated as uncovered.

## Performance table

The values below show the approximate loss of **the current load per minute** for a material with a density similar to that of wheat, with an uncovered and fully loaded trailer.

| Speed | Loss / min |
|---:|---:|
| 25 km/h | 0.00% |
| 30 km/h | 0.04% |
| 40 km/h | 0.36% |
| 50 km/h | 1.00% |
| 60 km/h | 1.96% |
| 75 km/h | 4.00% |
| 90 km/h | 6.76% |
| 100 km/h | 9.00% |

A material density factor and an exposure factor, which depends on the fill level, are then applied to the above value.

Example for wheat at 50 km/h:

| Fill level | Approximate loss / min |
|---:|---:|
| 25% | 0.00% |
| 50% | 0.33% |
| 75% | 0.67% |
| 100% | 1.00% |

The maximum loss is limited by:

```lua
FS25LooseCargo.MAX_LOSS_PER_MINUTE = 0.12
```

i.e. up to 12% of the current cargo per minute before the exposure factor is taken into account.

## Configuration

The most important parameters are at the start of the `LooseCargo.lua` file:

```lua
FS25LooseCargo.MIN_SPEED_KMH = 25.0
FS25LooseCargo.REFERENCE_SPEED_KMH = 50.0
FS25LooseCargo.BASE_LOSS_PER_MINUTE = 0.01
FS25LooseCargo.MAX_LOSS_PER_MINUTE = 0.12
FS25LooseCargo.MIN_EXPOSED_FILL_PERCENT = 0.25
FS25LooseCargo.MIN_DENSITY_FACTOR = 0.50
FS25LooseCargo.MAX_DENSITY_FACTOR = 2.50
FS25LooseCargo.UPDATE_INTERVAL_MS = 1000
```

Parameter meanings:

- `MIN_SPEED_KMH` — the minimum speed above which losses may occur;
- `REFERENCE_SPEED_KMH` — the reference speed for `BASE_LOSS_PER_MINUTE`;
- `BASE_LOSS_PER_MINUTE` — the base loss of the current cargo per minute at the reference speed;
- `MAX_LOSS_PER_MINUTE` — the limit on the maximum rate of loss;
- `MIN_EXPOSED_FILL_PERCENT` — the fill level below which no losses occur;
- `MIN_DENSITY_FACTOR` / `MAX_DENSITY_FACTOR` — limits on the influence of material density;
- `UPDATE_INTERVAL_MS` — the interval between loss calculations.

Changing `BASE_LOSS_PER_MINUTE` from `0.01` to `0.02` will double the base loss rate. A value of `0.005` will halve it.

## Supported vehicles

The mod monitors vehicles belonging to the following categories:

- `TRAILERS` — trailers;
- `TRAILERSSEMI` — semi-trailers;
- `AUGERWAGONS` — transfer wagons.

During testing, the correct operation of standard trailers, semi-trailers and transhipment wagons was confirmed, including the correct handling of covers and vehicles driven by an AI operator.

## Installation

1. Copy the `FS25_LooseCargo.zip` file to the following directory:

   ```text
   Documents\My Games\FarmingSimulator2025\mods
   ```

2. Enable the mod when loading a save file.

This mod is intended for single-player gameplay.

## Change log

### 1.1.0.0

- first stable version ready for general use;
- code refactoring and removal of diagnostic entries from the log;
- retention of verified handling of trailers, semi-trailers and transfer trailers;
- retention of the effects of speed, density, cover and fill level;
- refinement of `modDesc.xml` and the documentation.

### 1.0.5.0

- added an exposure factor dependent on the fill level;
- no losses at 25% or below;
- the intensity of losses increases linearly from 25% to 100% fill level.

### 1.0.4.0

- Support for materials that may also appear as pallets or bales has been improved;
- potatoes, beetroot, carrots, parsnips, wood chips, silage, grass, hay, straw, chaff and TMR are now correctly treated as bulk cargo in the trailer.

### 1.0.3.0

- the `BULK` category has been implemented to identify bulk materials;
- the `fillType` and `massPerLiter` diagnostics have been added for testing purposes.

### 1.0.2.0

- the method for classifying vehicles into shop categories has been changed;
- support for `TRAILERS`, `TRAILERSSEMI` and `AUGERWAGONS` has been added.

### 1.0.1.0

- The timing of specialisation injection via `TypeManager.validateTypes` has been corrected.

### 1.0.0.0

- First prototype version of the cargo loss mechanism.

## Notes

The mod deliberately does not include a particle effect showing material spilling out. A universal method for determining the emission point for all trailer and transfer wagon models would require additional assumptions regarding their geometry. The current version therefore remains lightweight and independent of specific vehicle models.
