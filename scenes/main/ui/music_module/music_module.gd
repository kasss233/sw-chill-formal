extends Control
@export var music_list_scene:PackedScene
@export var audio_res:AudioRes
@onready var tab_container=$FoldableContainer/TabContainer
@onready var folder=$FoldableContainer
signal music_changed(_name:String)
signal music_status_changed
var current_list:int=0
func _ready() -> void:
	setup_music()
	get_signal()
func setup_music()->void:
	add_music_list("全部音乐")
	add_music_list("收藏")
	var list=tab_container.get_node("全部音乐") as MusicList
	for item in audio_res.BGM:
		list.add_music(item.name)
		print("[Music Module] Loaded music item: %s" % item.name)
func add_music_list(_name:String):
	var music_list_instance=music_list_scene.instantiate() as MusicList
	music_list_instance.name=_name
	tab_container.add_child(music_list_instance)
func add_music(_list_name:String,_music_name:String):
	var target_list=tab_container.get_node(_list_name) as MusicList
	if target_list:
		target_list.add_music(_music_name)
func get_signal() -> void:
	for child in tab_container.get_children():
		if child is MusicList:
			child.music_changed.connect(change_music)

func change_music(_name:String) -> void:
	print("[Music Module] Changing music to: %s" % _name)
	music_changed.emit(_name)
	folder.title = _name


func _on_last_button_pressed() -> void:
	var list=tab_container.get_child(current_list) as MusicList
	list.play_last_music()


func _on_status_button_pressed() -> void:
	music_status_changed.emit()
	print("[Music Module] music_changed_play_status emitted")


func _on_next_button_pressed() -> void:
	var list=tab_container.get_child(current_list) as MusicList
	list.play_next_music()


func _on_tab_container_tab_changed(tab: int) -> void:
	current_list=tab
