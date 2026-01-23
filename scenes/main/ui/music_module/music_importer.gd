class_name MusicImporter
extends RefCounted

## 音乐导入器
## 负责处理音乐文件的导入

# --- 信号 ---
signal music_imported(music_name: String, file_path: String)
signal import_cancelled

# --- 成员变量 ---
var _file_dialog: FileDialog
var _parent_node: Node
var _audio_res: AudioRes

## 初始化
func initialize(parent_node: Node, audio_res: AudioRes) -> void:
	_parent_node = parent_node
	_audio_res = audio_res
	_setup_file_dialog()

## 设置文件对话框
func _setup_file_dialog() -> void:
	if not _parent_node:
		push_error("[MusicImporter] Parent node not set")
		return

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_file_dialog.display_mode = FileDialog.DISPLAY_LIST
	# 支持 OGG, WAV 和 MP3 格式
	_file_dialog.filters = ["*.ogg ; OGG Vorbis Audio", "*.wav ; WAV Audio", "*.mp3 ; MP3 Audio"]
	_file_dialog.use_native_dialog = true
	_file_dialog.files_selected.connect(_on_files_selected)
	_file_dialog.canceled.connect(_on_import_cancelled)
	_parent_node.add_child(_file_dialog)
	print("[MusicImporter] File dialog initialized")

## 打开导入对话框
func open_import_dialog() -> void:
	if _file_dialog:
		_file_dialog.popup_centered()
		print("[MusicImporter] Import dialog opened")
	else:
		push_error("[MusicImporter] File dialog not initialized")

## 当文件被选中时
func _on_files_selected(files: PackedStringArray) -> void:
	if not _audio_res:
		push_error("[MusicImporter] Audio resource not set")
		return

	for file_path in files:
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var music_name = file.get_path().get_file().get_basename()
			_audio_res.add_bgm(music_name, file_path)
			music_imported.emit(music_name, file_path)
			print("[MusicImporter] Imported music: %s from %s" % [music_name, file_path])
		else:
			push_error("[MusicImporter] Failed to open file: %s" % file_path)

## 当导入被取消时
func _on_import_cancelled() -> void:
	import_cancelled.emit()
	print("[MusicImporter] Import cancelled")

## 清理资源
func cleanup() -> void:
	if _file_dialog and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()
		_file_dialog = null
	print("[MusicImporter] Cleaned up")
