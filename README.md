# HelloDruid

A lean, opinionated ability manager for WoW Classic Era Druids. It follows Cat, Bear, and Balance forms, recommends the next useful action, and puts the resources and combat information for the active form in one compact cluster.

HelloDruid never casts automatically. Every action comes from a secure button you click or bind.

## What it does

- **Form-following layouts.** Cat Form and Bear/Dire Bear Form have dedicated grids. Humanoid, Moonkin, Travel, Aquatic, and other forms use Balance; a caster-form button always provides a way back to humanoid form.
- **Practical PvE recommendations.** Blizzard-style spell alerts mark the best current action, maintenance needs, interrupts, taunts, and urgent resource actions, matching HelloWarrior's visual language.
- **Cat support.** Combo points, Rake/Rip timers, finishers, Clearcasting-aware cues, and a secure powershift button. Powershift recommendations require Furor rank 5, enough mana, low energy, and account for Wolfshead Helm.
- **Bear support.** Maul queue shine, rage-cap warning, Faerie Fire and Demoralizing Roar upkeep, Growl alerts, and Bash/Feral Charge cast alerts.
- **Balance support.** Moonfire/Insect Swarm/Faerie Fire upkeep and contextual nukes: Wrath while solo or tanking the target, Starfire in groups.
- **Combat telemetry.** Energy/rage plus shapeshift mana, Balance mana, melee swing timing, range state, GCD/cooldown sweeps, and a compact player cast bar.
- **Position-following keybinds.** `/hd keys` binds visible positions, so keys continue to follow collapsed talent slots and form changes.

Healing spells are deliberately absent. HelloHealer owns the healing workflow; HelloDruid keeps Rebirth, Innervate, Barkskin, buffs, and racial utility available.

## Commands

- `/hd` — show help.
- `/hd config` — open settings.
- `/hd bars [on|off]` — show or hide the cluster.
- `/hd castbar [on|off]` — toggle the addon cast bar and restore Blizzard's when disabled.
- `/hd pos [lock|unlock|reset]` — move or reset the cluster.
- `/hd keys` — enter keybind mode; `/hd keys clear|reset` manages bindings.
- `/hd reset` — reset saved variables and reload.

## Caveats

- Classic Era only; other game versions are unsupported.
- English spell and aura names are used in this first release.
- Shred can be recommended when optimal, but the Classic API cannot reliably tell whether you are behind the target. Claw remains beside it as the fallback.
- Travel and Aquatic forms display Balance by design. Balance buttons cancel those forms before casting; compatible Balance spells retain Moonkin Form.
- Recommendations are practical defaults, not a parsing simulator or bot.

Released under the [MIT License](LICENSE).
