extends SceneTree

const Scene = preload("res://games/stone_rubbing/stone_rubbing.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.stage = game.STAGE_INK
	game.paper_placed = true
	game.selected_tool = game.STAGE_INK
	game._update_visuals()

	var target_rect: Rect2 = game.paper_target.get_global_rect()
	game._apply_ink_stamp(target_rect.position + target_rect.size * 0.5)
	assert(game.ink_progress > 0.0)
	assert(game.final_artwork.visible)
	assert(game.final_artwork.material.get_shader_parameter("reveal_mask") != null)
	assert(game.stage == game.STAGE_INK)

	for row in range(9):
		for column in range(13):
			var point := target_rect.position + Vector2(40 + column * 74, 35 + row * 74)
			game._apply_ink_stamp(point)
			if game.stage == game.STAGE_COMPLETE:
				break
		if game.stage == game.STAGE_COMPLETE:
			break
	assert(game.stage == game.STAGE_COMPLETE)
	assert(game.ink_progress >= 0.85)
	quit(0)
