extends Resource
class_name AudioRes 
@export var BGM:Array[AudioItem]
@export var sound_effect:Array[AudioItem]
signal bgm_added(_name:String)
func add_bgm(name: String, path: String) -> void:
	if get_bgm_item_by_name(name) != null:
		push_warning("AudioRes.add_bgm: BGM %s already exists!" % name)
		return

	# 加载外部音频文件
	var stream: AudioStream = null
	var file_ext = path.get_extension().to_lower()

	match file_ext:
		"ogg":
			# 加载 OGG 文件
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var bytes = file.get_buffer(file.get_length())
				file.close()

				var ogg_stream = AudioStreamOggVorbis.new()
				ogg_stream.packet_sequence = OggPacketSequence.new()
				ogg_stream.packet_sequence.packet_data = bytes
				stream = ogg_stream
			else:
				push_error("AudioRes.add_bgm: Failed to open file: %s" % path)
				return

		"wav":
			# 加载 WAV 文件
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var bytes = file.get_buffer(file.get_length())
				file.close()

				var wav_stream = AudioStreamWAV.new()
				wav_stream.data = bytes
				# 注意：这里可能需要设置 format, mix_rate, stereo 等属性
				# 但 Godot 4.x 的 AudioStreamWAV 应该能自动解析 WAV 文件头
				stream = wav_stream
			else:
				push_error("AudioRes.add_bgm: Failed to open file: %s" % path)
				return

		"mp3":
			# 加载 MP3 文件
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var bytes = file.get_buffer(file.get_length())
				file.close()

				var mp3_stream = AudioStreamMP3.new()
				mp3_stream.data = bytes
				stream = mp3_stream
				print("AudioRes.add_bgm: Loaded MP3 file: %s" % path)
			else:
				push_error("AudioRes.add_bgm: Failed to open file: %s" % path)
				return

		_:
			push_error("AudioRes.add_bgm: Unsupported audio format: %s" % file_ext)
			return

	if stream:
		var item = AudioItem.new()
		item.name = name
		item.stream = stream
		BGM.append(item)
		bgm_added.emit(name)
		print("AudioRes.add_bgm: Successfully added BGM: %s" % name)
	else:
		push_error("AudioRes.add_bgm: Failed to load audio stream from: %s" % path)
func remove_bgm(name:String)->void:
	var item=get_bgm_item_by_name(name)
	if item==null:
		push_warning("AudioRes.remove_bgm: BGM %s not found!" % name)
		return
	BGM.erase(item)

func get_bgm_item_by_name(name:String)->AudioItem:
	for item in BGM:    
		if item.name==name:
			return item
	return null
