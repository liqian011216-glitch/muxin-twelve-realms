class_name RubbingRevealMask
extends RefCounted

const COMPLETION_THRESHOLD := 0.85
const VISIBLE_THRESHOLD := 0.18
const LOBE_COUNT := 4
const DEFAULT_SEED := 1208

var _image: Image
var _texture: ImageTexture
var _rng := RandomNumberGenerator.new()
var _coverage := 0.0
var _seed := DEFAULT_SEED
var _stamp_index := 0


func _init(width := 256, height := 176, seed := DEFAULT_SEED) -> void:
	_seed = seed
	_image = Image.create(width, height, false, Image.FORMAT_RF)
	_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_texture = ImageTexture.create_from_image(_image)
	_rng.seed = _seed


func reset() -> void:
	_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_texture.update(_image)
	_rng.seed = _seed
	_stamp_index = 0
	_coverage = 0.0


func stamp(local_point: Vector2, target_size: Vector2) -> float:
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		return _coverage
	if local_point.x < 0.0 or local_point.y < 0.0 or local_point.x > target_size.x or local_point.y > target_size.y:
		return _coverage

	var mask_size := Vector2(_image.get_width(), _image.get_height())
	var center := local_point / target_size * mask_size
	for lobe in range(LOBE_COUNT):
		_stamp_lobe(center, lobe, mask_size)
	_stamp_index += 1
	_texture.update(_image)
	_recalculate_coverage()
	return _coverage


func get_coverage() -> float:
	return _coverage


func is_complete() -> bool:
	return _coverage >= COMPLETION_THRESHOLD


func get_texture() -> ImageTexture:
	return _texture


func get_image() -> Image:
	return _image


func _stamp_lobe(center: Vector2, lobe: int, mask_size: Vector2) -> void:
	var lobe_center := center
	if lobe > 0:
		var offset_angle := _rng.randf_range(0.0, TAU)
		var offset_distance := _rng.randf_range(3.0, 8.0)
		lobe_center += Vector2.from_angle(offset_angle) * offset_distance

	var radius_x := _rng.randf_range(30.0, 42.0) if lobe == 0 else _rng.randf_range(18.0, 31.0)
	var radius_y := _rng.randf_range(22.0, 34.0) if lobe == 0 else _rng.randf_range(15.0, 27.0)
	var rotation := _rng.randf_range(-0.45, 0.45)
	var cosine := cos(rotation)
	var sine := sin(rotation)
	var min_x := maxi(0, int(floor(lobe_center.x - radius_x - 1.0)))
	var max_x := mini(int(mask_size.x) - 1, int(ceil(lobe_center.x + radius_x + 1.0)))
	var min_y := maxi(0, int(floor(lobe_center.y - radius_y - 1.0)))
	var max_y := mini(int(mask_size.y) - 1, int(ceil(lobe_center.y + radius_y + 1.0)))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var delta := Vector2(x, y) - lobe_center
			var rotated_x := delta.x * cosine + delta.y * sine
			var rotated_y := -delta.x * sine + delta.y * cosine
			var distance := sqrt(pow(rotated_x / radius_x, 2.0) + pow(rotated_y / radius_y, 2.0))
			if distance >= 1.0:
				continue
			var fade := clampf((1.0 - distance) / 0.45, 0.0, 1.0)
			fade = fade * fade * (3.0 - 2.0 * fade)
			var grain := _grain(x, y, lobe)
			var ink := fade * grain
			var previous := _image.get_pixel(x, y).r
			if ink > previous:
				_image.set_pixel(x, y, Color(ink, 0.0, 0.0, 1.0))


func _grain(x: int, y: int, lobe: int) -> float:
	var value: float = sin(float(x * 127 + y * 311 + lobe * 67 + _stamp_index * 173)) * 43758.5453
	var normalized: float = value - floor(value)
	return lerpf(0.86, 1.0, normalized)


func _recalculate_coverage() -> void:
	var visible_pixels := 0
	var total_pixels := _image.get_width() * _image.get_height()
	for y in range(_image.get_height()):
		for x in range(_image.get_width()):
			if _image.get_pixel(x, y).r >= VISIBLE_THRESHOLD:
				visible_pixels += 1
	_coverage = float(visible_pixels) / float(total_pixels)
