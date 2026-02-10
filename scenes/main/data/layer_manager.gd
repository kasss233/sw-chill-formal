extends Node

## 层级管理器 Autoload 单例
## 统一管理所有 CanvasLayer 的层级，避免模块依赖 UI 协调器

const BASE_LAYER: int = 10
const COMPACT_THRESHOLD: int = 100

## 所有已注册的 CanvasLayer（弱引用数组）
var _registered_layers: Array[CanvasLayer] = []


## 注册一个 CanvasLayer，退出场景树时自动注销
func register(cl: CanvasLayer) -> void:
	if cl in _registered_layers:
		return
	_registered_layers.append(cl)
	cl.tree_exiting.connect(_unregister.bind(cl))


## 将指定 CanvasLayer 置顶（设为当前最大值 + 1）
func bring_to_front(cl: CanvasLayer) -> void:
	if cl not in _registered_layers:
		register(cl)

	var max_layer: int = BASE_LAYER
	for registered_cl in _registered_layers:
		if is_instance_valid(registered_cl) and registered_cl.layer > max_layer:
			max_layer = registered_cl.layer

	if cl.layer <= max_layer:
		cl.layer = max_layer + 1

	if cl.layer > COMPACT_THRESHOLD:
		_compact()


## 注销 CanvasLayer
func _unregister(cl: CanvasLayer) -> void:
	_registered_layers.erase(cl)


## 压缩层级：按当前相对顺序从 BASE_LAYER 开始重新分配连续值
func _compact() -> void:
	# 清理无效引用
	_registered_layers = _registered_layers.filter(func(cl): return is_instance_valid(cl))

	# 按当前 layer 值排序
	_registered_layers.sort_custom(func(a, b): return a.layer < b.layer)

	# 从 BASE_LAYER 开始重新分配
	for i in range(_registered_layers.size()):
		_registered_layers[i].layer = BASE_LAYER + i
