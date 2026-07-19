# Pixel-Art Roguelite (Dead Cells-like) — Framework Architecture

**Engine:** Godot 4 (GDScript) · **Platform:** PC · **Scope:** solo/small-team indie

**Pillars:** (1) tight combat feel, (2) procedural level assembly, (3) movement kit. Meta-progression is a designed-for extension point only — one seam, no systems built on it yet.

---

## 1. Project & Scene Structure

**Language & typing rule:** GDScript with *limited* `class_name` usage. `class_name` only on custom Resources and cross-boundary types (`WeaponData`, `AttackStep`, `BiomeConfig`, `RoomChunk`) that must be created from data or typed in exports. Everything else is plain scripts on composed nodes — fewer global names, less coupling, faster iteration.

**Composition over inheritance.** Actors are `CharacterBody2D` roots with child capability nodes — `StateMachine`, `Health`, `Hurtbox`, `Hitbox`, `MovementConfig`, sprite + `AnimationPlayer`. Player and enemies share `Health`/`Hurtbox`/`Hitbox` verbatim; they differ only in state machine content and input source (`Input` vs AI). No deep inheritance tree: `Actor` is one thin shared base at most, and enemy types are *scenes*, not subclasses.

**Folder layout (res://):**

```
autoload/        # EventBus, RunManager, AudioBus, SaveStub
actors/player/   # player.tscn + states/
actors/enemies/  # enemy_base.tscn + per-type scenes
combat/          # weapon_data.gd, attack_step.gd, hitbox.gd, hurtbox.gd, health.gd
level/           # generator/, chunks/biome_x/*.tscn, stage.tscn
fx/              # hitstop, shaker, particles, flashes
ui/              # HUD, menus
data/            # .tres: weapons, biomes, enemy stats
```

**Autoloads (4, no more):**

| Autoload | Responsibility |
|---|---|
| `EventBus` | Cross-cutting signals: `hit_landed`, `enemy_killed`, `room_cleared`, `player_died`, `currency_dropped` |
| `RunManager` | Run seed, biome sequence, stage loading, death/restart |
| `AudioBus` | SFX pools (pooled `AudioStreamPlayer2D`s to avoid allocation spikes) + music |
| `SaveStub` | Persistent dictionary written on run end — the *only* meta-progression hook |

---

## 2. Player Controller (movement kit)

**Pattern: flat state machine, per-state child nodes** under a `StateMachine` node. Justification: a Dead Cells-like ends with 15+ states; a single-script enum `match` becomes an unreadable 1000-line file, while per-state nodes give each state isolated config, are add/remove-friendly, and map 1:1 onto the scene tree. It is *flat*, not a true HSM — shared logic (air steering, gravity) lives in helper functions on the player, not in parent-state classes. True hierarchical nesting adds complexity GDScript doesn't repay at this scale.

**States:** `Idle, Run, Jump, Fall, Roll, WallCling, WallJump, LedgeClimb, Attack, Hurt, Dead`. `Attack` is a single state parameterized by `AttackStep` data (§3) so it serves every weapon move.

**Feel systems** (all tunable exported floats, verified in a greybox playground):

- **Coyote time** ~0.10s and **jump buffer** ~0.12s — two countdown timers stamped on edge events.
- **Variable jump height** — on jump release while ascending: `velocity.y *= jump_cut` (~0.4).
- **Acceleration** — `move_toward` with separate ground/air accel and decel constants (snappy: near-instant ground accel, lower air accel); expose a `Curve` only if constants feel wrong.
- **Roll** — fixed-distance impulse with i-frames during active frames, cancelable into attack near the end (cancel window in data).
- **Wall interactions** — `WallCling` (slide at capped fall speed), `WallJump` (input-buffered), ledge detection via two raycasts (head/feet); `LedgeClimb` plays a locked animation then hands control back.

**Animation binding:** `AnimationPlayer` as single source of truth; each state's `enter()` calls `play(anim)`. Chosen over `AnimationTree` — pixel-art clips are short and discrete; the Tree's graph complexity buys nothing here.

> ⚠ **Critical rule:** hitbox enable/disable and movement impulses are fired from **Call Method tracks on the animation timeline**, never from timers. Hitboxes can then never desync from frames, and designers retime attacks by dragging keys.

---

## 3. Combat System (combat feel)

**Data-driven weapons.** `WeaponData` (Resource) holds an ordered `Array[AttackStep]`. Each `AttackStep` (Resource) defines:

- animation name, damage, poise damage
- hitbox shape + offset (`Shape2D` + `Vector2`)
- knockback vector, forward lunge impulse
- windup/active/recovery as animation frame ranges
- cancel windows (roll-cancelable from frame X, chain-cancelable from frame Y)

The `Attack` state reads the current step, advances the chain on buffered attack input, and resets on timeout. **Adding a weapon = authoring a `.tres` + animations, zero code.**

**Hitbox/Hurtbox via Area2D.** `Hitbox` (Area2D, `monitoring=true`) lives on the attacker; `Hurtbox` (Area2D) on the victim. On overlap, the hitbox looks up the victim's `Health` and calls `take_hit(HitInfo)`. `HitInfo` packs damage, poise damage, knockback, attacker direction.

**Collision layers (name these in Project Settings on day one — numeric layers in code are a classic source of silent combat bugs):**

| Layer | Name | Mask contents |
|---|---|---|
| 1 | world | collides with player/enemy bodies |
| 2 | player_body | 1, 3, 9 |
| 3 | enemy_body | 1, 2, 3, 9 |
| 4 | player_hitbox | 7 |
| 5 | enemy_hitbox | 6 |
| 6 | player_hurtbox | 5, 10 |
| 7 | enemy_hurtbox | 4, 10 |
| 8 | pickup | 2 |
| 9 | trigger (doors, room bounds, kill-zones) | 2, 3 |
| 10 | projectile | 1, 6, 7 |

**Damage pipeline:** `Hitbox → Hurtbox → Health.take_hit` → i-frame check → damage/poise application → knockback impulse → emit `EventBus.hit_landed(HitInfo)` → `Hurt` state **only if poise broken**. Light hits flash but don't interrupt — this is what makes combat feel fast.

**Juice layer** (subscribes to `hit_landed`, fully decoupled from gameplay logic):

- **Hitstop:** `Engine.time_scale = 0.05` for ~70–100ms on hit (heavier on kill). ⚠ Sharp edge: `SceneTreeTimer`/`create_timer` ignore `time_scale` by default — restore via a manually accumulated timer in `_process`, or `create_timer(x, true, false, true)` with `ignore_time_scale=true`.
- **Screen shake:** trauma-based `Camera2D` shaker — trauma decays over time, offset = noise × trauma².
- **I-frames:** roll sets `Hurtbox.monitoring=false` + sprite blink shader; post-hit grace ~0.5s.
- **Particles/flash:** pooled one-shot `GPUParticles2D` + white-flash shader on victim.

---

## 4. Enemy Framework

Proportionate to its priority — this framework should total a few hundred lines.

- `enemy_base.tscn` = `CharacterBody2D` + `Health`, `Hurtbox`, `Hitbox`, `DetectionZone` (Area2D + one LOS `RayCast2D`), `StateMachine` reusing the player pattern.
- Per-enemy scenes add: stats `.tres`, animations, and 3–5 states from `Idle, Patrol, Chase, Telegraph, Attack, Stagger, Dead`.
- **Telegraphs are mandatory states, not animation details:** `Telegraph` has a fixed readable duration (flash + sound cue) before `Attack` — this is what makes encounters fair.
- **Poise:** hidden meter reduced by poise damage; break → forced `Stagger` (interrupt + vulnerability window), then refills.
- Detection stays dumb: radius + LOS ray, walk-toward-player, ledge-avoid raycasts. No pathfinding.

---

## 5. Procedural Level Assembly (the Dead Cells way)

**Authoring format — chunks are scenes.** `RoomChunk` root (`Node2D` + `class_name RoomChunk`) containing:

- `TileMapLayer` nodes (terrain + decoration)
- child `Marker2D` connectors (`Connector_N/S/E/W` with an export for door width)
- spawn markers (`EnemySpawn`, `TreasureSpawn`, `PlayerStart`)
- exports: `role` (start/combat/shop/treasure/boss/branch), `biome` tag, difficulty budget

Chunks are hand-authored, so every jump inside them is guaranteed makeable — the fundamental difference from naive random-walk/tile-noise generation, which produces unreachable gaps and flat pacing.

> ⚠ **Godot 4 sharp edge:** the monolithic `TileMap` node is deprecated as of 4.3 in favor of `TileMapLayer`. Author all chunks with `TileMapLayer` from day one. Because chunks are instanced as whole scenes (not drawn into a shared tilemap), no runtime tile copying is needed — instancing *is* the merge step.

**Generator — critical path first, then branches:**

1. From `BiomeConfig` (Resource: weighted chunk lists per role, path length range, budget): sample a role path, e.g. `Start → Combat → Combat → (Shop|Treasure) → Combat → BossDoor`.
2. Place greedily on a coarse grid: for each step, pick a chunk whose connector direction/width matches the previous chunk's open socket; snap door-to-door; retry bounded times on collision, then backtrack one step.
3. Attach optional branches (dead-end treasure/challenge rooms) to remaining open sockets on path rooms.
4. **Validation pass:** walk the connector graph, assert boss reachable from start and every room on some path; regenerate on failure (near-free with seeds).
5. Populate spawn markers against a difficulty budget (enemy cost points scaled by room distance from start).

**Deterministic seeds:** one `RandomNumberGenerator` at run start; per-stage RNG seeded as `hash(run_seed, biome_index)` so any stage is reproducible in isolation (invaluable for bug reports: "seed 81244, stage 2").

---

## 6. Data Flow & Run Lifecycle

**Run:** `RunManager.start_run(seed)` → load hub → `start_stage(0)` → load `stage.tscn`, run generator, instance chunks, spawn player at `PlayerStart`.

**All chunks of one stage live in one scene.** Room transitions are camera moves, not scene loads: each chunk carries a `CameraBounds` Area2D (layer 9) that retargets `Camera2D` limits; combat rooms lock doors (layer 1 blockers toggle) until `room_cleared`. Chunk streaming (load/unload) only if profiling demands it — at indie scope one scene per stage is fine.

**Death:** `player_died` → `RunManager` writes `SaveStub` (currency earned, unlock flags) → death screen → new seed. Resets per run: player build, level layouts, economy. Persists: only `SaveStub` contents — the meta-progression extension point.

**Bus vs direct references — the rule:**

- *Many-listener, must-not-break-gameplay-if-absent* events (juice, audio, achievements, UI) → `EventBus`.
- *Must-not-fail-silently, 1:1* interactions (state machine → body, hitbox → health, generator → chunks) → direct calls.
- Never use the bus to reach your own children.

---

## 7. Pixel-Art Pipeline

- **Viewport:** base 480×270 (integer-scales ×4 to 1080p, ×8 to 4K). `stretch/mode = canvas_items`, `aspect = keep`.
- **Filtering:** `rendering/textures/canvas_textures/default_texture_filter = Nearest` project-wide; use the importer's "2D Pixel" preset (no filter, no mipmaps).
- **Snap:** enable `rendering/2d/snap/snap_2d_transforms_to_pixel` and `snap_2d_vertices_to_pixel`.
- ⚠ **Camera jitter trap:** `Camera2D.position_smoothing` causes sub-pixel shimmer on pixel art — ship with smoothing off, or quantize camera position to whole pixels in `_process`. Test at non-integer window sizes (e.g. 150% display scaling) where `keep` aspect reveals shimmer.
- **Grid:** 16×16 tiles; characters on 32×32 or 48×48 canvases, ~24–32px tall in-world (Dead Cells proportions). Animation at 10–12 fps authored, snappier attack anims at 15+.
- **TileSet:** physics layer 1 for collision shapes, terrain sets for autotiling chunk edges.

---

## 8. Phased Roadmap

Front-loads the three prioritized pillars.

| Milestone | Scope | Done when |
|---|---|---|
| **M1 — Greybox movement** (pillar 3) | Flat FSM: Idle/Run/Jump/Fall/Roll/WallCling/WallJump/LedgeClimb; coyote, buffer, variable jump, accel tuning | In a playground of rectangles, a traversal circuit (gaps, walls, ledges) feels responsive with zero "eaten" jumps across 5 minutes of play |
| **M2 — Combat core + juice** (pillar 1) | One melee weapon, 3-hit chain from `WeaponData`; hitbox/hurtbox/health pipeline; one stationary dummy + one walking enemy; hitstop, shake, knockback, i-frames, flash, particles | Chaining hits on the dummy feels weighty; roll-through attacks reliably avoid damage |
| **M3 — Chunks + generator** (pillar 2) | `RoomChunk` format; 8–10 greybox chunks for one biome; critical-path-then-branches generator with seeded RNG + connectivity validation; camera bounds + door locks | 20 consecutive seeds each produce a walkable start→boss path; layouts differ meaningfully |
| **M4 — Enemy variety** | 3–4 enemies (melee rusher, ranged, flyer, heavy with poise), telegraph states, spawn budgets wired to generator | Combat rooms play as distinct encounters, not mobs |
| **M5 — Run loop** | Biome sequence, death/restart, pickups + light in-run economy, HUD, audio pass, options (screenshake toggle!); `SaveStub` written on death — extension point armed, meta systems explicitly deferred | A full start→death→restart loop ships to a friend who asks for "one more run" |

---

## 9. Key Risks & Mitigations

1. **State machine explosion.** Roll/attack/air permutations breed 30 states. → Cap states aggressively; parameterize `Attack` by data; express "cancel-into" as per-step frame windows, not new states.
2. **Procgen unfair or samey.** → Hand-authored chunks make fairness structural; connectivity validator regenerates bad layouts; budget-based population; keep a headless test that generates 500 seeds and asserts reachability.
3. **Animation/combat desync.** Hitboxes driven by timers drift from frames. → AnimationPlayer Call Method tracks only — retiming an attack retimes its hitbox automatically.
4. **Pixel jitter kills "tight" feel.** → Nearest + snap + smoothing-off decisions locked in M1, tested at multiple scales, before content exists.
5. **Meta-progression scope creep.** → Exactly one seam (`SaveStub` + `EventBus.currency_dropped`); no meta UI until M5's loop is fun without it.

---

## Critical Files (to be created in M1–M3)

- `actors/player/state_machine.gd` + `actors/player/states/` — per-state player controller
- `combat/weapon_data.gd` / `attack_step.gd` — data-driven combat resources
- `combat/hitbox.gd` / `hurtbox.gd` / `health.gd` — shared damage pipeline components
- `level/generator/stage_generator.gd` + `level/chunks/room_chunk.gd` — chunk format and critical-path generator
- `autoload/run_manager.gd` + `event_bus.gd` — run lifecycle and decoupling seam
