extends Node2D
## sprite显示当前viewport
@onready var sprite: Sprite2D = $Sprite2D

const OUTPUT_DIR := "res://assets/ui/3d_item_tex"

@export var auto_save_on_ready: bool = true
@export var output_file_name: String = "purple_planet"
@export var warmup_frames: int = 2


func _ready() -> void:
	if not auto_save_on_ready:
		return
	await _wait_for_render_ready()
	_save_sprite_texture()


func _save_sprite_texture() -> void:
	if sprite == null:
		push_error("保存失败：未找到 Sprite2D 节点")
		return

	if sprite.texture == null:
		push_error("保存失败：Sprite2D 没有 texture")
		return

	var image: Image = await _extract_image_from_texture(sprite.texture)
	if image == null:
		push_error("保存失败：当前 texture 类型不支持导出图片")
		return

	if image.is_empty():
		push_error("保存失败：导出的图片为空")
		return

	var final_output_path := _build_output_path()
	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if dir_err != OK:
		push_error("保存失败：无法创建目录 %s，错误码=%d" % [OUTPUT_DIR, dir_err])
		return

	var err := image.save_png(final_output_path)
	if err != OK:
		push_error("保存失败：%s，错误码=%d" % [final_output_path, err])
		return

	print("Sprite 纹理已保存：%s" % final_output_path)


func _build_output_path() -> String:
	var file_name := output_file_name.strip_edges()
	if file_name.is_empty():
		file_name = "sprite_texture"
	if file_name.to_lower().ends_with(".png"):
		file_name = file_name.substr(0, file_name.length() - 4)
	return "%s/%s.png" % [OUTPUT_DIR, file_name]


func _wait_for_render_ready() -> void:
	var count: int = max(warmup_frames, 1)
	for i in range(count):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw


func _extract_image_from_texture(tex: Texture2D) -> Image:
	if tex is ViewportTexture:
		var vp_tex := tex as ViewportTexture
		if vp_tex.get_viewport_path_in_scene().is_empty():
			return null
		var viewport := get_node_or_null(vp_tex.get_viewport_path_in_scene()) as Viewport
		if viewport == null:
			return null
		if viewport.get_camera_3d() == null:
			push_warning("Viewport 没有激活的 Camera3D，结果可能是黑图")

		var old_update_mode: int = viewport.render_target_update_mode
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var viewport_tex := viewport.get_texture()
		var img := viewport_tex.get_image() if viewport_tex else null
		viewport.render_target_update_mode = old_update_mode
		return img

	if tex is ImageTexture:
		return tex.get_image()

	# 兜底：尝试通用 get_image（部分 Texture2D 子类可用）
	return tex.get_image()
