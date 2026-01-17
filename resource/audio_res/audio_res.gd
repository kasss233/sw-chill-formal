extends Resource
class_name AudioRes 
@export var BGM:Array[AudioItem]
@export var sound_effect:Array[AudioItem]
signal bgm_added(_name:String)
func add_bgm(name:String,path:String)->void:
	if get_bgm_item_by_name(name)!=null:
		push_warning("AudioRes.add_bgm: BGM %s already exists!" % name)
		return
	var item=AudioItem.new()
	BGM.append(item)
	item.name=name
	item.stream=load(path) as AudioStream
	bgm_added.emit(name)
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
