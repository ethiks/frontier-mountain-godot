extends SceneTree
## Distributor restoration integration checks; run with isolated user:// storage.
func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> bool:
    if ok:
        print("PASS: DISTRIBUTOR " + label)
    else:
        push_error("FAIL: DISTRIBUTOR " + label)
    return ok

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if not _check(scene != null,"Godot scene loads"):
        quit(1);return
    var game: Node = scene.instantiate()
    root.add_child(game)
    await process_frame
    var market = game.get("distributor")
    var ui = game.get("ui")
    if not _check(market != null and ui != null,"Distributor and UI systems installed"):
        quit(1);return
    var stall: Sprite2D = game.get_node_or_null("Prop_MarketDistributor")
    if not _check(stall != null and stall.texture != null and stall.texture.get_width() * stall.scale.x >= 400.0,"Approved market stall scales clerk with logger"):
        quit(1);return
    var coins = game.get("trade_sfx")
    if not _check(coins != null and coins.get("purchase_sound") != null and coins.get("sale_sound") != null, "Separate purchase and sale coin generators installed"):
        quit(1);return
    var buy_clip: AudioStreamWAV = coins.get("purchase_sound")
    var sell_clip: AudioStreamWAV = coins.get("sale_sound")
    if not _check(buy_clip.data.size() > 12000 and sell_clip.data.size() > 12000 and buy_clip.data != sell_clip.data, "Purchase and payout coin effects are distinct playable PCM samples"):
        quit(1);return
    if not _check(game.get_node_or_null("Prop_trader-open") == null,"Miniature old trader sprite removed"):
        quit(1);return
    if not _check(ui.get("ui_atlas") != null and ui.menu_panel.get_node_or_null("ApprovedLedgerFrame") != null,"Approved UI atlas and parchment menu imported"):
        quit(1);return
    if not _check(ui.market_tabs.get_parent() == ui.menu_panel and ui.market_tab_buttons.size() == 4, "Market navigation tabs fixed outside scroll region"):
        quit(1);return
    if not _check(ui.action_button.text != "" and ui.action_hint != null and not ui.action_hint.visible, "Blank approved button art displays exactly one dynamic action label"):
        quit(1);return
    if not _check(ui.market_tabs.get_node_or_null("Approved_green") == null, "Menu tabs do not reuse cut-off baked-label artwork"):
        quit(1);return
    if not _check(market.SHOP.size() == 17 and market.SUPPLY_SHOP.size() == 3,"Full 17-item distributor catalog and three supply types listed"):
        quit(1);return
    ui.open_menu("MARKET")
    if not _check(ui.market_view == "sell" and ui.menu_rows.get_child_count() > 8,"Market has selectable species stock ledger"):
        quit(1);return
    ui.market_view = "contracts"
    ui.refresh_menu()
    if not _check(ui.menu_rows.get_child_count() > 7,"Buyer offer board renders"):
        quit(1);return
    ui.market_view = "shop"
    ui.refresh_menu()
    if not _check(ui.menu_rows.get_child_count() > 15,"Original distributor shop listings render"):
        quit(1);return
    ui.market_view = "supplies"
    ui.refresh_menu()
    if not _check(ui.menu_rows.get_child_count() > 7,"Supplies and processing service menu renders"):
        quit(1);return
    ui.close_menu()
    if not _check(market.total_raw() == 0,"Depot starts without decorative or phantom logs"):
        quit(1);return

    game.set("player_pos", Vector2(1662,1324))
    game.get("carried").clear()
    game.get("carried").append_array([0,1,1])
    var before_cash: int = game.get("cash")
    game.call("_interact")
    if not _check(game.get("carried").is_empty() and market.available(0)==1 and market.available(1)==2 and game.get("cash")==before_cash,"Unloading stores species in yard instead of auto-selling"):
        quit(1);return
    if not _check(market.sell_selected(game,[2,0,0,0,0,0,0])["income"] == 0 and market.available(0)==1,"Overselling is rejected without losing stock"):
        quit(1);return
    var receipt: Dictionary = market.sell_selected(game,[1,0,0,0,0,0,0])
    if not _check(receipt["income"] == game.progression.market_price(0) and market.available(1) == 2,"Selectively sell pine without consuming stored spruce"):
        quit(1);return
    if not _check(market.sell_selected(game,[0,0,0,0,0,0,0])["income"]==0,"Zero-quantity sales cannot mint money"):
        quit(1);return

    market.contract_offers.clear()
    market.active_contracts.clear()
    market.contract_offers.append({"id":"smoke","index":1,"species":1,"product":"raw","qty":2,"payout":68,"xp":40,"deadline":4})
    if not _check(market.accept_contract(game,"smoke") and market.active_contracts.size()==1,"Buyer order accepted and moved from offers to active"):
        quit(1);return
    var cash_before_order: int = game.get("cash")
    if not _check(market.deliver_contract(game,"smoke") and market.available(1)==0 and game.get("cash")==cash_before_order+68 and market.reputation==2,"Contract delivery consumes warehouse logs and pays once with reputation"):
        quit(1);return
    if not _check(not market.deliver_contract(game,"smoke") and game.get("cash")==cash_before_order+68,"Contract cannot be delivered twice"):
        quit(1);return
    market.generate_offers(2)
    if not _check(market.contract_offers.size()==4 and market.current_day==2,"Distributor generates four daily buyer offers"):
        quit(1);return
    # All offered inventory is visible immediately, as in v0.6.1.
    game.set("cash",15000)
    if not _check(market.buy_shop_item(game,"sharp") and game.progression.axe_level>=1,"Sharpened axe increases cutting tier"):
        quit(1);return
    if not _check(not market.buy_shop_item(game,"sharp"),"Owned upgrade cannot be repurchased"):
        quit(1);return
    if not _check(market.buy_shop_item(game,"steel") and market.buy_shop_item(game,"chainsaw") and game.progression.axe_level==3,"Steel axe and chainsaw are purchasable"):
        quit(1);return
    market.buy_shop_item(game,"chain")
    if not _check(market.is_owned("chain"),"Professional chainsaw chain purchased"):
        quit(1);return
    market.buy_shop_item(game,"handcart")
    market.buy_shop_item(game,"heavycart")
    if not _check(game.progression.capacity()>=8,"Original handcart and heavy wagon increase hauling capacity"):
        quit(1);return
    market.buy_shop_item(game,"tank")
    if not _check(market.fuel_max()==200 and game.progression.fuel==200.0,"Extended chainsaw fuel tank provides 200 capacity"):
        quit(1);return
    market.buy_shop_item(game,"shed")
    market.buy_supply(game,"parts")
    game.progression.condition=4.0
    if not _check(market.field_repair(game) and market.repair_parts==2,"Spare parts permit field repairs with owned tool shed expansion"):
        quit(1);return
    market.buy_shop_item(game,"sawmill")
    market.buy_shop_item(game,"kiln")
    market.buy_shop_item(game,"sawfeed")
    market.yard_stock[0]=2
    if not _check(market.queue_sawmill(game,2) and market.milling_queue==2 and market.available(0)==0,"Portable sawmill reserves actual stocked logs"):
        quit(1);return
    market.tick(4.0,game)
    market.tick(4.0,game)
    if not _check(market.available(4)>=1 and market.available(6)>=1,"Sawmill produces boards and marketable sawdust"):
        quit(1);return
    if not _check(market.queue_kiln(game,1),"Kiln accepts milled boards"):
        quit(1);return
    market.tick(9.0,game)
    if not _check(market.available(5)>=1,"Kiln yields finished dried boards"):
        quit(1);return
    var old_stock: Array = market.yard_stock.duplicate()
    var save_path := "user://frontier_distributor_test.json"
    if not _check(game.progression.save_game(game,save_path),"Complete warehouse/contracts/shop save succeeds"):
        quit(1);return
    market.yard_stock=[0,0,0,0,0,0,0]
    market.shop_owned.clear()
    if not _check(game.progression.load_game(game,save_path) and market.yard_stock==old_stock and market.is_owned("sawmill"),"Legacy v2 save extension restores processed goods and bought facilities"):
        quit(1);return
    print("PASS: DISTRIBUTOR full original merchant restoration, approved art and persistence complete")
    quit(0)
