# 効果音。素材ファイルを使わず、起動時に波形を合成して AudioStreamWAV を作る。
extends Node

const RATE := 22050

var _streams: Dictionary = {}
var _players: Array = []
var _next := 0
var volume_db := -6.0


func _ready() -> void:
	for i in range(12):
		var p = AudioStreamPlayer.new()
		p.volume_db = volume_db
		add_child(p)
		_players.append(p)
	_streams["hit"] = _make(0.12, func(t: float, i: int) -> float:
		return (_noise() * 0.7 + sin(t * 900.0 * TAU * (1.0 - t * 4.0)) * 0.5) * _env(t, 0.12, 0.002))
	_streams["hit_heavy"] = _make(0.25, func(t: float, i: int) -> float:
		return (_noise() * 0.6 + sin(t * 120.0 * TAU) * 0.8) * _env(t, 0.25, 0.002))
	_streams["slash"] = _make(0.14, func(t: float, i: int) -> float:
		return _noise() * 0.5 * _env(t, 0.14, 0.03) * (0.5 + t * 5.0))
	_streams["shot"] = _make(0.1, func(t: float, i: int) -> float:
		return (_noise() * 0.8 + _sq(t * 220.0)) * 0.5 * _env(t, 0.1, 0.001))
	_streams["magic"] = _make(0.5, func(t: float, i: int) -> float:
		return (sin(t * TAU * (600.0 + 900.0 * t)) * 0.4 + sin(t * TAU * (900.0 + 1300.0 * t)) * 0.2) * _env(t, 0.5, 0.05))
	_streams["cast"] = _make(0.35, func(t: float, i: int) -> float:
		return sin(t * TAU * (300.0 + sin(t * 40.0) * 40.0)) * 0.3 * _env(t, 0.35, 0.1))
	_streams["explode"] = _make(0.5, func(t: float, i: int) -> float:
		return (_noise() * 0.9 + sin(t * TAU * 70.0) * 0.6) * _env(t, 0.5, 0.005))
	_streams["heal"] = _make(0.6, func(t: float, i: int) -> float:
		var f = 523.0 if t < 0.15 else (659.0 if t < 0.3 else 784.0)
		return sin(t * TAU * f) * 0.35 * _env(t, 0.6, 0.01))
	_streams["guard"] = _make(0.15, func(t: float, i: int) -> float:
		return (sin(t * TAU * 1400.0) * 0.5 + _noise() * 0.2) * _env(t, 0.15, 0.001))
	_streams["select"] = _make(0.06, func(t: float, i: int) -> float:
		return _sq(t * 880.0) * 0.18 * _env(t, 0.06, 0.002))
	_streams["confirm"] = _make(0.14, func(t: float, i: int) -> float:
		var f = 660.0 if t < 0.06 else 990.0
		return _sq(t * f) * 0.2 * _env(t, 0.14, 0.002))
	_streams["cancel"] = _make(0.12, func(t: float, i: int) -> float:
		var f = 440.0 if t < 0.05 else 330.0
		return _sq(t * f) * 0.18 * _env(t, 0.12, 0.002))
	_streams["levelup"] = _make(0.9, func(t: float, i: int) -> float:
		var notes = [523.0, 659.0, 784.0, 1047.0]
		var f: float = notes[min(3, int(t / 0.12))]
		return (_sq(t * f) * 0.12 + sin(t * TAU * f) * 0.2) * _env(t, 0.9, 0.01))
	_streams["link"] = _make(1.0, func(t: float, i: int) -> float:
		return (sin(t * TAU * (200.0 + 800.0 * t)) * 0.4 + _noise() * 0.2 * t) * _env(t, 1.0, 0.05))
	_streams["text"] = _make(0.03, func(t: float, i: int) -> float:
		return _sq(t * 1200.0) * 0.06 * _env(t, 0.03, 0.001))
	_streams["jump"] = _make(0.12, func(t: float, i: int) -> float:
		return _sq(t * (300.0 + t * 2000.0)) * 0.12 * _env(t, 0.12, 0.002))
	_streams["down"] = _make(0.4, func(t: float, i: int) -> float:
		return sin(t * TAU * (400.0 - t * 700.0)) * 0.4 * _env(t, 0.4, 0.01))
	_streams["warn"] = _make(0.5, func(t: float, i: int) -> float:
		return _sq(t * 880.0) * 0.15 * (1.0 if fmod(t, 0.125) < 0.07 else 0.0))
	_streams["chat"] = _make(0.12, func(t: float, i: int) -> float:
		var f = 700.0 if t < 0.05 else 1050.0
		return sin(t * TAU * f) * 0.18 * _env(t, 0.12, 0.003))
	_streams["coin"] = _make(0.25, func(t: float, i: int) -> float:
		var f = 988.0 if t < 0.07 else 1319.0
		return _sq(t * f) * 0.13 * _env(t, 0.25, 0.002))


func play(id: String, pitch: float = 1.0, vol: float = 0.0) -> void:
	if not _streams.has(id):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.volume_db = volume_db + vol
	p.play()


func _env(t: float, length: float, attack: float) -> float:
	if t < attack:
		return t / attack
	return pow(max(0.0, 1.0 - (t - attack) / (length - attack)), 2.0)


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _sq(phase: float) -> float:
	return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0


func _make(length: float, gen: Callable) -> AudioStreamWAV:
	var n = int(length * RATE)
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t = float(i) / RATE
		var v: float = clamp(gen.call(t, i), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
