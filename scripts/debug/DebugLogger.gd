extends Node

const LOG_LEVEL_VERBOSE = 0
const LOG_LEVEL_INFO = 1
const LOG_LEVEL_WARNING = 2
const LOG_LEVEL_ERROR = 3

var current_log_level = LOG_LEVEL_INFO
var log_to_file = false
var log_file_path = "user://debug_log.txt"
var log_file = null

# History of position data for analysis
var position_history = {
    "player": [],
    "dummies": {},
    "camera": []
}
var history_limit = 1000

func _ready():
    if log_to_file:
        log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
        log_file.close()

func _exit_tree():
    if log_file and log_file.is_open():
        log_file.close()

func verbose(message, context=""):
    if current_log_level <= LOG_LEVEL_VERBOSE:
        log_message("[VERBOSE] " + str(context) + ": " + str(message))

func info(message, context=""):
    if current_log_level <= LOG_LEVEL_INFO:
        log_message("[INFO] " + str(context) + ": " + str(message))

func warning(message, context=""):
    if current_log_level <= LOG_LEVEL_WARNING:
        log_message("[WARNING] " + str(context) + ": " + str(message))

func error(message, context=""):
    if current_log_level <= LOG_LEVEL_ERROR:
        log_message("[ERROR] " + str(context) + ": " + str(message))

func log_message(message):
    print(message)
    
    if log_to_file:
        var timestamp = Time.get_datetime_dict_from_system()
        var time_str = "%02d:%02d:%02d" % [timestamp.hour, timestamp.minute, timestamp.second]
        
        log_file = FileAccess.open(log_file_path, FileAccess.READ_WRITE)
        log_file.seek_end()
        log_file.store_line(time_str + " " + message)
        log_file.close()
func log_position(entity_type, entity_name, position, global_position=null):
    var entry = {
        "time": Time.get_ticks_msec(),
        "position": position,
        "global_position": global_position if global_position else position
    }
    
    if entity_type == "player":
        position_history.player.append(entry)
        if position_history.player.size() > history_limit:
            position_history.player.pop_front()
    elif entity_type == "dummy":
        if not position_history.dummies.has(entity_name):
            position_history.dummies[entity_name] = []
        position_history.dummies[entity_name].append(entry)
        if position_history.dummies[entity_name].size() > history_limit:
            position_history.dummies[entity_name].pop_front()
    elif entity_type == "camera":
        position_history.camera.append(entry)
        if position_history.camera.size() > history_limit:
            position_history.camera.pop_front()
    
    # Only log at verbose level
    verbose("Position update - " + entity_name + ": pos=" + str(position) + 
            (", global=" + str(global_position) if global_position else ""), entity_type)

func analyze_position_jumps(entity_type, entity_name, threshold=100.0):
    var history = []
    
    if entity_type == "player":
        history = position_history.player
    elif entity_type == "dummy" and position_history.dummies.has(entity_name):
        history = position_history.dummies[entity_name]
    elif entity_type == "camera":
        history = position_history.camera
    
    if history.size() < 2:
        return []
    
    var jumps = []
    for i in range(1, history.size()):
        var prev_pos = history[i-1].global_position
        var curr_pos = history[i].global_position
        var distance = prev_pos.distance_to(curr_pos)
        
        if distance > threshold:
            jumps.append({
                "from_pos": prev_pos,
                "to_pos": curr_pos,
                "distance": distance,
                "time_diff": history[i].time - history[i-1].time
            })
    
    return jumps
