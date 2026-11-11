extends Node
## Migrated from Frontier Mountain 0.6.1's original sample and music URLs.
## Bundled Ogg Vorbis assets are decoded by Godot and work offline on mobile.
const ASSET_ROOT := "res://assets/audio/"
const TRACK := "old-growth-stillness"
const FX_NAMES := ["axe-chop", "wood-buck", "log-lift", "log-drop", "mill-load", "mill-cut", "tree-fall", "chainsaw-rev"]
const USER_PREFS := "user://frontier_audio.cfg"
var enabled := true
var unlocked := false
var music_level := 0.58
var sfx_level := 0.78
var music_player: AudioStreamPlayer
var samples: Dictionary = {}
var sound_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
    _load_preferences()
    music_player = AudioStreamPlayer.new()
    music_player.name = "OldGrowthStillness"
    add_child(music_player)
    var music_path := ASSET_ROOT + TRACK + ".ogg"
    if ResourceLoader.exists(music_path):
        var stream := load(music_path) as AudioStreamOggVorbis
        if stream != null:
            stream.loop = true
            music_player.stream = stream
    else:
        push_warning("Missing original Frontier Mountain track: " + music_path)
    music_player.volume_linear = music_level if enabled else 0.0
    for name in FX_NAMES:
        var sample_path: String = ASSET_ROOT + name + ".ogg"
        if ResourceLoader.exists(sample_path):
            var sample := load(sample_path) as AudioStream
            if sample != null:
                samples[name] = sample
        else:
            push_warning("Missing Frontier Mountain effect: " + name)

func begin_audio() -> void:
    if unlocked:
        return
    unlocked = true
    if enabled and music_player != null and music_player.stream != null:
        music_player.play()

func play_fx(name: String, strength := 1.0) -> void:
    if not unlocked:
        begin_audio()
    if not enabled or sfx_level <= 0.0 or not samples.has(name):
        return
    # A few reusable sample players allow overlapping chops and falls.
    var player: AudioStreamPlayer
    if sound_players.size() < 10:
        player = AudioStreamPlayer.new()
        player.name = "FX_" + name
        add_child(player)
        sound_players.append(player)
    else:
        player = sound_players[0]
        for candidate in sound_players:
            if not candidate.playing:
                player = candidate
                break
    player.stop()
    player.stream = samples[name]
    player.volume_linear = clampf(sfx_level * strength, 0.0, 1.0)
    player.play()

func toggle_enabled() -> void:
    if not unlocked:
        unlocked = true
        enabled = true
    else:
        enabled = not enabled
    if music_player != null:
        if enabled:
            music_player.volume_linear = music_level
            if not music_player.playing and music_player.stream != null:
                music_player.play()
        else:
            music_player.stop()
    if not enabled:
        for player in sound_players:
            player.stop()
    _save_preferences()

func set_music_level(value: float) -> void:
    music_level = clampf(value, 0.0, 1.0)
    if music_player != null:
        music_player.volume_linear = music_level if enabled else 0.0
    _save_preferences()

func set_sfx_level(value: float) -> void:
    sfx_level = clampf(value, 0.0, 1.0)
    _save_preferences()

func _load_preferences() -> void:
    var prefs := ConfigFile.new()
    if prefs.load(USER_PREFS) == OK:
        enabled = bool(prefs.get_value("audio", "enabled", true))
        music_level = clampf(float(prefs.get_value("audio", "music", 0.58)), 0.0, 1.0)
        sfx_level = clampf(float(prefs.get_value("audio", "effects", 0.78)), 0.0, 1.0)

func _save_preferences() -> void:
    var prefs := ConfigFile.new()
    prefs.set_value("audio", "enabled", enabled)
    prefs.set_value("audio", "music", music_level)
    prefs.set_value("audio", "effects", sfx_level)
    var result := prefs.save(USER_PREFS)
    if result != OK:
        push_warning("Audio settings could not be saved")
