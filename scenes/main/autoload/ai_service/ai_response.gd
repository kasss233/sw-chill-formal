class_name AIResponse extends RefCounted
## AI 响应数据类
## 统一封装各种类型的 AI 响应（文本、TTS、函数调用等）
##
## 使用示例:
##   var response = AIResponse.new()
##   response.type = AIResponse.ResponseType.TEXT
##   response.text_content = "你好！"
##
## 响应类型说明:
##   - TEXT: 普通文本响应，用于 DialogueBox 显示
##   - TTS: 语音合成响应，包含音频 URL 或二进制数据
##   - FUNCTION_CALL: 函数调用请求，AI 要求执行某个操作
##   - ENVIRONMENT / ACTION: SSE 扩展，环境设置与演出动作
##   - FUNCTION_RESULT: 函数执行结果，用于回传给 AI
##   - ERROR: 错误响应
##   - DONE: 流式传输完成标记

## 响应类型枚举
enum ResponseType {
	TEXT,            ## 文本内容
	TTS,             ## 语音合成
	FUNCTION_CALL,   ## 函数调用请求
	ENVIRONMENT,     ## 环境/场景设置（SSE environment）
	ACTION,          ## 演出动作（SSE action）
	FUNCTION_RESULT, ## 函数调用结果
	ERROR,           ## 错误
	DONE,            ## 完成标记
	LOADING_HINT,    ## SSE loading_hint（vision_understanding / thinking）
}

## 响应类型
var type: ResponseType = ResponseType.TEXT

## ============ 文本相关 ============
## 文本内容（用于 TEXT 类型）
var text_content: String = ""
## 是否为流式传输的增量内容
var is_delta: bool = false

## ============ TTS 相关 ============
## TTS 音频 URL（如果服务端返回 URL）
var tts_url: String = ""
## TTS 音频二进制数据（如果服务端返回 base64 或直接二进制）
var tts_data: PackedByteArray = []
## TTS 音频格式 ("mp3", "wav", "ogg")
var tts_format: String = "mp3"

## ============ 函数调用相关 ============
## 函数调用 ID（用于匹配结果）
var function_call_id: String = ""
## 函数名称
var function_name: String = ""
## 函数参数（JSON 解析后的字典）
var function_args: Dictionary = {}
## environment / action 载荷（SSE 扩展）
var environment_data: Dictionary = {}
var action_data: Dictionary = {}
## 函数执行结果（用于 FUNCTION_RESULT 类型）
var function_result: Variant = null

## ============ 错误相关 ============
## 错误信息
var error_message: String = ""
## 错误代码
var error_code: int = 0

## ============ 元数据 ============
## 原始响应数据（用于调试）
var raw_data: Dictionary = {}
## 时间戳
var timestamp: int = 0

## LOADING_HINT：与后端约定 phase = vision_understanding | thinking
var loading_hint_phase: String = ""


## 供外部脚本判断类型（避免跨文件访问 ResponseType.LOADING_HINT 时 LSP 解析失败）
func is_loading_hint() -> bool:
	return type == ResponseType.LOADING_HINT


## 创建文本响应
static func text(content: String, delta: bool = false) -> AIResponse:
	var r = AIResponse.new()
	r.type = ResponseType.TEXT
	r.text_content = content
	r.is_delta = delta
	r.timestamp = Time.get_unix_time_from_system()
	return r


## 创建 TTS 响应
static func tts(url: String = "", data: PackedByteArray = [], format: String = "mp3") -> AIResponse:
	var r = AIResponse.new()
	r.type = ResponseType.TTS
	r.tts_url = url
	r.tts_data = data
	r.tts_format = format
	r.timestamp = Time.get_unix_time_from_system()
	return r


## 创建函数调用响应
static func function_call(id: String, name: String, args: Dictionary) -> AIResponse:
	var r = AIResponse.new()
	r.type = ResponseType.FUNCTION_CALL
	r.function_call_id = id
	r.function_name = name
	r.function_args = args
	r.timestamp = Time.get_unix_time_from_system()
	return r


## 创建 environment 响应
static func environment_payload(data: Dictionary) -> AIResponse:
	var r = AIResponse.new()
	r.type = ResponseType.ENVIRONMENT
	r.environment_data = data.duplicate(true)
	r.timestamp = Time.get_unix_time_from_system()
	return r


## 创建 action（演出）响应
static func action_payload(data: Dictionary) -> AIResponse:
	var r = AIResponse.new()
	r.type = ResponseType.ACTION
	r.action_data = data.duplicate(true)
	r.timestamp = Time.get_unix_time_from_system()
	return r


## 创建错误响应
static func error(message: String, code: int = 0) -> AIResponse:
	var r = AIResponse.new()
	r.type = ResponseType.ERROR
	r.error_message = message
	r.error_code = code
	r.timestamp = Time.get_unix_time_from_system()
	return r


## 创建完成标记
static func done() -> AIResponse:
	var r = AIResponse.new()
	r.type = ResponseType.DONE
	r.timestamp = Time.get_unix_time_from_system()
	return r


## 创建加载阶段提示（与 chill-backend SSE event loading_hint 对齐）
static func loading_hint(phase: String) -> AIResponse:
	var r = AIResponse.new()
	r.type = ResponseType.LOADING_HINT
	r.loading_hint_phase = phase
	r.timestamp = Time.get_unix_time_from_system()
	return r
