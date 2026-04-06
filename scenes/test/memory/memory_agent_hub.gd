extends Control
class_name MemoryAgentHub

## 图心 Agent 节点：子节点在场景树中可编辑（圆环为 Panel + StyleBoxFlat）。[br]
## 连线锚点仍用 [method get_anchor_in_parent]。

@export_group("脉冲外环")
@export var enable_pulse: bool = true
@export var pulse_speed: float = 2.2
@export_range(0.0, 0.2) var pulse_scale_amplitude: float = 0.077

@onready var _pulse_glow: Panel = $PulseGlow

var _anim_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size.x < 1.0 or size.y < 1.0:
		size = custom_minimum_size
	set_process(enable_pulse)


func _process(delta: float) -> void:
	if not is_instance_valid(_pulse_glow):
		return
	_anim_time += delta
	var pulse := 0.5 + 0.5 * sin(_anim_time * pulse_speed)
	_pulse_glow.pivot_offset = _pulse_glow.size * 0.5
	_pulse_glow.scale = Vector2.ONE * (1.0 + pulse * pulse_scale_amplitude)


func get_anchor_in_parent() -> Vector2:
	return position + size * 0.5
