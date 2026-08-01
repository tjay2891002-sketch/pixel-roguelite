# HANDOFF — Pixel Roguelite (Dead Cells-like)

> Read this to pick up the project cold. Last updated 2026-07-26.

## What this is

A 2D pixel-art roguelite action-platformer (Dead Cells-like) in **Godot 4.7.1 / GDScript**, PC. Framework design in `docs/ARCHITECTURE.md`. Playable loop: title → procedurally-generated stages → shop/treasure → boss door → next stage → death → restart.

## Run & Test

- Open `pixel-roguelite/project.godot` in Godot 4.7.1, F5. Main scene: `level/stage.tscn`.
- Headless tests (all must pass): run each from the console exe —
  `Godot_v4.7.1-stable_win64_console.exe --headless --path <proj> --script res://tools/<name>_test.gd`
  where `<name>` ∈ smoke / climb / combat / generator / stage / enemy.
- Controls: A/D move, Space jump (x2), J attack, K/Shift dash, F interact (weapon swap / shop), Esc pause, F3 debug.

## Status — everything below is DONE

- **M1** movement FSM (coyote/buffer/jump-cut/dash/wall/ledge), **M2** combat + juice (hitstop/shake/i-frames/poise), **M3** procgen (ASCII-map room chunks + critical-path generator, camera bounds, door locks, boss-door stage advance), **M4** 4 enemy archetypes, **M5** run loop + economy + HUD + death screen. Rooms enlarged 2026-08 (boss arena 22x11, combat 22-26 wide); enemies fenced to the walkable span (never into door planes/blockers). Stage-wide `FillBackdrop` TileMapLayer (z -2, real collision) paints solid rock over the stage bounds minus carved room interiors — walls are solid mass now, not hollow frames.
- **Art (all real)**: player fighter, rat, spitter+Ball, heavy, eagle, GothicVania tiles+parallax bg, Gothic HUD, Gothic pause menu, shop stands, room props.
- **Audio**: village BGM (Music bus), combat hit=`Sword Impact`, swing=`sfx_swing_1/2/3.ogg` — one whoosh per combo step (split from freesound "Whoosh Triple", peaks normalized, attack.gd adds a pitch ladder 1.0/1.06/0.94 so the finisher reads heavier), other SFX procedural in `fx/sfx_builder.gd`.
- **Props**: crates/barrels destructible (solid to player, roll-through smashes, 12 dmg blast vs enemies); sign/street-lamp decor z=-1 behind actors (was blocking the view). Scatter: 2-3/room, weighted (barrel/crate 3, sign 2, lamp 1), lamps only in combat/boss rooms with a per-stage cap of 2; spots need a solid `#` floor cell below (bottom-door pits floated props) and clear of T markers.
- **Progression**: kill XP → levels on RunManager (+8% damage, +4 max hp & small heal per level; HUD shows a blue XP bar + Lv label); crates drop weapon-swap (pool: sword/dagger/NEW heavy axe — walk-up + F to swap, old weapon drops aside) / heal potion 30% / rage+swift buffs / curse debuff / cells (`level/drops.gd` table, `level/pickup.gd`). Shop buys also moved to F. HUD: weapon line shows attack power in parens (step-1 dmg × mults); StatusRow shows colored buff chips with countdowns, hidden when none active. Potions + rage/swift are F-confirm too (leave them on the floor for later); cells auto-collect, curse stays a contact landmine by design. Props never scatter onto T markers (a solid crate on a stand shoved the player out of range — stage_test flake).
- **Bosses**: three rotated by stage_index (`BOSS_SCENES`) — GATEKEEPER (heavy art 1.6x, melee + phase-2 3-ball volleys), HEXCASTER (set-4 witch, ranged 3-ball from phase 1, enrage = 5-ball), STREET STRAY (set-3 redcap, fast melee, enrage = pure speed). Phase-2 behavior is per-boss data on `boss_brain.gd` exports (speed/telegraph mults, volley count, alternate toggle). Boss room locks the player in, bottom bar shows the brain's bar_name; kill (40 xp) triggers fanfare + a reward burst (unlocked-pool weapon + potion + SHARDS) + the ENCHANT POOL surfaces at room center, and turns the door flag gold — only then does the door advance the stage. The door hugs the room's RIGHT wall (marker-independent).
- **Two currencies**: coins 金币 (treasure rooms, coin.png) feed the SHOP; shards 魔晶 (crate rolls + boss rewards) feed the enchant pool — +12% weapon damage per rank (max 5, cost 10+5·rank), per weapon id, run-scoped on RunManager (`enchant_pool.gd`, F to buy). HUD shows both (coin count + blue shard count); the weapon line gains a `+N` suffix when enchanted.
- **Boss door** (`level/boss_door.gd`): ornate-arch portal at the boss room's RIGHT wall, **F to enter** — no auto-teleport (the user got yanked mid-loot). Inner glow teal when sealed, gold on clear; prompt reads Sealed/[F] Enter.
- **Real assets everywhere**: HP bar red gradient fill (hp_fill.png) in the ornate frame; XP bar ornate frame (xp_frame.png) + blue fill (xp_fill.png); treasure coins (coin.png, also the HUD cell icon); heal/buff pickups are the potion flask tinted per effect (rage/swift/curse); boss door arch (ornate_arch.png). Generated fills/coin via python/PIL.
- **中文物品提示**: pickups ([F] 治疗/狂暴/疾速 + Chinese weapon names), enchant pool (附魔池 / [F] 附魔 平衡之剑 +1（10 魔晶）/已满级), boss door (封印中/[F] 进入下一层), buff chips (狂暴/疾速/诅咒), weapon display_names in tres. Godot's default font has NO CJK glyphs — all Chinese labels go through `fx/game_font.gd` (SystemFont: Microsoft YaHei/SimHei fallback). Boss bar names stay English (proper nouns). Weapon pickups are dual-purpose: tap F = equip, **long-press F (0.45s) = dismantle into shards** (half the unlock cost, min 4); hold ticks in `_physics_process` (game-time — idle real-time races in unthrottled headless).

## 当前任务清单 / Task List

> 每次大改动后同步本表 + `MEMORY/pixel-roguelite-game.md`（见文末约定）。状态：✅ 完成 · 🚧 进行中 · 📋 待办

| 状态 | 任务 | 备注 |
|---|---|---|
| ✅ | 核心玩法 M1–M5 | 移动/战斗/关卡生成/敌人/跑局 |
| ✅ | 美术迁移 | 主角+四类敌人+地块+背景+道具+UI+商店 |
| ✅ | 音频迁移 | BGM + 打击/挥击真实采样 |
| ✅ | 可破坏道具 | 箱子/木桶：碰撞+可破坏+对敌爆破；高装饰物移到角色下层 |
| ✅ | 升级 + 掉落 | 杀怪得经验升级（加攻/加血）；箱子掉武器（新重斧）/药瓶/buff/curse/细胞 |
| ✅ | 武器解锁池 | 6 武器（剑/匕/枪/巨剑/斧/锤）；商店卖解锁（细胞付费，SaveStub 持久化），已解锁才进掉落池；暂停菜单可见已解锁 |
| ✅ | Boss 战 | Gatekeeper：进房锁门+大血条，半血狂暴（提速+弹幕交替），击破后开门进下一层 |
| ✅ | Boss 轮换 + 击杀奖励 | 素材库 set3/4 启用：女巫 HEXCASTER（远程弹幕）+ 红帽 STREET STRAY（快速近战），按层轮换；击杀掉武器+药瓶+魔晶奖励雨 |
| ✅ | 附魔系统 | 魔晶（箱子/boss 奖励的特殊货币）在 boss 房附魔池给武器强化（+12%/级，上限5）；大门挪到 boss 房右墙 |
| ✅ | P2 弹簧机关 | 蘑菇弹簧（S 标记进 ASCII 地图）：坠落踩上高弹（>双跳）+ 刷新空中跳；标记仅 60% 概率出现，落点按标记向下找实地（不再埋进平台阴影） |
| ✅ | P2 biome 变体 | 洞穴 biome：换色瓦片集 + 史莱姆（Poo Goo 素材）替换老鼠 + 冷色调背景；奇偶层轮换城镇/洞穴，验证生成器通用性 |
| ✅ | P3 meta 进度 UI | 死亡结算面板：带回金币数 + 永久解锁列表（数字键 1-5 购买，SaveStub 持久化）；标题页有提示 |
| ✅ | P3 高音质战斗音 | Kenney Impact Sounds (CC0)：打击=金属重击 002，击杀=金属重击 001；挥击保留三段拆分 |
| ✅ | 房间布局扩充 | 战斗房 3→8：高台/双平台/深坑/窄巷/阶梯（combat_d~h，注册进城镇+洞穴两个 biome 池） |
| ✅ | 连续性 | 记忆文件 + 本文档 |


## Architecture quick map

- `autoload/` EventBus, RunManager (seeded RNG + stage advance), AudioBus (SFX pool + music), SaveStub (the ONLY meta seam).
- `actors/player/` player.gd + `state_machine/` + `states/`; sprite anims `player_anims.gd`, attack clips `placeholder_anims.gd`.
- `actors/enemies/` shared `enemy.gd` (+ per-archetype `*_anims.gd`, scenes, `states/`, `projectile.tscn`).
- `combat/` WeaponData/AttackStep (data-driven weapons), Health/Hitbox/Hurtbox (shared damage pipeline).
- `level/` room_chunk.gd (ASCII-map chunks), `generator/stage_generator.gd`, tileset_builder.gd, stage.gd+tscn, shop_stand.*, destructible_prop.gd + prop_health.gd (crates/barrels: solid to player via layer 11 prop_body, 1 hit or roll-through breaks, blast deals 12 to enemies in 30px; tall decor stays z=-1 visual-only), drops.gd + pickup.gd (crate drop table + pickups; autoload-free, runtime lookups).
- `fx/juice.gd` (hitstop/trauma/particles/flash), `fx/sfx_builder.gd`.
- `data/weapons/` sword, dagger, spear (reach), greatsword (slow wide), axe (2-step heavy), hammer (single slam); `data/biomes/greybox.tres`.

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
- Never `add_child` a collision-bearing node inside a physics signal (body_entered, hitbox dispatch): shape creation/monitoring mid-flush errors ("Can't change this state while flushing queries"). `call_deferred` the spawn (see destructible_prop's drop roll + pickup's swap-drop).
- Autoload `_ready` (e.g. SaveStub.load_data) runs AFTER a `--script` main loop's `_initialize` — mutate autoload state from frame 1+, never in `_initialize`.
- `SaveStub.flush()` AND `load_data()` are headless no-ops: tests never touch the real user://save.json, and a late `load_data` replacing `data` mid-test can't wipe test state (stage_test treasure flake).
- Enemy room confinement margin is 28px (`enemy.ROOM_MARGIN`): wall tile (16) + lock-blocker intrusion (24) — the old 8px clamp put enemies INSIDE the red blocker. patrol/chase steer inside it; the clamp is the backstop.
- `obj.get("x") or default` is a BOOL op in GDScript (`40 or 0` → `true` → `int(true)` = 1 — the boss paid 1 xp instead of 40). Use `v if v != null else default`.
- Children are ready BEFORE the parent: a child component can't read the parent's `@onready` vars in its own `_ready` — `get_node()` directly (boss_brain reads Health this way).
- The boss bar hides on ANY boss-room unlock, not just on clear — stepping out mid-fight unlocks-without-clearing, and a clear-only hide left the bar stuck on into the next stage (user report).

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
