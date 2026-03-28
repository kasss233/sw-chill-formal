extends Control

@onready var mic_option_button: OptionButton = $CenterContainer/VBoxContainer/MicRow/MicOptionButton
@onready var output_option_button: OptionButton = $CenterContainer/VBoxContainer/OutputRow/OutputOptionButton
@onready var record_button: Button = $CenterContainer/VBoxContainer/RecordButton
@onready var open_folder_button: Button = $CenterContainer/VBoxContainer/OpenFolderButton
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel

var _record_effect: AudioEffectRecord
var _mic_player: AudioStreamPlayer
var _preview_player: AudioStreamPlayer
var _is_recording := false


func _ready() -> void:
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		status_label.text = "未开启音频输入，请在项目设置启用后重启"
		record_button.disabled = true
		mic_option_button.disabled = true
		return

	_setup_record_bus()
	_setup_microphone_player()
	_setup_preview_player()
	_setup_output_selector()
	_setup_mic_selector()
	status_label.text = "按住按钮开始录音"
	_check_headset_route_warning()


func _setup_output_selector() -> void:
	output_option_button.clear()
	var devices: PackedStringArray = AudioServer.get_output_device_list()

	if devices.is_empty():
		output_option_button.add_item("未检测到输出设备")
		output_option_button.disabled = true
		return

	output_option_button.disabled = false
	var current_device := AudioServer.get_output_device()
	var selected_idx := 0

	for i in devices.size():
		var device_name := devices[i]
		output_option_button.add_item(device_name)
		if device_name == current_device:
			selected_idx = i

	output_option_button.select(selected_idx)
	_set_output_device(devices[selected_idx])


func _set_output_device(device_name: String) -> void:
	AudioServer.set_output_device(device_name)
	_check_headset_route_warning()


func _setup_mic_selector() -> void:
	mic_option_button.clear()
	var devices: PackedStringArray = AudioServer.get_input_device_list()

	if devices.is_empty():
		mic_option_button.add_item("未检测到麦克风")
		mic_option_button.disabled = true
		status_label.text = "未检测到可用麦克风"
		return

	mic_option_button.disabled = false
	var current_device := AudioServer.get_input_device()
	var selected_idx := 0

	for i in devices.size():
		var device_name := devices[i]
		mic_option_button.add_item(device_name)
		if device_name == current_device:
			selected_idx = i

	mic_option_button.select(selected_idx)
	_set_input_device(devices[selected_idx])


func _set_input_device(device_name: String) -> void:
	AudioServer.set_input_device(device_name)
	status_label.text = "当前麦克风: %s" % device_name


func _setup_record_bus() -> void:
	var bus_name := "Record"
	var bus_idx := AudioServer.get_bus_index(bus_name)

	if bus_idx == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_idx, bus_name)

	if AudioServer.get_bus_effect_count(bus_idx) == 0:
		AudioServer.add_bus_effect(bus_idx, AudioEffectRecord.new(), 0)
	elif not (AudioServer.get_bus_effect(bus_idx, 0) is AudioEffectRecord):
		AudioServer.remove_bus_effect(bus_idx, 0)
		AudioServer.add_bus_effect(bus_idx, AudioEffectRecord.new(), 0)

	_record_effect = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectRecord
	# 使用 16-bit PCM，避免部分播放器对压缩 WAV 兼容性差导致“有文件但无声”。
	_record_effect.format = AudioStreamWAV.FORMAT_16_BITS


func _setup_microphone_player() -> void:
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = "Record"
	add_child(_mic_player)


func _setup_preview_player() -> void:
	_preview_player = AudioStreamPlayer.new()
	_preview_player.bus = "Master"
	add_child(_preview_player)


func _on_record_button_down() -> void:
	if _record_effect == null:
		status_label.text = "录音器初始化失败"
		return

	if _preview_player != null and _preview_player.playing:
		_preview_player.stop()

	_record_effect.set_recording_active(true)
	_mic_player.play()
	_is_recording = true
	record_button.text = "松开结束录音"
	status_label.text = "录音中..."
	_check_headset_route_warning()


func _on_record_button_up() -> void:
	if not _is_recording:
		return

	_mic_player.stop()
	_record_effect.set_recording_active(false)
	_is_recording = false
	record_button.text = "按住开始录音"

	var wav_stream := _record_effect.get_recording() as AudioStreamWAV
	if wav_stream == null:
		status_label.text = "未捕获到音频数据"
		return
	if wav_stream.data.is_empty():
		status_label.text = "录音数据为空，请检查麦克风权限/设备"
		return

	var save_dir := "user://recordings"
	DirAccess.make_dir_recursive_absolute(save_dir)

	var file_name := "stt_%s.wav" % Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var save_path := save_dir.path_join(file_name)
	var err := wav_stream.save_to_wav(save_path)

	if err == OK:
		var abs_path := ProjectSettings.globalize_path(save_path)
		status_label.text = "录音已保存: %s" % abs_path
		_preview_player.stream = wav_stream
		_preview_player.play()
	else:
		status_label.text = "保存失败，错误码: %d" % err


func _on_mic_option_button_item_selected(index: int) -> void:
	var device_name := mic_option_button.get_item_text(index)
	_set_input_device(device_name)


func _on_output_option_button_item_selected(index: int) -> void:
	var device_name := output_option_button.get_item_text(index)
	_set_output_device(device_name)


func _check_headset_route_warning() -> void:
	var input_name := AudioServer.get_input_device().to_lower()
	var output_name := AudioServer.get_output_device().to_lower()

	var input_headset := input_name.find("headset") != -1 or input_name.find("hands-free") != -1 or input_name.find("ag audio") != -1
	var output_headphones := output_name.find("headphones") != -1 and output_name.find("hands-free") == -1

	if input_headset and output_headphones:
		status_label.text = "检测到耳机麦+立体声耳机输出，蓝牙设备可能静音。请改为Hands-Free输出或改用电脑扬声器。"


func _on_open_folder_button_pressed() -> void:
	var save_dir := "user://recordings"
	DirAccess.make_dir_recursive_absolute(save_dir)
	var abs_dir := ProjectSettings.globalize_path(save_dir)
	var ok := OS.shell_open(abs_dir)
	if ok != OK:
		status_label.text = "打开目录失败: %s" % abs_dir
	else:
		status_label.text = "已打开录音目录: %s" % abs_dir


func _exit_tree() -> void:
	if _is_recording and _record_effect != null:
		_record_effect.set_recording_active(false)
	if _mic_player != null and _mic_player.playing:
		_mic_player.stop()
	if _preview_player != null and _preview_player.playing:
		_preview_player.stop()
