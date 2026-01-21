extends Control

## MaterialFAB 演示脚本
## 展示 FAB 的各种尺寸和样式

func _ready() -> void:
	# 连接所有 FAB 的 pressed 信号
	for child in get_children():
		if child is MaterialFAB:
			child.pressed.connect(_on_fab_pressed.bind(child.name))

func _on_fab_pressed(fab_name: String) -> void:
	print("FAB 被点击: ", fab_name)
