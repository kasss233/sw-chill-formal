extends Node2D

signal startup_transition_finished

@export var auto_play_on_ready: bool = true
@export var block_input_during_transition: bool = true
@export var shutter_duration: float = 0.28
@export var scanline_duration: float = 0.34
@export var focus_pulse_duration: float = 0.2

var _is_playing: bool = false

var _layer: CanvasLayer
var _root: Control
var _fade: ColorRect
var _shutter_top: ColorRect
var _shutter_bottom: ColorRect
var _scanline: ColorRect
var _focus_frame: Panel


func _ready() -> void:
	_ensure_overlay_nodes()
	_layout_overlay()
	get_viewport().size_changed.connect(_layout_overlay)
	if auto_play_on_ready:
		call_deferred("play_startup_transition")


func play_startup_transition() -> void:
	if _is_playing:
		return
	_is_playing = true

	_ensure_overlay_nodes()
	_layout_overlay()

	_root.visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if block_input_during_transition else Control.MOUSE_FILTER_IGNORE

	var viewport_size := get_viewport().get_visible_rect().size
	var width := viewport_size.x
	var height := viewport_size.y

	_fade.modulate.a = 1.0
	_shutter_top.position = Vector2(0.0, 0.0)
	_shutter_bottom.position = Vector2(0.0, height * 0.5)
	_scanline.position = Vector2(0.0, -8.0)
	_scanline.modulate.a = 0.0
	_focus_frame.scale = Vector2(1.22, 1.22)
	_focus_frame.modulate.a = 0.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	tween.parallel().tween_property(_fade, "modulate:a", 0.12, max(shutter_duration * 0.72, 0.05))
	tween.parallel().tween_property(_shutter_top, "position:y", -height * 0.5, max(shutter_duration, 0.05))
	tween.parallel().tween_property(_shutter_bottom, "position:y", height, max(shutter_duration, 0.05))

	tween.tween_property(_fade, "modulate:a", 0.0, 0.14)
	tween.tween_callback(func() -> void:
		_scanline.modulate.a = 0.55
	)
	tween.parallel().tween_property(_scanline, "position:y", height + 8.0, max(scanline_duration, 0.05))
	tween.parallel().tween_property(_scanline, "modulate:a", 0.0, max(scanline_duration, 0.05))

	tween.tween_callback(func() -> void:
		_focus_frame.scale = Vector2(1.18, 1.18)
		_focus_frame.modulate.a = 0.0
	)
	tween.parallel().tween_property(_focus_frame, "scale", Vector2.ONE, max(focus_pulse_duration * 0.6, 0.05))
	tween.parallel().tween_property(_focus_frame, "modulate:a", 0.85, max(focus_pulse_duration * 0.6, 0.05))
	tween.tween_property(_focus_frame, "modulate:a", 0.0, max(focus_pulse_duration * 0.4, 0.05))

	tween.finished.connect(_on_startup_tween_finished)


func _on_startup_tween_finished() -> void:
	if _root:
		_root.visible = false
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_playing = false
	startup_transition_finished.emit()


func _ensure_overlay_nodes() -> void:
	if _layer:
		return

	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)

	_root = Control.new()
	_root.name = "TransitionOverlay"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_root.add_child(_fade)

	_shutter_top = ColorRect.new()
	_shutter_top.name = "ShutterTop"
	_shutter_top.color = Color(0.02, 0.02, 0.03, 0.95)
	_root.add_child(_shutter_top)

	_shutter_bottom = ColorRect.new()
	_shutter_bottom.name = "ShutterBottom"
	_shutter_bottom.color = Color(0.02, 0.02, 0.03, 0.95)
	_root.add_child(_shutter_bottom)

	_scanline = ColorRect.new()
	_scanline.name = "Scanline"
	_scanline.color = Color(0.84, 0.94, 1.0, 0.0)
	_root.add_child(_scanline)

	_focus_frame = Panel.new()
	_focus_frame.name = "FocusFrame"
	_focus_frame.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_focus_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color = Color(0.85, 0.95, 1.0, 1.0)
	frame_style.corner_radius_top_left = 8
	frame_style.corner_radius_top_right = 8
	frame_style.corner_radius_bottom_right = 8
	frame_style.corner_radius_bottom_left = 8
	_focus_frame.add_theme_stylebox_override("panel", frame_style)
	_root.add_child(_focus_frame)

	_root.visible = false


func _layout_overlay() -> void:
	if _root == null:
		return

	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 0.0
	_root.offset_top = 0.0
	_root.offset_right = 0.0
	_root.offset_bottom = 0.0

	var viewport_size := get_viewport().get_visible_rect().size
	var width := viewport_size.x
	var height := viewport_size.y

	var half_h := height * 0.5
	_shutter_top.size = Vector2(width, half_h)
	_shutter_bottom.size = Vector2(width, half_h)

	_scanline.size = Vector2(width, max(height * 0.035, 4.0))

	var frame_w :float= clamp(width * 0.18, 120.0, 220.0)
	var frame_h :float= frame_w
	_focus_frame.size = Vector2(frame_w, frame_h)
	_focus_frame.position = Vector2((width - frame_w) * 0.5, (height - frame_h) * 0.5)
