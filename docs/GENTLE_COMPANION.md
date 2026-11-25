# Gentle companion preview 0.8

TamoTank now opens on a resident betta and a small care dock. A friendship grows
through optional interaction. The design rule is additive care: absence never
causes lost progress, unmet needs, suffering, sickness, death or a broken streak.
There is no hunger, energy or cleanliness debt to repay.

## Playable flow

- Tap the name to rename the resident. Names are limited to 24 characters.
- **Snack** creates one visible golden pellet inside the reachable tank. The
  production swimming controller steers to it; contact awards a shared snack.
  Uneaten food harmlessly disappears. Brief cooldowns prevent stacked events.
- **Play** invites follow-the-finger. Hold or drag in open water. A short game
  adds a memory; releasing the touch or ending play clears steering.
- **Sparkle** is an optional water-refresh celebration. Water never becomes
  hazardous or dirty while the user is away.
- **Rest / Wake** selects peaceful hovering, dim lighting, or normal swimming.
  Rest releases a turning curl rather than freezing a bent pose. It changes no
  care score and is never required to restore depleted energy.
- **Memories** keeps shared snacks, games, refreshes, age and first experiences.
- **Looks** provides four persistent colour tints of the current fish.

The modified BlueMesh rig, front flex, coated material, compound turns and dual
quaternion skinning remain in use. The purchased Gusai pack is not bundled yet:
private download and inspection of its rig are pending browser access. Raw paid
assets must stay outside the public repository, including Git LFS and releases.

## Persistence

`user://companion.json` stores identity, appearance, rest choice, additive bond,
action counts and up to eight memories. Writes go to a temporary file before
rename. The last valid save is retained as `.bak`; malformed current files fall
back to that backup. Progress is saved after actions, every 30 seconds, and on
application pause. Platform uninstall can remove app data; this is not a cloud
save or an import/export feature.

## Validation

`tests/test_companion.gd` checks a year of absence without lost progress,
identity/colour/memory persistence, damaged-save recovery, real snack approaches
from both side walls and the centre, calm rest, play reward/steering cleanup,
refresh cooldown and integrated save/reload. The existing swim, pivot, volume
and 42 wall/corner cases remain relevant and are retained in CI.

`scripts/CompanionShowcase.gd` records the real app flow with a disposable save:
snack, sparkle, following, memories, appearance and rest. Use `--snapshot` for a
short still review and `--landscape` for the wider layout. An optional
`--output-dir=/absolute/path` controls screenshot output; otherwise it uses the
engine's user data directory. The showcase does not represent manual phone
testing.

## Current boundaries

This is a normal Android companion app, not yet a registered live wallpaper.
There is no WallpaperService, background media picker, cloud sync, sound pack,
or purchased-rig integration in this preview. The older debug controls remain
in source as a development HUD but are not part of the companion flow.
