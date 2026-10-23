extends SceneTree


func _initialize() -> void:
	call_deferred("_show_preview")


func _show_preview() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.day = 1
	game.leaves = 30
	game.greenhouse_level = 0
	game.exhibition_count = 0
	game.exhibition_progress = {"daisy": 0, "lavender": 0, "sunflower": 0}
	game.harvest_counts = {"daisy": 0, "lavender": 0, "sunflower": 0}
	game.order_number = 0
	game.order_progress = 0
	game.decorations = [null, null, null]
	for i in range(game.PLOT_COUNT):
		game.plants[i] = null
	game.plants[1] = {"kind": "daisy", "growth": 100, "water": 0, "fed": false}
	game.plants[6] = {"kind": "lavender", "growth": 55, "water": 1, "fed": false}
	game.selected_plot = -1
	game.message_label.text = ""
	game._redraw_all_plants()
	game._redraw_all_decorations()
	game._apply_weather_visuals()
	game._refresh_ui()
