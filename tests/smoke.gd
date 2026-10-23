extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://garden_save.json"
	var previous := ""
	var had_save := FileAccess.file_exists(save_path)
	if had_save:
		previous = FileAccess.get_file_as_string(save_path)
	var scene = load("res://scenes/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	game.day = 1
	game._apply_weather_visuals()
	assert(not game.rain_effects.visible and not game.wind_effects.visible)
	game.leaves = 30
	game.greenhouse_level = 0
	game.order_number = 0
	game.order_progress = 0
	game.exhibition_count = 0
	game.exhibition_progress = {"daisy": 0, "lavender": 0, "sunflower": 0}
	game.harvest_counts = {"daisy": 0, "lavender": 0, "sunflower": 0}
	game.decorations = [null, null, null]
	for i in range(game.PLOT_COUNT):
		game.plants[i] = null
	game._select_tool("daisy")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = game.camera.unproject_position(game.plot_positions[0] + Vector3(0, 0.36, 0))
	game._unhandled_input(tap)
	assert(game.selected_plot == 0)
	assert(game.leaves == 26)
	assert(game.plants[0]["kind"] == "daisy")
	game._select_tool("water")
	game._tap_plot(0)
	game._next_day()
	assert(game.rain_effects.visible and not game.wind_effects.visible)
	assert(is_equal_approx(game.sun_light.light_energy, 0.61))
	assert(game.rain_drops.size() == 88)
	var rain_y: float = game.rain_drops[0].position.y
	game._process(0.25)
	assert(not is_equal_approx(game.rain_drops[0].position.y, rain_y))
	game._next_day()
	assert(not game.rain_effects.visible and not game.wind_effects.visible)
	assert(is_equal_approx(game.sun_light.light_energy, 0.86))
	assert(game.plants[0]["growth"] == 76)
	game._tap_plot(0)
	game._next_day()
	game._next_day()
	assert(game.wind_effects.visible and not game.rain_effects.visible)
	assert(game.plants[0]["growth"] == 100)
	game._select_tool("harvest")
	game._tap_plot(0)
	assert(game.leaves == 37)
	assert(game.harvest_counts["daisy"] == 1)
	assert(game.order_number == 0)
	assert(game.order_progress == 1)
	assert(game.plants[0] == null)
	game._show_decor_shop()
	assert(game.shop_grid.visible)
	game._choose_decoration("pot")
	assert(not game.modal.visible)
	game.last_tap_msec = 0
	tap.position = game.camera.unproject_position(game.decor_positions[0] + Vector3(0, 0.36, 0))
	game._unhandled_input(tap)
	assert(game.decorations[0] == "pot")
	assert(game.leaves == 23)
	assert(game.decor_hosts[0].get_child_count() > 0)
	game._tap_decor(0)
	assert(game.leaves == 23)
	game._choose_decoration("bench")
	game._tap_decor(1)
	assert(game.decorations[1] == null)
	assert(game.leaves == 23)
	assert(FileAccess.file_exists(save_path))
	var backup := FileAccess.get_file_as_string(save_path)
	game.plants[3] = {"kind": "lavender", "growth": 0, "water": 0, "fed": false}
	game.day = 1
	game._next_day()
	assert(game.plants[3]["growth"] == 44)
	game.plants[4] = {"kind": "sunflower", "growth": 0, "water": 2, "fed": false}
	game.day = 2
	game._next_day()
	assert(game.plants[4]["growth"] == 52)
	game.plants[2] = {"kind": "lavender", "growth": 0, "water": 0, "fed": false}
	game.day = 5
	game._next_day()
	assert(game.plants[2]["growth"] == 9)
	game.decorations[1] = "pot"
	game.plants[2]["growth"] = 0
	game.day = 5
	game._next_day()
	assert(game.plants[2]["growth"] == 9)
	game.decorations[1] = "lamp"
	game.plants[2]["growth"] = 0
	game.day = 8
	game._next_day()
	assert(game.plants[2]["growth"] == 17)
	game.decorations[2] = "bench"
	game.plants[2]["growth"] = 100
	game._select_tool("harvest")
	var before_harvest: int = game.leaves
	game._tap_plot(2)
	assert(game.leaves - before_harvest == 18)
	game._show_journal()
	assert(game.modal_body.text.contains("벤치 사용 중"))
	assert(game._apply_backup_json(backup))
	assert(game.decorations == ["pot", null, null])
	assert(game.wind_effects.visible and not game.rain_effects.visible)
	game.leaves = 300
	game._upgrade_greenhouse()
	game._upgrade_greenhouse()
	game._upgrade_greenhouse()
	assert(game.greenhouse_level == 3)
	assert(game.leaves == 90)
	assert(game.greenhouse_tiers[2].visible)
	game._select_tool("harvest")
	for i in range(2):
		game.plants[0] = {"kind": "daisy", "growth": 100, "water": 0, "fed": false}
		game._tap_plot(0)
	assert(game.harvest_counts["daisy"] == 3)
	assert(game.order_number == 1)
	assert(game.order_progress == 0)
	assert(game.leaves == 150)
	assert(game.collection_badges["daisy"].visible)
	game._choose_decoration("bench")
	game._tap_decor(1)
	assert(game.decorations[1] == "bench")
	assert(game.leaves == 126)
	game._choose_decoration("remove")
	game._tap_decor(0)
	assert(game.decorations[0] == null)
	assert(game.leaves == 133)
	game.plants[0] = {"kind": "daisy", "growth": 0, "water": 0, "fed": false}
	game._select_tool("water")
	game._tap_plot(0)
	assert(game.plants[0]["water"] == 3)
	game._show_journal()
	assert(game.modal_body.text.contains("완성"))
	assert(not game.backup_row.visible)
	game.leaves = 1
	assert(not game._apply_backup_json("not a save"))
	assert(game.leaves == 1)
	assert(game._apply_backup_json(backup))
	assert(game.leaves == 23)
	assert(game.harvest_counts["daisy"] == 1)
	assert(game.order_number == 0)
	assert(game.order_progress == 1)
	assert(game.decorations == ["pot", null, null])
	assert(not game.collection_badges["daisy"].visible)
	var version_three: Dictionary = JSON.parse_string(backup)
	version_three["version"] = 3
	version_three.erase("decorations")
	assert(game._apply_backup_json(JSON.stringify(version_three)))
	assert(game.decorations == [null, null, null])
	var previous_version: Dictionary = JSON.parse_string(backup)
	previous_version["version"] = 2
	previous_version.erase("order_number")
	previous_version.erase("order_progress")
	previous_version.erase("decorations")
	assert(game._apply_backup_json(JSON.stringify(previous_version)))
	assert(game.order_number == 0)
	assert(game.order_progress == 0)
	assert(game.decorations == [null, null, null])
	var legacy: Dictionary = JSON.parse_string(backup)
	legacy["version"] = 1
	legacy.erase("harvest_counts")
	legacy.erase("order_number")
	legacy.erase("order_progress")
	legacy.erase("decorations")
	assert(game._apply_backup_json(JSON.stringify(legacy)))
	assert(game.harvest_counts["daisy"] == 0)
	assert(game.order_progress == 0)
	assert(game._apply_backup_json(backup))
	var version_four: Dictionary = JSON.parse_string(backup)
	version_four["version"] = 4
	version_four.erase("exhibition_count")
	version_four.erase("exhibition_progress")
	assert(game._apply_backup_json(JSON.stringify(version_four)))
	assert(game.exhibition_count == 0)
	game.queue_free()
	var loaded = scene.instantiate()
	root.add_child(loaded)
	assert(loaded.day == 5)
	assert(loaded.wind_effects.visible and not loaded.rain_effects.visible)
	assert(loaded.leaves == 23)
	assert(loaded.harvest_counts["daisy"] == 1)
	assert(loaded.order_number == 0)
	assert(loaded.order_progress == 1)
	assert(loaded.decorations == ["pot", null, null])
	loaded.greenhouse_level = 3
	loaded.exhibition_progress = {"daisy": 2, "lavender": 1, "sunflower": 0}
	loaded.plants[0] = {"kind": "sunflower", "growth": 100, "water": 0, "fed": false}
	loaded._select_tool("harvest")
	loaded._tap_plot(0)
	assert(loaded.exhibition_count == 1)
	assert(loaded.exhibition_progress["daisy"] == 0)
	assert(loaded.exhibition_lights[0].visible)
	assert(loaded.exhibition_tiers[0].visible)
	assert(loaded._current_exhibition()["name"] == "비향기 전시")
	loaded.queue_free()
	var festival_loaded = scene.instantiate()
	root.add_child(festival_loaded)
	assert(festival_loaded.exhibition_count == 1)
	festival_loaded.leaves = 100
	for i in range(festival_loaded.PLOT_COUNT):
		festival_loaded.plants[i] = null
	var next_step: Dictionary = festival_loaded._next_step()
	assert(next_step["action"] == "plant" and next_step["seed"] == "lavender")
	festival_loaded._on_guide_action()
	assert(festival_loaded.plants[int(next_step["plot"])]["kind"] == "lavender")
	festival_loaded.queue_free()
	if had_save:
		var restore := FileAccess.open(save_path, FileAccess.WRITE)
		assert(restore != null)
		restore.store_string(previous)
		restore.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("SMOKE PASS: touch, animated rain, flower traits, collection, orders, decor, upgrades, repeating exhibitions, v1-v4 migration, save and restore")
	quit()
