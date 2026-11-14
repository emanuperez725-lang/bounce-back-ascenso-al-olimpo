class_name Fx
## One-shot (or looping) effect from Super Pixel Effects Gigapack (Will Tice / unTied Games).
## `name` is the folder under PNG/ holding frame0000.png, frame0001.png, ...

const ROOT := "res://Super Pixel Effects Gigapack (Free Version) v3.2.0/Super Pixel Effects Gigapack (Free Version)/PNG/"
static var _cache := {}


static func play(parent: Node, name: String, pos: Vector2, loop := false) -> AnimatedSprite2D:
	if not _cache.has(name):
		var frames := SpriteFrames.new()
		var i := 0
		while ResourceLoader.exists(ROOT + name + "/frame%04d.png" % i):
			frames.add_frame("default", load(ROOT + name + "/frame%04d.png" % i))
			i += 1
		frames.set_animation_speed("default", 24.0)
		_cache[name] = frames
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = _cache[name]
	fx.sprite_frames.set_animation_loop("default", loop)
	fx.position = pos
	fx.z_index = 6
	if not loop:
		fx.animation_finished.connect(fx.queue_free)
	parent.add_child(fx)
	fx.play()
	return fx
