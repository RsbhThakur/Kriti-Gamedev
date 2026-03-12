# Seen vs Unseen - Godot Prototype

Top-down survival prototype for the **Seen vs Unseen** theme.

## Core Gameplay
- Player uses two joysticks: movement + aim/fire.
- Enemies are visible only inside the player torch cone (90°).
- Enemy behavior:
  - Detects/chases player with obstacle-aware movement.
  - Speed boost only when line-of-sight exists.
  - Melee attacks reduce player health by 20.
- Player stats:
  - Health starts at 100.
  - Regeneration: +1 per second when not recently hit.
  - 3 total lives.
- Enemy takes 3 bullets to kill.
- Difficulty scales over time (spawn interval + enemy pace).
- Random enemy spawns and procedural vegetation map chunks.

## Audio
- `bgm.mp3`: looping background music.
- `zombieattack.mp3`: played per enemy melee attack.
- `zombie.mp3`: alert cue when one or more enemies enter detection state.

## Controls
### Desktop
- Movement: WASD / Arrow keys / left virtual joystick.
- Aim + Shoot: right virtual joystick.
- Pause menu: `Esc` (works even on game over).

### Mobile
- Left joystick: move.
- Right joystick: aim + shoot.

## Scenes
- Main menu: `node_2d.tscn`
- Gameplay: `game.tscn`

## Folder Structure
- `scripts/gameplay/` - active gameplay scripts (`game`, `player`, `enemy`, `bullet`)
- `scripts/ui/` - UI scripts (main menu)
- `images/` and `addons/virtual_joystick/Objects/Nature/` - visual assets

## Android / APK Notes
Fullscreen behavior is configured via `project.godot` display stretch settings and runtime fullscreen request on Android.

## Run
1. Open project in Godot 4.6+
2. Press Play on `node_2d.tscn` or run `game.tscn` directly for gameplay testing

## License and Assets
Use only assets you have rights to distribute. Keep third-party asset attribution and license terms in submissions.
