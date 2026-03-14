extends Control

signal select_requested(item_id: int)
signal deselect_requested(item_id: int)

@onready var texture_rect: TextureRect = %TextureRect
@onready var item_info_label: Label = $InnerPanel/VBoxContainer/ItemInfoLabel
@onready var lock_state_label: Label = $InnerPanel/VBoxContainer/LockStateLabel
@onready var toggle_button: MaterialToggleButton = $InnerPanel/VBoxContainer/MaterialToggleButton
@onready var toggle_button_2: MaterialToggleButton = $InnerPanel/MaterialToggleButton2

var _item_id: int = -1
var _unlocked: bool = false
var _syncing: bool = false


func _ready() -> void:
	pass
	#if toggle_button and not toggle_button.pressed.is_connected(_on_toggle_button_pressed):
		#toggle_button.pressed.connect(_on_toggle_button_pressed)


func set_data(data: Dictionary) -> void:
	_item_id = int(data.get("id", -1))
	_unlocked = bool(data.get("unlocked", false))

	item_info_label.text = str(data.get("name", "未命名物品"))
	var required_level := int(data.get("required_level", 1))
	if _unlocked:
		lock_state_label.text = "已解锁"
	else:
		lock_state_label.text = "等级%d时解锁" % required_level

	var target_state := 0 if bool(data.get("selected", false)) else 1
	_syncing = true
	toggle_button.disabled = not _unlocked
	toggle_button.current_state = target_state
	toggle_button_2.disabled = not _unlocked
	toggle_button_2.current_state = target_state
	_syncing = false

	var icon_path := str(data.get("icon_path", "")).strip_edges()
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return
	var tex := load(icon_path) as Texture2D
	print("加载纹理：%s，结果：%s" % [icon_path, tex])
	if tex:
		texture_rect.texture = tex


func update_display(data: Dictionary) -> void:
	set_data(data)


func is_unlocked() -> bool:
	return _unlocked


#func _on_toggle_button_pressed() -> void:
	#if not _unlocked or _item_id <= 0:
		#return
	#select_requested.emit(_item_id)


func _on_material_toggle_button_2_state_changed(old_state: int, new_state: int) -> void:
	if _syncing:
		return
	match new_state:
		0:
			toggle_button.set_state(0)
			select_requested.emit(_item_id)
		1:
			toggle_button.set_state(1)
			deselect_requested.emit(_item_id)
