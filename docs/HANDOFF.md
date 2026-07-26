# HANDOFF — Pixel Roguelite (Dead Cells-like)

> Read this to pick up the project cold. Last updated 2026-07-26.

## What this is

A 2D pixel-art roguelite action-platformer (Dead Cells-like) in **Godot 4.7.1 / GDScript**, PC. Framework design in `docs/ARCHITECTURE.md`. Playable loop: title → procedurally-generated stages → shop/treasure → boss door → next stage → death → restart.

## Run & Test

- Open `pixel-roguelite/project.godot` in Godot 4.7.1, F5. Main scene: `level/stage.tscn`.
- Headless tests (all must pass): run each from the console exe —
  `Godot_v4.7.1-stable_win64_console.exe --headless --path <proj> --script res://tools/<name>_test.gd`
  where `<name>` ∈ smoke / climb / combat / generator / stage / enemy.
- Controls: A/D move, Space jump (x2), J attack, K/Shift dash, Esc pause, F3 debug.

## Status — everything below is DONE

- **M1** movement FSM (coyote/buffer/jump-cut/dash/wall/ledge), **M2** combat + juice (hitstop/shake/i-frames/poise), **M3** procgen (ASCII-map room chunks + critical-path generator, camera bounds, door locks, boss-door stage advance), **M4** 4 enemy archetypes, **M5** run loop + economy + HUD + death screen.
- **Art (all real)**: player fighter, rat, spitter+Ball, heavy, eagle, GothicVania tiles+parallax bg, Gothic HUD, Gothic pause menu, shop stands, room props.
- **Audio**: village BGM (Music bus), combat hit=`Sword Impact`, swing=`sfx_swing_1/2/3.ogg` — one whoosh per combo step (split from freesound "Whoosh Triple", peaks normalized, attack.gd adds a pitch ladder 1.0/1.06/0.94 so the finisher reads heavier), other SFX procedural in `fx/sfx_builder.gd`.
- **Props**: crates/barrels destructible (solid to player, roll-through smashes, 12 dmg blast vs enemies); sign/street-lamp decor z=-1 behind actors (was blocking the view).

## 当前任务清单 / Task List

> 每次大改动后同步本表 + `MEMORY/pixel-roguelite-game.md`（见文末约定）。状态：✅ 完成 · 🚧 进行中 · 📋 待办

| 状态 | 任务 | 备注 |
|---|---|---|
| ✅ | 核心玩法 M1–M5 | 移动/战斗/关卡生成/敌人/跑局 |
| ✅ | 美术迁移 | 主角+四类敌人+地块+背景+道具+UI+商店 |
| ✅ | 音频迁移 | BGM + 打击/挥击真实采样 |
| ✅ | 可破坏道具 | 箱子/木桶：碰撞+可破坏+对敌爆破；高装饰物移到角色下层 |
| ✅ | 连续性 | 记忆文件 + 本文档 |
| 📋 P1 | Boss 战 | 在 boss 房间放一个 Boss 敌人（大血条+多阶段），打通 stage→stage 的瓶颈 |
| 📋 P1 | 武器池 + 随机掉落 | WeaponData.id 已就绪；按用户要求「已解锁武器随机掉」 |
| 📋 P2 | Sunny Land 弹簧机关 | mushroom-spring 素材已备，做弹跳平台 |
| 📋 P2 | biome 变体 | 第二个 BiomeConfig（新 tileset + 新敌人组合），验证生成器通用性 |
| 📋 P3 | meta 进度 UI | SaveStub 已埋点；永久解锁界面（Delve-bound 才有意义，先 fun） |
| 📋 P3 | 更高音质战斗音 | freesound 原版 wav 需登录；当前用预览流 lq 版 |

## Architecture quick map

- `autoload/` EventBus, RunManager (seeded RNG + stage advance), AudioBus (SFX pool + music), SaveStub (the ONLY meta seam).
- `actors/player/` player.gd + `state_machine/` + `states/`; sprite anims `player_anims.gd`, attack clips `placeholder_anims.gd`.
- `actors/enemies/` shared `enemy.gd` (+ per-archetype `*_anims.gd`, scenes, `states/`, `projectile.tscn`).
- `combat/` WeaponData/AttackStep (data-driven weapons), Health/Hitbox/Hurtbox (shared damage pipeline).
- `level/` room_chunk.gd (ASCII-map chunks), `generator/stage_generator.gd`, tileset_builder.gd, stage.gd+tscn, shop_stand.*, destructible_prop.gd + prop_health.gd (crates/barrels: solid to player via layer 11 prop_body, 1 hit or roll-through breaks, blast deals 12 to enemies in 30px; tall decor stays z=-1 visual-only).
- `fx/juice.gd` (hitstop/trauma/particles/flash), `fx/sfx_builder.gd`.
- `data/weapons/` sword.tres, dagger.tres. `data/biomes/greybox.tres`.

## Hard-won gotchas (verified, don't relearn)

- Freed objects are **falsy** in GDScript bool checks — never gate logic on them; capture flags early.
- TileData collision validates only **after** the source is added to the TileSet.
- Reserved virtuals (`_get`, `_ready`, etc.) — don't reuse as helper names.
- `:=` inference fails on Variant — use plain `=` (many states use untyped `player`/`machine`/`actor` refs).
- Autoload names don't resolve at compile time in `--script` main loops — `root.get_node("EventBus")`.
- `is_action_just_pressed` spans ALL physics ticks in one frame iteration — buffer input in `_unhandled_input`, not polls.
- Same-name `change_state` no-ops — use `state_machine.restart()` for parameterized re-entry (attack chain).
- Hitbox hits rejected by grace must stay **pending + retry**; i-frame rejections are **whiffs** (no retry). Roll i-frames need a tail (~0.12–0.18s).
- `create_timer` respects time_scale — use `create_timer(x, true, false, true)` for wall-clock (death beat, hitstop restore).
- TextureRect fill needs `stretch_mode=SCALE` + `expand_mode=IGNORE_SIZE` (KEEP mode was the HUD bug).
- Godot **import cache goes stale** after re-cropping a PNG on disk — re-run `--import`.
- Headless can't render — screenshots need a **windowed** run + `get_viewport().get_texture().get_image()`; and the capture node needs `process_mode=PROCESS_MODE_ALWAYS` to survive `get_tree().paused`.
- Fighter art sits ~10.5px left of frame center → center with `visual.offset.x` (offset, **not** position — position made roll orbit).
- Autoload names also fail to resolve in scripts reached via a `--script` main loop's **preload chain** (not just the loop itself) — look up `get_tree().root.get_node_or_null("EventBus")` at runtime (see prop_health.gd).
- `hurtbox._ready` finds its sibling `Health` on sight — when building nodes in code, Health must enter the tree BEFORE the Hurtbox.
- .tscn property lines don't take inline `#` comments (parser risk) — keep comments in gd files.
- An infinite `set_loops()` tween bound to the WRONG node outlives freed targets; they collapse to 0 duration → "Infinite loop detected". Bind looping tweens to the node that owns the targets (`pickup.create_tween()`).

## Conventions / decisions

- Pillars: tight combat feel, procedural levels (hand-authored chunks + critical path), movement kit. Meta-progression deferred to the single `SaveStub` seam.
- `class_name` only on data Resources. TileMapLayer (not deprecated TileMap). Hitboxes from AnimationPlayer Call Method tracks, never timers.
- Sprite foot offset = `body_half − frame_half`: rat -7, spitter -15, heavy -11, eagle -8 @0.7 scale, player -12.
- Roll is a **dash** (forward lean + i-frames), NOT a tumble.

## Sync convention (keep this + memory fresh)

After any major change, the working session updates BOTH:
1. This file (`docs/HANDOFF.md`) — status + task-list table above.
2. Memory `pixel-roguelite-game.md` — state, gotchas, decisions.

That keeps the next conversation current without re-briefing.

## Assets provenance

- `E:\Test\素材` — rat (OutlinedRat), fighter/enemies (sets 1–6, Free City style), GothicVania town (tiles/props/NPC/music), Sunny Land (eagle/piranha/spring), Gothic Pixel UI. License: craftpix.net/file-licenses.
- freesound.org — velcronator "Sword Impact" + "Whoosh Triple" (CC0). Preview streams used; full wav needs freesound login. `sfx_swing.ogg` = first whoosh only (0–215ms + 30ms fade), cropped 2026-07-26 via python/soundfile.
