extends Node
## Frontier Mountain game systems: 15-minute days, economy, contracts, tools and save data.
## Gameplay uses existing approved artwork only. New cart/tool sprites require separate approval.
const SAVE_VERSION := 2
const SAVE_PATH := "user://frontier_mountain_v2.json"
const DAY_SECONDS := 900.0
const BASE_PRICES := [8, 10, 12, 14]
const SPECIES := ["Pine", "Spruce", "Birch", "Oak"]
const AXES := ["Camp Axe", "Hardened Axe", "Steel Axe", "Chainsaw"]
const AXE_COSTS := [0, 70, 160, 380]
const AXE_DAMAGE := [1, 1, 2, 3]
const AXE_CONDITION := [100.0, 120.0, 160.0, 170.0]
const CARTS := ["Backpack", "Handcart", "Timber Cart"]
const CART_COSTS := [0, 145, 420]
const CART_CAPACITY := [4, 8, 12]
const FUEL_REFILL_COST := 18
const FUEL_CAPACITY := 60.0

var day := 1
var day_seconds := 60.0
var axe_level := 0
var cart_level := 0
var condition := 100.0
var fuel := 60.0
var contract_species := 0
var contract_goal := 3
var contract_progress := 0
var contract_claimed := false
var contract_reward := 35
var total_delivered := 0
var total_earned := 0
var autosave_elapsed := 0.0
var loaded_saved_game := false

func _ready() -> void:
    _new_contract()

func clock_string() -> String:
    var minutes := posmod(6 * 60 + int(day_seconds / DAY_SECONDS * 24.0 * 60.0), 24 * 60)
    return "%02d:%02d" % [int(minutes / 60), minutes % 60]

func ambient_color() -> Color:
    var clock_hour := float(posmod(6 * 60 + int(day_seconds / DAY_SECONDS * 1440.0), 1440)) / 60.0
    var brightness := 1.0
    if clock_hour >= 19.0 or clock_hour <= 5.0:
        brightness = 0.58
    elif clock_hour > 17.0:
        brightness = lerpf(1.0, 0.58, (clock_hour - 17.0) / 2.0)
    elif clock_hour < 7.0:
        brightness = lerpf(0.58, 1.0, (clock_hour - 5.0) / 2.0)
    return Color(brightness, brightness * 0.97, lerpf(brightness, 0.82, 0.3), 1.0)

func tick(delta: float, game: Node) -> void:
    if delta <= 0.0:
        return
    day_seconds += delta
    autosave_elapsed += delta
    if day_seconds >= DAY_SECONDS:
        day_seconds = fmod(day_seconds, DAY_SECONDS)
        day += 1
        _new_contract()
        if game.get("distributor") != null:
            game.distributor.on_new_day(day)
        game.call("_say", "Day %d dawns. Timber prices and the contract board have changed." % day)
        save_game(game)
        autosave_elapsed = 0.0
    elif autosave_elapsed >= 35.0:
        autosave_elapsed = 0.0
        save_game(game)

func rest(game: Node) -> bool:
    var position: Vector2 = game.get("player_pos")
    if position.distance_to(Vector2(1567.0, 1112.0)) > 94.0:
        game.call("_say", "Rest at the cabin door.")
        return false
    day += 1
    day_seconds = 30.0
    _new_contract()
    if game.get("distributor") != null:
        game.distributor.on_new_day(day)
    game.call("_say", "Rested at the cabin. Day %d — fresh market and contract." % day)
    save_game(game)
    return true

func _new_contract() -> void:
    contract_species = posmod(day * 3 + 1, SPECIES.size())
    contract_goal = 2 + posmod(day, 3)
    contract_progress = 0
    contract_claimed = false
    contract_reward = 30 + contract_goal * 9 + day % 5 * 4

func market_price(species: int) -> int:
    if species < 0 or species >= BASE_PRICES.size():
        return 0
    var fluctuation := float(posmod(day * 17 + species * 29 + day * species * 11, 9) - 4) * 0.06
    return maxi(1, int(round(float(BASE_PRICES[species]) * (1.0 + fluctuation))))

func sell_logs(game: Node, entries: Array) -> Dictionary:
    if entries.is_empty():
        return {"income": 0, "bonus": 0, "count": 0}
    var income := 0
    var bonus := 0
    for entry in entries:
        var species: int = int(entry)
        if species < 0 or species >= SPECIES.size():
            continue
        income += market_price(species)
        if species == contract_species and not contract_claimed:
            contract_progress = mini(contract_goal, contract_progress + 1)
    if not contract_claimed and contract_progress >= contract_goal:
        contract_claimed = true
        bonus = contract_reward
    game.set("cash", int(game.get("cash")) + income + bonus)
    total_delivered += entries.size()
    total_earned += income + bonus
    return {"income": income, "bonus": bonus, "count": entries.size()}

func axe_name() -> String:
    return AXES[axe_level]

func cart_name() -> String:
    return CARTS[cart_level]

func capacity() -> int:
    return CART_CAPACITY[cart_level]

func chop_power() -> int:
    return AXE_DAMAGE[axe_level]

func can_chop() -> bool:
    return condition > 0.0 and (axe_level != 3 or fuel >= 1.0)

func expend_chop() -> void:
    condition = maxf(0.0, condition - [2.0, 1.6, 1.1, 2.5][axe_level])
    if axe_level == 3:
        fuel = maxf(0.0, fuel - 1.0)

func buy_axe(game: Node) -> bool:
    if axe_level >= AXES.size() - 1:
        game.call("_say", "You already own the best cutting tool.")
        return false
    var price: int = AXE_COSTS[axe_level + 1]
    if int(game.get("cash")) < price:
        game.call("_say", "Not enough cash — %s costs $%d." % [AXES[axe_level + 1], price])
        return false
    game.set("cash", int(game.get("cash")) - price)
    axe_level += 1
    condition = AXE_CONDITION[axe_level]
    game.trade_sfx.play_purchase(game.audio_engine)
    game.call("_say", "Equipped %s. Improved chopping power and durability." % axe_name())
    save_game(game)
    return true

func buy_cart(game: Node) -> bool:
    if cart_level >= CARTS.size() - 1:
        game.call("_say", "Maximum hauling capacity already unlocked.")
        return false
    var price: int = CART_COSTS[cart_level + 1]
    if int(game.get("cash")) < price:
        game.call("_say", "%s requires $%d." % [CARTS[cart_level + 1], price])
        return false
    game.set("cash", int(game.get("cash")) - price)
    cart_level += 1
    game.trade_sfx.play_purchase(game.audio_engine)
    game.call("_say", "%s capacity: %d logs. Cart graphic pending art approval." % [cart_name(), capacity()])
    save_game(game)
    return true

func repair_tool(game: Node) -> bool:
    var maximum: float = AXE_CONDITION[axe_level]
    if condition >= maximum:
        game.call("_say", "Your tool is already in good condition.")
        return false
    var cost := maxi(4, int(ceil((maximum - condition) / maximum * (14.0 + float(axe_level) * 12.0))))
    if int(game.get("cash")) < cost:
        game.call("_say", "Tool repair requires $%d." % cost)
        return false
    game.set("cash", int(game.get("cash")) - cost)
    condition = maximum
    game.trade_sfx.play_purchase(game.audio_engine)
    game.call("_say", "Cutting tool repaired for $%d." % cost)
    save_game(game)
    return true

func refill_fuel(game: Node) -> bool:
    if axe_level < 3:
        game.call("_say", "Fuel is only needed for the chainsaw.")
        return false
    var max_fuel: float = game.distributor.fuel_max() if game.get("distributor") != null else FUEL_CAPACITY
    if fuel >= max_fuel:
        game.call("_say", "Chainsaw fuel tank is already full.")
        return false
    if int(game.get("cash")) < FUEL_REFILL_COST:
        game.call("_say", "Refuelling costs $%d." % FUEL_REFILL_COST)
        return false
    game.set("cash", int(game.get("cash")) - FUEL_REFILL_COST)
    fuel = max_fuel
    game.trade_sfx.play_purchase(game.audio_engine)
    game.call("_say", "Chainsaw refuelled.")
    save_game(game)
    return true

func save_game(game: Node, path: String = SAVE_PATH) -> bool:
    var tree_data: Array = []
    for tree in game.get("trees"):
        tree_data.append([int(tree["state"]), int(tree["hp"]), float(tree["fall_time"])])
    var dropped: Array = []
    for item in game.get("ground_logs"):
        var p: Vector2 = item["pos"]
        dropped.append([p.x, p.y, int(item["type"])])
    var position: Vector2 = game.get("player_pos")
    var data := {
        "version": SAVE_VERSION,
        "saved_at": Time.get_unix_time_from_system(),
        "day": day, "seconds": day_seconds,
        "player": [position.x, position.y],
        "cash": int(game.get("cash")),
        "carried": game.get("carried").duplicate(),
        "trees": tree_data, "dropped": dropped,
        "axe": axe_level, "cart": cart_level,
        "condition": condition, "fuel": fuel,
        "contract": [contract_species, contract_goal, contract_progress, contract_claimed, contract_reward],
        "delivered": total_delivered, "earned": total_earned,
        "distributor": game.distributor.export_data() if game.get("distributor") != null else {}
    }
    var temp_path := path + ".tmp"
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        push_warning("Cannot open save file: " + temp_path)
        return false
    file.store_string(JSON.stringify(data))
    file.flush()
    file.close()
    var original := ProjectSettings.globalize_path(temp_path)
    var final := ProjectSettings.globalize_path(path)
    var renamed := DirAccess.rename_absolute(original, final)
    if renamed != OK:
        # Some sandboxed Web file systems do not implement rename; write directly.
        var fallback := FileAccess.open(path, FileAccess.WRITE)
        if fallback == null:
            push_warning("Save failed: could not write " + path)
            return false
        fallback.store_string(JSON.stringify(data))
        fallback.flush()
        fallback.close()
    return true

func load_game(game: Node, path: String = SAVE_PATH) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return false
    var data: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(data) != TYPE_DICTIONARY or int(data.get("version", -1)) != SAVE_VERSION:
        push_warning("Unsupported or corrupt Frontier Mountain saved game")
        return false
    if typeof(data.get("trees", null)) != TYPE_ARRAY or data["trees"].size() != game.get("trees").size():
        push_warning("Incompatible tree world; save not applied")
        return false
    if typeof(data.get("player", null)) != TYPE_ARRAY or data["player"].size() != 2:
        return false
    if typeof(data.get("carried", null)) != TYPE_ARRAY or typeof(data.get("dropped", null)) != TYPE_ARRAY:
        return false
    var p := Vector2(float(data["player"][0]), float(data["player"][1]))
    if p.x < 33.0 or p.x > 3039.0 or p.y < 33.0 or p.y > 2399.0:
        return false
    day = maxi(1, int(data.get("day", 1)))
    day_seconds = clampf(float(data.get("seconds", 60.0)), 0.0, DAY_SECONDS - 0.01)
    axe_level = clampi(int(data.get("axe", 0)), 0, AXES.size() - 1)
    cart_level = clampi(int(data.get("cart", 0)), 0, CARTS.size() - 1)
    condition = clampf(float(data.get("condition", 100.0)), 0.0, AXE_CONDITION[axe_level])
    fuel = clampf(float(data.get("fuel", FUEL_CAPACITY)), 0.0, FUEL_CAPACITY)
    var contract: Array = data.get("contract", [])
    if contract.size() == 5:
        contract_species = clampi(int(contract[0]), 0, 3)
        contract_goal = clampi(int(contract[1]), 1, 20)
        contract_progress = clampi(int(contract[2]), 0, contract_goal)
        contract_claimed = bool(contract[3])
        contract_reward = maxi(0, int(contract[4]))
    else:
        _new_contract()
    total_delivered = maxi(0, int(data.get("delivered", 0)))
    total_earned = maxi(0, int(data.get("earned", 0)))
    game.set("player_pos", p)
    game.set("cash", maxi(0, int(data.get("cash", 0))))
    game.get("carried").clear()
    for item in data["carried"]:
        if game.get("carried").size() >= capacity():
            break
        var species := int(item)
        if species >= 0 and species < SPECIES.size():
            game.get("carried").append(species)
    var tree_entries: Array = data["trees"]
    for i in range(tree_entries.size()):
        var saved: Variant = tree_entries[i]
        if typeof(saved) != TYPE_ARRAY or saved.size() < 3:
            continue
        var tree: Dictionary = game.get("trees")[i]
        tree["state"] = clampi(int(saved[0]), 0, 3)
        tree["hp"] = clampi(int(saved[1]), 0, int(tree["max_hp"]))
        tree["fall_time"] = maxf(0.0, float(saved[2]))
    for old in game.get("ground_logs"):
        var sprite: Sprite2D = old["sprite"]
        if is_instance_valid(sprite):
            sprite.queue_free()
    game.get("ground_logs").clear()
    for item in data["dropped"]:
        if typeof(item) != TYPE_ARRAY or item.size() < 3:
            continue
        var lp := Vector2(float(item[0]), float(item[1]))
        var species := int(item[2])
        if lp.x >= 0 and lp.x <= 3072 and lp.y >= 0 and lp.y <= 2432 and species >= 0 and species < 4:
            game.call("_spawn_log", lp, species)
    if game.get("distributor") != null:
        game.distributor.import_data(data.get("distributor", {}), day)
    game.call("_rebuild_tree_sprites")
    autosave_elapsed = 0.0
    loaded_saved_game = true
    return true
