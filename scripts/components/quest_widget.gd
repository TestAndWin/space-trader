extends PanelContainer

signal clicked

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")

var hover_bg_color: Color = Color(0.1, 0.2, 0.35, 0.8)
var normal_bg_color: Color = Color(0.04, 0.08, 0.16, 0.8)
var warning_bg_color: Color = Color(0.3, 0.1, 0.1, 0.8)

var _is_hovered: bool = false
var _style: StyleBoxFlat

@onready var vbox: VBoxContainer = VBoxContainer.new()
@onready var title_label: Label = Label.new()
@onready var desc_label: Label = Label.new()

func _ready() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = normal_bg_color
	_style.border_color = Color(0.8, 0.7, 0.2)
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(4)
	_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", _style)

	mouse_entered.connect(func(): _is_hovered = true; _update_style())
	mouse_exited.connect(func(): _is_hovered = false; _update_style())
	
	add_child(vbox)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	title_label.text = "[!] ACTIVE QUEST"
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.25))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)
	
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)
	
	update_widget()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()


func update_widget() -> void:
	if not QuestManager.has_active_quest():
		visible = false
		return
		
	visible = true
	var q: Dictionary = QuestManager.current_quest
	
	var turns: int = q.get("turns_left", 0)
	desc_label.text = "%dx %s -> %s\n%d trips left | Stage %d/%d" % [
		q.get("deliver_qty", 0),
		q.get("deliver_good", "unknown"),
		q.get("destination", "unknown"),
		turns,
		q.get("stage", 1),
		q.get("chain_length", 1)
	]
	
	if turns <= 1:
		_style.bg_color = warning_bg_color
		title_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	elif turns <= 3:
		_style.bg_color = normal_bg_color
		title_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.1))
	else:
		_style.bg_color = normal_bg_color
		title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.25))
		
	_update_style()


func _update_style() -> void:
	var turns: int = int(QuestManager.current_quest.get("turns_left", 99)) if QuestManager.has_active_quest() else 99
	var base_bg: Color = warning_bg_color if turns <= 1 else normal_bg_color
	if _is_hovered:
		_style.bg_color = base_bg.lightened(0.2)
	else:
		_style.bg_color = base_bg
