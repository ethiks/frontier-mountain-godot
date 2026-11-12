extends Node
## Distinct original procedural coin SFX for distributor transactions.
## Generated PCM locally; no third-party sound assets or licensing dependencies.
const SAMPLE_RATE := 22050
const LENGTH := 0.43
var purchase_player: AudioStreamPlayer
var sale_player: AudioStreamPlayer
var purchase_sound: AudioStreamWAV
var sale_sound: AudioStreamWAV

func _ready() -> void:
    purchase_sound = _make_coin_sound(false)
    sale_sound = _make_coin_sound(true)
    purchase_player = AudioStreamPlayer.new()
    purchase_player.name = "PurchaseCoins"
    purchase_player.stream = purchase_sound
    add_child(purchase_player)
    sale_player = AudioStreamPlayer.new()
    sale_player.name = "SaleCoins"
    sale_player.stream = sale_sound
    add_child(sale_player)

func _make_coin_sound(selling: bool) -> AudioStreamWAV:
    var sound := AudioStreamWAV.new()
    sound.format = AudioStreamWAV.FORMAT_16_BITS
    sound.mix_rate = SAMPLE_RATE
    sound.stereo = false
    var samples := int(LENGTH * float(SAMPLE_RATE))
    var bytes := PackedByteArray()
    bytes.resize(samples * 2)
    for i in range(samples):
        var t := float(i) / float(SAMPLE_RATE)
        var v := 0.0
        if selling:
            # Rising, bright triple-coin payout; three separate pitches.
            for step in range(3):
                var onset := float(step) * 0.092
                var age := t - onset
                if age >= 0.0:
                    var env := exp(-age * 15.0) * minf(1.0, age * 160.0)
                    var freq: float = [1047.0, 1319.0, 1568.0][step]
                    v += env * (sin(TAU * freq * age) + 0.22 * sin(TAU * freq * 2.03 * age))
        else:
            # Lower two-clink purchase / coins leaving the purse.
            for step in range(2):
                var onset := float(step) * 0.126
                var age := t - onset
                if age >= 0.0:
                    var env := exp(-age * 19.0) * minf(1.0, age * 140.0)
                    var freq: float = [880.0, 659.25][step]
                    v += env * (sin(TAU * freq * age) + 0.27 * sin(TAU * freq * 1.71 * age))
        var pcm := int(round(clampf(v * 0.37, -1.0, 1.0) * 32767.0))
        bytes.encode_s16(i * 2, pcm)
    sound.data = bytes
    return sound

func play_purchase(audio: Node) -> void:
    _play(purchase_player, audio)

func play_sale(audio: Node) -> void:
    _play(sale_player, audio)

func _play(player: AudioStreamPlayer, audio: Node) -> void:
    if player == null or audio == null or not bool(audio.get("enabled")):
        return
    audio.call("begin_audio")
    var volume := clampf(float(audio.get("sfx_level")) * 0.9, 0.0, 1.0)
    if volume <= 0.001:
        return
    player.stop()
    player.volume_linear = volume
    player.play()
