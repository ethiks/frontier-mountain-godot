extends CanvasLayer
## Mobile-first unified in-game UI. All components use native Godot Controls;
## no unapproved icons, new character sprites, or bitmap fonts are introduced.
const INK := Color("#17231f")
const PANEL := Color("#192b25")
const PANEL_LIGHT := Color("#304638")
const TIMBER := Color("#ad8858")
const GOLD := Color("#ecd19b")
const CREAM := Color("#f2e6c6")
const MUTED := Color("#c7cbb3")
const DANGER := Color("#a26052")

# Crops from the user-approved Frontier Mountain carved-wood UI artboard.
const UI_REGIONS := {
    "banner": Rect2(0,0,1167,141),
    "ledger": Rect2(0,150,608,451),
    "action": Rect2(620,151,444,97),
    "camp": Rect2(620,255,186,79),
    "market": Rect2(814,255,196,78),
    "gear": Rect2(1016,255,174,78),
    "message": Rect2(622,348,528,91),
    "green": Rect2(622,448,185,80),
    "sound": Rect2(810,448,100,80),
    "mix": Rect2(914,448,93,80),
    "save": Rect2(1010,448,98,80),
    "full": Rect2(1110,448,93,80),
    "joystick": Rect2(0,610,162,167)
}
const APPROVED_UI := "res://assets/ui/approved_ui.webp"
var ui_atlas: Texture2D
var banner_art: TextureRect
var message_art: TextureRect
var ledger_art: NinePatchRect
var market_view := "sell"
var shop_filter := "all"
var sale_quantities := [0,0,0,0,0,0,0]

func _region_texture(name: String) -> AtlasTexture:
    var crop := AtlasTexture.new()
    crop.atlas = ui_atlas
    crop.region = UI_REGIONS[name]
    crop.filter_clip = true
    return crop

func _image(parent: Node, asset_name: String) -> TextureRect:
    var img := TextureRect.new()
    img.name = "Approved_" + asset_name
    img.texture = _region_texture(asset_name)
    img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    img.stretch_mode = TextureRect.STRETCH_SCALE
    img.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(img)
    return img

func _decorate_button(button: Button, asset_name: String, fixed_label: bool = false) -> void:
    # Texture stays behind the native button's input/focus and dynamic text.
    var invisible := StyleBoxEmpty.new()
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        button.add_theme_stylebox_override(state, invisible)
    var art := _image(button, asset_name)
    art.show_behind_parent = true
    art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if fixed_label:
        button.text = ""
        button.tooltip_text = asset_name.capitalize()
    else:
        button.add_theme_color_override("font_color", Color("#342315"))
        button.add_theme_color_override("font_hover_color", Color("#342315"))

var game
var root: Control
var top_panel: ColorRect
var hud: Label
var instructions: Label
var message: Label
var message_backdrop: ColorRect
var navigation_label: Label
var joystick: Control
var action_button: Button
var sound_button: Button
var mixer_button: Button
var fullscreen_button: Button
var save_button: Button
var camp_button: Button
var market_button: Button
var gear_button: Button
var mixer_panel: Panel
var music_slider: HSlider
var effects_slider: HSlider
var shade: ColorRect
var menu_panel: Panel
var menu_title: Label
var menu_scroll: ScrollContainer
var menu_rows: VBoxContainer
var menu_close: Button
var current_menu := ""
var is_open := false
var compact := false
var ui_scale := 1.0

func build(p_game: Node) -> void:
    game = p_game
    ui_atlas = load(APPROVED_UI) as Texture2D
    root = Control.new()
    root.name = "UnifiedHUD"
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(root)
    top_panel = ColorRect.new()
    top_panel.name = "StatusRibbon"
    top_panel.color = Color(0.07, 0.15, 0.12, 0.92)
    top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(top_panel)
    banner_art = _image(top_panel, "banner")
    hud = _label(root, "FRONTIER MOUNTAIN", 22, GOLD)
    instructions = _label(root, "DAY 1 07:36  |  $0", 17, CREAM)
    navigation_label = _label(root, "LOGS 0/4  |  CAMP AXE", 15, MUTED)
    message_backdrop = ColorRect.new()
    message_backdrop.name = "FieldHintBackdrop"
    message_backdrop.color = Color(0.08, 0.15, 0.12, 0.83)
    message_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(message_backdrop)
    message_art = _image(root, "message")
    message = _label(root, "Chop · Buck · Haul · Sell", 15, GOLD)
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    # Retain the approved virtual joystick and 8-direction logger.
    joystick = preload("res://scripts/virtual_joystick.gd").new()
    joystick.name = "MoveStick"
    root.add_child(joystick)
    action_button = _button(root, "CHOP", 21, true)
    action_button.name = "PrimaryAction"
    action_button.pressed.connect(_primary_action)
    camp_button = _button(root, "CAMP", 15)
    camp_button.name = "CampTab"
    camp_button.pressed.connect(func(): open_menu("CAMP"))
    market_button = _button(root, "MARKET", 15)
    market_button.name = "MarketTab"
    market_button.pressed.connect(func(): open_menu("MARKET"))
    gear_button = _button(root, "GEAR", 15)
    gear_button.name = "GearTab"
    gear_button.pressed.connect(func(): open_menu("GEAR"))
    sound_button = _button(root, "SOUND", 13)
    sound_button.pressed.connect(func(): game.call("_toggle_audio"))
    mixer_button = _button(root, "MIX", 13)
    mixer_button.pressed.connect(func(): game.call("_toggle_mixer"))
    save_button = _button(root, "SAVE", 13)
    save_button.pressed.connect(_save_now)
    fullscreen_button = _button(root, "FULL", 13)
    fullscreen_button.pressed.connect(func(): game.call("_toggle_fullscreen"))
    _decorate_button(action_button, "action")
    _decorate_button(camp_button, "camp", true)
    _decorate_button(market_button, "market", true)
    _decorate_button(gear_button, "gear", true)
    _decorate_button(sound_button, "sound", true)
    _decorate_button(mixer_button, "mix", true)
    _decorate_button(save_button, "save", true)
    _decorate_button(fullscreen_button, "full", true)


    _build_mixer()
    _build_menu()
    resize_layout(get_viewport().get_visible_rect().size)

func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
    var result := Label.new()
    result.text = value
    result.add_theme_font_size_override("font_size", font_size)
    result.add_theme_color_override("font_color", color)
    result.add_theme_color_override("font_shadow_color", Color("#080d0b"))
    result.add_theme_constant_override("shadow_offset_x", 1)
    result.add_theme_constant_override("shadow_offset_y", 1)
    result.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(result)
    return result

func _button(parent: Node, text_value: String, font_size: int, primary: bool = false) -> Button:
    var button := Button.new()
    button.text = text_value
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_size_override("font_size", font_size)
    button.add_theme_color_override("font_color", Color("#14211b") if primary else CREAM)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_stylebox_override("normal", _style(TIMBER if primary else PANEL_LIGHT, GOLD if primary else Color("#61745b"), 2))
    button.add_theme_stylebox_override("hover", _style(Color("#d7af72") if primary else Color("#47604b"), GOLD, 2))
    button.add_theme_stylebox_override("pressed", _style(Color("#7a6845"), GOLD, 2))
    button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 2))
    button.add_theme_stylebox_override("disabled", _style(Color("#27332b"), Color("#526052"), 1))
    parent.add_child(button)
    return button

func _style(fill: Color, outline: Color, border_size: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = outline
    style.set_border_width_all(border_size)
    style.set_corner_radius_all(9)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 6
    style.content_margin_bottom = 6
    return style

func _build_mixer() -> void:
    mixer_panel = Panel.new()
    mixer_panel.name = "SoundMixer"
    mixer_panel.add_theme_stylebox_override("panel", _style(PANEL, TIMBER, 2))
    mixer_panel.visible = false
    root.add_child(mixer_panel)
    var header := _label(mixer_panel, "AUDIO", 17, GOLD)
    header.position = Vector2(16, 12)
    var music_label := _label(mixer_panel, "Music", 14, CREAM)
    music_label.position = Vector2(16, 50)
    music_slider = HSlider.new()
    music_slider.position = Vector2(100, 48)
    music_slider.size = Vector2(170, 28)
    music_slider.min_value = 0
    music_slider.max_value = 1
    music_slider.step = 0.05
    music_slider.value = game.audio_engine.music_level
    music_slider.value_changed.connect(func(v: float): game.audio_engine.set_music_level(v))
    mixer_panel.add_child(music_slider)
    var sfx_label := _label(mixer_panel, "Effects", 14, CREAM)
    sfx_label.position = Vector2(16, 101)
    effects_slider = HSlider.new()
    effects_slider.position = Vector2(100, 99)
    effects_slider.size = Vector2(170, 28)
    effects_slider.min_value = 0
    effects_slider.max_value = 1
    effects_slider.step = 0.05
    effects_slider.value = game.audio_engine.sfx_level
    effects_slider.value_changed.connect(func(v: float): game.audio_engine.set_sfx_level(v))
    mixer_panel.add_child(effects_slider)
    var close := _button(mixer_panel, "CLOSE", 13)
    close.position = Vector2(14, 145)
    close.size = Vector2(263, 39)
    close.pressed.connect(func(): mixer_panel.visible = false)

func _build_menu() -> void:
    shade = ColorRect.new()
    shade.name = "MenuBackdrop"
    shade.color = Color(0.01, 0.04, 0.03, 0.76)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.visible = false
    root.add_child(shade)
    menu_panel = Panel.new()
    menu_panel.name = "FieldLedger"
    menu_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    menu_panel.visible = false
    root.add_child(menu_panel)
    ledger_art = NinePatchRect.new()
    ledger_art.name = "ApprovedLedgerFrame"
    ledger_art.texture = _region_texture("ledger")
    ledger_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ledger_art.patch_margin_left = 75
    ledger_art.patch_margin_right = 63
    ledger_art.patch_margin_top = 105
    ledger_art.patch_margin_bottom = 68
    ledger_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_panel.add_child(ledger_art)
    menu_title = _label(menu_panel, "CAMP", 22, GOLD)
    menu_title.position = Vector2(21, 14)
    menu_close = _button(menu_panel, "CLOSE", 14)
    menu_close.pressed.connect(close_menu)
    menu_scroll = ScrollContainer.new()
    menu_scroll.name = "LedgerScroll"
    menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    menu_scroll.follow_focus = true
    menu_panel.add_child(menu_scroll)
    menu_rows = VBoxContainer.new()
    menu_rows.name = "LedgerRows"
    menu_rows.add_theme_constant_override("separation", 8)
    menu_scroll.add_child(menu_rows)

func _calculate_ui_scale(logical: Vector2, actual_height: float) -> float:
    # Godot Web canvas_items may render its 1280x720 reference viewport
    # into a 844x390 browser canvas. Without scaling, 47px buttons become
    # approximately 25 physical pixels high and are hard to tap.
    if actual_height < 505.0 and logical.y > 590.0:
        return 1.52
    if actual_height < 620.0 and logical.y > 590.0:
        return 1.17
    return 1.0

func resize_layout(size: Vector2) -> void:
    if root == null:
        return
    var physical_h := size.y
    if OS.has_feature("web"):
        var browser_h: Variant = JavaScriptBridge.eval("Number(window.innerHeight)")
        if typeof(browser_h) == TYPE_INT or typeof(browser_h) == TYPE_FLOAT:
            physical_h = float(browser_h)
    ui_scale = _calculate_ui_scale(size, physical_h)
    var w := maxf(600.0, size.x / ui_scale)
    var h := maxf(345.0, size.y / ui_scale)
    compact = w < 1030.0 or h < 520.0
    root.position = Vector2.ZERO
    root.scale = Vector2.ONE * ui_scale
    root.size = Vector2(w, h)
    top_panel.position = Vector2.ZERO
    top_panel.size = Vector2(w, 98.0 if compact else 104.0)
    banner_art.position = Vector2.ZERO
    banner_art.size = Vector2(maxf(510.0, w - 325.0), top_panel.size.y)

    hud.position = Vector2(16, 10)
    hud.add_theme_font_size_override("font_size", 18 if compact else 23)
    instructions.position = Vector2(400 if compact else 424, 24)
    instructions.add_theme_font_size_override("font_size", 14 if compact else 16)
    navigation_label.position = Vector2(400 if compact else 424, 54)
    navigation_label.add_theme_font_size_override("font_size", 12 if compact else 14)
    message.position = Vector2(16, 111 if compact else 117)
    message.size = Vector2(minf(w - 43.0, 525.0), 47)
    message_backdrop.position = message.position - Vector2(8, 4)
    message_backdrop.size = Vector2(message.size.x + 16, 51)
    message_art.position = message_backdrop.position - Vector2(4, 6)
    message_art.size = Vector2(message_backdrop.size.x + 8, message_backdrop.size.y + 9)

    message.add_theme_font_size_override("font_size", 13 if compact else 15)
    var tool_w := 68.0 if compact else 80.0
    var gap := 5.0
    var start_x := w - (tool_w * 4.0 + gap * 3.0) - 11.0
    for i in range(4):
        var b: Button = [sound_button, mixer_button, save_button, fullscreen_button][i]
        b.position = Vector2(start_x + float(i) * (tool_w + gap), 12)
        b.size = Vector2(tool_w, 42.0)
        b.add_theme_font_size_override("font_size", 12 if compact else 14)
    var stick_y := h - 190.0
    joystick.position = Vector2(11, stick_y)
    var action_w := 154.0 if compact else 184.0
    action_button.size = Vector2(action_w, 77.0 if compact else 90.0)
    action_button.position = Vector2(w - action_w - 18.0, h - action_button.size.y - 19.0)
    var menu_w := 91.0 if compact else 105.0
    var menu_y := action_button.position.y - 58.0
    for i in range(3):
        var b: Button = [camp_button, market_button, gear_button][i]
        b.size = Vector2(menu_w, 47)
        b.position = Vector2(w - (menu_w * 3.0 + 5.0 * 2.0) - 18.0 + float(i) * (menu_w + 5), menu_y)
    mixer_panel.size = Vector2(292, 197)
    mixer_panel.position = Vector2(w - 305.0, 59)
    shade.position = Vector2.ZERO
    shade.size = Vector2(w, h)
    var panel_w := minf(610.0, w - 46.0)
    var panel_h := minf(552.0, h - 42.0)
    menu_panel.size = Vector2(panel_w, panel_h)
    ledger_art.position = Vector2.ZERO
    ledger_art.size = menu_panel.size

    menu_panel.position = Vector2((w - panel_w) * 0.5, (h - panel_h) * 0.5)
    menu_title.position = Vector2(70.0, 77.0)
    menu_title.add_theme_color_override("font_color", Color("#432e1c"))
    menu_close.position = Vector2(panel_w - 135.0, 69.0)
    menu_close.size = Vector2(96, 42)
    menu_scroll.position = Vector2(57, 127)
    menu_scroll.size = Vector2(panel_w - 115.0, panel_h - 167.0)
    menu_rows.custom_minimum_size.x = panel_w - 139.0

func update_header() -> void:
    if game == null:
        return
    var progress = game.progression
    var money: int = int(game.get("cash"))
    hud.text = ""  # The approved banner already has the logo lettering.
    instructions.text = "DAY %d  %s  •  $%d  •  %s" % [progress.day, progress.clock_string(), money, progress.axe_name()]
    navigation_label.text = "LOGS %d/%d  •  TOOL %d%%  •  HOME %d tiles" % [game.get("carried").size(), progress.capacity(), int(progress.condition / progress.AXE_CONDITION[progress.axe_level] * 100.0), int(game.get("player_pos").distance_to(game.YARD_POSITION) / 32.0)]
    message.text = game.get("message_text")
    sound_button.modulate = Color.WHITE if game.audio_engine.enabled else Color(0.75, 0.50, 0.45, 0.85)
    if is_open and current_menu != "":
        # Text refresh happens after transactions; don't rebuild scroll every frame.
        pass

func open_menu(which: String) -> void:
    current_menu = which
    is_open = true
    shade.visible = true
    menu_panel.visible = true
    mixer_panel.visible = false
    refresh_menu()

func _primary_action() -> void:
    if not is_open:
        game.call("_interact")

func close_menu() -> void:
    is_open = false
    shade.visible = false
    menu_panel.visible = false
    current_menu = ""

func refresh_menu() -> void:
    if not is_open:
        return
    for existing in menu_rows.get_children():
        menu_rows.remove_child(existing)
        existing.queue_free()
    menu_title.text = "CAMP & SAVES" if current_menu == "CAMP" else ("TIMBER MARKET" if current_menu == "MARKET" else "EQUIPMENT & HAULING")
    var progress = game.progression
    if current_menu == "CAMP":
        _paragraph("DAY %d  •  %s  •  fifteen-minute day cycle" % [progress.day, progress.clock_string()], true)
        _paragraph("Progress saves automatically after logging, purchases, trading and every 35 seconds.")
        _menu_button("SAVE GAME", _save_now)
        _menu_button("LOAD LAST SAVE", _load_now)
        _menu_button("REST UNTIL MORNING  ·  at cabin door", _rest_now)
        _paragraph("Sleeping advances the day and refreshes timber prices and the daily contract.")
    elif current_menu == "MARKET":
        _paragraph("TODAY'S TIMBER PRICES", true)
        for species in range(4):
            _paragraph("%s logs     $%d each" % [progress.SPECIES[species], progress.market_price(species)])
        var contract_status := "PAID" if progress.contract_claimed else "%d/%d delivered" % [progress.contract_progress, progress.contract_goal]
        _paragraph("DAILY CONTRACT", true)
        _paragraph("Deliver %d %s logs  •  bonus $%d\n%s" % [progress.contract_goal, progress.SPECIES[progress.contract_species], progress.contract_reward, contract_status])
        var distance: float = game.get("player_pos").distance_to(game.YARD_POSITION)
        var enabled: bool = distance < 110.0 and game.get("carried").size() > 0
        _menu_button("SELL CARRIED LOGS  ·  at loading zone", _sell_now, enabled)
        _paragraph("Prices change each morning. Contract bonuses pay once when the required species are delivered.")
        _paragraph("Lifetime: %d logs sold  •  $%d earned" % [progress.total_delivered, progress.total_earned])
    else:
        _paragraph("CURRENT EQUIPMENT", true)
        _paragraph("%s  •  Power %d  •  Condition %d/%d" % [progress.axe_name(), progress.chop_power(), int(progress.condition), int(progress.AXE_CONDITION[progress.axe_level])])
        _paragraph("Hauling: %s  •  %d logs" % [progress.cart_name(), progress.capacity()])
        if progress.axe_level < progress.AXES.size() - 1:
            _menu_button("UPGRADE TO %s    $%d" % [progress.AXES[progress.axe_level + 1], progress.AXE_COSTS[progress.axe_level + 1]], _upgrade_axe)
        if progress.cart_level < progress.CARTS.size() - 1:
            _menu_button("UPGRADE TO %s    $%d" % [progress.CARTS[progress.cart_level + 1], progress.CART_COSTS[progress.cart_level + 1]], _upgrade_cart)
        _menu_button("REPAIR CUTTING TOOL", _repair)
        if progress.axe_level == 3:
            _paragraph("Chainsaw fuel: %d/%d" % [int(progress.fuel), int(progress.FUEL_CAPACITY)])
            _menu_button("REFUEL CHAINSAW    $%d" % progress.FUEL_REFILL_COST, _fuel)
        _paragraph("Tool and cart upgrades affect harvesting and load capacity. New visual sprites remain pending separate approval.")

func _paragraph(text_value: String, accent: bool = false) -> void:
    var row := _label(menu_rows, text_value, 18 if accent else 15, GOLD if accent else CREAM)
    row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.custom_minimum_size.y = 34.0 if accent else (56.0 if "\n" in text_value else 30.0)

func _menu_button(title: String, callback: Callable, enabled: bool = true) -> void:
    var b := _button(menu_rows, title, 15, true)
    b.custom_minimum_size.y = 47
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.disabled = not enabled
    b.pressed.connect(callback)

func _save_now() -> void:
    if game.progression.save_game(game):
        game.call("_say", "Game saved. Your forest and inventory are protected.")
    else:
        game.call("_say", "Unable to save on this device.")
    refresh_menu()

func _load_now() -> void:
    if game.progression.load_game(game):
        game.call("_say", "Saved forest restored.")
    else:
        game.call("_say", "No compatible save found.")
    refresh_menu()

func _rest_now() -> void:
    game.progression.rest(game)
    refresh_menu()

func _sell_now() -> void:
    game.call("_interact")
    refresh_menu()

func _upgrade_axe() -> void:
    game.progression.buy_axe(game)
    refresh_menu()

func _upgrade_cart() -> void:
    game.progression.buy_cart(game)
    refresh_menu()

func _repair() -> void:
    game.progression.repair_tool(game)
    refresh_menu()

func _fuel() -> void:
    game.progression.refill_fuel(game)
    refresh_menu()
