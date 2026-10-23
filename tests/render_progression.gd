extends SceneTree


func _initialize() -> void:
	call_deferred("_show_progression")


func _show_progression() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.day = 11
	game.leaves = 36
	game.greenhouse_level = 3
	game.exhibition_count = 3
	game.exhibition_progress = {"daisy": 1, "lavender": 0, "sunflower": 0}
	game.order_number = 2
	game.order_progress = 1
	game.decorations = ["pot", "bench", "lamp"]
	for i in range(game.PLOT_COUNT):
		game.plants[i] = null
	for kind in ["daisy", "lavender", "sunflower"]:
		game.harvest_counts[kind] = 3
	game.plants[1] = {"kind": "daisy", "growth": 100, "water": 1, "fed": false}
	game.plants[6] = {"kind": "lavender", "growth": 100, "water": 1, "fed": false}
	game.plants[10] = {"kind": "sunflower", "growth": 100, "water": 1, "fed": false}
	game.selected_plot = -1
	game._redraw_all_plants()
	game._redraw_all_decorations()
	game._apply_weather_visuals()
	game._refresh_ui()
