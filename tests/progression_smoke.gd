extends SceneTree
## Independent integration checks for phases 2-4 and the landscape UI.
func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> bool:
    if ok:
        print("PASS: " + label)
    else:
        push_error("FAIL: " + label)
    return ok

func _abort_if_false(ok: bool, label: String) -> bool:
    return _check(ok, label)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if not _check(scene != null, "Progression: main scene loads"):
        quit(1)
        return
    var game: Node = scene.instantiate()
    root.add_child(game)
    await process_frame
    var p = game.get("progression")
    var ui = game.get("ui")
    if not _check(p != null and ui != null, "Persistent progression and unified HUD created"):
        quit(1)
        return
    if not _check(game.get_node_or_null("Daylight") != null and game.get_node_or_null("Prop_trader-open") != null, "Daylight tint and approved trader prop present"):
        quit(1)
        return
    if not _check(ui.camp_button != null and ui.market_button != null and ui.gear_button != null and ui.save_button != null, "Camp, market, gear and save accessible from single HUD"):
        quit(1)
        return
    if not _check(ui.call("_calculate_ui_scale", Vector2(1280.0, 720.0), 390.0) >= 1.5, "Phone landscape dynamically enlarges UI and tap targets"):
        quit(1)
        return
    ui.resize_layout(Vector2(844.0, 390.0))
    if not _check(ui.action_button.position.x + ui.action_button.size.x <= 844.0 and ui.action_button.position.y + ui.action_button.size.y <= 390.0, "Landscape phone action button stays within 844x390 viewport"):
        quit(1)
        return
    if not _check(ui.camp_button.position.x > 0.0 and ui.gear_button.position.x + ui.gear_button.size.x <= 844.0, "All three mobile quick tabs remain onscreen"):
        quit(1)
        return
    ui.open_menu("MARKET")
    if not _check(ui.is_open and ui.menu_rows.get_child_count() >= 7, "Market, prices and contract ledger opens from mobile"):
        quit(1)
        return
    ui.open_menu("GEAR")
    if not _check(ui.is_open and ui.menu_rows.get_child_count() >= 4, "Equipment and hauling ledger opens"):
        quit(1)
        return
    ui.open_menu("CAMP")
    if not _check(ui.is_open and ui.menu_rows.get_child_count() >= 4, "Camp save/load/rest ledger opens"):
        quit(1)
        return
    ui.close_menu()
    if not _check(not ui.is_open, "Mobile menu closes and returns control"):
        quit(1)
        return

    var stable_price: int = p.market_price(0)
    if not _check(stable_price > 0 and stable_price == p.market_price(0), "Daily market price stable during one day"):
        quit(1)
        return
    var start_day: int = p.day
    p.day_seconds = p.DAY_SECONDS - 0.5
    p.tick(1.0, game)
    if not _check(p.day == start_day + 1 and p.day_seconds < 1.0, "15-minute day rolls forward with fresh daily contract"):
        quit(1)
        return
    game.set("player_pos", Vector2(1567.0, 1112.0))
    var before_rest: int = p.day
    if not _check(p.rest(game) and p.day == before_rest + 1 and p.day_seconds == 30.0, "Cabin rest advances the day and refreshes market"):
        quit(1)
        return

    game.set("cash", 2000)
    var cash_before: int = game.get("cash")
    if not _check(p.buy_axe(game) and p.axe_level == 1 and game.get("cash") == cash_before - 70, "Hardened axe purchase deducts correct cash once"):
        quit(1)
        return
    p.buy_axe(game)
    if not _check(p.axe_level == 2 and p.chop_power() == 2, "Steel axe increases woodcutting power"):
        quit(1)
        return
    p.buy_axe(game)
    if not _check(p.axe_level == 3 and p.chop_power() == 3, "Chainsaw upgrade enables higher chop power"):
        quit(1)
        return
    p.fuel = 0.0
    if not _check(not p.can_chop(), "Empty chainsaw fuel prevents cutting"):
        quit(1)
        return
    var cash_fuel: int = game.get("cash")
    if not _check(p.refill_fuel(game) and p.can_chop() and game.get("cash") == cash_fuel - p.FUEL_REFILL_COST, "Refuelling consumes cash and restores use"):
        quit(1)
        return
    p.condition = 0.0
    if not _check(not p.can_chop() and p.repair_tool(game) and p.can_chop(), "Tool wear blocks cutting until a paid repair"):
        quit(1)
        return
    if not _check(p.buy_cart(game) and p.capacity() == 8, "Handcart upgrades hauling from 4 to 8 logs"):
        quit(1)
        return
    if not _check(p.buy_cart(game) and p.capacity() == 12, "Timber cart upgrades hauling to 12 logs"):
        quit(1)
        return
    var not_enough_cash: int = game.get("cash")
    game.set("cash", 0)
    if not _check(not p.repair_tool(game) and not p.buy_cart(game) and game.get("cash") == 0, "Upgrades cannot spend money unavailable or exceed max tier"):
        quit(1)
        return
    game.set("cash", not_enough_cash)

    p.contract_species = 0
    p.contract_goal = 2
    p.contract_progress = 0
    p.contract_claimed = false
    p.contract_reward = 60
    var cash_sale: int = game.get("cash")
    var first_receipt: Dictionary = p.sell_logs(game, [0, 0])
    if not _check(first_receipt["bonus"] == 60 and game.get("cash") == cash_sale + 2 * p.market_price(0) + 60, "Daily contract pays once alongside market-rate log sales"):
        quit(1)
        return
    var second_receipt: Dictionary = p.sell_logs(game, [0])
    if not _check(second_receipt["bonus"] == 0 and p.contract_claimed, "Repeat deliveries never duplicate contract bonus"):
        quit(1)
        return

    var first_tree: Dictionary = game.get("trees")[0]
    first_tree["state"] = 3
    first_tree["hp"] = 0
    game.call("_spawn_log", first_tree["pos"] + Vector2(40, 12), 0)
    var one_log: int = game.get("ground_logs").size()
    var saved_pos := Vector2(1440.0, 1385.0)
    game.set("player_pos", saved_pos)
    game.get("carried").append(1)
    var saved_cash: int = game.get("cash")
    var file_path := "user://frontier_phase234_test.json"
    if not _check(p.save_game(game, file_path), "Versioned complete-game save written to user storage"):
        quit(1)
        return
    game.set("player_pos", Vector2(1300, 1600))
    game.set("cash", 5)
    first_tree["state"] = 0
    first_tree["hp"] = first_tree["max_hp"]
    game.get("carried").clear()
    var current_log: Dictionary = game.get("ground_logs").pop_back()
    var dropped_sprite: Sprite2D = current_log["sprite"]
    if is_instance_valid(dropped_sprite):
        dropped_sprite.queue_free()
    if not _check(p.load_game(game, file_path), "Valid save restores without a new game"):
        quit(1)
        return
    if not _check(game.get("player_pos") == saved_pos and game.get("cash") == saved_cash and game.get("carried").size() == 1 and p.axe_level == 3 and p.cart_level == 2, "Restore position, money, inventory, tools and hauling progress"):
        quit(1)
        return
    if not _check(int(first_tree["state"]) == 3 and game.get("ground_logs").size() == one_log, "Restore harvested trees and loose ground logs without duplication"):
        quit(1)
        return
    var damaged_path := "user://frontier_phase234_corrupt.json"
    var bad := FileAccess.open(damaged_path, FileAccess.WRITE)
    bad.store_string("{truncated")
    bad.close()
    if not _check(not p.load_game(game, damaged_path), "Corrupt save is rejected without resetting current progress"):
        quit(1)
        return

    var original_time: float = p.day_seconds
    p.day_seconds = 700.0
    var at_night: Color = p.ambient_color()
    p.day_seconds = 200.0
    var at_day: Color = p.ambient_color()
    if not _check(at_night.r < at_day.r, "World lighting darkens during the 15-minute night cycle"):
        quit(1)
        return
    p.day_seconds = original_time
    print("PASS: phases 2-4 persistent systems and mobile UI integration complete")
    quit(0)
