extends Node
## Frontier Mountain original distributor systems, adapted to Godot with the approved assets.
## Yard inventory is distinct from carried timber; shop and contracts are persistent.
const SPECIES := ["Pine", "Spruce", "Birch", "Oak"]
const GOODS := ["Pine logs","Spruce logs","Birch logs","Oak logs","Milled boards","Kiln-dried boards","Sawdust"]
const MARKET_CATEGORIES := ["all","tools","hauling","machines","supplies"]
const SHOP := [
 {"id":"sharp","name":"Sharpened axe","detail":"Stronger, longer-lasting axe.","price":110,"category":"tools"},
 {"id":"handcart","name":"Two-wheeled log cart","detail":"Upgrade your hauling capacity.","price":175,"category":"hauling"},
 {"id":"steel","name":"Steel felling axe","detail":"Fell trees with fewer swings.","price":360,"category":"tools"},
 {"id":"ridge","name":"North ridge logging permit","detail":"Reserve access to the northern ridge.","price":480,"category":"supplies"},
 {"id":"chainsaw","name":"First chainsaw","detail":"Fast cutting; burns fuel and needs repairs.","price":850,"category":"tools"},
 {"id":"chain","name":"Professional chainsaw chain","detail":"+2 damage with the chainsaw.","price":420,"category":"tools"},
 {"id":"tank","name":"Extended fuel tank","detail":"Increase maximum fuel capacity to 200.","price":430,"category":"supplies"},
 {"id":"tractor","name":"Compact forestry tractor","detail":"Heavy hauling and faster travel.","price":1650,"category":"hauling"},
 {"id":"sawmill","name":"Portable sawmill","detail":"Process raw logs into boards and sawdust.","price":1150,"category":"machines"},
 {"id":"kiln","name":"Lumber drying kiln","detail":"Dry boards into premium finished timber.","price":2600,"category":"machines"},
 {"id":"heavycart","name":"Reinforced log wagon","detail":"Increase your timber hauling capacity.","price":620,"category":"hauling"},
 {"id":"sawfeed","name":"Automatic sawmill feed","detail":"Halves processing time.","price":1900,"category":"machines"},
 {"id":"boots","name":"Logger boots","detail":"Travel faster while hauling.","price":270,"category":"hauling"},
 {"id":"shed","name":"Tool shed expansion","detail":"Field repairs with repair parts.","price":475,"category":"supplies"},
 {"id":"lantern","name":"Camp lanterns","detail":"Brighter yard and path visibility after sunset.","price":150,"category":"supplies"},
 {"id":"yardupgrade","name":"Expanded lumber landing","detail":"Increase depot storage from 240 to 450 logs.","price":650,"category":"hauling"},
 {"id":"bridgeupgrade","name":"Logging road bridge","detail":"Reserve access to future river route.","price":825,"category":"supplies"}
]
const SUPPLY_SHOP := [
 {"id":"saplings","name":"Five saplings","detail":"Seed stock for the upcoming planting system.","price":45},
 {"id":"parts","name":"Repair parts (3)","detail":"Service a tool in the field after buying the shed expansion.","price":55},
 {"id":"fuel","name":"Fuel can (+60)","detail":"Top up a chainsaw without an automatic refill.","price":80}
]
var yard_stock := [0,0,0,0,0,0,0]
var reputation := 0
var experience := 0
var haul_delivered := 0
var lifetime_sales := 0
var lifetime_revenue := 0
var shop_owned: Dictionary = {}
var saplings := 4
var repair_parts := 0
var contract_offers: Array[Dictionary] = []
var active_contracts: Array[Dictionary] = []
var contract_sequence := 0
var current_day := 1
var last_event := "A good day to build up your timber outfit."
var milling_queue := 0
var drying_queue := 0
var milling_clock := 0.0
var drying_clock := 0.0
var suppress_save := false

func _ready() -> void:
    generate_offers(1)

func total_raw() -> int:
    return int(yard_stock[0]) + int(yard_stock[1]) + int(yard_stock[2]) + int(yard_stock[3])

func total_inventory() -> int:
    var count := 0
    for value in yard_stock:
        count += int(value)
    return count

func stock_capacity() -> int:
    return 450 if is_owned("yardupgrade") else 240

func available(index: int) -> int:
    if index < 0 or index >= yard_stock.size():
        return 0
    return int(yard_stock[index])

func price(index: int, progression: Node) -> int:
    if index < 0 or index >= 7:
        return 0
    if index < 4:
        return int(progression.market_price(index))
    return [46,76,4][index - 4]

func deposit(game: Node, carried: Array) -> int:
    if carried.is_empty():
        return 0
    var free := maxi(0, stock_capacity() - total_raw())
    var deposited := mini(carried.size(), free)
    for i in range(deposited):
        var species := int(carried[i])
        if species >= 0 and species < 4:
            yard_stock[species] = int(yard_stock[species]) + 1
    for i in range(deposited):
        carried.remove_at(0)
    haul_delivered += deposited
    if deposited > 0:
        game.progression.save_game(game)
    return deposited

func sell_selected(game: Node, selection: Array) -> Dictionary:
    if selection.size() != yard_stock.size():
        return {"count":0,"income":0}
    var counts := []
    var income := 0
    var count := 0
    for i in range(yard_stock.size()):
        var requested := int(selection[i])
        if requested < 0 or requested > int(yard_stock[i]):
            return {"count":0,"income":0}
        counts.append(requested)
        count += requested
        income += requested * price(i, game.progression)
    if count == 0:
        return {"count":0,"income":0}
    for i in range(yard_stock.size()):
        yard_stock[i] = int(yard_stock[i]) - int(counts[i])
    game.set("cash", int(game.get("cash")) + income)
    lifetime_sales += count
    lifetime_revenue += income
    game.progression.total_earned += income
    game.progression.save_game(game)
    game.call("_say", "Sold %d timber units for $%d." % [count, income])
    return {"count":count,"income":income}

func generate_offers(day: int) -> void:
    current_day = day
    contract_offers.clear()
    var announcements := [
        "Pine buyers are rebuilding their timber stock.",
        "The northern mills are paying fairly for clean lumber.",
        "Fresh contracts came in with the morning wagon.",
        "A construction crew needs seasoned boards."
    ]
    last_event = announcements[posmod(day, announcements.size())]
    # Offers are deterministic, limited to three active orders, and re-roll each day.
    for index in range(4):
        contract_sequence += 1
        var species := posmod(day * 3 + index * 5, 4)
        var qty := 2 + posmod(index + day, 4)
        var grade := "raw"
        var product_idx := species
        if index == 3 and is_owned("sawmill"):
            grade = "boards"
            product_idx = 4
        if index == 2 and is_owned("kiln"):
            grade = "dried"
            product_idx = 5
        var unit: int = 46 if grade == "boards" else (76 if grade == "dried" else [13,17,19,27][species])
        var offer: Dictionary = {
            "id": "D%d-%d-%d" % [day,index,contract_sequence],
            "species": species,
            "product": grade,
            "index": product_idx,
            "qty": qty,
            "payout": int(ceil(float(qty * unit) * (1.18 + float(reputation) * 0.01))),
            "xp": 45 + qty * 14,
            "deadline": day + 3 + posmod(index, 2)
        }
        contract_offers.append(offer)

func on_new_day(day: int) -> void:
    # Existing accepted contracts remain active until their deadline.
    var keep: Array[Dictionary] = []
    for item in active_contracts:
        if day <= int(item["deadline"]):
            keep.append(item)
    active_contracts = keep
    generate_offers(day)

func accept_contract(game: Node, offer_id: String) -> bool:
    if active_contracts.size() >= 3:
        game.call("_say", "Maximum 3 active buyer contracts.")
        return false
    for i in range(contract_offers.size()):
        var entry: Dictionary = contract_offers[i]
        if str(entry["id"]) == offer_id:
            active_contracts.append(entry.duplicate(true))
            contract_offers.remove_at(i)
            game.call("_say", "Contract added to your distributor ledger.")
            game.progression.save_game(game)
            return true
    return false

func deliver_contract(game: Node, offer_id: String) -> bool:
    for i in range(active_contracts.size()):
        var entry: Dictionary = active_contracts[i]
        if str(entry["id"]) != offer_id:
            continue
        var idx := int(entry["index"])
        var need := int(entry["qty"])
        if available(idx) < need:
            game.call("_say", "Contract needs %d %s in the loading yard." % [need, GOODS[idx]])
            return false
        yard_stock[idx] = int(yard_stock[idx]) - need
        var payout := int(entry["payout"])
        game.set("cash", int(game.get("cash")) + payout)
        lifetime_sales += need
        lifetime_revenue += payout
        experience += int(entry["xp"])
        reputation += 2
        active_contracts.remove_at(i)
        game.progression.save_game(game)
        game.call("_say", "Buyer order completed! +$%d, reputation +2." % payout)
        return true
    return false

func is_owned(shop_id: String) -> bool:
    return bool(shop_owned.get(shop_id, false))

func _shop_item(shop_id: String) -> Dictionary:
    for item in SHOP:
        if str(item["id"]) == shop_id:
            return item
    return {}

func buy_shop_item(game: Node, shop_id: String) -> bool:
    var item := _shop_item(shop_id)
    if item.is_empty() or is_owned(shop_id):
        return false
    var cost := int(item["price"])
    if int(game.get("cash")) < cost:
        game.call("_say", "Not enough money for %s ($%d)." % [item["name"], cost])
        return false
    game.set("cash", int(game.get("cash")) - cost)
    shop_owned[shop_id] = true
    # Map legacy tiers to the existing, fully tested logging/hauling mechanics.
    match shop_id:
        "sharp":
            game.progression.axe_level = maxi(game.progression.axe_level, 1)
        "steel":
            game.progression.axe_level = maxi(game.progression.axe_level, 2)
        "chainsaw":
            game.progression.axe_level = 3
        "handcart":
            game.progression.cart_level = maxi(game.progression.cart_level, 1)
        "heavycart", "tractor":
            game.progression.cart_level = maxi(game.progression.cart_level, 2)
        "tank":
            game.progression.fuel = 200.0
    if shop_id == "sharp" or shop_id == "steel" or shop_id == "chainsaw":
        game.progression.condition = game.progression.AXE_CONDITION[game.progression.axe_level]
    game.progression.save_game(game)
    game.call("_say", "Purchased %s for $%d." % [item["name"],cost])
    return true

func buy_supply(game: Node, supply_id: String) -> bool:
    var item: Dictionary = {}
    for candidate in SUPPLY_SHOP:
        if str(candidate["id"]) == supply_id:
            item = candidate
    if item.is_empty():
        return false
    var cost := int(item["price"])
    if int(game.get("cash")) < cost:
        game.call("_say", "This supply costs $%d." % cost)
        return false
    if supply_id == "fuel" and game.progression.axe_level < 3:
        game.call("_say", "The chainsaw is required before purchasing fuel.")
        return false
    game.set("cash", int(game.get("cash")) - cost)
    match supply_id:
        "saplings":
            saplings += 5
        "parts":
            repair_parts += 3
        "fuel":
            game.progression.fuel = minf(fuel_max(), game.progression.fuel + 60.0)
    game.progression.save_game(game)
    game.call("_say", "Distributor supplied %s." % item["name"])
    return true

func field_repair(game: Node) -> bool:
    if not is_owned("shed") or repair_parts < 1:
        game.call("_say", "Field repairs require a shed expansion and spare parts.")
        return false
    if game.progression.condition >= game.progression.AXE_CONDITION[game.progression.axe_level]:
        return false
    repair_parts -= 1
    game.progression.condition = game.progression.AXE_CONDITION[game.progression.axe_level]
    game.progression.save_game(game)
    game.call("_say", "Field repair complete: one repair part used.")
    return true

func fuel_max() -> float:
    return 200.0 if is_owned("tank") else 60.0

func movement_multiplier() -> float:
    return (1.17 if is_owned("tractor") else 1.0) * (1.11 if is_owned("boots") else 1.0)

func sawmill_seconds() -> float:
    return 1.5 if is_owned("sawfeed") else 3.0

func queue_sawmill(game: Node, amount: int) -> bool:
    if not is_owned("sawmill") or amount <= 0:
        return false
    var quantity := mini(amount, total_raw())
    if quantity <= 0:
        return false
    for species in range(4):
        while quantity > 0 and int(yard_stock[species]) > 0:
            yard_stock[species] = int(yard_stock[species]) - 1
            milling_queue += 1
            quantity -= 1
    game.progression.save_game(game)
    game.call("_say", "Timber queued for the sawmill.")
    return true

func queue_kiln(game: Node, amount: int) -> bool:
    if not is_owned("kiln") or amount <= 0:
        return false
    var qty := mini(amount, int(yard_stock[4]))
    if qty <= 0:
        return false
    yard_stock[4] = int(yard_stock[4]) - qty
    drying_queue += qty
    game.progression.save_game(game)
    game.call("_say", "%d boards queued for kiln drying." % qty)
    return true

func tick(delta: float, game: Node) -> void:
    if milling_queue > 0:
        milling_clock += delta
        if milling_clock >= sawmill_seconds():
            milling_clock -= sawmill_seconds()
            milling_queue -= 1
            yard_stock[4] = int(yard_stock[4]) + 1
            yard_stock[6] = int(yard_stock[6]) + 1
            game.progression.save_game(game)
    if drying_queue > 0:
        drying_clock += delta
        if drying_clock >= 8.0:
            drying_clock -= 8.0
            drying_queue -= 1
            yard_stock[5] = int(yard_stock[5]) + 1
            game.progression.save_game(game)

func export_data() -> Dictionary:
    return {
        "yard": yard_stock.duplicate(), "reputation": reputation, "xp": experience,
        "haul_delivered": haul_delivered, "lifetime_sales": lifetime_sales,
        "lifetime_revenue": lifetime_revenue, "owned": shop_owned.duplicate(true),
        "saplings": saplings, "parts": repair_parts,
        "offers": contract_offers.duplicate(true), "active": active_contracts.duplicate(true),
        "sequence": contract_sequence, "day": current_day,
        "milling": milling_queue, "drying": drying_queue,
        "mill_clock": milling_clock, "dry_clock": drying_clock
    }

func import_data(data: Variant, day: int) -> void:
    if typeof(data) != TYPE_DICTIONARY:
        generate_offers(day)
        return
    var stocks: Variant = data.get("yard", [])
    if typeof(stocks) == TYPE_ARRAY and stocks.size() == 7:
        for i in range(7):
            yard_stock[i] = clampi(int(stocks[i]), 0, 100000)
    reputation = maxi(0, int(data.get("reputation", 0)))
    experience = maxi(0, int(data.get("xp", 0)))
    haul_delivered = maxi(0, int(data.get("haul_delivered", 0)))
    lifetime_sales = maxi(0, int(data.get("lifetime_sales", 0)))
    lifetime_revenue = maxi(0, int(data.get("lifetime_revenue", 0)))
    var purchased: Variant = data.get("owned", {})
    if typeof(purchased) == TYPE_DICTIONARY:
        shop_owned = purchased.duplicate(true)
    saplings = maxi(0, int(data.get("saplings", 4)))
    repair_parts = maxi(0, int(data.get("parts", 0)))
    contract_sequence = maxi(0, int(data.get("sequence", 0)))
    current_day = maxi(1, int(data.get("day", day)))
    contract_offers.clear()
    for v in data.get("offers", []):
        if typeof(v) == TYPE_DICTIONARY:
            contract_offers.append(v.duplicate(true))
    active_contracts.clear()
    for v in data.get("active", []):
        if typeof(v) == TYPE_DICTIONARY and active_contracts.size() < 3:
            active_contracts.append(v.duplicate(true))
    milling_queue = maxi(0, int(data.get("milling", 0)))
    drying_queue = maxi(0, int(data.get("drying", 0)))
    milling_clock = maxf(0.0, float(data.get("mill_clock", 0.0)))
    drying_clock = maxf(0.0, float(data.get("dry_clock", 0.0)))
    if current_day != day or contract_offers.is_empty():
        on_new_day(day)
