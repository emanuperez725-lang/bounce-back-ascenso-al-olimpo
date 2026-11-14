extends Cutscene
## Ending (scenes/ending.tscn): Kira brings the apple home, Melina wakes, then the run's
## stats and the credits. A press on the last page goes back to the intro.

@export_multiline var credits := """Fantasy Swamp Forest: @theflavare
Super Pixel Effects Gigapack: Will Tice / unTied Games
2D Platformer Character Template (base de Kira)
BoldPixels: YukiPixels (CC BY-SA 4.0)
Paper UI System: Humble Gift
Dungeon Tile Set  ·  32x32 Isometric Slimes"""

@onready var _kira: Sprite2D = $Kira
@onready var _apple: Sprite2D = $Apple
@onready var _melina: Sprite2D = $Melina
@onready var _stats: Label = $Stats
@onready var _credits: Label = $Credits


func _ready() -> void:
	paper(_stats)
	_stats.modulate.a = 0.0
	_credits.modulate.a = 0.0
	_melina.modulate = STONE
	super._ready()


func _process(_delta: float) -> void:
	_apple.position.y = _kira.position.y - 64.0 + sin(Time.get_ticks_msec() / 400.0) * 3.0
	_apple.position.x = _kira.position.x + 40.0


func _beat(i: int) -> void:
	match i:
		0: # the apple, held high on the summit
			var glow := Fx.play(_apple, "Fantasy Spells/status_sparkling_001/status_sparkling_001_small_yellow", Vector2.ZERO, true)
			glow.scale = Vector2(0.5, 0.5) # the apple sprite is drawn x2
		1: # the run home
			_kira.frame = 1
			var t := create_tween()
			t.tween_property(_kira, "position:x", 300.0, 2.5).from(80.0)
			t.tween_callback(func() -> void: _kira.frame = 0)
		2: # stone cracks from the heart down
			Fx.play(self, "Fantasy Spells/spell_heal_001/spell_heal_001_small_red", _melina.position + Vector2(0, -50))
			create_tween().tween_property(_melina, "modulate", Color.WHITE, 2.0)
		3: # Hermes watches
			Fx.play(self, "Magic Bursts/round_light_burst_001/round_light_burst_001_small_yellow", Vector2(560, 60))


func _finale() -> void:
	var s: Dictionary = get_tree().root.get_meta("stats", {})
	var secs := int(s.get("time", 0.0))
	_stats.text = "Caídas: %d   ·   Levantadas: %d\nParries: %d   ·   Tiempo: %d:%02d\n\nGracias por jugar\nC (A): volver al inicio" % [
		s.get("falls", 0), s.get("falls", 0), s.get("parries", 0), secs / 60, secs % 60]
	_credits.text = credits
	fade(_credits, 1.0)
	await fade(_stats, 1.0)
