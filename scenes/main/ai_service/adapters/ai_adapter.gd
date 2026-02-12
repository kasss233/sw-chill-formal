class_name AIAdapter extends RefCounted
## AI 适配器基类
## 将不同的 API 提供商（OpenAI、自定义后端等）统一成相同的接口
##
## 功能:
##   1. 定义统一的请求/响应接口
##   2. 子类实现具体的 API 调用逻辑
##   3. 支持流式和非流式响应
##   4. 处理上下文注入
##
## 实现新适配器:
##   1. 继承 AIAdapter
##   2. 实现 _do_request() 方法
##   3. 实现 _parse_response() 方法
##   4. 在 AIAdapterFactory 中注册
##
## 子类示例:
##   - OpenAIAdapter: 标准 OpenAI API
##   - CustomAPIAdapter: 自定义后端 API（支持 TTS、Function Calling）

## 请求完成（非流式）
signal request_completed(response: AIResponse)
## 流式数据块
signal stream_chunk(response: AIResponse)
## 流式完成
signal stream_completed(full_response: String)
## 请求失败
signal request_failed(error: String)

## 适配器名称（用于识别）
var adapter_name: String = "base"

## 是否支持流式传输
var supports_streaming: bool = true

## 是否支持 TTS
var supports_tts: bool = false

## 是否支持 Function Calling
var supports_function_calling: bool = false


## 发送消息（由子类实现）
## @param messages 消息数组
## @param context 上下文字典（来自 ContextCollector）
## @param stream 是否使用流式传输
func send_request(
	_messages: Array,
	_context: Dictionary = {},
	_stream: bool = true
) -> void:
	push_error("AIAdapter.send_request() 必须由子类实现")


## 取消请求
func cancel_request() -> void:
	push_error("AIAdapter.cancel_request() 必须由子类实现")


## 构建系统提示词（包含上下文）
## @param base_prompt 基础系统提示词
## @param context 上下文字典
## @return 完整的系统提示词
func build_system_prompt(base_prompt: String, context: Dictionary) -> String:
	if context.is_empty():
		return base_prompt

	var context_section = _format_context(context)
	if context_section.is_empty():
		return base_prompt

	return base_prompt + "\n\n" + context_section


## 格式化上下文为提示词片段
## @param context 上下文字典
## @return 格式化后的字符串
func _format_context(context: Dictionary) -> String:
	var parts: Array[String] = []

	if context.has("datetime"):
		parts.append("当前时间: " + str(context["datetime"]))

	if context.has("tasks") and not context["tasks"].is_empty():
		var tasks = context["tasks"]
		if tasks.has("total"):
			parts.append("任务状态: 共 %d 个任务，已完成 %d 个" % [
				tasks.get("total", 0),
				tasks.get("completed", 0)
			])

	if context.has("pomodoro") and not context["pomodoro"].is_empty():
		var pomo = context["pomodoro"]
		if pomo.get("is_running", false):
			var mode = "工作" if pomo.get("is_work_mode", true) else "休息"
			var remaining = pomo.get("remaining_seconds", 0)
			parts.append("番茄钟: %s阶段，剩余 %d 分钟" % [mode, remaining / 60])

	if context.has("music") and not context["music"].is_empty():
		var music = context["music"]
		if music.get("is_playing", false):
			parts.append("正在播放: " + music.get("current_track", "未知"))

	if parts.is_empty():
		return ""

	return "[当前状态]\n" + "\n".join(parts)
