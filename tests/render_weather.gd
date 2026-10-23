extends SceneTree


func _initialize() -> void:
	call_deferred("_show_rain")


func _show_rain() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.day = 2
	game.leaves = 26
	for i in range(game.PLOT_COUNT):
		game.plants[i] = null
	game.plants[0] = {"kind": "daisy", "growth": 35, "water": 2, "fed": false}
	game.plants[5] = {"kind": "lavender", "growth": 100, "water": 2, "fed": false}
	game.plants[9] = {"kind": "sunflower", "growth": 28, "water": 2, "fed": false}
	game._redraw_all_plants()
	game._apply_weather_visuals()
	game._refresh_ui()
	game._message("비가 내려 화단이 촉촉해졌어요.")
