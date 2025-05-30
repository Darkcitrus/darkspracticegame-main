@tool
class_name CogniteGraphNode extends GraphNode

var id: int
var assemble: CogniteAssemble
var is_ready: bool

var graph_editor: Control


func init(_assemble: CogniteAssemble, _id: int, type: int):
	assemble = _assemble
	if _id != 0 and assemble.nodes.has(_id):
		id = _id
		set_data(assemble.nodes[id])
	else:                                   ## {to node id: right port, left port}
		id = get_instance_id()              ## {node_id_1: Vector2i.x, Vector2i.y}
		assemble.nodes[id] = {"type": type, "right_connections": {}}
	
	position_offset_changed.connect(save_position)
	focus_entered
	return id


func _ready():
	is_ready = true
	get_options()


func _draw():
	draw_char(get_theme_default_font(), Vector2(size.x -12, 12), "x", 13)


func _input(event: InputEvent):
	if selected and event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		_on_close_button_up.call_deferred()


func _gui_input(event: InputEvent):
	if event is InputEventMouseMotion:
		return
	
	assemble.actualize()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		if Rect2(Vector2(size.x -12, 1), Vector2(13, 13)).has_point(event.position):
			_on_close_button_up()


func get_options():
	pass


func _filter_string(string: String) -> String:
	var word = ''
	var regex = RegEx.new()
	regex.compile("[A-Za-z0-9_]")
	
	for valid_character in regex.search_all(string):
		word += valid_character.get_string()
	
	return word


func set_data(data: Dictionary):
	pass

func save_position():
	assemble.nodes[id]["position"] = position_offset


func _on_close_button_up():
	graph_editor.remove_node(id)
	queue_free.call_deferred()
