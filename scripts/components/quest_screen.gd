extends ColorRect

## Quest screen — fullscreen overlay for viewing/accepting/delivering quests,
## managing loans, and paying off bounties.

signal quest_closed

const UIStyles = preload("res://scripts/autoloads/ui_styles.gd")
const BackgroundUtils = preload("res://scripts/tools/background_utils.gd")

const QUEST_ICONS = {
	0: "✉",  # ✉
	1: "✉",  # ✉
	2: "✉",  # ✉
	3: "✉",  # ✉
	4: "✉",  # ✉
}

enum Tab { QUESTS, LOAN, BOUNTY }

const TAB_TITLES: Dictionary = {
	Tab.QUESTS: "Quests",
	Tab.LOAN: "Finances",
	Tab.BOUNTY: "Authorities",
}

var _planet_type: int = 0
var _planet_name: String = ""
var _title_label: Label
var _status_label: Label
var _tab_bar: TabBar
var _tab_content: MarginContainer
var _active_tab: int = Tab.QUESTS
var _quest_display: Control  # QuestDisplay instance
var _loan_panel: Control
var _bounty_panel: Control

const QuestDisplayScene: PackedScene = preload("res://scenes/components/quest_display.tscn")
const LoanPanelScene: PackedScene = preload("res://scenes/components/loan_panel.tscn")
const BountyPanelScene: PackedScene = preload("res://scenes/components/bounty_panel.tscn")


func setup(planet_type: int, planet_name: String) -> void:
	_planet_type = planet_type
	_planet_name = planet_name
	if _quest_display:
		_quest_display.setup(planet_name)
	# Built in _ready() before setup() delivers the planet type — re-apply here.
	if _title_label:
		_title_label.text = CityMap.get_building_name(CityMap.BUILDING_QUEST, _planet_type).to_upper()
	_refresh_ui()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0, 0, 0, 0.0)
	_build_ui()


func _build_ui() -> void:
	# Background image
	BackgroundUtils.add_building_background(self, "quest", 0.4)

	var scaffold: Dictionary = UIStyles.create_overlay_scaffold(
		self,
		CityMap.get_building_name(CityMap.BUILDING_QUEST, _planet_type).to_upper(),
		"Accept contracts, manage loans, and deal with authorities",
		QUEST_ICONS.get(_planet_type, "✉"),
		"Back to City",
		close,
	)
	var main_vbox: VBoxContainer = scaffold["main_vbox"]
	_title_label = scaffold["title_label"]

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_status_label)

	_tab_bar = TabBar.new()
	for tab: int in [Tab.QUESTS, Tab.LOAN, Tab.BOUNTY]:
		_tab_bar.add_tab(TAB_TITLES[tab])
	_tab_bar.add_theme_font_size_override("font_size", 16)
	_tab_bar.tab_changed.connect(_on_tab_changed)
	main_vbox.add_child(_tab_bar)

	_tab_content = MarginContainer.new()
	_tab_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_content.add_theme_constant_override("margin_top", 8)
	main_vbox.add_child(_tab_content)

	_show_tab(_active_tab)


func _on_tab_changed(tab: int) -> void:
	_show_tab(tab)


func _show_tab(tab: int) -> void:
	if _tab_content == null:
		return
	_active_tab = tab
	_quest_display = null
	_loan_panel = null
	_bounty_panel = null
	for child in _tab_content.get_children():
		child.queue_free()

	var centre := HBoxContainer.new()
	centre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_content.add_child(centre)

	match tab:
		Tab.QUESTS:
			_quest_display = QuestDisplayScene.instantiate()
			_quest_display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_quest_display.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
			_quest_display.custom_minimum_size = Vector2(720, 0)
			centre.add_child(_quest_display)
			_quest_display.setup(_planet_name)
			_quest_display.quest_changed.connect(_on_action_changed)
		Tab.LOAN:
			_loan_panel = LoanPanelScene.instantiate()
			_loan_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_loan_panel.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
			_loan_panel.custom_minimum_size = Vector2(480, 0)
			centre.add_child(_loan_panel)
			_loan_panel.loan_changed.connect(_on_action_changed)
		Tab.BOUNTY:
			_bounty_panel = BountyPanelScene.instantiate()
			_bounty_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_bounty_panel.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
			_bounty_panel.custom_minimum_size = Vector2(480, 0)
			centre.add_child(_bounty_panel)
			_bounty_panel.bounty_paid.connect(_on_action_changed)

	_refresh_ui()


func _on_action_changed() -> void:
	_refresh_ui()


func _refresh_ui() -> void:
	if _status_label:
		var faction: String = StandingManager.get_planet_faction(_planet_name)
		_status_label.text = "%s | Reputation %s | Loyalty %s | Bounty %s" % [
			faction,
			StandingManager.get_reputation_tier(faction),
			_get_loyalty_status_text(_planet_name),
			StandingManager.get_bounty_tier(),
		]


func _get_loyalty_status_text(planet_name: String) -> String:
	var loyalty_tier: String = StandingManager.get_loyalty_tier(planet_name)
	if loyalty_tier == "Unknown":
		return "No standing yet"
	return loyalty_tier


func close() -> void:
	quest_closed.emit()
	queue_free()
