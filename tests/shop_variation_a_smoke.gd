extends SceneTree
## Approval gate for Frontier Mountain's Variation A shop and gamepad UX.
func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> bool:
    if ok:
        print("PASS: VARIATION A " + label)
    else:
        push_error("FAIL: VARIATION A " + label)
    return ok

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if not _check(scene != null, "scene loads"):
        quit(1)
        return
    var game: Node = scene.instantiate()
    root.add_child(game)
    await process_frame
    var ui = game.get("ui")
    var shop = ui.shop_a
    if not _check(shop != null and shop.item_icon_atlas != null, "approved item artwork and independent shop screen load"):
        quit(1)
        return
    ui.open_menu("MARKET")
    ui._choose_market_page("shop")
    if not _check(ui.is_open and shop.visible and not ui.menu_panel.visible, "Variation A replaces previous stacked shop rather than overlapping it"):
        quit(1)
        return
    if not _check(shop.category_buttons.size() == 10 and shop.filtered_items.size() == 17, "all 17 distributor items visible under five categories"):
        quit(1)
        return
    if not _check(shop.selected_item_id == "handcart" and shop.detail_icon.texture != null and shop.buy_button.text.begins_with("BUY"), "approved Log Cart is initial selected item with illustrated detail and price"):
        quit(1)
        return
    var axe_row: Button = shop.item_rows.get_node("Item_sharp")
    var axe_icon: TextureRect = axe_row.get_node("ApprovedThumbnail_sharp")
    var axe_name: Label = axe_row.get_node("ProductName")
    var axe_price: Label = axe_row.get_node("ProductPrice")
    print("ROW_DEBUG icon=", axe_icon.position, "/", axe_icon.size, " name=", axe_name.position, "/", axe_name.size, " price=", axe_price.position, "/", axe_price.size, " row=", axe_row.size)
    if not _check(axe_icon.position.x + axe_icon.size.x <= axe_name.position.x and axe_name.position.x + axe_name.size.x <= axe_price.position.x, "Approved item icon, product name and price occupy separate columns"):
        quit(1)
        return
    if not _check(shop.buy_button.get_node_or_null("ApprovedCarvedWood") != null and shop.nav_bar.get_child(0).get_node_or_null("ApprovedCarvedWood") != null, "Variation A purchase and tabs use approved carved-wood textures instead of flat buttons"):
        quit(1)
        return
    if not _check(shop.category_panel.visible and not shop.category_mobile.visible, "desktop shows Variation A's category rail"):
        quit(1)
        return
    var selected_before: int = shop.active_index
    shop.handle_button(JOY_BUTTON_DPAD_DOWN)
    if not _check(shop.active_index == selected_before + 1 and shop.list_buttons[shop.active_index].has_focus(), "D-pad changes item selection and visible gamepad focus"):
        quit(1)
        return
    # End-to-end synthetic Kishi button event routed through the game node.
    var kishi := InputEventJoypadButton.new()
    kishi.button_index = JOY_BUTTON_DPAD_DOWN
    kishi.pressed = true
    game.call("_input", kishi)
    if not _check(shop.active_index == selected_before + 2, "Game forwards Kishi D-pad events into shop selection rather than moving lumberjack"):
        quit(1)
        return
    shop.handle_button(JOY_BUTTON_DPAD_UP)
    shop.handle_button(JOY_BUTTON_DPAD_UP)
    if not _check(shop.active_index == selected_before, "D-pad can navigate back up"):
        quit(1)
        return
    shop.choose_category("tools")
    if not _check(shop.filtered_items.size() >= 4 and shop.filtered_items.size() < 17, "tools filter limits catalog"):
        quit(1)
        return
    for entry in shop.filtered_items:
        if not _check(str(entry["category"]) == "tools", "tools category never shows unrelated items"):
            quit(1)
            return
    shop.choose_category("hauling")
    if not _check(shop.filtered_items.size() >= 3, "hauling category shows carts and mobility equipment"):
        quit(1)
        return
    shop.choose_category("all")
    shop.select_item_by_id("handcart")
    game.set("cash", 500)
    shop.refresh_data()
    var before_cash: int = game.get("cash")
    if not _check(shop.buy_button.text == "BUY $175" and not shop.buy_button.disabled, "cart purchase price and affordability shown"):
        quit(1)
        return
    shop.handle_button(JOY_BUTTON_A)
    if not _check(shop.pending_id == "handcart" and int(game.get("cash")) == before_cash and not game.distributor.is_owned("handcart"), "first A asks for confirmation without spending"):
        quit(1)
        return
    shop.handle_button(JOY_BUTTON_B)
    if not _check(shop.pending_id == "" and ui.is_open, "B cancels transaction and keeps shop open"):
        quit(1)
        return
    shop.handle_button(JOY_BUTTON_A)
    shop.handle_button(JOY_BUTTON_A)
    if not _check(game.distributor.is_owned("handcart") and int(game.get("cash")) == before_cash - 175 and game.progression.capacity() >= 8, "second A confirms an actual $175 purchase and activates hauling upgrade"):
        quit(1)
        return
    if not _check(shop.buy_button.disabled and shop.buy_button.text == "PURCHASED", "owned cart cannot be bought twice"):
        quit(1)
        return
    # Controller shoulders move between shop and other distributor pages.
    ui.handle_controller_button(JOY_BUTTON_RIGHT_SHOULDER)
    if not _check(ui.market_view == "supplies" and shop.visible and not ui.menu_panel.visible and shop.page == "supplies", "RB changes page content without changing header or frame"):
        quit(1)
        return
    ui.handle_controller_button(JOY_BUTTON_LEFT_SHOULDER)
    if not _check(ui.market_view == "shop" and shop.visible, "LB returns to approved shop screen"):
        quit(1)
        return
    # The analog stick can browse without walking the lumberjack.
    shop.select_item_by_id("sharp")
    var analog_before: int = shop.active_index
    shop.set_axis(JOY_AXIS_LEFT_Y, 0.92)
    if not _check(shop.active_index == analog_before + 1, "left analog stick moves highlighted selection"):
        quit(1)
        return
    shop.set_axis(JOY_AXIS_LEFT_Y, 0.0)
    # Compact phone-landscape geometry must preserve list + detail panels.
    ui.resize_layout(Vector2(844.0, 390.0))
    if not _check(shop.compact and shop.category_mobile.visible and not shop.category_panel.visible, "phone landscape replaces vertical rail with five responsive category chips"):
        quit(1)
        return
    print("LAYOUT_DEBUG item=", shop.item_panel.size, " detail=", shop.detail_panel.size, " buy_pos=", shop.buy_button.position, " buy_size=", shop.buy_button.size, " ui_scale=", ui.ui_scale)
    if not _check(shop.item_panel.size.x > 210.0 and shop.detail_panel.size.x > 200.0 and shop.buy_button.position.y + shop.buy_button.size.y <= shop.detail_panel.size.y, "phone shop retains side-by-side inventory and touch-safe purchase panel"):
        quit(1)
        return
    shop.handle_button(JOY_BUTTON_B)
    if not _check(not ui.is_open and not shop.visible, "B closes shop without trapping gamepad focus"):
        quit(1)
        return
    print("PASS: VARIATION A end-to-end market layout, controller navigation and purchase confirmation complete")
    quit(0)
