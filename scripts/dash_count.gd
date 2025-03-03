extends Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = "2"  # Initial dash count

# Called every frame to update the dash count
func _process(_delta: float) -> void:
	if get_parent() and get_parent().has_method("get_dodges"):
		text = str(get_parent().get_dodges())
