class_name Cutscene
extends Node2D
## Story cards over a little stage of sprites (scenes/intro.tscn, scenes/ending.tscn).
## Edit `cards` in the Inspector. Each card fades in, plays its beat (_beat in the
## subclass animates the sprites), waits, fades out. Jump / dash / parry skips a card;
## on the last page it loads `next_scene`.

const PAPER := preload("res://assets/third_party/paper_ui/holders/5.png")
const COL_INK := Color("#2b2233")
const STONE := Color(0.45, 0.45, 0.5) ## Melina petrified

@export_multiline var cards: Array[String] = []
@export_file("*.tscn") var next_scene := "res://scenes/game.tscn"
@export var card_time := 4.5

var done := false # last page up: a press loads next_scene
var _skip := false

@onready var _card: Label = $Card


func _ready() -> void:
	paper(_card)
	_card.modulate.a = 0.0
	_play()


func _play() -> void:
	for i in cards.size():
		_card.text = cards[i]
		_beat(i)
		await fade(_card, 1.0)
		await wait(card_time)
		await fade(_card, 0.0)
	await _finale()
	done = true


## Override: animate the stage for card `i` (don't await long tweens here).
func _beat(_i: int) -> void:
	pass


## Override: the last page, shown until a press.
func _finale() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("jump") or event.is_action_pressed("dash") or event.is_action_pressed("parry")):
		return
	if done:
		get_tree().change_scene_to_file(next_scene)
	else:
		_skip = true


## Wait `seconds`, or less if a button skips the card (a press during a fade counts too).
func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _skip:
		await get_tree().process_frame
		left -= get_process_delta_time()
	_skip = false


func fade(node: CanvasItem, to: float, time := 0.8) -> void:
	await create_tween().tween_property(node, "modulate:a", to, time).finished


## Paper UI box with dark ink.
static func paper(label: Label) -> void:
	var box := StyleBoxTexture.new()
	box.texture = PAPER
	box.set_texture_margin_all(8)
	box.set_content_margin_all(12)
	label.add_theme_stylebox_override("normal", box)
	label.add_theme_color_override("font_color", COL_INK)
