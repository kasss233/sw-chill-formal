class_name ContextCollector extends Node
## 上下文收集器
## 负责从各个模块收集当前状态信息，附加到 AI 请求中
##
## 使用场景:
##   当用户发送消息时，自动收集任务完成情况、音乐状态、番茄钟状态等
##   让 AI 能够感知用户当前的工作状态，提供更智能的响应
##
## 扩展方式:
##   1. 添加新的 _collect_xxx 方法
##   2. 在 collect() 中调用新方法
##   3. 如需自定义收集器，继承此类并重写相关方法
##
## 数据格式示例:
##   {
##     "timestamp": 1234567890,
##     "tasks": { "total": 5, "completed": 2, "pending": 3 },
##     "music": { "current_track": "song.mp3", "is_playing": true },
##     "pomodoro": { "is_running": true, "is_work_mode": true, "remaining": 1500 }
##   }

## 收集完成时发出
signal collection_completed(context: Dictionary)

## UI 节点路径（用于获取各模块引用）
@export var ui_path: NodePath = "/root/Main/UI"

## 是否启用各项收集（可在编辑器中配置）
@export_group("收集开关")
@export var collect_tasks: bool = true
@export var collect_music: bool = true
@export var collect_pomodoro: bool = true
@export var collect_environment: bool = true
@export var collect_notes: bool = false  ## 便签内容可能较大，默认关闭

## 缓存的 UI 引用
var _ui: Node = null


func _ready() -> void:
	# 延迟获取 UI 引用（确保场景树已就绪）
	call_deferred("_cache_ui_reference")


func _cache_ui_reference() -> void:
	_ui = get_node_or_null(ui_path)
	if not _ui:
		push_warning("ContextCollector: 无法获取 UI 节点")


## 收集所有上下文信息
## @return 上下文字典
func collect() -> Dictionary:
	var context: Dictionary = {
		"timestamp": Time.get_unix_time_from_system(),
		"datetime": Time.get_datetime_string_from_system()
	}

	if collect_tasks:
		context["tasks"] = _collect_tasks()

	if collect_music:
		context["music"] = _collect_music()

	if collect_pomodoro:
		context["pomodoro"] = _collect_pomodoro()

	if collect_environment:
		context["environment"] = _collect_environment()

	if collect_notes:
		context["notes"] = _collect_notes()

	collection_completed.emit(context)
	return context


## 收集任务状态
## @return 任务信息字典
func _collect_tasks() -> Dictionary:
	# TODO: 实现任务收集
	# 预期返回: { total, completed, pending, recent_tasks[] }
	return {}


## 收集音乐状态
## @return 音乐信息字典
func _collect_music() -> Dictionary:
	# TODO: 实现音乐状态收集
	# 预期返回: { current_track, is_playing, volume, play_mode }
	return {}


## 收集番茄钟状态
## @return 番茄钟信息字典
func _collect_pomodoro() -> Dictionary:
	# TODO: 实现番茄钟状态收集
	# 预期返回: { is_running, is_paused, is_work_mode, remaining_seconds, current_loop }
	return {}


## 收集环境状态
## @return 环境信息字典
func _collect_environment() -> Dictionary:
	# TODO: 实现环境状态收集
	# 预期返回: { time_mode, weather_mode }
	return {}


## 收集便签内容
## @return 便签信息字典
func _collect_notes() -> Dictionary:
	# TODO: 实现便签收集
	# 预期返回: { count, recent_notes[] }
	return {}


## 获取 UI 引用（供子类使用）
func _get_ui() -> Node:
	if not _ui:
		_ui = get_node_or_null(ui_path)
	return _ui


## 格式化上下文为提示词片段
## 将收集的上下文转换为自然语言描述，可直接插入 system prompt
## @param context 上下文字典
## @return 格式化后的字符串
func format_as_prompt(context: Dictionary) -> String:
	# TODO: 实现上下文格式化
	# 示例输出: "当前用户有 5 个任务，已完成 2 个。正在进行番茄钟工作阶段，剩余 15 分钟。"
	return ""
