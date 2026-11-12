extends Control
## Approved Variation A: a three-region item ledger (categories | list | detail)
## with controller-first selection and a deliberate two-step purchase.
## Only the four item thumbnails extracted from the APPROVED Variation A concept
## are used; other merchandise uses honest category labels, not invented art.
const COLORS := {
    "frame": Color("#39291c"),
    "edge": Color("#986a40"),
    "pine": Color("#264635"),
    "pine_hover": Color("#355a42"),
    "gold": Color("#e7b85b"),
    "parchment": Color("#e9cfaa"),
    "parchment2": Color("#d8b88c"),
    "ink": Color("#392919"),
    "cream": Color("#fff0c8")
}
const CATEGORIES := [
    ["all", "ALL STOCK"],
    ["tools", "TOOLS"],
    ["hauling", "HAULING"],
    ["machines", "MACHINES"],
    ["supplies", "SUPPLIES"]
]
const ITEM_ICONS := {
    "sharp": 0, "steel": 2, "chainsaw": 3,
    "handcart": 1, "heavycart": 1
}
const ICON_FILE := "res://assets/ui/variation_a_item_icons.webp"
const ICON_SIZE := Vector2(96, 72)

var host
var game
var selected_category := "all"
var selected_item_id := "handcart"
var active_index := 0
var filtered_items: Array[Dictionary] = []
var pending_id := ""
var list_buttons: Array[Button] = []
var category_buttons: Array[Button] = []
var header_art: NinePatchRect
var frame: Panel
var top_title: Label
var day_gold: Label
var nav_bar: HBoxContainer
var category_panel: Panel
var category_mobile: HBoxContainer
var desktop_categories: VBoxContainer
var mobile_categories: HBoxContainer
var item_panel: Panel
var item_scroll: ScrollContainer
var item_rows: VBoxContainer
var detail_panel: Panel
var item_title: Label
var detail_icon: TextureRect
var no_icon: Label
var item_description: Label
var item_price: Label
var item_state: Label
var buy_button: Button
var footer: Label
var back_button: Button
var compact := false
var item_icon_atlas: Texture2D
var analog_y := 0.0
var analog_repeat := 0.0

func setup(p_host, p_game) -> void:
    host = p_host
    game = p_game
    item_icon_atlas = load(ICON_FILE) as Texture2D
    mouse_filter = Control.MOUSE_FILTER_PASS
    frame = Panel.new()
    frame.name = "VariationAFrame"
    frame.add_theme_stylebox_override("panel", _style(COLORS.frame, COLORS.edge, 5))
    add_child(frame)

    header_art = NinePatchRect.new()
    header_art.name = "ApprovedWoodHeader"
    header_art.texture = host._region_texture("message")
    header_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    header_art.patch_margin_left = 32
    header_art.patch_margin_right = 33
    header_art.patch_margin_top = 19
    header_art.patch_margin_bottom = 19
    header_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(header_art)

    top_title = _label(frame, "ELIAS  ·  FRONTIER SUPPLY CO.", 23, COLORS.cream)
    day_gold = _label(frame, "DAY 1  ·  $0", 17, COLORS.gold)
    nav_bar = HBoxContainer.new()
    nav_bar.name = "ShopPageTabs"
    nav_bar.add_theme_constant_override("separation", 6)
    frame.add_child(nav_bar)
    for entry in [["sell","SELL"],["contracts","CONTRACTS"],["shop","SHOP"],["supplies","SUPPLIES"]]:
        var key: String = str(entry[0])
        var title: String = str(entry[1])
        var btn := _button(nav_bar, title, true)
        btn.name = "Navigate_" + key
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.pressed.connect(func(): host._choose_market_page(key))

    category_panel = _panel(frame, "Categories", COLORS.frame)
    desktop_categories = VBoxContainer.new()
    desktop_categories.name = "CategoryRail"
    desktop_categories.add_theme_constant_override("separation", 7)
    category_panel.add_child(desktop_categories)
    category_mobile = HBoxContainer.new()
    category_mobile.name = "CategoryStrip"
    category_mobile.add_theme_constant_override("separation", 5)
    frame.add_child(category_mobile)
    for entry in CATEGORIES:
        var key: String = str(entry[0])
        var label_name: String = str(entry[1])
        var desktop := _button(desktop_categories, label_name, true)
        desktop.custom_minimum_size.y = 54
        desktop.pressed.connect(func(): choose_category(key))
        category_buttons.append(desktop)
        var mobile := _button(category_mobile, label_name, true)
        mobile.add_theme_font_size_override("font_size", 12)
        mobile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        mobile.pressed.connect(func(): choose_category(key))
        category_buttons.append(mobile)

    item_panel = _panel(frame, "ItemList", COLORS.parchment)
    item_scroll = ScrollContainer.new()
    item_scroll.name = "InventoryScroll"
    item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    item_scroll.follow_focus = true
    item_panel.add_child(item_scroll)
    item_rows = VBoxContainer.new()
    item_rows.name = "InventoryRows"
    item_rows.add_theme_constant_override("separation", 5)
    item_scroll.add_child(item_rows)

    detail_panel = _panel(frame, "Details", COLORS.parchment)
    item_title = _label(detail_panel, "LOG CART", 23, COLORS.ink)
    item_title.clip_text = true
    item_description = _label(detail_panel, "Carry up to 8 logs.", 17, COLORS.ink)
    item_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_icon = TextureRect.new()
    detail_icon.name = "ApprovedItemThumbnail"
    detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    detail_panel.add_child(detail_icon)
    no_icon = _label(detail_panel, "FRONTIER\nSUPPLY", 15, COLORS.edge)
    no_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    item_price = _label(detail_panel, "$175", 23, COLORS.ink)
    item_state = _label(detail_panel, "Select an item to inspect it.", 14, COLORS.ink)
    buy_button = _button(detail_panel, "BUY $175", true)
    buy_button.name = "ConfirmPurchase"
    buy_button.add_theme_font_size_override("font_size", 19)
    buy_button.pressed.connect(_request_purchase)
    back_button = _button(frame, "◀ BACK", true)
    back_button.name = "ControllerBack"
    back_button.pressed.connect(func(): host.close_menu())
    footer = _label(frame, "D-PAD / STICK  SELECT     A  BUY     B  BACK     LB / RB  PAGE", 14, COLORS.cream)
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    resize_shop(Vector2(1060, 640), false)
    refresh_data()

func _style(fill: Color, border: Color, thickness: int, corner: int = 5) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = fill
    sb.border_color = border
    sb.set_border_width_all(thickness)
    sb.set_corner_radius_all(corner)
    sb.content_margin_left = 10
    sb.content_margin_right = 10
    sb.content_margin_top = 7
    sb.content_margin_bottom = 7
    return sb

func _label(parent: Node, value: String, size_px: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size_px)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func _panel(parent: Node, label_name: String, background: Color) -> Panel:
    var panel := Panel.new()
    panel.name = label_name
    panel.add_theme_stylebox_override("panel", _style(background, COLORS.edge, 4))
    parent.add_child(panel)
    return panel

func _button(parent: Node, caption: String, dark: bool) -> Button:
    var button := Button.new()
    button.text = caption
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", COLORS.cream if dark else COLORS.ink)
    button.add_theme_color_override("font_hover_color", COLORS.cream if dark else COLORS.ink)
    button.add_theme_color_override("font_focus_color", COLORS.cream if dark else COLORS.ink)
    var base_fill := Color.TRANSPARENT if dark else COLORS.parchment2
    button.add_theme_stylebox_override("normal", _style(base_fill, COLORS.edge, 2))
    button.add_theme_stylebox_override("hover", _style(Color.TRANSPARENT if dark else COLORS.gold, COLORS.gold, 3))
    button.add_theme_stylebox_override("pressed", _style(Color.TRANSPARENT if dark else COLORS.parchment, COLORS.gold, 3))
    button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, COLORS.gold, 4))
    button.add_theme_stylebox_override("disabled", _style(Color.TRANSPARENT if dark else Color("#88765d"), COLORS.edge, 2))
    parent.add_child(button)
    if dark:
        # Genuine approved blank sign texture (not a flat coloured Button).
        # Nine-patch scaling keeps the carved rim intact on wide tabs and
        # narrow mobile controls; dynamic text stays above the artwork.
        var wood := NinePatchRect.new()
        wood.name = "ApprovedCarvedWood"
        wood.texture = host._region_texture("message")
        wood.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        wood.patch_margin_left = 33
        wood.patch_margin_right = 33
        wood.patch_margin_top = 18
        wood.patch_margin_bottom = 18
        wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
        wood.show_behind_parent = true
        button.add_child(wood)
        wood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    return button

func resize_shop(available_size: Vector2, mobile: bool) -> void:
    compact = mobile
    var w: float = maxf(600.0, available_size.x - 18.0)
    var h: float = maxf(318.0, available_size.y - 12.0)
    position = Vector2((available_size.x - w) * 0.5, (available_size.y - h) * 0.5)
    size = Vector2(w, h)
    frame.position = Vector2.ZERO
    frame.size = size
    var head_h := 64.0 if compact else 83.0
    header_art.position = Vector2(7, 7)
    header_art.size = Vector2(w - 14.0, head_h - 3.0)
    top_title.position = Vector2(24, 19 if compact else 26)
    top_title.add_theme_font_size_override("font_size", 16 if compact else 24)
    day_gold.position = Vector2(w - (174.0 if compact else 217.0), 22 if compact else 30)
    day_gold.add_theme_font_size_override("font_size", 13 if compact else 18)
    nav_bar.position = Vector2(15, head_h + 3.0)
    nav_bar.size = Vector2(w - 30.0, 48.0 if compact else 54.0)
    var content_y := head_h + (59.0 if compact else 66.0)
    var content_bottom := h - (51.0 if compact else 62.0)
    var content_h := maxf(120.0, content_bottom - content_y)
    category_panel.visible = not compact
    category_mobile.visible = compact
    if compact:
        category_mobile.position = Vector2(13.0, content_y)
        category_mobile.size = Vector2(w - 26.0, 39.0)
        content_y += 44.0
        content_h -= 44.0
    var gap := 9.0
    var details_width := (w - 29.0) * (0.47 if compact else 0.39)
    if compact:
        var inventory_w := w - details_width - 30.0
        item_panel.position = Vector2(12.0, content_y)
        item_panel.size = Vector2(inventory_w, content_h)
    else:
        var category_w := 159.0
        category_panel.position = Vector2(12.0, content_y)
        category_panel.size = Vector2(category_w, content_h)
        desktop_categories.position = Vector2(9.0, 16.0)
        desktop_categories.size = Vector2(category_w - 18.0, content_h - 32.0)
        var list_w := w - 28.0 - category_w - details_width - gap * 2.0
        item_panel.position = Vector2(12.0 + category_w + gap, content_y)
        item_panel.size = Vector2(list_w, content_h)
    detail_panel.position = Vector2(item_panel.position.x + item_panel.size.x + gap, content_y)
    detail_panel.size = Vector2(details_width - gap, content_h)
    item_scroll.position = Vector2(9.0, 10.0)
    item_scroll.size = item_panel.size - Vector2(18.0, 20.0)
    item_rows.custom_minimum_size.x = item_scroll.size.x - 18.0
    item_title.position = Vector2(16.0, 12.0)
    item_title.size = Vector2(detail_panel.size.x - 32.0, 31.0)
    item_title.add_theme_font_size_override("font_size", 18 if compact else 23)
    if compact:
        # In phone landscape, place picture and description side-by-side;
        # a stacked 160px detail card would overlap its Buy button.
        var icon_w := minf(93.0, detail_panel.size.x * 0.33)
        detail_icon.position = Vector2(9.0, 37.0)
        detail_icon.size = Vector2(icon_w, minf(86.0, maxf(45.0, content_h - 127.0)))
        no_icon.position = detail_icon.position
        no_icon.size = detail_icon.size
        var copy_x := 14.0 + icon_w
        item_description.position = Vector2(copy_x, 40.0)
        item_description.size = Vector2(detail_panel.size.x - copy_x - 12.0, maxf(28.0, content_h - 135.0))
        item_description.add_theme_font_size_override("font_size", 12)
        item_price.position = Vector2(copy_x, content_h - 93.0)
        item_price.add_theme_font_size_override("font_size", 18)
        item_state.visible = false
        # Clear large desktop font/style content margins: otherwise Godot
        # enforces a 71px minimum button height in a 160px phone detail card.
        buy_button.add_theme_font_size_override("font_size", 14)
        for state in ["normal", "hover", "pressed", "focus", "disabled"]:
            var skin := _style(Color.TRANSPARENT, COLORS.gold if state != "disabled" else COLORS.edge, 2)
            skin.content_margin_top = 0
            skin.content_margin_bottom = 0
            skin.content_margin_left = 4
            skin.content_margin_right = 4
            buy_button.add_theme_stylebox_override(state, skin)
        buy_button.position = Vector2(12.0, content_h - 49.0)
        buy_button.size = Vector2(detail_panel.size.x - 24.0, 39.0)
    else:
        var image_height := minf(160.0, maxf(55.0, content_h * 0.38))
        detail_icon.position = Vector2(18.0, 47.0)
        detail_icon.size = Vector2(detail_panel.size.x - 36.0, image_height)
        no_icon.position = detail_icon.position
        no_icon.size = detail_icon.size
        var info_y := 50.0 + image_height
        item_description.position = Vector2(15.0, info_y)
        item_description.size = Vector2(detail_panel.size.x - 30.0, maxf(34.0, content_h - info_y - 112.0))
        item_description.add_theme_font_size_override("font_size", 17)
        item_price.position = Vector2(17.0, content_h - 111.0)
        item_price.add_theme_font_size_override("font_size", 23)
        item_state.visible = true
        item_state.position = Vector2(16.0, content_h - 86.0)
        item_state.size = Vector2(detail_panel.size.x - 30.0, 22.0)
        item_state.add_theme_font_size_override("font_size", 14)
        for state in ["normal", "hover", "pressed", "focus", "disabled"]:
            var skin := _style(COLORS.pine if state != "disabled" else Color("#665c4b"), COLORS.gold, 2)
            skin.content_margin_top = 3
            skin.content_margin_bottom = 3
            buy_button.add_theme_stylebox_override(state, skin)
        buy_button.add_theme_font_size_override("font_size", 18)
        buy_button.position = Vector2(13.0, content_h - 58.0)
        buy_button.size = Vector2(detail_panel.size.x - 26.0, 46.0)
    back_button.position = Vector2(18.0, h - 47.0)
    back_button.size = Vector2(114.0, 37.0)
    footer.position = Vector2(144.0, h - 44.0)
    footer.size = Vector2(w - 160.0, 40.0)
    footer.add_theme_font_size_override("font_size", 11 if compact else 14)
    _sync_filters()
    if not filtered_items.is_empty():
        _build_rows()
    _refresh_detail()

func _icon_texture(identifier: String) -> Texture2D:
    if item_icon_atlas == null or not ITEM_ICONS.has(identifier):
        return null
    var atlas := AtlasTexture.new()
    atlas.atlas = item_icon_atlas
    atlas.region = Rect2(Vector2(float(int(ITEM_ICONS[identifier])) * ICON_SIZE.x, 0), ICON_SIZE)
    atlas.filter_clip = true
    return atlas

func _category_index() -> int:
    for i in range(CATEGORIES.size()):
        if CATEGORIES[i][0] == selected_category:
            return i
    return 0

func choose_category(key: String) -> void:
    selected_category = key
    pending_id = ""
    _refilter()
    _build_rows()
    _sync_filters()

func cycle_category(direction: int) -> void:
    var current := _category_index()
    var next := posmod(current + direction, CATEGORIES.size())
    choose_category(str(CATEGORIES[next][0]))
    focus_selected()

func _sync_filters() -> void:
    if category_buttons.is_empty():
        return
    for index in range(category_buttons.size()):
        var btn: Button = category_buttons[index]
        var key: String = str(CATEGORIES[int(index / 2)][0])
        var on := key == selected_category
        btn.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, COLORS.gold if on else COLORS.edge, 3 if on else 2))
        btn.add_theme_color_override("font_color", COLORS.cream if on else Color("#deccac"))
        btn.modulate = Color.WHITE if on else Color(0.76, 0.78, 0.74)

func _refilter() -> void:
    filtered_items.clear()
    for value in game.distributor.SHOP:
        var item: Dictionary = value
        if selected_category == "all" or str(item["category"]) == selected_category:
            filtered_items.append(item)
    active_index = 0
    for i in range(filtered_items.size()):
        if str(filtered_items[i]["id"]) == selected_item_id:
            active_index = i
            break
    if not filtered_items.is_empty():
        selected_item_id = str(filtered_items[active_index]["id"])

func refresh_data() -> void:
    if game == null:
        return
    day_gold.text = "DAY %d  ·  $%d" % [game.progression.day, int(game.get("cash"))]
    _refilter()
    _build_rows()
    _sync_filters()

func _build_rows() -> void:
    for old in item_rows.get_children():
        item_rows.remove_child(old)
        old.queue_free()
    list_buttons.clear()
    for i in range(filtered_items.size()):
        var item: Dictionary = filtered_items[i]
        var id: String = str(item["id"])
        var item_name: String = str(item["name"])
        var price: int = int(item["price"])
        var owned: bool = game.distributor.is_owned(id)
        # The button is the single focus/input surface; labels and approved
        # thumbnails have separate columns so neither can occlude the other.
        var btn := _button(item_rows, "", false)
        btn.name = "Item_" + id
        btn.custom_minimum_size = Vector2(item_scroll.size.x - 24.0, 48.0 if compact else 58.0)
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var row_width := item_scroll.size.x - 24.0
        var name_x := 78.0 if ITEM_ICONS.has(id) else 16.0
        var price_width := 86.0
        if ITEM_ICONS.has(id):
            var icon := TextureRect.new()
            icon.name = "ApprovedThumbnail_" + id
            icon.texture = _icon_texture(id)
            icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
            icon.position = Vector2(4.0, 4.0)
            icon.size = Vector2(66.0, 48.0 if not compact else 40.0)
            icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
            btn.add_child(icon)
        var item_label := _label(btn, item_name, 14 if compact else 16, COLORS.ink)
        item_label.name = "ProductName"
        item_label.clip_text = true
        item_label.position = Vector2(name_x, 11.0 if compact else 15.0)
        item_label.size = Vector2(maxf(40.0, row_width - name_x - price_width - 8.0), 28.0)
        var price_label := _label(btn, "OWNED" if owned else "$%d" % price, 13 if compact else 15, COLORS.ink)
        price_label.name = "ProductPrice"
        price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        price_label.position = Vector2(row_width - price_width - 6.0, 11.0 if compact else 15.0)
        price_label.size = Vector2(price_width, 28.0)
        btn.pressed.connect(func(): select_item_by_id(id))
        btn.focus_entered.connect(func(): select_item_by_id(id, false))
        list_buttons.append(btn)
    _refresh_selection()

func select_item_by_id(identifier: String, focus: bool = true) -> void:
    for i in range(filtered_items.size()):
        if str(filtered_items[i]["id"]) == identifier:
            active_index = i
            selected_item_id = identifier
            pending_id = ""
            _refresh_selection()
            if focus:
                focus_selected()
            return

func move_selection(direction: int) -> void:
    if filtered_items.is_empty():
        return
    active_index = clampi(active_index + direction, 0, filtered_items.size() - 1)
    selected_item_id = str(filtered_items[active_index]["id"])
    pending_id = ""
    _refresh_selection()
    focus_selected()

func focus_selected() -> void:
    if active_index < 0 or active_index >= list_buttons.size():
        return
    var btn: Button = list_buttons[active_index]
    btn.grab_focus()
    item_scroll.ensure_control_visible(btn)

func _refresh_selection() -> void:
    for i in range(list_buttons.size()):
        var btn: Button = list_buttons[i]
        var active := i == active_index
        btn.add_theme_stylebox_override("normal", _style(COLORS.gold if active else COLORS.parchment2, COLORS.edge if not active else Color("#fff4b7"), 3 if active else 1))
        btn.add_theme_color_override("font_color", COLORS.ink)
    _refresh_detail()

func _selected_item() -> Dictionary:
    if filtered_items.is_empty() or active_index >= filtered_items.size():
        return {}
    return filtered_items[active_index]

func _refresh_detail() -> void:
    if item_title == null or game == null:
        return
    var item := _selected_item()
    if item.is_empty():
        item_title.text = "NO STOCK"
        item_description.text = "Nothing in this category."
        buy_button.disabled = true
        return
    var id := str(item["id"])
    var name := str(item["name"])
    var price := int(item["price"])
    var owned: bool = game.distributor.is_owned(id)
    var funds: int = int(game.get("cash"))
    item_title.text = name.to_upper()
    item_description.text = str(item["detail"]) + "\n\n" + str(item["category"]).to_upper() + "  ·  FRONTIER SUPPLY"
    detail_icon.texture = _icon_texture(id)
    detail_icon.visible = detail_icon.texture != null
    no_icon.visible = not detail_icon.visible
    no_icon.text = str(item["category"]).to_upper() + "\nFRONTIER SUPPLY"
    item_price.text = "PRICE  $%d" % price
    item_state.text = "OWNED" if owned else ("NOT ENOUGH GOLD" if price > funds else "AVAILABLE")
    if owned:
        buy_button.text = "PURCHASED"
    elif pending_id == id:
        buy_button.text = "CONFIRM $%d" % price
    else:
        buy_button.text = "BUY $%d" % price
    buy_button.disabled = owned or price > funds

func _request_purchase() -> void:
    var item := _selected_item()
    if item.is_empty():
        return
    var id := str(item["id"])
    if game.distributor.is_owned(id) or int(game.get("cash")) < int(item["price"]):
        return
    if pending_id != id:
        pending_id = id
        _refresh_detail()
        return
    if game.distributor.buy_shop_item(game, id):
        pending_id = ""
        refresh_data()
        focus_selected()

func back_action() -> void:
    if pending_id != "":
        pending_id = ""
        _refresh_detail()
    else:
        host.close_menu()

func handle_button(button_index: int) -> bool:
    match button_index:
        JOY_BUTTON_DPAD_UP:
            move_selection(-1)
        JOY_BUTTON_DPAD_DOWN:
            move_selection(1)
        JOY_BUTTON_DPAD_LEFT:
            cycle_category(-1)
        JOY_BUTTON_DPAD_RIGHT:
            cycle_category(1)
        JOY_BUTTON_A:
            _request_purchase()
        JOY_BUTTON_B:
            back_action()
        _:
            return false
    return true

func handle_keyboard(keycode: int) -> bool:
    match keycode:
        KEY_UP:
            move_selection(-1)
        KEY_DOWN:
            move_selection(1)
        KEY_LEFT:
            cycle_category(-1)
        KEY_RIGHT:
            cycle_category(1)
        KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
            _request_purchase()
        KEY_ESCAPE:
            back_action()
        _:
            return false
    return true

func set_axis(axis: int, value: float) -> bool:
    if axis != JOY_AXIS_LEFT_Y:
        return false
    var old := analog_y
    analog_y = value
    if absf(value) < 0.28:
        analog_repeat = 0.0
        return true
    if absf(old) < 0.28 or signf(old) != signf(value):
        move_selection(1 if value > 0 else -1)
        analog_repeat = 0.43
    return true

func _process(delta: float) -> void:
    if not visible or absf(analog_y) < 0.45:
        return
    analog_repeat -= delta
    if analog_repeat <= 0.0:
        move_selection(1 if analog_y > 0 else -1)
        analog_repeat = 0.18
