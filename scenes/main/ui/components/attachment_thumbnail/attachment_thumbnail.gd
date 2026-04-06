@tool
extends Control
class_name AttachmentThumbnail

signal deleted()

@export var image_path: String = "":
	set(value):
		image_path = value
		if is_node_ready():
			_load_thumbnail()

@export var thumbnail_size: Vector2 = Vector2(64, 64)

@onready var texture_rect: TextureRect = %TextureRect
@onready var delete_button: Button = %DeleteButton


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	delete_button.pressed.connect(_on_delete_pressed)
	delete_button.modulate.a = 0.3
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_load_thumbnail()


func _load_thumbnail() -> void:
	print("[AttachmentThumbnail] _load_thumbnail called")

	if image_path.is_empty():
		print("[AttachmentThumbnail] image_path is empty")
		return

	var normalized_path := image_path.replace("\\", "/")
	print("[AttachmentThumbnail] Normalized path: ", normalized_path)

	if not is_instance_valid(texture_rect):
		print("[AttachmentThumbnail] ERROR: texture_rect is not valid!")
		return

	print("[AttachmentThumbnail] Loading image: ", normalized_path)

	await get_tree().process_frame

	var file := FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		var open_error := FileAccess.get_open_error()
		push_error("[AttachmentThumbnail] Cannot open file (error %d): %s" % [open_error, normalized_path])
		return

	var buffer := file.get_buffer(file.get_length())
	file.close()

	print("[AttachmentThumbnail] File read, size: ", buffer.size(), " bytes")

	var image := Image.new()
	var err := _decode_image(buffer, normalized_path, image)
	if err != OK:
		push_error("[AttachmentThumbnail] Image decode failed: %s (error %d)" % [normalized_path, err])
		return

	if image.is_empty():
		push_error("[AttachmentThumbnail] Image is empty after loading")
		return

	print("[AttachmentThumbnail] Image loaded: ", image.get_width(), "x", image.get_height())

	var aspect := float(image.get_width()) / float(image.get_height())
	var new_width: int
	var new_height: int

	if aspect > 1.0:
		new_width = int(thumbnail_size.x)
		new_height = int(thumbnail_size.x / aspect)
	else:
		new_width = int(thumbnail_size.y * aspect)
		new_height = int(thumbnail_size.y)

	print("[AttachmentThumbnail] Resizing to: ", new_width, "x", new_height)
	image.resize(new_width, new_height)

	print("[AttachmentThumbnail] Creating texture...")
	var texture := ImageTexture.create_from_image(image)

	print("[AttachmentThumbnail] Setting texture to TextureRect...")
	texture_rect.texture = texture
	print("[AttachmentThumbnail] Texture set successfully")


func _decode_image(buffer: PackedByteArray, normalized_path: String, image: Image) -> Error:
	var ext := normalized_path.get_extension().to_lower()
	var decode_order := _build_decode_order(buffer, ext)

	for format_name in decode_order:
		print("[AttachmentThumbnail] Decoding as ", format_name, "...")
		var err := _try_decode(buffer, image, format_name)
		print("[AttachmentThumbnail] ", format_name.to_upper(), " decode result: ", err)
		if err == OK:
			return OK

	return ERR_PARSE_ERROR


func _build_decode_order(buffer: PackedByteArray, ext: String) -> Array[String]:
	var ordered_formats: Array[String] = []
	var detected_format := _detect_format_from_magic(buffer)

	if not detected_format.is_empty():
		ordered_formats.append(detected_format)

	if ext in ["png", "jpg", "jpeg", "webp", "bmp"] and not ordered_formats.has(ext):
		ordered_formats.append(ext)

	for format_name in ["png", "jpg", "jpeg", "webp", "bmp"]:
		if not ordered_formats.has(format_name):
			ordered_formats.append(format_name)

	return ordered_formats


func _detect_format_from_magic(buffer: PackedByteArray) -> String:
	if buffer.size() >= 8 \
	and buffer[0] == 0x89 and buffer[1] == 0x50 and buffer[2] == 0x4E and buffer[3] == 0x47 \
	and buffer[4] == 0x0D and buffer[5] == 0x0A and buffer[6] == 0x1A and buffer[7] == 0x0A:
		return "png"

	if buffer.size() >= 3 \
	and buffer[0] == 0xFF and buffer[1] == 0xD8 and buffer[2] == 0xFF:
		return "jpg"

	if buffer.size() >= 12 \
	and buffer[0] == 0x52 and buffer[1] == 0x49 and buffer[2] == 0x46 and buffer[3] == 0x46 \
	and buffer[8] == 0x57 and buffer[9] == 0x45 and buffer[10] == 0x42 and buffer[11] == 0x50:
		return "webp"

	if buffer.size() >= 2 and buffer[0] == 0x42 and buffer[1] == 0x4D:
		return "bmp"

	return ""


func _try_decode(buffer: PackedByteArray, image: Image, format_name: String) -> Error:
	match format_name:
		"png":
			return image.load_png_from_buffer(buffer)
		"jpg", "jpeg":
			return image.load_jpg_from_buffer(buffer)
		"webp":
			return image.load_webp_from_buffer(buffer)
		"bmp":
			return image.load_bmp_from_buffer(buffer)
		_:
			return ERR_UNAVAILABLE


func _on_mouse_entered() -> void:
	var tween = create_tween()
	tween.tween_property(delete_button, "modulate:a", 1.0, 0.15)


func _on_mouse_exited() -> void:
	var tween = create_tween()
	tween.tween_property(delete_button, "modulate:a", 0.3, 0.15)


func _on_delete_pressed() -> void:
	deleted.emit()
