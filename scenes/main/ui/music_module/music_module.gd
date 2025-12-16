extends Control
@onready var vbox=$FoldableContainer/ScrollContainer/VBoxContainer
@onready var folder=$FoldableContainer
signal music_changed(_name:String)
signal music_changed_play_status
var cur_index:int
func _ready() -> void:
	get_signal()
func get_signal() -> void:
	for c in vbox.get_children():
		c = c as SingleMusic
		if c:
			c.music_changed.connect(change_music.bind(c))

func change_music(_name:String,_emitter:SingleMusic) -> void:
	print("[%s] change_music,index:[%d]" % [_emitter.name,_emitter.get_index()])
	music_changed.emit(_name)
	folder.title = _name
	cur_index = _emitter.get_index()


func _on_last_button_pressed() -> void:
	var last_index=(cur_index-1+vbox.get_child_count())%vbox.get_child_count()
	var last_music=vbox.get_child(last_index) as SingleMusic
	last_music.play_music()


func _on_status_button_pressed() -> void:
	music_changed_play_status.emit()
	print("[%s] music_changed_play_status emitted" % name)


func _on_next_button_pressed() -> void:
	var next_index=(cur_index+1)%vbox.get_child_count()
	var next_music=vbox.get_child(next_index) as SingleMusic
	next_music.play_music()
