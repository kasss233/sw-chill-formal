extends Control
class_name MusicList
@onready var vbox=$ScrollContainer/VBoxContainer
@export var music_item:PackedScene
var current_playing_index:int=-1
var current_playing_name:String=""
signal music_changed(_name:String)
signal music_favoured(_name:String)
signal music_moved(_name:String)
signal music_options_requested(music_name:String,list_name:String)
func get_music_count()->int:
	return vbox.get_child_count()
func get_playing_index()->int:
	return current_playing_index
func set_music_list_name(_name:String):
	self.name=_name
func add_music(_name:String):
	if _name=="":
		print("MusicList.add_music: empty name")
		return
	elif vbox.has_node(_name):
		print("MusicList.add_music: name already exists")
		return
	var m=music_item.instantiate() as MusicItem
	m.set_music_name(_name)
	vbox.add_child(m)
	m.music_changed.connect(change_music)
	m.music_favoured.connect(favour_music)
	#m.music_moved.connect(move_music)
	m.music_options_requested.connect(request_options)
func remove_music(_name:String):
	for child in vbox.get_children():
		if child is MusicItem:
			if child.get_music_name()==_name:
				vbox.remove_child(child)
				child.queue_free()
				return
func play_music(_index:int):
	var child=vbox.get_child(_index)
	if child is MusicItem:
		child.play_music()
		current_playing_index=_index
		current_playing_name=child.music_name
func play_next_music():
	if current_playing_index==-1:
		return
	var next_index=current_playing_index+1
	if next_index>=vbox.get_child_count():
		next_index=0
	play_music(next_index)
func play_last_music():
	if current_playing_index==-1:
		return
	var last_index=current_playing_index-1
	if last_index<0:
		last_index=vbox.get_child_count()-1
	play_music(last_index)
func change_music(_name:String):
	emit_signal("music_changed",_name)
	current_playing_name=_name
	for i in range(vbox.get_child_count()):
		var child=vbox.get_child(i)
		if child is MusicItem:
			if child.get_music_name()==_name:
				current_playing_index=i
				return
func favour_music(_name:String):
	emit_signal("music_favoured",_name)
func move_music(_name:String):
	emit_signal("music_moved",_name)
func request_options(_name:String):
	emit_signal("music_options_requested",_name,self.name)
