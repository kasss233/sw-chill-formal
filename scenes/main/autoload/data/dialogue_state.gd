extends Node
## 对话框状态管理单例
## 发送对话框相关的信号，供 UI 模块监听

# 对话状态信号
signal dialogue_started # 对话开始时发出
signal dialogue_finished # 对话完成时发出
signal dialogue_stopped # 对话被停止时发出
signal button_pressed(button_index: int) # 按钮被点击时发出signal function_executing(func_name: String, call_id: String) # 函数执行时发出
signal function_executing(func_name: String, call_id: String)
signal function_completed(func_name: String, call_id: String, success: bool) # 函数完成时发出
# 对话框显示状态变化信号
signal dialogue_shown # 对话框显示时发出
signal dialogue_hidden # 对话框隐藏时发出


func _ready() -> void:
	pass


## 发出对话开始信号
## @param text: 对话文本内容
func emit_dialogue_started(text: String = "") -> void:
	dialogue_started.emit(text)


## 发出对话完成信号
func emit_dialogue_finished() -> void:
	dialogue_finished.emit()


## 发出对话停止信号
func emit_dialogue_stopped() -> void:
	dialogue_stopped.emit()


## 发出按钮点击信号
## @param button_index: 按钮索引
func emit_button_pressed(button_index: int) -> void:
	button_pressed.emit(button_index)


## 发出函数执行信号
## @param func_name: 函数名称
## @param call_id: 函数调用ID
func emit_function_executing(func_name: String, call_id: String) -> void:
	function_executing.emit(func_name, call_id)


## 发出函数完成信号
## @param func_name: 函数名称
## @param call_id: 函数调用ID
## @param success: 是否成功
func emit_function_completed(func_name: String, call_id: String, success: bool) -> void:
	function_completed.emit(func_name, call_id, success)


## 发出对话框显示信号
func emit_dialogue_shown() -> void:
	dialogue_shown.emit()


## 发出对话框隐藏信号
func emit_dialogue_hidden() -> void:
	dialogue_hidden.emit()
