extends SceneTree
## Unified four-tab distributor, world HUD, mobile controls and kiosk scaling.
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool, label: String) -> bool:
    if ok:
        print("PASS: UNIFIED UI " + label)
    else:
        push_error("FAIL: UNIFIED UI " + label)
    return ok
func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if not _check(scene != null, "main Godot scene loads"):
        quit(1)
        return
    var game: Node = scene.instantiate()
    root.add_child(game)
    await process_frame
    var ui = game.get("ui")
    if not _check(ui != null and ui.world_ui_atlas != null and ui.status_plate != null, "approved world HUD sprite atlas and floating status plate imported"):
        quit(1)
        return
    if not _check(not ui.top_panel.visible and not ui.banner_art.visible and not ui.hud.visible, "permanent game logo and top gameplay-covering ribbon removed"):
        quit(1)
        return
    if not _check(not ui.camp_button.visible and not ui.market_button.visible and not ui.gear_button.visible, "bottom-right Camp / Market / Gear shortcut icons removed"):
        quit(1)
        return
    if not _check(ui.sound_button.visible and ui.mixer_button.visible and ui.save_button.visible and ui.fullscreen_button.visible, "floating four utility icons remain enabled"):
        quit(1)
        return
    if not _check(ui.message_art.texture.atlas == ui.world_ui_atlas and ui.sound_button.get_node("Approved_sound").texture.atlas == ui.world_ui_atlas, "world message and utility icons share one approved sprite atlas"):
        quit(1)
        return
    ui.reveal_message("Five-second notification")
    ui._process(4.0)
    if not _check(ui.hint_seconds > 0.0 and ui.message.modulate.a > 0.95, "message remains visible during first four seconds"):
        quit(1)
        return
    ui._process(0.8)
    if not _check(ui.message.modulate.a < 0.5, "message begins fading before five seconds"):
        quit(1)
        return
    ui._process(0.3)
    if not _check(ui.message.modulate.a == 0.0 and ui.message_art.modulate.a == 0.0, "notification fades completely after five seconds"):
        quit(1)
        return
    game.call("_say", "New logging message")
    if not _check(ui.hint_seconds == 5.0 and ui.message.modulate.a == 1.0, "new actions reset the five-second message lifetime"):
        quit(1)
        return
    var stall: Sprite2D = game.get_node("Prop_MarketDistributor")
    if not _check(absf(stall.texture.get_width() * stall.scale.x - 285.6) < 1.0, "world distributor physically reduced to exactly seventy percent of former width"):
        quit(1)
        return

    var ledger = ui.shop_a
    ui.open_menu("MARKET")
    if not _check(ledger.visible and not ui.menu_panel.visible and ledger.page == "sell" and ledger.filtered_items.size() == 7, "Sell Timber uses one shared market frame with all seven products"):
        quit(1)
        return
    var frame_id: int = ledger.get_instance_id()
    ui._choose_market_page("contracts")
    if not _check(ledger.get_instance_id() == frame_id and ledger.page == "contracts" and ledger.filtered_items.size() >= 4, "Contracts changes content without rebuilding shared header/frame"):
        quit(1)
        return
    ui._choose_market_page("shop")
    if not _check(ledger.get_instance_id() == frame_id and ledger.page == "shop" and ledger.filtered_items.size() == 17, "Shop displays all distributor equipment inside the same frame"):
        quit(1)
        return
    ui._choose_market_page("supplies")
    if not _check(ledger.get_instance_id() == frame_id and ledger.page == "supplies" and ledger.filtered_items.size() >= 5, "Supplies and services share identical header/navigation"):
        quit(1)
        return

    ui.handle_controller_button(JOY_BUTTON_LEFT_SHOULDER)
    if not _check(ledger.page == "shop", "LB returns to previous tab"):
        quit(1)
        return
    ui.handle_controller_button(JOY_BUTTON_RIGHT_SHOULDER)
    if not _check(ledger.page == "supplies", "RB advances to next tab"):
        quit(1)
        return

    game.distributor.yard_stock[0] = 3
    ui._choose_market_page("sell")
    ledger.select_item_by_id("sale_0")
    ledger.adjust_quantity(2)
    if not _check(ledger.qty_minus.visible and ledger.qty_plus.visible and ledger.qty_max.visible and ledger.qty_display.text == "2 / 3", "touchable Sell quantity minus, plus, MAX controls show selected stock"):
        quit(1)
        return
    ledger._request_purchase()
    if not _check(game.distributor.available(0) == 3 and ledger.pending_id == "sale_0", "first A confirms sale but does not consume timber"):
        quit(1)
        return
    ledger._request_purchase()
    if not _check(game.distributor.available(0) == 1 and game.get("cash") == 2 * game.progression.market_price(0), "second A sells chosen quantity at market price without duplication"):
        quit(1)
        return
    if not _check(ledger.qty_display.text == "0 / 1", "touch quantity resets after successful sale"):
        quit(1)
        return

    var first_offer: Dictionary = game.distributor.contract_offers[0]
    ui._choose_market_page("contracts")
    ledger.select_item_by_id("offer_" + str(first_offer["id"]))
    ledger._request_purchase()
    ledger._request_purchase()
    if not _check(game.distributor.active_contracts.size() == 1 and game.distributor.contract_offers.size() == 3, "buyer offer can be accepted through unified contract panel"):
        quit(1)
        return

    ui.resize_layout(Vector2(844.0, 390.0))
    if not _check(ledger.compact and ledger.category_mobile.visible and ledger.item_panel.size.x > 210.0 and ledger.detail_panel.size.x > 200.0, "landscape phone uses touch-friendly split inventory/details"):
        quit(1)
        return
    if not _check(ui.fullscreen_button.position.x + ui.fullscreen_button.size.x <= 844.0 and ui.status_plate.size.x < 400.0, "floating HUD elements fit within 844px viewport"):
        quit(1)
        return
    ui.close_menu()
    if not _check(not ui.is_open and not ledger.visible, "B/close returns to game without invisible menu controls"):
        quit(1)
        return
    print("PASS: UNIFIED UI world overlay, four-tab market, touch/controller transactions and message expiry complete")
    quit(0)
