class_name AgentExecutor extends Node
## Agent 函数执行器
## 负责执行 AI 请求的函数调用（Function Calling / Tool Use）
##
## 功能:
##   1. 注册可被 AI 调用的函数
##   2. 执行 AI 发来的函数调用请求
##   3. 返回执行结果供回传给 AI
##
## 使用流程:
##   1. AI 返回 FUNCTION_CALL 类型响应
##   2. ChatController 调用 execute()
##   3. 执行对应函数并获取结果
##   4. 将结果发送回 AI（可选，用于多轮函数调用）
##
## 注册自定义函数:
##   agent_executor.register("my_function", my_callable, my_definition)
##
## 函数定义格式（OpenAI function calling 格式）:
##   {
##     "name": "add_task",
##     "description": "添加一个新任务",
##     "parameters": {
##       "type": "object",
##       "properties": {
##         "title": { "type": "string", "description": "任务标题" }
##       },
##       "required": ["title"]
##     }
##   }

## 函数执行成功
signal function_executed(call_id: String, name: String, result: Variant)
## 函数执行失败
signal function_failed(call_id: String, name: String, error: String)
## 函数开始执行（用于 UI 反馈）
signal function_started(call_id: String, name: String)

## UI 节点路径
@export var ui_path: NodePath = "/root/Main/UI"

## 是否启用函数执行（安全开关）
@export var enabled: bool = true

## 是否自动注册默认函数
@export var auto_register_defaults: bool = true

## 已注册的函数 { name: { callable: Callable, definition: Dictionary } }
var _functions: Dictionary = {}

## 缓存的 UI 引用
var _ui: Node = null


func _ready() -> void:
	call_deferred("_init_executor")


func _init_executor() -> void:
	_ui = get_node_or_null(ui_path)
	if auto_register_defaults:
		_register_default_functions()


## 注册一个可调用函数
## @param name 函数名（AI 调用时使用）
## @param callable 实际执行的 Callable
## @param definition 函数定义（用于发送给 AI）
func register(name: String, callable: Callable, definition: Dictionary = {}) -> void:
	_functions[name] = {
		"callable": callable,
		"definition": definition
	}


## 注销函数
func unregister(name: String) -> void:
	_functions.erase(name)


## 检查函数是否已注册
func has_function(name: String) -> bool:
	return _functions.has(name)


## 执行函数调用
## @param call_id 调用 ID（用于追踪）
## @param name 函数名
## @param args 参数字典
## @return 执行结果
func execute(call_id: String, name: String, args: Dictionary) -> Dictionary:
	if not enabled:
		var error = "函数执行已禁用"
		function_failed.emit(call_id, name, error)
		return {"success": false, "error": error}

	if not _functions.has(name):
		var error = "未知函数: " + name
		function_failed.emit(call_id, name, error)
		return {"success": false, "error": error}

	function_started.emit(call_id, name)

	# TODO: 实际执行函数
	# var callable = _functions[name]["callable"]
	# var result = callable.call(args)

	var result = {"success": false, "error": "TODO: 实现函数执行"}
	function_failed.emit(call_id, name, result.get("error", ""))
	return result


## 获取所有函数定义（用于发送给 AI）
## @return 函数定义数组
func get_function_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for name in _functions:
		var def = _functions[name].get("definition", {})
		if not def.is_empty():
			definitions.append(def)
	return definitions


## 获取已注册的函数名列表
func get_registered_functions() -> Array[String]:
	var names: Array[String] = []
	for name in _functions:
		names.append(name)
	return names


## 注册默认函数（任务、音乐、便签等）
func _register_default_functions() -> void:
	# ============ 任务相关 ============
	register("add_task", _fn_add_task, {
		"name": "add_task",
		"description": "添加一个新任务到任务列表",
		"parameters": {
			"type": "object",
			"properties": {
				"title": {"type": "string", "description": "任务标题"},
				"due_timestamp": {"type": "integer", "description": "截止时间戳（Unix 时间戳，可选）"}
			},
			"required": ["title"]
		}
	})

	register("complete_task", _fn_complete_task, {
		"name": "complete_task",
		"description": "标记一个任务为已完成",
		"parameters": {
			"type": "object",
			"properties": {
				"task_id": {"type": "integer", "description": "任务 ID"}
			},
			"required": ["task_id"]
		}
	})

	register("get_tasks", _fn_get_tasks, {
		"name": "get_tasks",
		"description": "获取当前所有任务列表",
		"parameters": {"type": "object", "properties": {}}
	})

	# ============ 音乐相关 ============
	register("play_music", _fn_play_music, {
		"name": "play_music",
		"description": "播放音乐",
		"parameters": {
			"type": "object",
			"properties": {
				"track_name": {"type": "string", "description": "音乐名称（可选，不传则继续播放当前曲目）"}
			}
		}
	})

	register("pause_music", _fn_pause_music, {
		"name": "pause_music",
		"description": "暂停音乐播放",
		"parameters": {"type": "object", "properties": {}}
	})

	# ============ 便签相关 ============
	register("take_note", _fn_take_note, {
		"name": "take_note",
		"description": "创建一个便签",
		"parameters": {
			"type": "object",
			"properties": {
				"content": {"type": "string", "description": "便签内容"}
			},
			"required": ["content"]
		}
	})

	# ============ 番茄钟相关 ============
	register("start_pomodoro", _fn_start_pomodoro, {
		"name": "start_pomodoro",
		"description": "启动番茄钟",
		"parameters": {
			"type": "object",
			"properties": {
				"work_minutes": {"type": "integer", "description": "工作时间（分钟），默认 25"},
				"rest_minutes": {"type": "integer", "description": "休息时间（分钟），默认 5"}
			}
		}
	})

	register("stop_pomodoro", _fn_stop_pomodoro, {
		"name": "stop_pomodoro",
		"description": "停止番茄钟",
		"parameters": {"type": "object", "properties": {}}
	})

	# ============ 环境相关 ============
	register("set_weather", _fn_set_weather, {
		"name": "set_weather",
		"description": "设置天气效果",
		"parameters": {
			"type": "object",
			"properties": {
				"weather": {"type": "string", "enum": ["sunny", "rainy", "snowy"], "description": "天气类型"}
			},
			"required": ["weather"]
		}
	})

	register("set_time_of_day", _fn_set_time_of_day, {
		"name": "set_time_of_day",
		"description": "设置时间（白天/黄昏/夜晚）",
		"parameters": {
			"type": "object",
			"properties": {
				"time": {"type": "string", "enum": ["day", "dusk", "night"], "description": "时间段"}
			},
			"required": ["time"]
		}
	})


# ============ 函数实现占位 ============
# TODO: 实现各函数的具体逻辑

func _fn_add_task(_args: Dictionary) -> Dictionary:
	return {"success": false, "error": "TODO"}

func _fn_complete_task(_args: Dictionary) -> Dictionary:
	return {"success": false, "error": "TODO"}

func _fn_get_tasks(_args: Dictionary) -> Dictionary:
	return {"success": false, "error": "TODO"}

func _fn_play_music(_args: Dictionary) -> Dictionary:
	return {"success": false, "error": "TODO"}

func _fn_pause_music(_args: Dictionary) -> Dictionary:
	return {"success": false, "error": "TODO"}

func _fn_take_note(_args: Dictionary) -> Dictionary:
	return {"success": false, "error": "TODO"}

func _fn_start_pomodoro(_args: Dictionary) -> Dictionary:
	return {"success": false, "error": "TODO"}

func _fn_stop_pomodoro(_args: Dictionary) -> Dictionary:
	return {"success": false, "error": "TODO"}

func _fn_set_weather(_args: Dictionary) -> Dictionary:
	return {"success": false, "error": "TODO"}

func _fn_set_time_of_day(_args: Dictionary) -> Dictionary:
	return {"success": false, "error": "TODO"}
