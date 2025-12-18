extends Control
@export var music_item_scene:PackedScene 
@export var audio_res:AudioRes
@onready var vbox=$FoldableContainer/ScrollContainer/VBoxContainer
@onready var folder=$FoldableContainer
signal music_changed(_name:String)
signal music_changed_play_status
var cur_index:int
func _ready() -> void:
	setup_music()
	get_signal()
func setup_music()->void:
	for item in audio_res.BGM:
		var music_item=music_item_scene.instantiate() as MusicItem
		music_item.set_music_name(item.name)
		vbox.add_child(music_item)
		print("[Music Module] Loaded music item: %s" % item.name)
func get_signal() -> void:
	for c in vbox.get_children():
		c = c as MusicItem
		if c:
			c.music_changed.connect(change_music.bind(c))

func change_music(_name:String,_emitter:MusicItem) -> void:
	print("[Music Module] Changing music to: %s" % _name)
	music_changed.emit(_name)
	folder.title = _name
	cur_index = _emitter.get_index()


func _on_last_button_pressed() -> void:
	var last_index=(cur_index-1+vbox.get_child_count())%vbox.get_child_count()
	var last_music=vbox.get_child(last_index) as MusicItem
	last_music.play_music()


func _on_status_button_pressed() -> void:
	music_changed_play_status.emit()
	print("[Music Module] music_changed_play_status emitted")


func _on_next_button_pressed() -> void:
	var next_index=(cur_index+1)%vbox.get_child_count()
	var next_music=vbox.get_child(next_index) as MusicItem
	next_music.play_music()
