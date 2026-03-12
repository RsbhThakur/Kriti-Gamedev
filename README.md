# Blinking Dead

**Team:** Hostel-2673  
**Event:** GDAI × Tech Meet Game Jam  
**Theme:** Seen vs. Unseen  
**Engine:** Godot 4.6.1  
**Platform:** Android (`.apk`)

---

## Theme Interpretation

In **Blinking Dead**, the only source of visibility is the player's directional torch. Enemies are present on the map at all times but are **completely invisible until they enter the torch cone**. The moment they exit the beam, they vanish. The torch governs every core mechanic — visibility, shooting range, bullet reach, and the existence of the boss — making perception the single central resource.

| System | Seen | Unseen |
|---|---|---|
| Small zombies | Visible inside torch cone + clear wall LOS | Invisible outside cone |
| Boss zombie | Visible once activated by proximity | Invisible and dormant at spawn |
| Shooting | Constrained to torch arc only | Cannot fire outside cone |
| Bullets | Wall-clipped via tile raycast | Blocked by obstacles |

---

## Gameplay

Top-down 2D survival. Survive as long as possible on a fixed walled map.

### Controls

| Action | Input |
|---|---|
| Move | Left virtual joystick |
| Aim / Shoot | Right virtual joystick |
| Pause | Pause button (top-right HUD) |

### Core Loop
- Torch faces movement direction. Gun aims independently via the right joystick.
- Enemies outside the torch cone are invisible — no indicator of their position or count.
- Small zombies spawn in escalating waves.
- Boss zombies are scattered across the map, invisible and frozen, activating only when the player enters their `230 px` activation radius.
- Player has **3 lives** with slow health regeneration between hits. All 3 depleted = game over.
- On life loss: all enemies clear, player respawns at map centre, 3-second grace period before play resumes.
- HUD tracks: health bar, lives remaining, survival time (MM:SS), total kills.

---

## How to Run

### Android
1. Download `blinking-dead-debug.apk` from the submission folder.
2. Enable **Install from unknown sources** in device settings.
3. Install and launch. Designed for landscape orientation.

### From Source
1. Open the project folder in **Godot 4.6.1**.
2. Press `F5` — main menu (`node_2d.tscn`) launches automatically.
3. To test gameplay directly, open and run `game.tscn`.

---

## Build Information

| Property | Value |
|---|---|
| Engine | Godot 4.6.1 (stable) |
| Language | GDScript |
| Viewport | 1280 × 720 |
| Stretch mode | Canvas items / Expand |
| Target platform | Android (Mobile feature tag) |
| Min Android API | 21+ (Godot 4.6 default) |
| Estimated RAM | < 256 MB |

---

## Technical Reference

### Player (`character_body_2d.gd`)

| Parameter | Value |
|---|---|
| Move speed | 200 px/s |
| Max health | 100 HP |
| Lives | 3 |
| Health regen | +1 HP/s, starts 1 s after last hit |
| Fire rate | 1 shot per 0.2 s (5 shots/s) |
| Torch cone angle | 70° total (±35° from facing direction) |
| Torch range | 360 px |
| Bullet speed | 600 px/s |
| Bullet lifetime | `(wall_distance − 40) / 600` s — dynamically clipped to first wall hit |

**Shooting constraint:** A shot is only fired when the gun joystick/mouse aim vector is within the torch half-angle. The angle between `facing_vector` and `aim_vector` must satisfy `|angle| ≤ 35°`.

**Torch polygon draw:** 28 interpolated ray steps across the cone are cast per frame, each clipped to the first wall tile hit. The result is rendered as a filled polygon (`Color(1.0, 0.95, 0.55, 0.18)`) with two boundary lines.

---

### Enemy — Small Zombie (`enemy_1.gd`, `configure_enemy(false)`)

| Parameter | Value |
|---|---|
| Max health | 1 HP (killed in 1 shot) |
| Walk speed | 62 px/s |
| Boost speed | 104 px/s (within 200 px of player) |
| Detect radius | 1200 px |
| Attack radius | 42 px |
| Attack damage | 10 HP |
| Attack cooldown | 1.35 s |
| Sprite scale | 1 × 1 |
| Initial visibility | Visible |

---

### Enemy — Boss Zombie (`enemy_1.gd`, `configure_enemy(true)`)

| Parameter | Value |
|---|---|
| Max health | 10 HP (10 shots to kill) |
| Walk speed | 48 px/s |
| Boost speed | 82 px/s (within 200 px of player) |
| Activation radius | 230 px |
| Attack radius | 90 px |
| Attack damage | 30 HP |
| Attack cooldown | 1.25 s |
| Sprite scale | 4 × 4 |
| Initial state | Invisible, frozen, inactive |

**Activation:** When player enters 230 px, boss becomes active, plays growl audio, and permanently chases player.

---

### Difficulty Scaling (`game.gd`)

All enemy speeds are multiplied by a difficulty scale that increases with survival time:

```
difficulty = clamp(1.0 + elapsed_time / 50.0,  min=1.0,  max=3.2)
```

| Elapsed time | Difficulty multiplier |
|---|---|
| 0 s | 1.0× |
| 50 s | 2.0× |
| 110 s | 3.2× (cap) |

Applied every frame to all active enemies via `set_difficulty_scale(difficulty)`.

---

### Spawn Rate System (`game.gd`)

**Small enemy interval formula:**

```
raw_interval  = max(minimum_spawn_interval,  base_spawn_interval − elapsed_time × spawn_acceleration)
               = max(3.5,  10.0 − elapsed_time × 0.008)

jitter        = randf_range(−0.6, 0.6)

final_interval = max(3.5,  raw_interval + jitter) / SMALL_SPAWN_RATE_MULTIPLIER
               = max(3.5,  raw_interval + jitter) / 1.4
```

| Parameter | Value |
|---|---|
| `base_spawn_interval` | 10.0 s |
| `minimum_spawn_interval` | 3.5 s |
| `spawn_acceleration` | 0.008 s⁻¹ |
| `SMALL_SPAWN_RATE_MULTIPLIER` | 1.4 |
| Jitter | ±0.6 s (uniform random) |
| Max simultaneous enemies | 22 |

At t=0 the interval is ~7.1 s. At t=812 s (~13.5 min) the floor of 3.5 s is hit, giving a final interval of ~2.5 s.

**Boss enemy initial count:**

```
initial_boss_count = round(hidden_main_enemy_count × BIG_SPAWN_RATE_MULTIPLIER)
                   = round(4 × 1.2)  =  5
```

Placed at game start at random positions > 320 px from player.

**Boss respawn on death (fractional credit):**

```
total  = BIG_SPAWN_RATE_MULTIPLIER + big_spawn_fractional_credit
       = 1.2 + carry

spawn_count            = floor(total)          # usually 1, every 5th death = 2
big_spawn_fractional_credit = total − spawn_count   # credit carries forward
```

This guarantees exactly 1.2× average boss replacements per death: 4 deaths spawn 1, every 5th death spawns 2.

---

### Spawn Point Selection

**Small enemies** — `_pick_random_spawn_point()`:
- 50 attempts: random angle `[0, 2π)`, distance `rand(280, 500)` px from player
- Accepted if: distance from player > 200 px AND position not blocked by physics collider
- Clamped within map bounds with 48 px margin
- Fallback (all 50 fail): 350 px from player at random angle

**Boss enemies** — `_pick_hidden_main_enemy_spawn()`:
- 60 attempts: random position within map bounds (48 px margin)
- Accepted if: distance from player > 320 px AND not blocked
- Fallback: random position in bounds

---

### Line-of-Sight & Wall Systems

**`_is_wall_between(from, to)`** — Bresenham integer line trace through TileMap cells:
- Converts both world positions to tile coordinates via `local_to_map()`
- Steps through each cell on the line using the standard Bresenham error accumulation
- Returns `true` on first cell with a collision polygon (Godot TileData API)
- Used for: enemy attack blocking, torch enemy reveal suppression

**`_ray_hit_wall_distance(origin, dir, max_dist)`** — Continuous ray march:
- Step size: `tile_world × 0.45 = 64 × 0.45 = 28.8 px`
- Samples `_world_to_tile()` at each step; returns distance on first wall hit
- Returns `-1.0` if no wall found within `max_dist`
- Used for: torch polygon shape, bullet lifetime calculation

**Tile world size:** TileMap at position `(7034, 2883)`, scale `(4, 4)`, tile size `16×16 px` → `64 px per tile` in world space.  
**Playable interior:** `map_rect` = origin `(7034 + 64, 2883 + 64)`, size `(70 × 64, 40 × 64)` = `4480 × 2560 px`.

---

### Alert Audio System

- Zombie growl sound plays when: any enemy is alerted **or** nearest enemy is within 320 px
- Cooldown between plays: 2.8 s
- Audio stops immediately on pause or game over

---

### Bullet (`bullet.gd`)

- Speed: 600 px/s
- Lifetime set dynamically at fire: `max((wall_distance − 40) / 600, 0.01)` s
- On collision with a node that has `take_damage()`: deals 1 damage and frees itself
- Cannot hit the player (added to player's collision exception list)

---

## Project Structure

```
gamedev/
├── scripts/
│   ├── gameplay/
│   │   ├── game.gd               # Main controller: spawning, HUD, lives, difficulty
│   │   ├── character_body_2d.gd  # Player: movement, torch cone, shooting arc
│   │   ├── enemy_1.gd            # Enemy AI: chase, seen/unseen, boss activation
│   │   └── bullet.gd             # Projectile: wall-clipped lifetime, collision
│   └── ui/
│       └── mainmenu.gd           # Start screen: responsive layout, audio toggle
├── addons/
│   └── virtual_joystick/         # Third-party touch input addon (MIT)
├── assets/
│   ├── audio/                    # BGM, gunshots, zombie SFX
│   └── (sprites, tilesets)
├── game.tscn                     # Gameplay scene root
├── node_2d.tscn                  # Main menu scene
├── newmap.tscn                   # Walled tilemap world
└── project.godot
```

---

## Assets & Licensing

| Asset | Description | License |
|---|---|---|
| Main menu background | AI-generated image (Google Gemini) | AI-generated, no third-party copyright |
| Zombie sprite sheets | Pixel art zombie walk cycles (all directions) | Creative Commons |
| Player character sprites | Pixel art character walk/idle (all directions) | Creative Commons |
| Tileset / environment | Walls, floors, obstacles | Creative Commons |
| Gunshot SFX (`.22LR`, `.556` WAV) | Firearm sound effects | Creative Commons |
| Zombie attack / alert SFX | Melee and growl audio | Creative Commons |
| Background music (`level3.ogg`) | Gameplay BGM loop | Creative Commons |
| Virtual Joystick addon | Touch joystick implementation | MIT — © 2025 Kent Coyoca |

The Virtual Joystick MIT `LICENSE` file is preserved at `addons/virtual_joystick/LICENSE` as required.  
All original GDScript code, scene structure, and game design in this repository are original work by the Hostel-2673 team.

---

## Hardware Requirements

| Requirement | Minimum |
|---|---|
| Android version | Android 5.0 (API 21) |
| RAM | 512 MB free |
| Screen orientation | Landscape |
| Touch inputs | 2-finger multitouch |

---

## Team

| Member | Role |
|---|---|
| Hostel-2673 | Game Design, Programming, Art Integration, Level Design |

*Submitted under the GDAI × Tech Meet — Low Prep track.*
