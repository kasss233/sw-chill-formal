extends Node2D

@onready var sprite = $Sprite2D
var status_label: Label

var camera_feed: CameraFeed

func _ready():
	# 初始化提示标签
	status_label = Label.new()
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(status_label)
	
	print("--- 正在检测摄像头 ---")
	_check_feeds()
	
	# 如果初次检测失败，1秒后再次尝试（防止硬件初始化延迟）
	get_tree().create_timer(1.0).timeout.connect(_check_feeds)
	
	# 监听摄像头状态变化
	CameraServer.camera_feed_added.connect(func(id):
		print("检测到新摄像头 ID: ", id)
		if camera_feed == null:
			_start_camera(CameraServer.get_feed(id))
	)

func _check_feeds():
	var feeds = CameraServer.feeds()
	print("当前可用摄像头数量: ", feeds.size())
	
	if feeds.size() > 0:
		for i in range(feeds.size()):
			print("摄像头 [", i, "]: ", feeds[i].get_name(), " (ID: ", feeds[i].get_id(), ")")
		
		if camera_feed == null:
			_start_camera(feeds[0])
	else:
		if camera_feed == null:
			_show_status("未检测到摄像头。尝试：\n1. 检查物理连接\n2. 确保权限已开启\n3. 关闭其他占用相机的程序")

func _show_status(msg: String):
	if status_label:
		status_label.text = msg
		status_label.show()
	print(msg)

func _start_camera(feed: CameraFeed):
	if status_label: status_label.hide()
	camera_feed = feed
	camera_feed.active = true
	
	# 设置 CameraTexture
	var camera_tex = CameraTexture.new()
	camera_tex.camera_feed_id = feed.get_id()
	# 自动根据图像类型（RGB/YUV）处理，通常选典型即可
	camera_tex.camera_is_active = true
	
	sprite.texture = camera_tex
	print("已连接摄像头: ", feed.get_name())

func _input(event):
	if event.is_action_pressed("ui_accept"): # 默认回车或空格
		take_photo()
	elif event.is_action_pressed("ui_up"): # 按 R 键重置/重新开启拍照
		_reset_camera()

func _reset_camera():
	var feeds = CameraServer.feeds()
	if feeds.size() > 0:
		_start_camera(feeds[0])
	else:
		_show_status("未检测到摄像头，请检查设备连接。")

func take_photo():
	if camera_feed == null or !camera_feed.active:
		print("摄像头未激活，无法拍照")
		return
		
	# 获取当前摄像头纹理的图像快照
	var tex = sprite.texture as CameraTexture
	if tex:
		# 注意：某些平台下 CameraTexture 可能无法直接 get_image
		# 更可靠的方法是直接从 CameraFeed 获取映射后的纹理或图像
		var img = camera_feed.get_texture().get_image()
		if img:
			var photo_tex = ImageTexture.create_from_image(img)
			
			# 创建一个新 Sprite 显示照片，或者替换当前的
			# 这里演示替换当前 Sprite 的纹理（即“定格”）
			sprite.texture = photo_tex
			camera_feed.active = false # 拍照后关闭摄像头（定格效果）
			print("拍照完成！")
