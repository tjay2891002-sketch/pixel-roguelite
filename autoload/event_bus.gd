extends Node
## EventBus — cross-cutting signals for many-listener, gameplay-optional events.
##
## Rule (per docs/ARCHITECTURE.md §6): juice, audio, UI, and achievements listen
## here. Must-not-fail 1:1 interactions (state machine -> body, hitbox -> health,
## generator -> chunks) use direct calls, never the bus.

## Emitted by Health after a hit lands (post i-frame check). Juice/audio/UI listen.
signal hit_landed(hit_info: Dictionary)

## Emitted when any enemy dies. Listeners: drops, room-clear tracking, audio.
signal enemy_killed(enemy: Node2D)

## Emitted when a combat room's last enemy dies. Unlocks that room's doors.
signal room_cleared(room: Node2D)

## Emitted when the player's Health reaches zero. RunManager listens.
signal player_died

## Emitted when currency is dropped/collected. The meta-progression seam —
## SaveStub accumulates; nothing else builds on this yet.
signal currency_dropped(amount: int, world_position: Vector2)

## Emitted by RunManager when the player levels up. Player (stats), stage
## (SFX/HUD) listen.
signal leveled_up(level: int)
