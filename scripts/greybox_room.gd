extends Node2D
## Builds a greybox test room from rectangles in tile units (8 px tiles, 48x27 = 384x216).
## Swap for a TileMapLayer once real tiles exist.

const TILE := 8
const SOLID_COLOR := Color("#7D381B")

## Each Rect2i is (x, y, w, h) in tiles.
@export var blocks: Array[Rect2i] = [
	Rect2i(0, 0, 48, 1),    # ceiling
	Rect2i(0, 0, 1, 27),    # left wall (climb test)
	Rect2i(47, 0, 1, 27),   # right wall
	Rect2i(0, 23, 14, 4),   # floor: start
	Rect2i(18, 23, 14, 4),  # floor: after pit 1 (4-tile dash gap, x 112..144)
	Rect2i(38, 23, 10, 4),  # floor: after pit 2
	Rect2i(5, 17, 4, 1),   # low ledge (coyote/buffer); x 72..112 stays clear as run-up for pit 1
	Rect2i(11, 9, 6, 1),    # high ledge
	Rect2i(23, 12, 1, 6),   # pillar (wall jump / slide)
	Rect2i(26, 5, 6, 1),    # ceiling chunk (corner nudge)
	Rect2i(36, 8, 5, 1),    # L-shape top
	Rect2i(36, 8, 1, 6),    # L-shape wall
	Rect2i(42, 13, 3, 1),   # small ledge
]


func _ready() -> void:
	for r in blocks:
		var rect := Rect2(Vector2(r.position * TILE), Vector2(r.size * TILE))
		var body := StaticBody2D.new()
		body.add_to_group("grecas") # sandbox: every wall is climbable
		body.position = rect.get_center()
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		col.shape = shape
		body.add_child(col)
		var vis := ColorRect.new()
		vis.color = SOLID_COLOR
		vis.size = rect.size
		vis.position = -rect.size / 2.0
		body.add_child(vis)
		add_child(body)
