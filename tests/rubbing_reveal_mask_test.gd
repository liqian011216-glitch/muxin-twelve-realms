extends SceneTree

const RevealMask = preload("res://scripts/rubbing_reveal_mask.gd")


func _init() -> void:
	var reveal = RevealMask.new(256, 176, 1208)
	assert(is_equal_approx(reveal.get_coverage(), 0.0))

	var coverage := reveal.stamp(Vector2(484, 336), Vector2(968, 672))
	assert(coverage > 0.0)
	assert(not reveal.is_complete())
	assert(reveal.get_image().get_pixel(128, 88).r > 0.1)
	assert(reveal.get_image().get_pixel(0, 0).r == 0.0)

	var changed := 0
	var transparent_inside_bounds := 0
	for y in range(50, 127):
		for x in range(75, 182):
			if reveal.get_image().get_pixel(x, y).r > 0.1:
				changed += 1
			else:
				transparent_inside_bounds += 1
	assert(changed > 0)
	assert(transparent_inside_bounds > 0, "stamp must not fill a rectangle")

	var outside_coverage := reveal.stamp(Vector2(-20, 30), Vector2(968, 672))
	assert(is_equal_approx(outside_coverage, coverage))

	for row in range(9):
		for column in range(13):
			reveal.stamp(Vector2(40 + column * 74, 35 + row * 74), Vector2(968, 672))
	assert(reveal.get_coverage() >= 0.85)
	assert(reveal.is_complete())

	reveal.reset()
	assert(is_equal_approx(reveal.get_coverage(), 0.0))
	assert(reveal.get_image().get_pixel(128, 88).r == 0.0)
	quit(0)
