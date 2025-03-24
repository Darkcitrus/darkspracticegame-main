extends CanvasLayer  # Changed from Node2D to CanvasLayer for better overlay rendering

# Visualization settings
var show_visualization = true
var expected_position = Vector2.ZERO
var actual_position = Vector2.ZERO
var position_history = []
var max_history = 20

func _ready():
    # Calculate expected player position
    expected_position = get_viewport().get_visible_rect().size / 2 + Vector2(-250, 0)
    
    # Set up tracking timer
    var timer = Timer.new()
    add_child(timer)
    timer.wait_time = 0.1
    timer.timeout.connect(update_player_position)
    timer.start()
    
    # Create visualization node that will draw on the CanvasLayer
    var vis_node = Control.new()
    vis_node.name = "VisualizationControl"
    vis_node.set_anchors_preset(Control.PRESET_FULL_RECT)  # Fill entire viewport
    vis_node.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Ignore mouse input
    add_child(vis_node)
    
    # Connect draw signal
    vis_node.connect("draw", _on_vis_node_draw)
    
    print("Player position visualizer initialized")

func _process(_delta):
    # Trigger redraw each frame
    $VisualizationControl.queue_redraw()

func _on_vis_node_draw():
    if not show_visualization:
        return
    
    var vis_node = $VisualizationControl
    var viewport_size = get_viewport().get_visible_rect().size
    
    # Draw expected position (green circle)
    vis_node.draw_circle(expected_position, 10, Color(0, 1, 0, 0.5))
    vis_node.draw_string(ThemeDB.fallback_font, expected_position + Vector2(10, 5), 
        "Expected", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 1, 0))
    
    # Draw current position (red circle)
    vis_node.draw_circle(actual_position, 8, Color(1, 0, 0, 0.7))
    vis_node.draw_string(ThemeDB.fallback_font, actual_position + Vector2(10, 5), 
        "Actual", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0, 0))
    
    # Draw line between expected and actual
    vis_node.draw_line(expected_position, actual_position, Color(1, 1, 0, 0.5), 1)
    
    # Draw position history
    for i in range(1, position_history.size()):
        var alpha = 0.5 - (0.5 * i / position_history.size())
        vis_node.draw_line(position_history[i-1], position_history[i], Color(1, 0.5, 0, alpha), 1)
    
    # Draw distance information
    var distance = (expected_position - actual_position).length()
    var distance_text = "Distance: %.1f px (%.1f%% of viewport)" % [
        distance, 100 * distance / viewport_size.length()
    ]
    vis_node.draw_string(ThemeDB.fallback_font, Vector2(20, 20), 
        distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))

func update_player_position():
    var player = get_tree().get_first_node_in_group("Player")
    if player:
        actual_position = player.global_position
        
        # Track position history
        position_history.push_front(actual_position)
        if position_history.size() > max_history:
            position_history.pop_back()
        
        # Print debug info
        var distance = (expected_position - actual_position).length()
        if Engine.get_frames_drawn() % 30 == 0:  # Less frequent logging
            print("Player position - Expected: %s, Actual: %s, Distance: %.1f" % [
                expected_position, actual_position, distance
            ])

func toggle_visualization():
    show_visualization = !show_visualization
    print("Position visualization: " + ("ON" if show_visualization else "OFF"))
