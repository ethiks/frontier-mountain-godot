extends "res://scripts/frontier_shop_a.gd"
## One identical approved Frontier Mountain market frame for ALL four tabs.
## Inherits its parchment split-view, carved wood tab/buttons, selection focus,
## scrolling and purchase confirmation. Only rows and details change by page.
const PAGES := ["sell", "contracts", "shop", "supplies"]
const SELL_CATEGORIES := [["all", "ALL"], ["raw", "RAW LOGS"], ["processed", "MILLED"]]
const CONTRACT_CATEGORIES := [["all", "ALL"], ["offers", "OFFERS"], ["active", "ACTIVE"]]
const SUPPLY_CATEGORIES := [["all", "ALL"], ["goods", "SUPPLIES"], ["services", "SERVICES"]]
var page := "shop"
var selected_quantities: Dictionary = {}
var market_assets: Texture2D
var qty_minus: Button
var qty_plus: Button
var qty_max: Button
var qty_display: Label

func setup(p_host, p_game) -> void:
    super.setup(p_host,p_game)
    qty_minus = _button(detail_panel, "−", true)
    qty_minus.name = "SellQuantityMinus"
    qty_minus.pressed.connect(func(): adjust_quantity(-1))
    qty_plus = _button(detail_panel, "+", true)
    qty_plus.name = "SellQuantityPlus"
    qty_plus.pressed.connect(func(): adjust_quantity(1))
    qty_max = _button(detail_panel, "MAX", true)
    qty_max.name = "SellQuantityMax"
    qty_max.pressed.connect(_choose_max)
    qty_display = _label(detail_panel, "0", 17, COLORS.ink)
    qty_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    resize_shop(Vector2(1060.0,640.0),false)

func resize_shop(available_size: Vector2, mobile: bool) -> void:
    super.resize_shop(available_size,mobile)
    if qty_minus == null:
        return
    var panel_width: float = detail_panel.size.x
    var y: float = detail_panel.size.y - (92.0 if compact else 107.0)
    var total_width: float = panel_width - 28.0
    var gap := 4.0
    qty_minus.position = Vector2(12.0,y)
    qty_minus.size = Vector2(40.0,34.0)
    qty_display.position = Vector2(57.0,y + 4.0)
    qty_display.size = Vector2(maxf(33.0,total_width - 144.0),28.0)
    qty_plus.position = Vector2(panel_width - 91.0,y)
    qty_plus.size = Vector2(37.0,34.0)
    qty_max.position = Vector2(panel_width - 51.0,y)
    qty_max.size = Vector2(40.0,34.0)
    for button in [qty_minus,qty_plus,qty_max]:
        button.add_theme_font_size_override("font_size",14)
    _update_quantity_controls()

func _choose_max() -> void:
    if page != "sell":
        return
    var entry: Dictionary = _selected_item()
    if entry.is_empty():
        return
    var key: String = str(entry["id"])
    selected_quantities[key] = game.distributor.available(int(entry["index"]))
    pending_id = ""
    _refresh_detail()

func _update_quantity_controls() -> void:
    if qty_minus == null:
        return
    var showing: bool = page == "sell"
    for control in [qty_minus,qty_plus,qty_max,qty_display]:
        control.visible = showing
    item_price.visible = not showing
    if not showing:
        return
    var entry: Dictionary = _selected_item()
    if entry.is_empty():
        qty_display.text = "0"
        qty_minus.disabled = true
        qty_plus.disabled = true
        qty_max.disabled = true
        return
    var count: int = int(selected_quantities.get(str(entry["id"]),0))
    var stock: int = game.distributor.available(int(entry["index"]))
    qty_display.text = "%d / %d" % [count,stock]
    qty_minus.disabled = count <= 0
    qty_plus.disabled = count >= stock
    qty_max.disabled = count >= stock


func _page_categories() -> Array:
    match page:
        "sell":
            return SELL_CATEGORIES
        "contracts":
            return CONTRACT_CATEGORIES
        "supplies":
            return SUPPLY_CATEGORIES
        _:
            return CATEGORIES

func set_page(next_page: String) -> void:
    if not PAGES.has(next_page):
        return
    if page != next_page:
        page = next_page
        selected_category = "all"
        selected_item_id = ""
        active_index = 0
        pending_id = ""
    refresh_data()
    if visible:
        focus_selected()

func _sync_page_tabs() -> void:
    if nav_bar == null:
        return
    for i in range(nav_bar.get_child_count()):
        var button: Button = nav_bar.get_child(i)
        var active: bool = PAGES[i] == page
        button.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, COLORS.gold if active else COLORS.edge, 3 if active else 1))
        button.add_theme_color_override("font_color", COLORS.cream if active else Color("#d4c09f"))
        button.modulate = Color.WHITE if active else Color(0.86, 0.87, 0.84)

func _sync_filters() -> void:
    if category_buttons.is_empty():
        return
    var categories: Array = _page_categories()
    var count: int = categories.size()
    for i in range(category_buttons.size()):
        var button: Button = category_buttons[i]
        var index: int = i % 5
        button.visible = index < count
        if index >= count:
            continue
        var entry: Array = categories[index]
        var key: String = str(entry[0])
        button.text = str(entry[1])
        var selected: bool = key == selected_category
        button.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, COLORS.gold if selected else COLORS.edge, 3 if selected else 1))
        button.add_theme_color_override("font_color", COLORS.cream if selected else Color("#d9cfb7"))
        button.modulate = Color.WHITE if selected else Color(0.76, 0.78, 0.75)

func _category_index() -> int:
    var options: Array = _page_categories()
    for i in range(options.size()):
        if str(options[i][0]) == selected_category:
            return i
    return 0

func cycle_category(direction: int) -> void:
    var options: Array = _page_categories()
    choose_category(str(options[posmod(_category_index() + direction, options.size())][0]))
    focus_selected()

func _make_entry(identifier: String, caption: String, detail: String, value: int, category_name: String, kind: String, index: int = -1) -> Dictionary:
    return {"id":identifier,"name":caption,"detail":detail,"price":value,"category":category_name,"kind":kind,"index":index}

func _refilter() -> void:
    if page == "shop":
        super._refilter()
        return
    filtered_items.clear()
    var dealer = game.distributor
    var entries: Array[Dictionary] = []
    match page:
        "sell":
            for i in range(7):
                var group := "raw" if i < 4 else "processed"
                var name: String = str(dealer.GOODS[i])
                var amount: int = dealer.available(i)
                var price_value: int = dealer.price(i, game.progression)
                var note := "Available %d  ·  Market price $%d / unit" % [amount, price_value]
                if i >= 4:
                    note += "\nProcessed timber from your sawmill or kiln."
                else:
                    note += "\nUnload harvested logs at the lumber landing first."
                entries.append(_make_entry("sale_%d" % i, name + "  ·  %d in stock" % amount, note, price_value, group, "sale", i))
        "contracts":
            for item in dealer.active_contracts:
                var entry: Dictionary = item
                var idx: int = int(entry["index"])
                var caption := "ACTIVE  ·  %d %s" % [int(entry["qty"]), str(dealer.GOODS[idx])]
                var details := "Due Day %d  ·  Stock %d/%d  ·  +%d XP\nComplete from stored depot inventory." % [int(entry["deadline"]), dealer.available(idx), int(entry["qty"]), int(entry["xp"])]
                var row := _make_entry("active_" + str(entry["id"]), caption, details, int(entry["payout"]), "active", "deliver", idx)
                row["offer"] = entry
                entries.append(row)
            for item in dealer.contract_offers:
                var entry: Dictionary = item
                var idx: int = int(entry["index"])
                var caption := "OFFER  ·  %d %s" % [int(entry["qty"]), str(dealer.GOODS[idx])]
                var details := "Due Day %d  ·  +%d XP\nUp to 3 active contracts. Accept to reserve this buyer order." % [int(entry["deadline"]), int(entry["xp"])]
                var row := _make_entry("offer_" + str(entry["id"]), caption, details, int(entry["payout"]), "offers", "accept", idx)
                row["offer"] = entry
                entries.append(row)
        "supplies":
            for item in dealer.SUPPLY_SHOP:
                var entry: Dictionary = item
                var row := _make_entry("supply_" + str(entry["id"]),str(entry["name"]),str(entry["detail"]),int(entry["price"]),"goods","supply")
                row["supply_id"] = str(entry["id"])
                entries.append(row)
            entries.append(_make_entry("repair_tool","Service cutting tool","Restore durability at the distributor.\nPrice depends on the condition of the tool.",0,"services","repair"))
            entries.append(_make_entry("field_repair","Field repair","Uses one repair part.\nRequires the tool-shed expansion purchase.",0,"services","field_repair"))
            if dealer.is_owned("sawmill"):
                entries.append(_make_entry("mill_one","Mill one raw log","Process raw timber into boards and sawdust.",0,"services","mill",1))
                entries.append(_make_entry("mill_all","Mill all raw logs","Queue all raw timber for processing.",0,"services","mill",-1))
            if dealer.is_owned("kiln"):
                entries.append(_make_entry("dry_one","Dry one board","Convert milled lumber into premium kiln-dried timber.",0,"services","kiln",1))
                entries.append(_make_entry("dry_all","Dry all boards","Queue all current boards for the drying kiln.",0,"services","kiln",-1))
    for entry in entries:
        if selected_category == "all" or str(entry["category"]) == selected_category:
            filtered_items.append(entry)
    active_index = 0
    for i in range(filtered_items.size()):
        if str(filtered_items[i]["id"]) == selected_item_id:
            active_index = i
            break
    if filtered_items.is_empty():
        selected_item_id = ""
    else:
        selected_item_id = str(filtered_items[active_index]["id"])

func refresh_data() -> void:
    if game == null:
        return
    super.refresh_data()
    _sync_page_tabs()
    var titles := {"sell":"SELL TIMBER", "contracts":"BUYER CONTRACTS", "shop":"EQUIPMENT SHOP", "supplies":"SUPPLIES & SERVICES"}
    top_title.text = "ELIAS  ·  " + str(titles.get(page, "FRONTIER SUPPLY CO."))
    day_gold.text = "D%d  $%d  REP %d" % [game.progression.day, int(game.get("cash")), game.distributor.reputation]
    if compact:
        top_title.add_theme_font_size_override("font_size", 15)
    footer.text = "D-PAD/STICK  BROWSE     A  SELECT / CONFIRM     B  BACK     LB / RB  TABS"
    _refresh_detail()

func _refresh_detail() -> void:
    if game == null or item_title == null:
        return
    if page == "shop":
        super._refresh_detail()
        _update_quantity_controls()
        return
    var entry: Dictionary = _selected_item()
    if entry.is_empty():
        item_title.text = "NO ITEMS"
        item_description.text = "Nothing here today."
        item_price.text = ""
        item_state.text = ""
        detail_icon.visible = false
        no_icon.visible = true
        no_icon.text = "FRONTIER\nSUPPLY"
        buy_button.disabled = true
        buy_button.text = "UNAVAILABLE"
        return
    var kind: String = str(entry["kind"])
    var identifier: String = str(entry["id"])
    item_title.text = str(entry["name"]).to_upper()
    item_description.text = str(entry["detail"])
    detail_icon.visible = false
    no_icon.visible = true
    no_icon.text = str(entry["category"]).to_upper() + "\nFRONTIER SUPPLY"
    var cost: int = int(entry["price"])
    var eligible := false
    var label_text := "SELECT"
    var state_text := ""
    match kind:
        "sale":
            var stock: int = game.distributor.available(int(entry["index"]))
            var quantity: int = clampi(int(selected_quantities.get(identifier, 0)),0,stock)
            selected_quantities[identifier] = quantity
            cost = quantity * int(entry["price"])
            label_text = "SELL %d  ·  $%d" % [quantity,cost]
            state_text = "QUANTITY %d/%d  ·  LT / RT TO ADJUST" % [quantity,stock]
            eligible = quantity > 0
        "accept":
            label_text = "ACCEPT ORDER"
            state_text = "%d / 3 ACTIVE" % game.distributor.active_contracts.size()
            eligible = game.distributor.active_contracts.size() < 3
        "deliver":
            var offer: Dictionary = entry["offer"]
            var have: int = game.distributor.available(int(offer["index"]))
            eligible = have >= int(offer["qty"])
            label_text = "DELIVER  +$%d" % cost
            state_text = "STOCK %d/%d  ·  DUE DAY %d" % [have,int(offer["qty"]),int(offer["deadline"])]
        "supply":
            label_text = "BUY  $%d" % cost
            state_text = "FUNDS $%d" % int(game.get("cash"))
            eligible = int(game.get("cash")) >= cost
        "repair":
            label_text = "REPAIR TOOL"
            state_text = "DURABILITY %d" % int(game.progression.condition)
            eligible = game.progression.condition < game.progression.AXE_CONDITION[game.progression.axe_level]
        "field_repair":
            label_text = "USE REPAIR PART"
            state_text = "PARTS %d" % game.distributor.repair_parts
            eligible = game.distributor.repair_parts > 0 and game.distributor.is_owned("shed")
        "mill":
            var available_raw: int = game.distributor.total_raw()
            label_text = "QUEUE MILL  ·  %d LOGS" % (mini(1,available_raw) if int(entry["index"]) == 1 else available_raw)
            state_text = "RAW STOCK %d" % available_raw
            eligible = available_raw > 0
        "kiln":
            var boards: int = game.distributor.available(4)
            label_text = "QUEUE KILN  ·  %d BOARDS" % (mini(1,boards) if int(entry["index"]) == 1 else boards)
            state_text = "BOARDS %d" % boards
            eligible = boards > 0
    item_price.text = ("TOTAL  $%d" % cost) if kind == "sale" else ("PAYOUT  $%d" % cost if kind == "deliver" or kind == "accept" else ("PRICE  $%d" % cost if kind == "supply" else "DISTRIBUTOR SERVICE"))
    item_state.text = state_text
    buy_button.text = ("CONFIRM  " + label_text) if pending_id == identifier else label_text
    buy_button.disabled = not eligible
    _update_quantity_controls()

func _request_purchase() -> void:
    if page == "shop":
        super._request_purchase()
        return
    var entry: Dictionary = _selected_item()
    if entry.is_empty() or buy_button.disabled:
        return
    var identifier := str(entry["id"])
    if pending_id != identifier:
        pending_id = identifier
        _refresh_detail()
        return
    var kind: String = str(entry["kind"])
    pending_id = ""
    match kind:
        "sale":
            var qty := int(selected_quantities.get(identifier,0))
            var counts := [0,0,0,0,0,0,0]
            counts[int(entry["index"])] = qty
            game.distributor.sell_selected(game,counts)
            selected_quantities[identifier] = 0
        "accept":
            var offer: Dictionary = entry["offer"]
            game.distributor.accept_contract(game,str(offer["id"]))
        "deliver":
            var offer: Dictionary = entry["offer"]
            game.distributor.deliver_contract(game,str(offer["id"]))
        "supply":
            game.distributor.buy_supply(game,str(entry["supply_id"]))
        "repair":
            game.progression.repair_tool(game)
        "field_repair":
            game.distributor.field_repair(game)
        "mill":
            game.distributor.queue_sawmill(game,1 if int(entry["index"]) == 1 else game.distributor.total_raw())
        "kiln":
            game.distributor.queue_kiln(game,1 if int(entry["index"]) == 1 else game.distributor.available(4))
    refresh_data()
    focus_selected()

func adjust_quantity(amount: int) -> void:
    if page != "sell":
        return
    var entry: Dictionary = _selected_item()
    if entry.is_empty() or str(entry["kind"]) != "sale":
        return
    var key: String = str(entry["id"])
    var maximum: int = game.distributor.available(int(entry["index"]))
    selected_quantities[key] = clampi(int(selected_quantities.get(key,0)) + amount,0,maximum)
    pending_id = ""
    _refresh_detail()

func handle_button(button_index: int) -> bool:
    if page == "sell":
        if button_index == JOY_BUTTON_X:
            adjust_quantity(-1)
            return true
        if button_index == JOY_BUTTON_Y:
            adjust_quantity(1)
            return true
    return super.handle_button(button_index)

func handle_keyboard(keycode: int) -> bool:
    if page == "sell":
        if keycode == KEY_MINUS or keycode == KEY_BRACKETLEFT:
            adjust_quantity(-1)
            return true
        if keycode == KEY_EQUAL or keycode == KEY_PLUS or keycode == KEY_BRACKETRIGHT:
            adjust_quantity(1)
            return true
    return super.handle_keyboard(keycode)

var left_trigger_held := false
var right_trigger_held := false
func set_axis(axis: int, value: float) -> bool:
    if page == "sell" and axis == JOY_AXIS_TRIGGER_LEFT:
        if value > 0.65 and not left_trigger_held:
            adjust_quantity(-1)
        left_trigger_held = value > 0.45
        return true
    if page == "sell" and axis == JOY_AXIS_TRIGGER_RIGHT:
        if value > 0.65 and not right_trigger_held:
            adjust_quantity(1)
        right_trigger_held = value > 0.45
        return true
    return super.set_axis(axis,value)
