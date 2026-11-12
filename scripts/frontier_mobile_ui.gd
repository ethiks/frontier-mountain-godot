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
const WORLD_UI_ATLAS := "res://assets/ui/world_ui_unified_atlas.png"
const WORLD_UI_REGIONS := {
    "bar_short": Rect2(0,0,268,59),
    "bar_medium": Rect2(290,0,442,66),
    "bar_long": Rect2(750,0,797,86),
    "utility_sound": Rect2(0,112,102,89),
    "utility_mix": Rect2(120,112,103,89),
    "utility_save": Rect2(240,112,102,89),
    "utility_full": Rect2(360,112,103,89),
    "title_camp": Rect2(500,112,183,86),
    "title_market": Rect2(705,112,187,86),
    "title_gear": Rect2(912,112,179,86)
}
var world_ui_atlas: Texture2D
var status_plate: TextureRect
var hint_seconds := 5.0
var last_hint := ""
func _world_texture(name: String) -> AtlasTexture:
    var region := AtlasTexture.new()
    region.atlas = world_ui_atlas
    region.region = WORLD_UI_REGIONS[name]
    region.filter_clip = true
    return region

func _world_image(parent: Node, asset_name: String) -> TextureRect:
    var image_node := TextureRect.new()
    image_node.name = "WorldArt_" + asset_name
    image_node.texture = _world_texture(asset_name)
    image_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    image_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image_node.stretch_mode = TextureRect.STRETCH_SCALE
    image_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(image_node)
    return image_node

func _carve_button(button: Button, asset_name: String = "bar_short") -> void:
    # NinePatchRect makes one approved blank wood frame work at any button width.
    var empty := StyleBoxEmpty.new()
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        button.add_theme_stylebox_override(state, empty)
    var art := NinePatchRect.new()
    art.name = "UnifiedCarvedWood"
    art.texture = _world_texture(asset_name)
    art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    art.patch_margin_left = 24
    art.patch_margin_right = 24
    art.patch_margin_top = 18
    art.patch_margin_bottom = 18
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.show_behind_parent = true
    button.add_child(art)
    art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    button.add_theme_color_override("font_color", CREAM)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 3))

func reveal_message(words: String) -> void:
    last_hint = words
    hint_seconds = 5.0
    if message != null:
        message.text = words
        message.modulate.a = 1.0
    if message_art != null:
        message_art.modulate.a = 1.0

func _process(delta: float) -> void:
    if message == null or message_art == null:
        return
    if hint_seconds > 0.0:
        hint_seconds = maxf(0.0, hint_seconds - delta)
    var opacity := clampf(hint_seconds / 0.75, 0.0, 1.0)
    message.modulate.a = opacity
    message_art.modulate.a = opacity

var ui_atlas: Texture2D
var banner_art: TextureRect
var message_art: TextureRect
var ledger_art: NinePatchRect
var menu_header_art: NinePatchRect
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
var market_tabs: HBoxContainer
var market_tab_buttons: Dictionary = {}
var shop_a
var action_hint: Label
var current_menu := ""
var is_open := false
var compact := false
var ui_scale := 1.0

func build(p_game: Node) -> void:
    game = p_game
    ui_atlas = load(APPROVED_UI) as Texture2D
    world_ui_atlas = load(WORLD_UI_ATLAS) as Texture2D
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
    status_plate = _world_image(root, "bar_medium")
    hud = _label(root, "FRONTIER MOUNTAIN", 22, GOLD)
    instructions = _label(root, "DAY 1 07:36  |  $0", 17, CREAM)
    navigation_label = _label(root, "LOGS 0/4  |  CAMP AXE", 15, MUTED)
    message_backdrop = ColorRect.new()
    message_backdrop.name = "FieldHintBackdrop"
    message_backdrop.color = Color(0.08, 0.15, 0.12, 0.83)
    message_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(message_backdrop)
    message_art = _image(root, "message")
    message_art.texture = _world_texture("bar_long")
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
    # Use the approved *unlettered* carved-wood sign as the primary action
    # texture. The original action crop already contains CHOP lettering and
    # cannot display PICK UP/BUCK/UNLOAD without doubled text.
    _decorate_button(action_button, "message")
    action_button.get_node("Approved_message").visible = false
    _carve_button(action_button, "bar_short")
    action_button.add_theme_color_override("font_color", CREAM)
    action_button.add_theme_color_override("font_hover_color", Color.WHITE)
    action_hint = _label(root, "", 14, GOLD)
    action_hint.visible = false
    _decorate_button(camp_button, "camp", true)
    _decorate_button(market_button, "market", true)
    _decorate_button(gear_button, "gear", true)
    _decorate_button(sound_button, "sound", true)
    _decorate_button(mixer_button, "mix", true)
    _decorate_button(save_button, "save", true)
    _decorate_button(fullscreen_button, "full", true)
    # Paint utility icons directly over the world, never in an opaque bar.
    sound_button.get_node("Approved_sound").texture = _world_texture("utility_sound")
    mixer_button.get_node("Approved_mix").texture = _world_texture("utility_mix")
    save_button.get_node("Approved_save").texture = _world_texture("utility_save")
    fullscreen_button.get_node("Approved_full").texture = _world_texture("utility_full")
    top_panel.visible = false
    banner_art.visible = false
    hud.visible = false
    message_backdrop.visible = false
    # Market/Camp/Gear are accessed from their physical world locations and
    # existing keyboard/gamepad shortcuts, not by blocking gameplay at right.
    camp_button.visible = false
    market_button.visible = false
    gear_button.visible = false



    _build_mixer()
    _build_menu()
    shop_a = preload("res://scripts/frontier_market_unified.gd").new()
    shop_a.name = "VariationAShop"
    root.add_child(shop_a)
    shop_a.setup(self, game)
    shop_a.visible = false
    reveal_message(str(game.get("message_text")))
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
    # One art frame, one fixed header, one page switcher and one scrolling
    # content surface. No UI text or controls are placed over the antler roof.
    shade = ColorRect.new()
    shade.name = "MenuBackdrop"
    shade.color = Color(0.005, 0.015, 0.012, 0.82)
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
    ledger_art.patch_margin_left = 74
    ledger_art.patch_margin_right = 65
    ledger_art.patch_margin_top = 114
    ledger_art.patch_margin_bottom = 61
    ledger_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_panel.add_child(ledger_art)
    # Mobile uses the approved blank timber sign instead of shrinking the
    # elaborate antler roof into half of the available phone screen.
    menu_header_art = NinePatchRect.new()
    menu_header_art.name = "ApprovedCompactWoodHeader"
    menu_header_art.texture = _region_texture("message")
    menu_header_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    menu_header_art.patch_margin_left = 29
    menu_header_art.patch_margin_right = 31
    menu_header_art.patch_margin_top = 24
    menu_header_art.patch_margin_bottom = 23
    menu_header_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_header_art.visible = false
    menu_panel.add_child(menu_header_art)
    menu_title = _label(menu_panel, "FIELD LEDGER", 19, Color("#3b2c21"))
    menu_title.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
    menu_title.add_theme_constant_override("shadow_offset_x", 0)
    menu_title.add_theme_constant_override("shadow_offset_y", 0)
    menu_close = _button(menu_panel, "CLOSE", 15)
    menu_close.name = "LedgerClose"
    menu_close.add_theme_stylebox_override("normal", _style(Color("#9a7049"), Color("#513720"), 2))
    menu_close.add_theme_stylebox_override("hover", _style(Color("#c79b61"), Color("#513720"), 2))
    menu_close.add_theme_color_override("font_color", Color("#fff0c7"))
    menu_close.pressed.connect(close_menu)

    market_tabs = HBoxContainer.new()
    market_tabs.name = "MarketPageTabs"
    market_tabs.add_theme_constant_override("separation", 7)
    market_tabs.visible = false
    menu_panel.add_child(market_tabs)
    for entry in [["sell", "SELL TIMBER"], ["contracts", "CONTRACTS"], ["shop", "SHOP"], ["supplies", "SUPPLIES"]]:
        var key: String = str(entry[0])
        var button := _button(market_tabs, str(entry[1]), 13)
        button.name = "Tab_" + key
        button.custom_minimum_size.y = 44
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(func(): _choose_market_page(key))
        market_tab_buttons[key] = button

    menu_scroll = ScrollContainer.new()
    menu_scroll.name = "LedgerScroll"
    menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    menu_scroll.follow_focus = true
    menu_panel.add_child(menu_scroll)
    menu_rows = VBoxContainer.new()
    menu_rows.name = "LedgerRows"
    menu_rows.add_theme_constant_override("separation", 5)
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
    # Compact, floating world HUD: everything overlays game imagery.
    top_panel.visible = false
    banner_art.visible = false
    hud.visible = false
    status_plate.position = Vector2(9.0, 7.0)
    status_plate.size = Vector2(295.0 if compact else 350.0, 69.0)
    instructions.position = Vector2(34.0, 20.0)
    instructions.size = Vector2(status_plate.size.x - 44.0, 23.0)
    navigation_label.position = Vector2(34.0, 46.0)
    navigation_label.size = Vector2(status_plate.size.x - 44.0, 20.0)
    instructions.add_theme_font_size_override("font_size", 13 if compact else 16)
    navigation_label.add_theme_font_size_override("font_size", 11 if compact else 14)
    message_backdrop.visible = false
    message_art.position = Vector2(10.0, 84.0)
    message_art.size = Vector2(minf(w * 0.66, 508.0), 59.0)
    message.position = message_art.position + Vector2(20.0, 14.0)
    message.size = message_art.size - Vector2(36.0, 16.0)
    message.add_theme_font_size_override("font_size", 13 if compact else 15)
    # Tap targets are independent 54px game buttons, floating over the map.
    var tool_w := 58.0 if compact else 62.0
    var tool_h := 54.0 if compact else 58.0
    var gap := 6.0
    var start_x := w - (tool_w * 4.0 + gap * 3.0) - 10.0
    for i in range(4):
        var button_node: Button = [sound_button,mixer_button,save_button,fullscreen_button][i]
        button_node.position = Vector2(start_x + float(i) * (tool_w + gap), 10.0)
        button_node.size = Vector2(tool_w, tool_h)
    joystick.position = Vector2(11.0,h - 190.0)
    var action_w := 164.0 if compact else 186.0
    action_button.size = Vector2(action_w, 74.0 if compact else 82.0)
    action_button.position = Vector2(w - action_w - 16.0,h - action_button.size.y - 19.0)
    action_hint.visible = false
    camp_button.visible = false
    market_button.visible = false
    gear_button.visible = false
    mixer_panel.size = Vector2(292.0,197.0)
    mixer_panel.position = Vector2(w - 305.0, 76.0)
    shade.position = Vector2.ZERO
    shade.size = Vector2(w, h)
    # Preserve the approved frame's aspect ratio rather than stretching it
    # to the whole screen. The ledger stays inside safe landscape margins.
    var panel_h := minf(574.0, h - 20.0)
    var panel_w := minf(minf(750.0, panel_h * 1.39), w - 40.0)
    menu_panel.size = Vector2(panel_w, panel_h)
    menu_panel.position = Vector2((w - panel_w) * 0.5, (h - panel_h) * 0.5)
    ledger_art.position = Vector2.ZERO
    ledger_art.size = menu_panel.size
    _layout_ledger_content()
    if shop_a != null:
        shop_a.resize_shop(Vector2(w,h), compact)

func _layout_ledger_content() -> void:
    if menu_panel == null:
        return
    var width_px := menu_panel.size.x
    var height_px := menu_panel.size.y
    market_tabs.visible = current_menu == "MARKET"
    if compact:
        # Purpose-built landscape phone ledger. Uses approved blank wood
        # banner and the game's parchment/green palette, while preserving
        # most of the screen for real, touch-scrollable market content.
        ledger_art.visible = false
        menu_header_art.visible = true
        menu_panel.add_theme_stylebox_override("panel", _style(Color("#ddc29a"), Color("#684127"), 6))
        menu_header_art.position = Vector2(6.0, 6.0)
        menu_header_art.size = Vector2(width_px - 12.0, 61.0)
        menu_title.position = Vector2(29.0, 21.0)
        menu_title.add_theme_color_override("font_color", Color("#fff1ce"))
        menu_title.add_theme_font_size_override("font_size", 18)
        menu_close.position = Vector2(width_px - 111.0, 16.0)
        menu_close.size = Vector2(90.0, 39.0)
        market_tabs.position = Vector2(16.0, 73.0)
        market_tabs.size = Vector2(width_px - 32.0, 45.0)
        var start_y := 126.0 if current_menu == "MARKET" else 80.0
        menu_scroll.position = Vector2(20.0, start_y)
        menu_scroll.size = Vector2(width_px - 40.0, maxf(70.0, height_px - start_y - 23.0))
        menu_rows.custom_minimum_size.x = width_px - 60.0
    else:
        # On desktop, retain the ornate approved frame. Move copy entirely
        # below the roof and within the parchment, away from its cloth props.
        ledger_art.visible = true
        menu_header_art.visible = false
        menu_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
        menu_title.position = Vector2(115.0, 129.0)
        menu_title.add_theme_color_override("font_color", Color("#4e301e"))
        menu_title.add_theme_font_size_override("font_size", 20)
        menu_close.position = Vector2(width_px - 149.0, 121.0)
        menu_close.size = Vector2(89.0, 38.0)
        market_tabs.position = Vector2(103.0, 176.0)
        market_tabs.size = Vector2(width_px - 206.0, 45.0)
        var start_y := 231.0 if current_menu == "MARKET" else 180.0
        menu_scroll.position = Vector2(126.0, start_y)
        menu_scroll.size = Vector2(width_px - 231.0, maxf(82.0, height_px - start_y - 105.0))
        menu_rows.custom_minimum_size.x = width_px - 255.0


func update_header() -> void:
    if game == null:
        return
    var progress = game.progression
    var money: int = int(game.get("cash"))
    hud.text = ""  # The approved banner already has the logo lettering.
    if compact:
        # Compact floating status strip; no permanent game logo.
        # Two genuinely short lines fit between the approved logo and
        # the four fixed utility icons on a 390px landscape phone.
        instructions.text = "D%d %s  $%d" % [progress.day, progress.clock_string(), money]
        navigation_label.text = "%d/%d LOGS · %d%%" % [game.get("carried").size(), progress.capacity(), int(progress.condition / progress.AXE_CONDITION[progress.axe_level] * 100.0)]
    else:
        instructions.text = "DAY %d  %s  •  $%d  •  %s" % [progress.day, progress.clock_string(), money, progress.axe_name()]
        navigation_label.text = "LOGS %d/%d  •  TOOL %d%%  •  HOME %d tiles" % [game.get("carried").size(), progress.capacity(), int(progress.condition / progress.AXE_CONDITION[progress.axe_level] * 100.0), int(game.get("player_pos").distance_to(game.YARD_POSITION) / 32.0)]
    var new_hint: String = str(game.get("message_text"))
    if new_hint != last_hint:
        reveal_message(new_hint)
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
    if shop_a != null and current_menu == "MARKET":
        shop_a.focus_selected()

func _primary_action() -> void:
    if not is_open:
        game.call("_interact")

func close_menu() -> void:
    is_open = false
    shade.visible = false
    menu_panel.visible = false
    if shop_a != null:
        shop_a.visible = false
        shop_a.pending_id = ""
        shop_a.analog_y = 0.0
    current_menu = ""

func refresh_menu() -> void:
    if not is_open:
        return
    var show_variation_a: bool = current_menu == "MARKET"
    menu_panel.visible = not show_variation_a
    if shop_a != null:
        shop_a.visible = show_variation_a
        if show_variation_a:
            shop_a.set_page(market_view)
            return
    for existing in menu_rows.get_children():
        menu_rows.remove_child(existing)
        existing.queue_free()
    menu_title.text = "CAMP LEDGER" if current_menu == "CAMP" else ("MARKET DISTRIBUTOR" if current_menu == "MARKET" else "GEAR & TOOLS")
    _layout_ledger_content()
    var progress = game.progression
    var dealer = game.distributor
    if current_menu == "CAMP":
        _paragraph("DAY %d   %s   ·   FUNDS $%d" % [progress.day,progress.clock_string(),int(game.get("cash"))], true)
        _paragraph("Your forest, fallen timber, yard inventory and distributor orders are stored in your save.")
        _menu_button("SAVE CURRENT GAME", _save_now)
        _menu_button("LOAD LAST SAVE", _load_now)
        _menu_button("SLEEP UNTIL MORNING (CABIN DOOR)", _rest_now)
        _paragraph("Sleeping refreshes the distributor's orders and market prices. Automatic saving remains enabled.")
    elif current_menu == "GEAR":
        _paragraph("CURRENT EQUIPMENT", true)
        _paragraph("%s  ·  POWER %d  ·  DURABILITY %d/%d" % [progress.axe_name(),progress.chop_power() + (2 if dealer.is_owned("chain") and progress.axe_level == 3 else 0),int(progress.condition),int(progress.AXE_CONDITION[progress.axe_level])])
        _paragraph("HAULING: %s  ·  %d logs" % [progress.cart_name(),progress.capacity()])
        _paragraph("CHAINSAW FUEL: %d/%d  ·  REPAIR PARTS: %d" % [int(progress.fuel),int(dealer.fuel_max()),dealer.repair_parts])
        _menu_button("VISIT DISTRIBUTOR SHOP", _open_shop)
        _menu_button("REPAIR CUTTING TOOL", _repair)
        _menu_button("FIELD REPAIR WITH PARTS", _field_repair, dealer.is_owned("shed") and dealer.repair_parts > 0)
        _paragraph("Equipment purchases are available through the distributor. Cart and chainsaw visuals remain pending their separately approved art.")
    else:
        _paragraph("ELIAS  ·  FRONTIER SUPPLY CO.  ·  $%d  ·  REP %d  ·  XP %d" % [int(game.get("cash")),dealer.reputation,dealer.experience], true)
        _paragraph(dealer.last_event)
        _market_navigation()
        match market_view:
            "contracts":
                _contracts_page()
            "shop":
                _shop_page()
            "supplies":
                _supplies_page()
            _:
                _sell_page()

func _paragraph(text_value: String, accent: bool = false) -> void:
    var row := _label(menu_rows, text_value, 17 if accent else 15, Color("#5c3d25") if accent else Color("#382b1f"))
    row.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
    row.add_theme_constant_override("shadow_offset_x", 0)
    row.add_theme_constant_override("shadow_offset_y", 0)
    row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.custom_minimum_size.y = 37.0 if accent else (58.0 if "\n" in text_value else 32.0)

func _menu_button(title: String, callback: Callable, enabled: bool = true) -> void:
    var b := _button(menu_rows, title, 15, false)
    _carve_button(b)
    # The approved parchment frame supplies art; text buttons use a matching
    # clean wood-tone StyleBox instead of the old cropped "CAMP" lettering.
    b.add_theme_color_override("font_color", CREAM)
    b.add_theme_color_override("font_hover_color", Color.WHITE)
    b.custom_minimum_size.y = 45
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.disabled = not enabled
    b.pressed.connect(callback)

func _market_navigation() -> void:
    # Tabs remain fixed outside the scrolling order book. Unlike the
    # previous sliced green-button crop, these buttons contain no baked
    # lettering that could conflict with the runtime labels.
    for key in market_tab_buttons.keys():
        var button: Button = market_tab_buttons[key]
        var selected := str(key) == market_view
        button.add_theme_stylebox_override("normal", _style(Color("#527044") if selected else Color("#32462f"), Color("#e7c58c") if selected else Color("#936f44"), 2))
        button.add_theme_color_override("font_color", Color("#fff0cc") if selected else Color("#dccba8"))
        button.add_theme_color_override("font_hover_color", Color.WHITE)

func _choose_market_page(name: String) -> void:
    market_view = name
    menu_scroll.scroll_vertical = 0
    refresh_menu()
    if shop_a != null and current_menu == "MARKET":
        shop_a.focus_selected()

func cycle_market_page(direction: int) -> void:
    var pages := ["sell", "contracts", "shop", "supplies"]
    _choose_market_page(str(pages[posmod(pages.find(market_view) + direction, pages.size())]))

func handle_controller_button(button_index: int) -> bool:
    if not is_open:
        return false
    if current_menu == "MARKET":
        if button_index == JOY_BUTTON_LEFT_SHOULDER:
            cycle_market_page(-1)
            return true
        if button_index == JOY_BUTTON_RIGHT_SHOULDER:
            cycle_market_page(1)
            return true
        if shop_a != null and shop_a.handle_button(button_index):
            return true
    if button_index == JOY_BUTTON_B:
        close_menu()
        return true
    if button_index == JOY_BUTTON_Y:
        open_menu("MARKET")
        return true
    if button_index == JOY_BUTTON_X:
        open_menu("GEAR")
        return true
    return false

func handle_controller_axis(axis: int, value: float) -> bool:
    if not is_open:
        return false
    if current_menu == "MARKET" and shop_a != null:
        return shop_a.set_axis(axis, value)
    return false

func handle_keyboard(keycode: int) -> bool:
    if not is_open:
        return false
    if current_menu == "MARKET" and keycode == KEY_Q:
        cycle_market_page(-1)
        return true
    if current_menu == "MARKET" and keycode == KEY_E:
        cycle_market_page(1)
        return true
    if current_menu == "MARKET" and shop_a != null and shop_a.handle_keyboard(keycode):
        return true
    if keycode == KEY_ESCAPE:
        close_menu()
        return true
    return false

func _sell_page() -> void:
    var dealer = game.distributor
    _paragraph("TODAY'S TIMBER PRICES  ·  STORED AT LANDING", true)
    _paragraph("Raw logs remain in the depot until you choose which species and quantity to sell.")
    for i in range(7):
        _sell_stock_row(i)
    var selected_count := 0
    var subtotal := 0
    for i in range(7):
        selected_count += int(sale_quantities[i])
        subtotal += int(sale_quantities[i]) * dealer.price(i, game.progression)
    _paragraph("SELECTED %d UNITS    ESTIMATED RECEIPT $%d" % [selected_count,subtotal], true)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    menu_rows.add_child(row)
    _row_button(row, "ALL", _select_all)
    _row_button(row, "CLEAR", _clear_selected)
    _row_button(row, "SELL $%d" % subtotal, _sell_selected, subtotal > 0)
    _paragraph("Yard occupancy: %d / %d raw logs  ·  Lifetime %d units sold" % [dealer.total_raw(),dealer.stock_capacity(),dealer.lifetime_sales])

func _sell_stock_row(index: int) -> void:
    var dealer = game.distributor
    var stock: int = dealer.available(index)
    var selected := mini(stock, int(sale_quantities[index]))
    sale_quantities[index] = selected
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    menu_rows.add_child(row)
    var text_label := _label(row, "%s    x%d  ·  $%d" % [dealer.GOODS[index],stock,dealer.price(index,game.progression)], 14, Color("#392a1e"))
    text_label.custom_minimum_size = Vector2(267,39)
    text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var minus := _button(row, "-", 19, false)
    minus.custom_minimum_size = Vector2(43,38)
    minus.disabled = selected <= 0
    minus.pressed.connect(func(): _change_selected(index,-1))
    var count := _label(row, str(selected), 17, Color("#573f20"))
    count.custom_minimum_size = Vector2(31,34)
    var plus := _button(row, "+", 18, false)
    plus.custom_minimum_size = Vector2(43,38)
    plus.disabled = selected >= stock
    plus.pressed.connect(func(): _change_selected(index,1))

func _row_button(parent: HBoxContainer, label_text: String, fn: Callable, enabled: bool = true) -> void:
    var b := _button(parent,label_text,15,false)
    b.add_theme_color_override("font_color", CREAM)
    b.custom_minimum_size.y = 45
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.disabled = not enabled
    b.pressed.connect(fn)

func _change_selected(idx: int, direction: int) -> void:
    sale_quantities[idx] = clampi(int(sale_quantities[idx]) + direction,0,game.distributor.available(idx))
    refresh_menu()

func _select_all() -> void:
    for i in range(7):
        sale_quantities[i] = game.distributor.available(i)
    refresh_menu()

func _clear_selected() -> void:
    sale_quantities = [0,0,0,0,0,0,0]
    refresh_menu()

func _sell_selected() -> void:
    var receipt: Dictionary = game.distributor.sell_selected(game, sale_quantities)
    # The distributor itself plays the dedicated sale-coins jingle.
    # Reserve the old log-drop sample for physically unloading timber.
    sale_quantities = [0,0,0,0,0,0,0]
    refresh_menu()

func _contracts_page() -> void:
    var dealer = game.distributor
    _paragraph("BUYER CONTRACTS  ·  %d / 3 ACTIVE" % dealer.active_contracts.size(),true)
    _paragraph("Accept orders, bring timber to the loading yard and deliver to the distributor before the due date.")
    if dealer.active_contracts.is_empty():
        _paragraph("No accepted orders. Choose one from today's offers.")
    for offer in dealer.active_contracts:
        var item: Dictionary = offer
        var idx := int(item["index"])
        _paragraph("ACTIVE · %d %s  ·  DUE DAY %d" % [int(item["qty"]),dealer.GOODS[idx],int(item["deadline"])],true)
        _paragraph("AVAILABLE %d/%d   PAYOUT $%d  ·  XP %d" % [dealer.available(idx),int(item["qty"]),int(item["payout"]),int(item["xp"])])
        var identifier := str(item["id"])
        _menu_button("DELIVER ORDER  +$%d" % int(item["payout"]),func(): _deliver_order(identifier), dealer.available(idx) >= int(item["qty"]))
    _paragraph("NEW DISTRIBUTOR OFFERS",true)
    if dealer.contract_offers.is_empty():
        _paragraph("All orders have been accepted. New orders arrive tomorrow.")
    for offer in dealer.contract_offers:
        var item: Dictionary = offer
        var identifier := str(item["id"])
        _paragraph("%d %s · DUE DAY %d · +%d XP" % [int(item["qty"]),dealer.GOODS[int(item["index"])],int(item["deadline"]),int(item["xp"])])
        _menu_button("ACCEPT ORDER  $%d" % int(item["payout"]),func(): _accept_order(identifier),dealer.active_contracts.size() < 3)
    _paragraph("Reputation %d  ·  Experience %d" % [dealer.reputation,dealer.experience])

func _accept_order(identifier: String) -> void:
    game.distributor.accept_contract(game,identifier)
    refresh_menu()

func _deliver_order(identifier: String) -> void:
    game.distributor.deliver_contract(game,identifier)
    refresh_menu()

func _shop_page() -> void:
    var dealer = game.distributor
    _paragraph("DISTRIBUTOR EQUIPMENT & UPGRADES",true)
    _paragraph("All merchandise is listed from the first morning. You can purchase any item you can afford.")
    var categories := HBoxContainer.new()
    categories.add_theme_constant_override("separation", 3)
    menu_rows.add_child(categories)
    for key in dealer.MARKET_CATEGORIES:
        var category := str(key)
        var b := _button(categories,category.capitalize(),12,false)
        b.custom_minimum_size = Vector2(80,39)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.pressed.connect(func(): _set_shop_filter(category))
    for item in dealer.SHOP:
        var entry: Dictionary = item
        if shop_filter != "all" and str(entry["category"]) != shop_filter:
            continue
        var identifier := str(entry["id"])
        var price := int(entry["price"])
        var owned: bool = dealer.is_owned(identifier)
        _paragraph("%s · $%d" % [entry["name"],price],true)
        _paragraph(str(entry["detail"]))
        _menu_button("OWNED" if owned else "BUY  $%d" % price,func(): _purchase_shop(identifier),not owned and int(game.get("cash")) >= price)
    _paragraph("Approved character animations remain unchanged. New cart, chainsaw and facility visuals require separate art approval.")

func _set_shop_filter(filter_name: String) -> void:
    shop_filter = filter_name
    refresh_menu()

func _purchase_shop(identifier: String) -> void:
    game.distributor.buy_shop_item(game,identifier)
    refresh_menu()

func _supplies_page() -> void:
    var dealer = game.distributor
    _paragraph("DISTRIBUTOR SUPPLIES & SERVICES",true)
    _paragraph("Saplings %d  ·  Repair parts %d  ·  Chainsaw fuel %d/%d" % [dealer.saplings,dealer.repair_parts,int(game.progression.fuel),int(dealer.fuel_max())])
    for item in dealer.SUPPLY_SHOP:
        var entry: Dictionary = item
        var identifier := str(entry["id"])
        _paragraph(str(entry["name"]) + "    $%d" % int(entry["price"]),true)
        _paragraph(str(entry["detail"]))
        _menu_button("PURCHASE SUPPLY",func(): _purchase_supply(identifier),int(game.get("cash")) >= int(entry["price"]))
    _paragraph("MAINTENANCE & FIELD SERVICES",true)
    _menu_button("SERVICE CUTTING TOOL",_repair)
    _menu_button("FIELD REPAIR (1 PART)",_field_repair,dealer.is_owned("shed") and dealer.repair_parts > 0)
    if dealer.is_owned("sawmill"):
        _paragraph("Sawmill: %d logs queued  ·  Boards %d  ·  Sawdust %d" % [dealer.milling_queue,dealer.available(4),dealer.available(6)])
        _menu_button("MILL ONE RAW LOG",func(): _queue_mill(1),dealer.total_raw() > 0)
        _menu_button("MILL ALL RAW LOGS",func(): _queue_mill(dealer.total_raw()),dealer.total_raw() > 0)
    if dealer.is_owned("kiln"):
        _paragraph("Kiln: %d drying  ·  Dried boards %d" % [dealer.drying_queue,dealer.available(5)])
        _menu_button("DRY ONE BOARD",func(): _queue_kiln(1),dealer.available(4) > 0)
        _menu_button("DRY ALL BOARDS",func(): _queue_kiln(dealer.available(4)),dealer.available(4) > 0)

func _purchase_supply(identifier: String) -> void:
    game.distributor.buy_supply(game,identifier)
    refresh_menu()

func _field_repair() -> void:
    game.distributor.field_repair(game)
    refresh_menu()

func _queue_mill(amount: int) -> void:
    game.distributor.queue_sawmill(game,amount)
    refresh_menu()

func _queue_kiln(amount: int) -> void:
    game.distributor.queue_kiln(game,amount)
    refresh_menu()

func _open_shop() -> void:
    current_menu = "MARKET"
    market_view = "shop"
    refresh_menu()

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
