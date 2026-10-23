extends Node3D

const UI_FONT: FontFile = preload("res://assets/fonts/Jua-Regular.ttf")
const MUSIC_STREAM: AudioStreamWAV = preload("res://assets/audio/garden_loop.wav")
const SOUND_SELECT: AudioStreamWAV = preload("res://assets/audio/select.wav")
const SOUND_PLANT: AudioStreamWAV = preload("res://assets/audio/plant.wav")
const SOUND_WATER: AudioStreamWAV = preload("res://assets/audio/water.wav")
const SOUND_FERTILIZE: AudioStreamWAV = preload("res://assets/audio/fertilize.wav")
const SOUND_HARVEST: AudioStreamWAV = preload("res://assets/audio/harvest.wav")
const SOUND_DAY: AudioStreamWAV = preload("res://assets/audio/new_day.wav")
const SOUND_UPGRADE: AudioStreamWAV = preload("res://assets/audio/upgrade.wav")
const SOUND_DECORATE: AudioStreamWAV = preload("res://assets/audio/decorate.wav")
const SAVE_PATH := "user://garden_save.json"
const SAVE_VERSION := 4
const PLOT_COUNT := 12
const DECOR_SLOT_COUNT := 3
const COLLECTION_GOAL := 3
const COLLECTION_REWARD := 12
const STUDIO_URL := "https://mcroky.github.io/roky-studio/"
const FEEDBACK_URL := "https://mcroky.github.io/roky-studio/#feedback"
const X_URL := "https://x.com/loki60542"
const THREADS_URL := "https://www.threads.com/@loki60542"

const FLOWERS := {
	"daisy": {"name": "데이지", "cost": 4, "reward": 11, "color": "#fff0d7", "center": "#e9ad55", "daily_growth": 6},
	"lavender": {"name": "라벤더", "cost": 6, "reward": 15, "color": "#9277b9", "center": "#b49ac9", "favorite_weather": "비", "weather_growth": 12},
	"sunflower": {"name": "해바라기", "cost": 8, "reward": 20, "color": "#f1b950", "center": "#6a4934", "favorite_weather": "맑음", "weather_growth": 12}
}
const ORDERS := [
	{"kind": "daisy", "count": 2, "bonus": 16},
	{"kind": "lavender", "count": 2, "bonus": 24},
	{"kind": "sunflower", "count": 2, "bonus": 32}
]
const DECORATIONS := {
	"pot": {"name": "꽃 화분", "cost": 14},
	"bench": {"name": "나무 벤치", "cost": 24},
	"lamp": {"name": "정원 등불", "cost": 18}
}

const TOOL_ORDER := ["daisy", "lavender", "sunflower", "water", "fertilizer", "harvest"]
const WEATHER_CYCLE := ["맑음", "비", "맑음", "흐림", "바람"]
const TOOL_TEXT := {
	"daisy": "데이지 심기\n4잎 · 기본",
	"lavender": "라벤더 심기\n6잎 · 비",
	"sunflower": "해바라기 심기\n8잎 · 햇빛",
	"water": "물주기\n성장 돕기",
	"fertilizer": "영양제\n5잎 · 보너스",
	"harvest": "수확하기\n잎 모으기"
}

var day := 1
var leaves := 30
var greenhouse_level := 0
var harvest_counts := {"daisy": 0, "lavender": 0, "sunflower": 0}
var order_number := 0
var order_progress := 0
var plants: Array = []
var decorations: Array = []
var selected_tool := "daisy"
var selected_plot := -1
var sound_enabled := true
var music_player: AudioStreamPlayer
var sound_players: Array[AudioStreamPlayer] = []
var next_sound_player := 0
var audio_unlocked := false

var camera: Camera3D
var weather_environment: Environment
var sun_light: DirectionalLight3D
var rain_effects: Node3D
var wind_effects: Node3D
var plot_positions: Array[Vector3] = []
var plant_hosts: Array[Node3D] = []
var highlights: Array[Node3D] = []
var greenhouse_marker: MeshInstance3D
var greenhouse_tiers: Array[Node3D] = []
var collection_badges := {}
var decor_positions: Array[Vector3] = []
var decor_hosts: Array[Node3D] = []
var decor_highlights: Array[Node3D] = []
var materials := {}

var ui_root: Control
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var detail_panel: PanelContainer
var action_row: HBoxContainer
var day_button: Button
var upgrade_button: Button
var decorate_button: Button
var header_label: Label
var sound_button: Button
var nav_buttons: Array[Button] = []
var guide_title: Label
var detail_label: Label
var guide_button: Button
var plot_label: Label
var order_label: Label
var message_label: Label
var tools_heading: Label
var tool_buttons := {}
var modal: Control
var modal_panel: PanelContainer
var modal_title: Label
var modal_body: Label
var backup_row: HBoxContainer
var shop_grid: GridContainer
var last_tap_msec := 0
var import_dialog: FileDialog
var export_dialog: FileDialog
var browser_import_pending := false


func _ready() -> void:
	_load_game()
	_build_audio()
	_build_world()
	_apply_weather_visuals()
	_build_ui()
	set_process(false)
	_redraw_all_plants()
	_redraw_all_decorations()
	_refresh_ui()
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()
	call_deferred("_layout_ui")


func _build_audio() -> void:
	music_player = AudioStreamPlayer.new()
	var music_wav := MUSIC_STREAM.duplicate() as AudioStreamWAV
	music_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music_wav.loop_begin = 0
	music_wav.loop_end = int(music_wav.get_length() * music_wav.mix_rate)
	music_player.stream = music_wav
	music_player.volume_db = -12.0
	add_child(music_player)
	for i in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -7.0
		add_child(player)
		sound_players.append(player)


func _play_sound(stream: AudioStream) -> void:
	if not sound_enabled:
		return
	if not audio_unlocked:
		audio_unlocked = true
		music_player.play()
	var player := sound_players[next_sound_player]
	next_sound_player = (next_sound_player + 1) % sound_players.size()
	player.stream = stream
	player.play()


func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	if sound_enabled:
		audio_unlocked = false
		_play_sound(SOUND_SELECT)
		_message("소리를 켰어요.")
	else:
		music_player.stop()
		for player in sound_players:
			player.stop()
		audio_unlocked = false
		_message("소리를 껐어요.")
	_refresh_ui()
	_save_game()


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#d9e6d5")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#e8edda")
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	weather_environment = settings
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, -12)
	sun.light_color = Color("#fff1d8")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun_light = sun
	add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.5
	camera.position = Vector3(8.5, 11.5, 16)
	add_child(camera)
	camera.look_at(Vector3(1.3, 0.2, 3.2))
	camera.current = true

	_box(self, Vector3(0, -0.47, 0), Vector3(6.4, 0.65, 7.25), "#8f6950")
	_box(self, Vector3(0, -0.10, 0), Vector3(6.7, 0.16, 7.55), "#b78b66")
	_box(self, Vector3(0, 0, 0), Vector3(6.35, 0.15, 7.2), "#7da270")
	_box(self, Vector3(0, 0.08, 3.36), Vector3(6.15, 0.10, 0.35), "#e3d3a4")
	_build_fence()
	_build_greenhouse()
	_build_collection_badges()

	for row in range(3):
		for col in range(4):
			var center := Vector3((float(col) - 1.5) * 1.45, 0, (float(row) - 1.0) * 1.6 + 0.35)
			plot_positions.append(center)
			_build_plot(center)
	_build_decor_terrace()

	for i in range(13):
		var angle := float(i) * TAU / 13.0
		var x := sin(angle) * 2.8
		var z := cos(angle) * 3.1
		if absf(x) > 2.2 or z < -2.8:
			_sphere(self, Vector3(x, 0.16, z), Vector3(0.13, 0.08, 0.14), "#587d59")
	_build_weather_effects()


func _build_weather_effects() -> void:
	rain_effects = Node3D.new()
	rain_effects.name = "RainEffects"
	add_child(rain_effects)
	# A few opaque strokes and shallow puddles keep the effect cheap on mobile WebGL.
	for i in range(20):
		var x := -2.72 + float(i % 5) * 1.36
		var z := -2.88 + float(i / 5) * 1.8
		var streak := _box(rain_effects, Vector3(x, 1.35 + float(i % 3) * 0.18, z), Vector3(0.035, 0.42, 0.035), "#b9d9dc")
		streak.rotation_degrees.z = 12.0
	for position in [Vector3(-2.65, 0.17, -1.35), Vector3(2.65, 0.17, 1.9), Vector3(-2.5, 0.18, 3.35)]:
		_sphere(rain_effects, position, Vector3(0.25, 0.015, 0.14), "#a8cdd0")

	wind_effects = Node3D.new()
	wind_effects.name = "WindEffects"
	add_child(wind_effects)
	for i in range(7):
		var x := -2.7 + float(i % 4) * 1.65
		var z := -2.7 + float(i / 4) * 4.5
		var leaf := _sphere(wind_effects, Vector3(x, 0.65 + float(i % 3) * 0.2, z), Vector3(0.14, 0.035, 0.07), "#b9bb69" if i % 2 == 0 else "#d4ae69")
		leaf.rotation_degrees = Vector3(16, float(i * 31), -25)


func _apply_weather_visuals() -> void:
	var weather := _weather_for_day(day)
	rain_effects.visible = weather == "비"
	wind_effects.visible = weather == "바람"
	match weather:
		"비":
			weather_environment.background_color = Color("#cadbdc")
			weather_environment.ambient_light_color = Color("#d5e5e6")
			sun_light.light_color = Color("#dbe9e8")
			sun_light.light_energy = 0.62
		"흐림":
			weather_environment.background_color = Color("#d8ded3")
			weather_environment.ambient_light_color = Color("#e2e7db")
			sun_light.light_color = Color("#e9ebdf")
			sun_light.light_energy = 0.77
		"바람":
			weather_environment.background_color = Color("#d7e5d5")
			weather_environment.ambient_light_color = Color("#e7ebd9")
			sun_light.light_color = Color("#f4e9cc")
			sun_light.light_energy = 0.94
		_:
			weather_environment.background_color = Color("#d9e6d5")
			weather_environment.ambient_light_color = Color("#e8edda")
			sun_light.light_color = Color("#fff1d8")
			sun_light.light_energy = 1.05


func _build_fence() -> void:
	for x in [-3.05, 3.05]:
		for i in range(6):
			_box(self, Vector3(x, 0.3, -3.15 + float(i) * 1.25), Vector3(0.10, 0.62, 0.10), "#ead8b1")
		_box(self, Vector3(x, 0.28, 0), Vector3(0.10, 0.07, 6.8), "#ead8b1")
	for i in range(6):
		_box(self, Vector3(-2.9 + float(i) * 1.16, 0.3, -3.28), Vector3(0.10, 0.62, 0.10), "#ead8b1")
	_box(self, Vector3(0, 0.28, -3.28), Vector3(5.9, 0.07, 0.10), "#ead8b1")


func _build_greenhouse() -> void:
	# Each upgrade adds visible structure to the landmark at the far edge.
	_box(self, Vector3(0, 0.38, -3.03), Vector3(1.55, 0.58, 0.64), "#e9e0c5")
	_box(self, Vector3(0, 0.75, -3.03), Vector3(1.75, 0.14, 0.82), "#8db5a0")
	_box(self, Vector3(-0.53, 0.39, -2.69), Vector3(0.15, 0.36, 0.08), "#8db5a0")
	_box(self, Vector3(0.53, 0.39, -2.69), Vector3(0.15, 0.36, 0.08), "#8db5a0")
	greenhouse_marker = _sphere(self, Vector3(0, 0.97, -3.03), Vector3(0.16, 0.16, 0.16), "#f0bf66")
	for i in range(3):
		var tier := Node3D.new()
		add_child(tier)
		tier.visible = false
		greenhouse_tiers.append(tier)
	var first := greenhouse_tiers[0]
	_box(first, Vector3(0, 0.89, -3.03), Vector3(1.86, 0.10, 0.92), "#f0c878")
	for side in [-1.0, 1.0]:
		_sphere(first, Vector3(side * 0.86, 0.87, -2.67), Vector3(0.15, 0.15, 0.15), "#f3d78e")
	var second := greenhouse_tiers[1]
	for side in [-1.0, 1.0]:
		_box(second, Vector3(side * 0.84, 0.47, -3.03), Vector3(0.12, 0.80, 0.92), "#7db4a5")
	_box(second, Vector3(0, 1.06, -3.03), Vector3(1.35, 0.11, 0.12), "#7db4a5")
	var third := greenhouse_tiers[2]
	_cylinder(third, Vector3(0, 1.13, -3.03), 0.07, 0.28, "#b98f59")
	_sphere(third, Vector3(0, 1.33, -3.03), Vector3(0.28, 0.28, 0.28), "#f3d78e")


func _build_collection_badges() -> void:
	var kinds := ["daisy", "lavender", "sunflower"]
	for i in range(kinds.size()):
		var badge := Node3D.new()
		badge.position = Vector3((float(i) - 1.0) * 1.5, 0, 3.03)
		add_child(badge)
		_cylinder(badge, Vector3(0, 0.20, 0), 0.19, 0.16, "#e3d3a4")
		_sphere(badge, Vector3(0, 0.38, 0), Vector3(0.22, 0.22, 0.22), str(FLOWERS[kinds[i]]["color"]))
		badge.visible = false
		collection_badges[kinds[i]] = badge


func _build_decor_terrace() -> void:
	_box(self, Vector3(0, -0.31, 3.98), Vector3(6.25, 0.55, 1.12), "#8f6950")
	_box(self, Vector3(0, -0.01, 3.98), Vector3(6.35, 0.13, 1.17), "#c79669")
	_box(self, Vector3(0, 0.08, 3.98), Vector3(6.15, 0.08, 1.06), "#e3d3a4")
	for i in range(DECOR_SLOT_COUNT):
		var position := Vector3((float(i) - 1.0) * 1.85, 0, 3.99)
		decor_positions.append(position)
		var slot := Node3D.new()
		slot.position = position
		add_child(slot)
		_cylinder(slot, Vector3(0, 0.15, 0), 0.57, 0.12, "#b7c69d")
		var highlight := Node3D.new()
		slot.add_child(highlight)
		_cylinder(highlight, Vector3(0, 0.17, 0), 0.62, 0.04, "#f4d27f")
		highlight.visible = false
		decor_highlights.append(highlight)
		var host := Node3D.new()
		host.position.y = 0.21
		slot.add_child(host)
		decor_hosts.append(host)


func _redraw_all_decorations() -> void:
	for i in range(DECOR_SLOT_COUNT):
		var host := decor_hosts[i]
		for child in host.get_children():
			host.remove_child(child)
			child.queue_free()
		match decorations[i]:
			"pot": _build_pot(host)
			"bench": _build_bench(host)
			"lamp": _build_lamp(host)


func _build_pot(host: Node3D) -> void:
	_cylinder(host, Vector3(0, 0.20, 0), 0.28, 0.38, "#bd7859")
	_cylinder(host, Vector3(0, 0.40, 0), 0.32, 0.07, "#d28b64")
	_cylinder(host, Vector3(0, 0.45, 0), 0.25, 0.04, "#685043")
	_cylinder(host, Vector3(0, 0.66, 0), 0.045, 0.40, "#5b8c61")
	for side in [-1.0, 1.0]:
		_sphere(host, Vector3(side * 0.18, 0.62, 0), Vector3(0.21, 0.07, 0.12), "#72a56e")
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		_sphere(host, Vector3(sin(angle) * 0.12, 0.88, cos(angle) * 0.12), Vector3(0.12, 0.07, 0.17), "#f7e3d0")
	_sphere(host, Vector3(0, 0.91, 0), Vector3(0.13, 0.09, 0.13), "#e9ad55")


func _build_bench(host: Node3D) -> void:
	for side in [-0.39, 0.39]:
		_box(host, Vector3(side, 0.18, -0.17), Vector3(0.09, 0.36, 0.09), "#705a48")
		_box(host, Vector3(side, 0.18, 0.17), Vector3(0.09, 0.36, 0.09), "#705a48")
		_box(host, Vector3(side, 0.47, 0.20), Vector3(0.09, 0.35, 0.09), "#705a48")
	_box(host, Vector3(0, 0.39, 0), Vector3(1.08, 0.10, 0.52), "#b6865c")
	_box(host, Vector3(0, 0.60, 0.21), Vector3(1.08, 0.25, 0.09), "#c49468")


func _build_lamp(host: Node3D) -> void:
	_cylinder(host, Vector3(0, 0.09, 0), 0.27, 0.17, "#6d806e")
	_cylinder(host, Vector3(0, 0.53, 0), 0.07, 0.79, "#61776b")
	_box(host, Vector3(0, 0.96, 0), Vector3(0.50, 0.09, 0.50), "#61776b")
	_sphere(host, Vector3(0, 1.12, 0), Vector3(0.21, 0.25, 0.21), "#ffe5a0")
	_box(host, Vector3(0, 1.34, 0), Vector3(0.56, 0.08, 0.56), "#61776b")


func _build_plot(center: Vector3) -> void:
	var plot := Node3D.new()
	plot.position = center
	add_child(plot)
	_box(plot, Vector3(0, 0.18, 0), Vector3(1.23, 0.28, 1.23), "#a87955")
	_box(plot, Vector3(0, 0.32, 0), Vector3(1.06, 0.06, 1.06), "#5e4a3a")
	for side in [-0.58, 0.58]:
		_box(plot, Vector3(side, 0.35, 0), Vector3(0.10, 0.12, 1.28), "#c79669")
		_box(plot, Vector3(0, 0.35, side), Vector3(1.28, 0.12, 0.10), "#c79669")
	var highlight := Node3D.new()
	plot.add_child(highlight)
	for side in [-0.68, 0.68]:
		_box(highlight, Vector3(side, 0.44, 0), Vector3(0.09, 0.07, 1.4), "#f4b447")
		_box(highlight, Vector3(0, 0.44, side), Vector3(1.4, 0.07, 0.09), "#f4b447")
	highlight.visible = false
	highlights.append(highlight)
	var plant_host := Node3D.new()
	plant_host.position = Vector3(0, 0.35, 0)
	plot.add_child(plant_host)
	plant_hosts.append(plant_host)


func _redraw_all_plants() -> void:
	for i in range(PLOT_COUNT):
		_redraw_plant(i)
	greenhouse_marker.material_override = _material("#f0bf66" if greenhouse_level == 0 else "#fff2ab")
	for i in range(greenhouse_tiers.size()):
		greenhouse_tiers[i].visible = greenhouse_level > i
	for kind in collection_badges:
		collection_badges[kind].visible = int(harvest_counts[kind]) >= COLLECTION_GOAL
func _redraw_plant(index: int) -> void:
	var host := plant_hosts[index]
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	var plant = plants[index]
	if plant == null:
		return
	var kind: String = str(plant.get("kind", "daisy"))
	var growth: int = int(plant.get("growth", 0))
	var bloom_color: String = str(FLOWERS[kind]["color"])
	var center_color: String = str(FLOWERS[kind]["center"])
	_sphere(host, Vector3(0, 0.03, 0), Vector3(0.24, 0.08, 0.22), "#74543f")
	if growth < 20:
		return
	var stem_height := 0.30 if growth < 55 else 0.72
	_cylinder(host, Vector3(0, stem_height * 0.5, 0), 0.065, stem_height, "#5b8c61")
	for side in [-1.0, 1.0]:
		var leaf := _sphere(host, Vector3(side * 0.20, stem_height * 0.58, 0), Vector3(0.27, 0.065, 0.14), "#72a56e")
		leaf.rotation = Vector3(0, 0, side * 0.25)
	if growth < 55:
		return
	if growth < 100:
		_sphere(host, Vector3(0, stem_height + 0.06, 0), Vector3(0.18, 0.20, 0.18), "#7fa272")
		return
	if kind == "lavender":
		for i in range(9):
			var angle := float(i) * 2.4
			var radius := 0.06 + float(i % 3) * 0.055
			_sphere(host, Vector3(sin(angle) * radius, 0.74 + float(i / 3) * 0.12, cos(angle) * radius), Vector3(0.11, 0.12, 0.11), bloom_color)
	else:
		var petal_count := 10 if kind == "sunflower" else 8
		for i in range(petal_count):
			var angle := float(i) * TAU / float(petal_count)
			var petal := _sphere(host, Vector3(sin(angle) * 0.22, 0.80, cos(angle) * 0.22), Vector3(0.15, 0.08, 0.29), bloom_color)
			petal.rotation = Vector3(0, angle, 0)
		_sphere(host, Vector3(0, 0.85, 0), Vector3(0.23, 0.13, 0.23), center_color)
	if int(plant.get("water", 0)) > 0:
		_sphere(host, Vector3(0.35, 0.04, 0.31), Vector3(0.07, 0.03, 0.09), "#9bc8c0")
	if bool(plant.get("fed", false)):
		_sphere(host, Vector3(-0.34, 0.05, 0.30), Vector3(0.07, 0.07, 0.07), "#f0bf66")


func _material(hex: String) -> StandardMaterial3D:
	if materials.has(hex):
		return materials[hex]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = 0.92
	materials[hex] = material
	return material


func _box(parent: Node3D, at: Vector3, dimensions: Vector3, hex: String) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = dimensions
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.material_override = _material(hex)
	instance.position = at
	parent.add_child(instance)
	return instance


func _sphere(parent: Node3D, at: Vector3, dimensions: Vector3, hex: String) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var instance := MeshInstance3D.new()
	instance.mesh = sphere
	instance.material_override = _material(hex)
	instance.position = at
	instance.scale = dimensions * 2.0
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, hex: String) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius * 1.2
	cylinder.height = height
	cylinder.radial_segments = 7
	var instance := MeshInstance3D.new()
	instance.mesh = cylinder
	instance.material_override = _material(hex)
	instance.position = at
	parent.add_child(instance)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	ui_root.theme = Theme.new()
	ui_root.theme.default_font = UI_FONT

	top_panel = _panel(ui_root)
	var top_stack := VBoxContainer.new()
	top_stack.add_theme_constant_override("separation", 6)
	top_panel.add_child(top_stack)
	header_label = _label(top_stack, "작은정원", 30, "#254a3a")
	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 8)
	top_stack.add_child(links)
	_link_button(links, "< Roky Studio", STUDIO_URL)
	_link_button(links, "의견", FEEDBACK_URL)
	_link_button(links, "X", X_URL)
	_link_button(links, "Threads", THREADS_URL)
	var menu := HBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	top_stack.add_child(menu)
	sound_button = _button(menu, "소리 켬", "#e4e9d6")
	sound_button.tooltip_text = "배경음과 효과음 켜기 또는 끄기"
	sound_button.pressed.connect(_toggle_sound)
	var info := _button(menu, "도움말", "#e4e9d6")
	info.pressed.connect(_show_info)
	var journal := _button(menu, "도감", "#e4e9d6")
	journal.pressed.connect(_show_journal)
	for row in [links, menu]:
		for button in row.get_children():
			button.custom_minimum_size = Vector2(0, 52)
			button.add_theme_font_size_override("font_size", 20)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nav_buttons.append(button as Button)

	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	ui_root.add_child(action_row)
	day_button = _button(action_row, "하루 보내기 >", "#f0bd6d")
	day_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_button.pressed.connect(_next_day)
	upgrade_button = _button(action_row, "온실 개선", "#b4d5b4")
	upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_button.pressed.connect(_upgrade_greenhouse)
	decorate_button = _button(action_row, "꾸미기", "#e6d5ac")
	decorate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decorate_button.pressed.connect(_show_decor_shop)

	detail_panel = _panel(ui_root)
	var guide_style := _style("#fff9e9", 18)
	guide_style.border_color = Color("#dfae55")
	guide_style.set_border_width_all(3)
	detail_panel.add_theme_stylebox_override("panel", guide_style)
	var detail_stack := VBoxContainer.new()
	detail_stack.add_theme_constant_override("separation", 3)
	detail_panel.add_child(detail_stack)
	guide_title = _label(detail_stack, "지금 할 일", 27, "#254a3a")
	detail_label = _label(detail_stack, "", 22, "#315342")
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_button = _button(detail_stack, "추천 행동", "#e7b76c")
	guide_button.custom_minimum_size.y = 58
	guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_button.pressed.connect(_on_guide_action)
	plot_label = _label(detail_stack, "", 19, "#57705e")
	plot_label.visible = false
	order_label = _label(detail_stack, "", 20, "#9a663e")
	order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	bottom_panel = _panel(ui_root)
	var bottom_stack := VBoxContainer.new()
	bottom_stack.add_theme_constant_override("separation", 8)
	bottom_panel.add_child(bottom_stack)
	tools_heading = _label(bottom_stack, "직접 가꾸기  ·  도구를 골라 화단 터치", 24, "#46614b")
	var tools_grid := GridContainer.new()
	tools_grid.columns = 3
	tools_grid.add_theme_constant_override("h_separation", 8)
	tools_grid.add_theme_constant_override("v_separation", 8)
	bottom_stack.add_child(tools_grid)
	for tool in TOOL_ORDER:
		var button := _button(tools_grid, TOOL_TEXT[tool], "#f3eedf")
		button.custom_minimum_size = Vector2(0, 84)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_tool.bind(tool))
		tool_buttons[tool] = button
	message_label = _label(bottom_stack, "", 22, "#8d5e42")
	message_label.custom_minimum_size.y = 32

	modal = Control.new()
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.visible = false
	ui_root.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.12, 0.20, 0.16, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	modal_panel = _panel(modal)
	var modal_stack := VBoxContainer.new()
	modal_stack.add_theme_constant_override("separation", 14)
	modal_panel.add_child(modal_stack)
	modal_title = _label(modal_stack, "작은정원 | 시제품 v0.9.0", 27, "#254a3a")
	modal_body = _label(modal_stack, "", 22, "#315342")
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_grid = GridContainer.new()
	shop_grid.columns = 2
	shop_grid.add_theme_constant_override("h_separation", 10)
	shop_grid.add_theme_constant_override("v_separation", 10)
	shop_grid.visible = false
	modal_stack.add_child(shop_grid)
	for kind in ["pot", "bench", "lamp"]:
		var button := _button(shop_grid, "%s %d잎" % [DECORATIONS[kind]["name"], int(DECORATIONS[kind]["cost"])], "#e6d5ac")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_decoration.bind(kind))
	var remove_button := _button(shop_grid, "장식 치우기", "#d6e8cf")
	remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove_button.pressed.connect(_choose_decoration.bind("remove"))
	backup_row = HBoxContainer.new()
	backup_row.add_theme_constant_override("separation", 10)
	modal_stack.add_child(backup_row)
	var export_button := _button(backup_row, "저장 백업", "#e6d5ac")
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button.pressed.connect(_export_backup)
	var import_button := _button(backup_row, "백업 불러오기", "#d6e8cf")
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_button.pressed.connect(_import_backup)
	var modal_spacer := Control.new()
	modal_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_stack.add_child(modal_spacer)
	var close_button := _button(modal_stack, "정원으로 돌아가기", "#b4d5b4")
	close_button.custom_minimum_size.y = 84
	close_button.pressed.connect(func(): modal.visible = false)

	import_dialog = FileDialog.new()
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.filters = PackedStringArray(["*.json ; JSON 백업"])
	import_dialog.file_selected.connect(_read_backup_file)
	add_child(import_dialog)
	export_dialog = FileDialog.new()
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.filters = PackedStringArray(["*.json ; JSON 백업"])
	export_dialog.file_selected.connect(_write_backup_file)
	add_child(export_dialog)


func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style("#f8f5e9", 18))
	parent.add_child(panel)
	return panel


func _label(parent: Control, value: String, size: int, hex: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(hex))
	parent.add_child(label)
	return label


func _button(parent: Control, value: String, hex: String) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_override("font", UI_FONT)
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 80
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("#254a3a"))
	button.add_theme_color_override("font_hover_color", Color("#254a3a"))
	button.add_theme_color_override("font_pressed_color", Color("#254a3a"))
	button.add_theme_color_override("font_hover_pressed_color", Color("#254a3a"))
	button.add_theme_color_override("font_focus_color", Color("#254a3a"))
	button.add_theme_stylebox_override("normal", _style(hex, 12))
	button.add_theme_stylebox_override("hover", _style("#d6e8cf", 12))
	button.add_theme_stylebox_override("pressed", _style("#9ec7a3", 12))
	button.add_theme_stylebox_override("focus", _focus_style())
	parent.add_child(button)
	return button


func _style(hex: String, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(hex)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("#335f48")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	return style


func _link_button(parent: Control, value: String, url: String) -> void:
	var button := _button(parent, value, "#e4e9d6")
	button.pressed.connect(_open_url.bind(url))


func _layout_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	ui_root.size = viewport_size
	var width := viewport_size.x
	var height := viewport_size.y
	var portrait := width / height < 1.15
	for button in nav_buttons:
		button.custom_minimum_size.y = 60 if portrait else 58
		button.add_theme_font_size_override("font_size", 23 if portrait else 24)
	for button in [day_button, upgrade_button, decorate_button]:
		button.add_theme_font_size_override("font_size", 25 if portrait else 27)
	for button in tool_buttons.values():
		button.custom_minimum_size.y = 84 if portrait else 104
		button.add_theme_font_size_override("font_size", 25 if portrait else 27)
	header_label.add_theme_font_size_override("font_size", 32 if portrait else 34)
	guide_title.add_theme_font_size_override("font_size", 31 if portrait else 32)
	detail_label.add_theme_font_size_override("font_size", 26 if portrait else 28)
	guide_button.custom_minimum_size.y = 58 if portrait else 72
	guide_button.add_theme_font_size_override("font_size", 26 if portrait else 29)
	plot_label.add_theme_font_size_override("font_size", 22 if portrait else 23)
	order_label.add_theme_font_size_override("font_size", 23 if portrait else 25)
	tools_heading.add_theme_font_size_override("font_size", 26 if portrait else 28)
	message_label.add_theme_font_size_override("font_size", 23 if portrait else 26)
	modal_title.add_theme_font_size_override("font_size", 31 if portrait else 27)
	modal_body.add_theme_font_size_override("font_size", 25 if portrait else 22)
	if width / height >= 1.15:
		var side_width := minf(850.0, maxf(720.0, width * 0.39))
		var side_x := width - side_width - 28.0
		var stack_top := maxf(80.0, (height - 740.0) * 0.5)
		top_panel.position = Vector2(24, 24)
		top_panel.size = Vector2(minf(900.0, side_x - 48.0), 210)
		detail_panel.position = Vector2(side_x, stack_top)
		detail_panel.size = Vector2(side_width, 260)
		action_row.position = Vector2(side_x, stack_top + 276)
		action_row.size = Vector2(side_width, 96)
		bottom_panel.position = Vector2(side_x, stack_top + 388)
		bottom_panel.size = Vector2(side_width, 352)
		camera.size = maxf(11.5, 9.8 * height / maxf(500.0, side_x - 120.0))
		var camera_shift := (width * 0.5 - side_x * 0.5) * camera.size / height * 1.1
		camera.position = Vector3(8.5 + camera_shift, 11.5, 16)
		camera.look_at(Vector3(1.3 + camera_shift, 0.2, 3.2))
		camera.position += camera.global_transform.basis.y * (camera.size * 0.24)
	else:
		var panel_width := minf(width - 32.0, 760.0)
		var panel_x := (width - panel_width) * 0.5
		top_panel.position = Vector2(panel_x, 18)
		top_panel.size = Vector2(panel_width, 206)
		bottom_panel.position = Vector2(panel_x, height - 330)
		bottom_panel.size = Vector2(panel_width, 310)
		detail_panel.position = Vector2(panel_x, height - 556)
		detail_panel.size = Vector2(panel_width, 220)
		action_row.position = Vector2(panel_x, height - 650)
		action_row.size = Vector2(panel_width, 84)
		camera.size = maxf(18.5, 18.5 * (720.0 / 1280.0) * height / width)
		camera.position = Vector3(8.5, 11.5, 16)
		camera.look_at(Vector3(1.3, 0.2, 3.2))
		var compact_shift := clampf((1500.0 - height) * 0.00023, 0.0, 0.055)
		camera.position -= camera.global_transform.basis.y * (camera.size * compact_shift)
	modal.size = viewport_size
	var modal_width := minf(width - 80.0, 760.0)
	modal_panel.position = Vector2((width - modal_width) * 0.5, (height - 600) * 0.5)
	modal_panel.size = Vector2(modal_width, 600)
	modal_body.custom_minimum_size = Vector2(modal_width - 60, 180 if shop_grid.visible else 300)


func _unhandled_input(event: InputEvent) -> void:
	if modal.visible:
		return
	var point := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		point = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	else:
		return
	var now := Time.get_ticks_msec()
	if now - last_tap_msec < 120:
		return
	last_tap_msec = now
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	if absf(direction.y) < 0.0001:
		return
	var distance := (0.36 - origin.y) / direction.y
	if distance < 0:
		return
	var world_point := origin + direction * distance
	for i in range(PLOT_COUNT):
		var center := plot_positions[i]
		if absf(world_point.x - center.x) < 0.62 and absf(world_point.z - center.z) < 0.62:
			_tap_plot(i)
			get_viewport().set_input_as_handled()
			return
	for i in range(DECOR_SLOT_COUNT):
		var center := decor_positions[i]
		if absf(world_point.x - center.x) < 0.74 and absf(world_point.z - center.z) < 0.53:
			_tap_decor(i)
			get_viewport().set_input_as_handled()
			return


func _select_tool(tool: String) -> void:
	_play_sound(SOUND_SELECT)
	selected_tool = tool
	message_label.text = "화단을 눌러 %s" % _tool_instruction(tool)
	_refresh_ui()


func _show_decor_shop() -> void:
	_play_sound(SOUND_SELECT)
	modal_title.text = "정원 꾸미기"
	modal_body.text = "화분: 모든 꽃 하루 성장 +4\n벤치: 꽃 수확 보상 +3잎\n등불: 흐림과 바람 날 성장 +8\n\n같은 종류를 여러 개 놓아도 효과는 한 번만 적용돼요. 물건을 골라 빈 자리를 터치하세요. 치우면 비용의 절반을 돌려받습니다."
	modal_body.add_theme_font_size_override("font_size", 22)
	shop_grid.visible = true
	backup_row.visible = false
	modal.visible = true
	_layout_ui()
	call_deferred("_layout_ui")


func _choose_decoration(kind: String) -> void:
	_play_sound(SOUND_SELECT)
	selected_tool = "decor_" + kind
	modal.visible = false
	if kind == "remove":
		_message("치울 장식 자리를 터치하세요.")
	else:
		_message("%s을 놓을 빈 장식 자리를 터치하세요." % DECORATIONS[kind]["name"])
	_refresh_ui()


func _tap_decor(index: int) -> void:
	var placed = decorations[index]
	if selected_tool == "decor_remove":
		if placed == null:
			_message("이 장식 자리는 비어 있어요.")
		else:
			var refund: int = int(DECORATIONS[placed]["cost"]) / 2
			leaves += refund
			decorations[index] = null
			_play_sound(SOUND_DECORATE)
			_message("%s을 치우고 잎 %d개를 돌려받았어요." % [DECORATIONS[placed]["name"], refund])
	elif selected_tool.begins_with("decor_"):
		var kind := selected_tool.trim_prefix("decor_")
		if placed != null:
			_message("이미 장식이 있어요. 꾸미기에서 먼저 치워 주세요.")
		elif not DECORATIONS.has(kind):
			return
		else:
			var cost: int = int(DECORATIONS[kind]["cost"])
			if leaves < cost:
				_message("%s을 놓으려면 잎 %d개가 필요해요." % [DECORATIONS[kind]["name"], cost])
			else:
				leaves -= cost
				decorations[index] = kind
				_play_sound(SOUND_DECORATE)
				_message("%s을 놓았어요!" % DECORATIONS[kind]["name"])
	else:
		if placed == null:
			_message("빈 장식 자리예요. 꾸미기에서 물건을 골라 주세요.")
		else:
			_message("%s이 놓여 있어요. 꾸미기에서 바꿀 수 있어요." % DECORATIONS[placed]["name"])
	_redraw_all_decorations()
	_refresh_ui()
	_save_game()


func _tool_instruction(tool: String) -> String:
	if FLOWERS.has(tool):
		return "씨앗을 심으세요."
	match tool:
		"water": return "물을 주세요."
		"fertilizer": return "영양제를 주세요."
		"harvest": return "다 자란 꽃을 수확하세요."
	return "가꾸어 보세요."


func _tap_plot(index: int) -> void:
	selected_plot = index
	var plant = plants[index]
	if FLOWERS.has(selected_tool):
		if plant != null:
			_message("이미 자라고 있는 화단이에요.")
		else:
			var price: int = int(FLOWERS[selected_tool]["cost"])
			var free_seed := selected_tool == "daisy" and leaves < price
			if free_seed:
				for existing_plant in plants:
					if existing_plant != null:
						free_seed = false
						break
			if leaves < price and not free_seed:
				_message("잎이 부족해요. 꽃을 수확해 보세요.")
			else:
				if not free_seed:
					leaves -= price
				plants[index] = {"kind": selected_tool, "growth": 0, "water": 0, "fed": false}
				_play_sound(SOUND_PLANT)
				_message("다시 시작할 데이지를 무료로 심었어요. 물을 주세요." if free_seed else "%s 씨앗을 심었어요. 물을 주고 하루를 보내세요." % FLOWERS[selected_tool]["name"])
	elif selected_tool == "water":
		if plant == null:
			_message("먼저 씨앗을 심어 주세요.")
		elif int(plant.get("water", 0)) >= _water_capacity():
			_message("흙이 이미 촉촉해요.")
		else:
			plant["water"] = _water_capacity()
			_play_sound(SOUND_WATER)
			_message("물을 주었어요. %d일 동안 촉촉해요." % _water_capacity())
	elif selected_tool == "fertilizer":
		if plant == null:
			_message("먼저 씨앗을 심어 주세요.")
		elif bool(plant.get("fed", false)):
			_message("이미 영양제를 주었어요.")
		elif leaves < 5:
			_message("영양제를 살 잎이 부족해요.")
		else:
			leaves -= 5
			plant["fed"] = true
			_play_sound(SOUND_FERTILIZE)
			_message("영양제를 주었어요. 성장과 수확 보상이 늘어요.")
	elif selected_tool == "harvest":
		if plant == null:
			_message("수확할 꽃이 없어요.")
		elif int(plant.get("growth", 0)) < 100:
			_message("조금 더 자라야 해요.")
		else:
			var reward: int = int(FLOWERS[str(plant["kind"])]["reward"])
			if bool(plant.get("fed", false)):
				reward += 5
			if greenhouse_level >= 3:
				reward += 5
			if decorations.has("bench"):
				reward += 3
			var kind := str(plant["kind"])
			harvest_counts[kind] = int(harvest_counts[kind]) + 1
			var collection_complete := int(harvest_counts[kind]) == COLLECTION_GOAL
			if collection_complete:
				reward += COLLECTION_REWARD
			var order_complete := false
			var order: Dictionary = ORDERS[order_number % ORDERS.size()]
			if kind == str(order["kind"]):
				order_progress += 1
				if order_progress >= int(order["count"]):
					reward += int(order["bonus"])
					order_number += 1
					order_progress = 0
					order_complete = true
			leaves += reward
			plants[index] = null
			_play_sound(SOUND_HARVEST)
			if collection_complete and order_complete:
				_message("%s 도감과 꽃 주문 완료! 잎 %d개를 얻었어요." % [FLOWERS[kind]["name"], reward])
			elif collection_complete:
				_message("%s 도감 완성! 잎 %d개를 얻었어요." % [FLOWERS[kind]["name"], reward])
			elif order_complete:
				_message("꽃 주문 완료! 보너스 포함 잎 %d개를 얻었어요." % reward)
			else:
				_message("꽃을 수확하고 잎 %d개를 얻었어요!" % reward)
	elif selected_tool.begins_with("decor_"):
		_message("장식은 정원 앞의 둥근 자리에 놓아 주세요.")
	_redraw_all_plants()
	_refresh_ui()
	_save_game()


func _next_day() -> void:
	_play_sound(SOUND_DAY)
	day += 1
	var weather := _weather_for_day(day)
	var bloomed := 0
	for i in range(PLOT_COUNT):
		var plant = plants[i]
		if plant == null or int(plant.get("growth", 0)) >= 100:
			continue
		if weather == "비":
			plant["water"] = _water_capacity()
		var growth_gain := 5
		if int(plant.get("water", 0)) > 0:
			growth_gain = 28 + (4 if greenhouse_level >= 1 else 0)
			if weather == "맑음":
				growth_gain += 8
			elif weather == "흐림" or weather == "바람":
				growth_gain -= 4
			plant["water"] = int(plant["water"]) - 1
			if weather == "바람":
				plant["water"] = 0
		if bool(plant.get("fed", false)):
			growth_gain += 8
		growth_gain += _flower_trait_growth(str(plant["kind"]), weather)
		if decorations.has("pot"):
			growth_gain += 4
		if decorations.has("lamp") and (weather == "흐림" or weather == "바람"):
			growth_gain += 8
		plant["growth"] = mini(100, int(plant["growth"]) + growth_gain)
		if int(plant["growth"]) >= 100:
			bloomed += 1
	if bloomed > 0:
		_message("%s 날씨에 꽃 %d송이가 피었어요!" % [weather, bloomed])
	elif weather == "비":
		_message("비가 내려 화단이 촉촉해졌어요.")
	elif weather == "바람":
		_message("바람이 불어 흙이 빨리 말랐어요.")
	else:
		_message("%s 아침이에요. 화단을 살펴보세요." % weather)
	_redraw_all_plants()
	_apply_weather_visuals()
	_refresh_ui()
	_save_game()


func _upgrade_greenhouse() -> void:
	if greenhouse_level >= 3:
		_message("온실을 모두 개선했어요.")
		return
	var cost := 40 + greenhouse_level * 30
	if leaves < cost:
		_message("온실 개선에는 잎 %d개가 필요해요." % cost)
		return
	leaves -= cost
	greenhouse_level += 1
	_play_sound(SOUND_UPGRADE)
	match greenhouse_level:
		1: _message("온실 1단계! 물 준 꽃이 더 빨리 자라요.")
		2: _message("온실 2단계! 물주기 효과가 3일 지속돼요.")
		3: _message("온실 3단계! 수확할 때 잎 5개를 더 얻어요.")
	_redraw_all_plants()
	_refresh_ui()
	_save_game()


func _message(value: String) -> void:
	message_label.text = value


func _weather_for_day(value: int) -> String:
	return WEATHER_CYCLE[(value - 1) % WEATHER_CYCLE.size()]


func _flower_trait_growth(kind: String, weather: String) -> int:
	var flower: Dictionary = FLOWERS[kind]
	var bonus := int(flower.get("daily_growth", 0))
	if weather == str(flower.get("favorite_weather", "")):
		bonus += int(flower.get("weather_growth", 0))
	return bonus


func _water_capacity() -> int:
	return 3 if greenhouse_level >= 2 else 2


func _next_step() -> Dictionary:
	for i in range(PLOT_COUNT):
		var plant = plants[i]
		if plant != null and int(plant.get("growth", 0)) >= 100:
			return {
				"title": "지금 할 일 · 꽃 수확하기",
				"hint": "%s가 피었어요. 수확해서 잎을 모으세요." % FLOWERS[str(plant["kind"])]["name"],
				"button": "바로 수확하기",
				"action": "harvest",
				"plot": i
			}
	for i in range(PLOT_COUNT):
		var plant = plants[i]
		if plant != null and int(plant.get("growth", 0)) < 100 and int(plant.get("water", 0)) == 0:
			return {
				"title": "지금 할 일 · 마른 꽃에 물주기",
				"hint": "%s의 흙이 말랐어요. 물을 주면 빠르게 자라요." % FLOWERS[str(plant["kind"])]["name"],
				"button": "바로 물주기",
				"action": "water",
				"plot": i
			}
	for plant in plants:
		if plant != null and int(plant.get("growth", 0)) < 100:
			return {"title": "지금 할 일 · 다음 날 보내기", "hint": "꽃이 자라는 중이에요. 하루가 지나면 더 자라요.", "button": "다음 날로", "action": "day", "plot": -1}
	for i in range(PLOT_COUNT):
		if plants[i] == null:
			var free_seed := leaves < int(FLOWERS["daisy"]["cost"])
			return {
				"title": "지금 할 일 · 꽃 심기",
				"hint": "잎이 없어도 데이지 한 송이는 무료로 심을 수 있어요." if free_seed else "빈 화단에 데이지를 심고 정원을 가꿔 보세요.",
				"button": "무료 데이지 심기" if free_seed else "데이지 심기",
				"action": "plant",
				"plot": i
			}
	return {"title": "지금 할 일 · 정원 살펴보기", "hint": "화단을 눌러 꽃 상태를 확인하세요.", "button": "", "action": "none", "plot": -1}


func _on_guide_action() -> void:
	if selected_tool.begins_with("decor_"):
		selected_tool = "daisy"
		_refresh_ui()
		return
	var step := _next_step()
	match str(step["action"]):
		"harvest", "water", "plant":
			selected_tool = "daisy" if str(step["action"]) == "plant" else str(step["action"])
			_tap_plot(int(step["plot"]))
		"day":
			_next_day()


func _refresh_ui() -> void:
	header_label.text = "작은정원   %d일째 | %s | 잎 %d" % [day, _weather_for_day(day), leaves]
	sound_button.text = "소리 켬" if sound_enabled else "소리 끔"
	sound_button.add_theme_stylebox_override("normal", _style("#b4d5b4" if sound_enabled else "#f3eedf", 12))
	var step := _next_step()
	guide_title.text = str(step["title"])
	detail_label.text = str(step["hint"])
	guide_button.text = str(step["button"])
	guide_button.visible = str(step["action"]) != "none"
	var order: Dictionary = ORDERS[order_number % ORDERS.size()]
	order_label.text = "꽃 주문 · %s %d/%d송이 수확하면 +%d잎" % [FLOWERS[str(order["kind"])]["name"], order_progress, int(order["count"]), int(order["bonus"])]
	day_button.text = "다음 날: %s >" % _weather_for_day(day + 1)
	if greenhouse_level >= 3:
		upgrade_button.text = "온실 최고 단계"
	else:
		upgrade_button.text = "온실 개선 %d잎" % (40 + greenhouse_level * 30)
	for tool in TOOL_ORDER:
		var button: Button = tool_buttons[tool]
		var base_color := "#f3eedf"
		match tool:
			"water": base_color = "#d9eae7"
			"fertilizer": base_color = "#eee3c8"
			"harvest": base_color = "#e9d6b9"
		var tool_style := _style("#a5cfa8" if tool == selected_tool else base_color, 12)
		if tool == selected_tool:
			tool_style.border_color = Color("#39714e")
			tool_style.set_border_width_all(3)
		button.add_theme_stylebox_override("normal", tool_style)
	var decorating := selected_tool.begins_with("decor_")
	decorate_button.add_theme_stylebox_override("normal", _style("#a5cfa8" if decorating else "#e6d5ac", 12))
	if decorating:
		guide_title.text = "지금 할 일 · 정원 꾸미기"
		detail_label.text = "정원 앞의 둥근 장식 자리를 터치하세요."
		guide_button.text = "일반 가꾸기로 돌아가기"
		guide_button.visible = true
	if selected_plot >= 0:
		var plant = plants[selected_plot]
		if plant == null:
			plot_label.text = "선택한 %d번 화단 · 비어 있어요" % (selected_plot + 1)
		else:
			var water_note := "촉촉" if int(plant.get("water", 0)) > 0 else "마름"
			var state := "수확 가능" if int(plant.get("growth", 0)) >= 100 else "성장 %d%%" % int(plant.get("growth", 0))
			plot_label.text = "선택한 %d번 화단 · %s · %s · 흙 %s" % [selected_plot + 1, FLOWERS[str(plant["kind"])]["name"], state, water_note]
		plot_label.visible = true
	else:
		plot_label.visible = false
	if message_label.text.is_empty():
		message_label.text = "주황 테두리는 추천 화단이에요." if int(step["plot"]) >= 0 else "꽃을 키우고 수확해 잎을 모으세요."
	for i in range(PLOT_COUNT):
		var suggested := i == int(step["plot"]) and not decorating
		var inspected := i == selected_plot and not suggested
		highlights[i].visible = suggested or inspected
		if suggested or inspected:
			for edge in highlights[i].get_children():
				(edge as MeshInstance3D).material_override = _material("#f4b447" if suggested else "#7bc8ac")
	for i in range(DECOR_SLOT_COUNT):
		decor_highlights[i].visible = decorating


func _show_info() -> void:
	_play_sound(SOUND_SELECT)
	modal_title.text = "작은정원 시작하기 | v0.9.0"
	modal_body.add_theme_font_size_override("font_size", 22)
	modal_body.text = "[지금 할 일]의 큰 버튼을 누르면 심기, 물주기, 다음 날, 수확을 차례로 진행할 수 있어요. 주황 테두리는 추천 화단이에요.\n\n직접 가꾸고 싶다면 아래 도구를 고른 뒤 화단을 터치하세요. 꽃 주문을 완료하면 보너스 잎을 받고, 잎으로 온실과 정원을 꾸밀 수 있어요.\n\n업데이트 | 2026-10-24: 다음 행동 안내와 추천 화단을 추가했어요. 진행 상황은 이 기기에 자동 저장됩니다. 브라우저 데이터를 지우기 전에는 저장 백업을 이용하세요."
	shop_grid.visible = false
	backup_row.visible = true
	modal.visible = true
	_layout_ui()
	call_deferred("_layout_ui")


func _show_journal() -> void:
	_play_sound(SOUND_SELECT)
	modal_title.text = "꽃 도감"
	modal_body.add_theme_font_size_override("font_size", 21)
	var rows := ["수확한 꽃 | 3송이씩 모아 보세요"]
	for kind in ["daisy", "lavender", "sunflower"]:
		var count := int(harvest_counts[kind])
		var status := "완성" if count >= COLLECTION_GOAL else "%d/3" % count
		rows.append("%s: %d송이 | %s" % [FLOWERS[kind]["name"], count, status])
	rows.append("")
	rows.append("꽃별 첫 3송이: 장식 + 잎 12개")
	rows.append("")
	rows.append("온실 %d/3단계" % greenhouse_level)
	rows.append("1단계: 물 준 꽃 성장 +4")
	rows.append("2단계: 물주기 3일 유지")
	rows.append("3단계: 수확 보상 +5잎")
	rows.append("")
	rows.append("꾸미기 효과 | 종류별 1회")
	rows.append("화분 %s: 매일 성장 +4" % ("사용 중" if decorations.has("pot") else "없음"))
	rows.append("벤치 %s: 수확 +3잎" % ("사용 중" if decorations.has("bench") else "없음"))
	rows.append("등불 %s: 흐림/바람 성장 +8" % ("사용 중" if decorations.has("lamp") else "없음"))
	modal_body.text = "\n".join(rows)
	shop_grid.visible = false
	backup_row.visible = false
	modal.visible = true
	_layout_ui()
	call_deferred("_layout_ui")


func _process(_delta: float) -> void:
	if not browser_import_pending:
		return
	var result = JavaScriptBridge.eval("window.__smallGardenImportResult || ''")
	if result is String and not result.is_empty():
		browser_import_pending = false
		set_process(false)
		JavaScriptBridge.eval("window.__smallGardenImportResult = ''")
		if result != "__cancelled__":
			_apply_backup_json(result)


func _export_backup() -> void:
	_save_game()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(SAVE_PATH), "small-garden-save.json", "application/json")
		_message("백업 파일을 다운로드했어요.")
	else:
		export_dialog.current_file = "small-garden-save.json"
		export_dialog.popup_centered_ratio(0.75)


func _import_backup() -> void:
	if OS.has_feature("web"):
		browser_import_pending = true
		set_process(true)
		JavaScriptBridge.eval("""
			(function () {
			window.__smallGardenImportResult = '';
			const input = document.createElement('input');
			input.type = 'file';
			input.accept = '.json,application/json';
			input.style.display = 'none';
			document.body.appendChild(input);
			input.onchange = () => {
			  if (!input.files || !input.files[0]) { window.__smallGardenImportResult = '__cancelled__'; input.remove(); return; }
			  const reader = new FileReader();
			  reader.onload = () => { window.__smallGardenImportResult = String(reader.result); input.remove(); };
			  reader.onerror = () => { window.__smallGardenImportResult = '읽기 실패'; input.remove(); };
			  reader.readAsText(input.files[0]);
			};
			input.oncancel = () => { window.__smallGardenImportResult = '__cancelled__'; input.remove(); };
			input.click();
			})();
		""")
	else:
		import_dialog.popup_centered_ratio(0.75)


func _write_backup_file(path: String) -> void:
	_save_game()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_message("백업 파일을 저장하지 못했어요.")
		return
	file.store_string(FileAccess.get_file_as_string(SAVE_PATH))
	file.close()
	_message("백업 파일을 저장했어요.")


func _read_backup_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_message("백업 파일을 읽지 못했어요.")
		return
	_apply_backup_json(file.get_as_text())


func _apply_backup_json(content: String) -> bool:
	var restored := _validated_save(content)
	if restored.is_empty():
		_message("올바른 작은정원 백업 파일이 아니에요.")
		return false
	_apply_save(restored)
	_redraw_all_plants()
	_redraw_all_decorations()
	_apply_weather_visuals()
	_refresh_ui()
	_save_game()
	modal.visible = false
	_message("백업을 불러왔어요.")
	return true


func _open_url(url: String) -> void:
	_play_sound(SOUND_SELECT)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s', '_blank', 'noopener,noreferrer');" % url)
	else:
		OS.shell_open(url)


func _load_game() -> void:
	plants.clear()
	for i in range(PLOT_COUNT):
		plants.append(null)
	decorations.clear()
	for i in range(DECOR_SLOT_COUNT):
		decorations.append(null)
	if not FileAccess.file_exists(SAVE_PATH):
		plants[1] = {"kind": "daisy", "growth": 100, "water": 0, "fed": false}
		plants[6] = {"kind": "lavender", "growth": 55, "water": 1, "fed": false}
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data := _validated_save(file.get_as_text())
	if not data.is_empty():
		_apply_save(data)


func _validated_save(content: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(content) != OK:
		return {}
	var data = parser.data
	if not data is Dictionary or int(data.get("version", -1)) not in [1, 2, 3, SAVE_VERSION]:
		return {}
	var saved_plants = data.get("plants", null)
	if not saved_plants is Array or saved_plants.size() != PLOT_COUNT:
		return {}
	var saved_counts = data.get("harvest_counts", {})
	if not saved_counts is Dictionary:
		return {}
	var clean_counts := {}
	for kind in ["daisy", "lavender", "sunflower"]:
		clean_counts[kind] = clampi(int(saved_counts.get(kind, 0)), 0, 1000000)
	var clean_order_number := clampi(int(data.get("order_number", 0)), 0, 1000000)
	var order: Dictionary = ORDERS[clean_order_number % ORDERS.size()]
	var clean_order_progress := clampi(int(data.get("order_progress", 0)), 0, int(order["count"]) - 1)
	var saved_decorations = data.get("decorations", null)
	if int(data["version"]) < SAVE_VERSION and saved_decorations == null:
		saved_decorations = [null, null, null]
	if not saved_decorations is Array or saved_decorations.size() != DECOR_SLOT_COUNT:
		return {}
	var clean_decorations := []
	for decoration in saved_decorations:
		if decoration == null or DECORATIONS.has(str(decoration)):
			clean_decorations.append(decoration)
		else:
			return {}
	var clean_plants := []
	for plant in saved_plants:
		if plant == null:
			clean_plants.append(null)
		elif plant is Dictionary and FLOWERS.has(str(plant.get("kind", ""))):
			clean_plants.append({
				"kind": str(plant["kind"]),
				"growth": clampi(int(plant.get("growth", 0)), 0, 100),
				"water": clampi(int(plant.get("water", 0)), 0, 3),
				"fed": bool(plant.get("fed", false))
			})
		else:
			return {}
	return {
		"day": clampi(int(data.get("day", 1)), 1, 1000000),
		"leaves": clampi(int(data.get("leaves", 30)), 0, 1000000),
		"greenhouse_level": clampi(int(data.get("greenhouse_level", 0)), 0, 3),
		"harvest_counts": clean_counts,
		"order_number": clean_order_number,
		"order_progress": clean_order_progress,
		"sound_enabled": bool(data.get("sound_enabled", true)),
		"decorations": clean_decorations,
		"plants": clean_plants
	}


func _apply_save(data: Dictionary) -> void:
	day = int(data["day"])
	leaves = int(data["leaves"])
	greenhouse_level = int(data["greenhouse_level"])
	harvest_counts = data["harvest_counts"]
	order_number = int(data["order_number"])
	order_progress = int(data["order_progress"])
	sound_enabled = bool(data["sound_enabled"])
	if music_player != null and not sound_enabled:
		music_player.stop()
		for player in sound_players:
			player.stop()
		audio_unlocked = false
	decorations = data["decorations"]
	plants = data["plants"]


func _save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_message("저장하지 못했어요. 저장 공간을 확인해 주세요.")
		return
	var data := {
		"version": SAVE_VERSION,
		"day": day,
		"leaves": leaves,
		"greenhouse_level": greenhouse_level,
		"harvest_counts": harvest_counts,
		"order_number": order_number,
		"order_progress": order_progress,
		"sound_enabled": sound_enabled,
		"decorations": decorations,
		"plants": plants
	}
	file.store_string(JSON.stringify(data))
	file.flush()
