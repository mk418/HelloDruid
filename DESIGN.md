# HelloDruid — Design

HelloDruid is the Druid companion to HelloWarrior: a zero-config, additive Classic Era combat cluster built entirely on secure action buttons.

## Secure form state

Form indices are discovered from `GetShapeshiftFormInfo`; they are not assumed to be fixed. A `SecureHandlerStateTemplate` receives a state driver assembled from the learned Cat and Bear indices. Every slot's Cat, Bear, and Balance macro is populated out of combat, and the restricted `_onstate-mode` snippet swaps only those prepared attributes during combat.

```
                       RANGE
                    player cast bar
 [learned forms]  resource / mana / swing  [MODE]
 [buff] [thorns] [barkskin] [innervate] [rebirth] [racial]
 [ ability ][ ability ][ ability ][ ability ][ ability ][ ability ][ ability ]
 [ ability ][ ability ][ ability ][ ability ][ ability ][ ability ][ ability ]
```

The active mode is Cat for Cat Form, Bear for Bear/Dire Bear, and Balance for every other form. Protected macros, visibility, bindings, and anchors are never reconfigured by insecure Lua during combat. Talent/spell changes are reapplied after combat.

## Recommendations

`Helper:Compute(mode)` evaluates target state, player auras, combo points, resource state, cooldowns, group context, and target casts. It returns soft/hard cues per ability. On-next-swing Maul and independent utility never displace the best GCD recommendation.

Cat powershift recommendations are deterministic: Furor must be rank 5, current energy must be low, Cat Form must be affordable, and Clearcasting must be absent. Wolfshead Helm changes the expected energy return from 40 to 60.

## Modules

- `Core.lua` — class gate, events, slash commands, locally animated shine.
- `Abilities.lua` / `Helper.lua` — catalogs and recommendation state.
- `FormIndicator.lua` / `ActionBar.lua` — secure forms, macros, grid, resources, range, cooldowns.
- `SwingTimer.lua` / `CastBar.lua` — form-aware combat timing.
- `Config.lua` / `Keybinds.lua` — saved state, settings, and position-following bindings.

The addon is standalone and does not hide or restyle Blizzard or DragonflightUI action bars. The sole exception is the player cast bar: while HelloDruid's replacement is enabled and visible, it uses Blizzard's own `SetAndUpdateShowCastbar` replacement-bar switch and restores the Blizzard bar when disabled.
