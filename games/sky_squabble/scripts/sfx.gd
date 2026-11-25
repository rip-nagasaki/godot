extends Node
## Procedurally synthesized sound effects and a little music loop (autoload "Sfx").
## Everything is generated at startup, so the project needs no audio files.

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var music: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _srng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -15.0
	add_child(music)
	# Synthesis takes a moment, so do it off the main thread.
	WorkerThreadPool.add_task(_build_all)


func _build_all() -> void:
	_build_sounds()
	var m := _build_music()
	_finish_music.call_deferred(m)


func _finish_music(m: AudioStreamWAV) -> void:
	music.stream = m
	music.play()


func play(sound_name: String, vol_db: float = 0.0, pitch: float = 1.0, spread: float = 0.06) -> void:
	if not sounds.has(sound_name):
		return
	var p := players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = sounds[sound_name]
	p.volume_db = vol_db - 4.0
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-spread, spread))
	p.play()


# ---------------------------------------------------------------- synthesis helpers

func _wav(data: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	return w


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Sine sweep from f0 to f1 with exponential decay.
func _sweep(b: PackedFloat32Array, f0: float, f1: float, amp: float, decay: float,
		start: float = 0.0, wave: int = 0, vib: float = 0.0) -> void:
	var phase := 0.0
	var s0 := int(start * RATE)
	var n := b.size() - s0
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / n
		var f := lerpf(f0, f1, k) * (1.0 + vib * sin(t * 38.0))
		phase += f / RATE
		var v: float
		match wave:
			1:
				v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				v *= 0.5
			2:
				v = 2.0 * absf(2.0 * fmod(phase, 1.0) - 1.0) - 1.0
			_:
				v = sin(phase * TAU)
		var env := exp(-t * decay) * minf(1.0, t * 400.0)
		b[s0 + i] += v * amp * env


func _noise(b: PackedFloat32Array, amp: float, decay: float, lp_from: float, lp_to: float,
		start: float = 0.0, attack: float = 0.002) -> void:
	var s0 := int(start * RATE)
	var n := b.size() - s0
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / n
		var a := clampf(lerpf(lp_from, lp_to, k), 0.001, 1.0)
		y += (_srng.randf_range(-1.0, 1.0) - y) * a
		var env := exp(-t * decay) * minf(1.0, t / attack)
		b[s0 + i] += y * amp * env


func _build_sounds() -> void:
	var b: PackedFloat32Array
	var out := {}

	b = _buf(0.28)
	_noise(b, 0.9, 9.0, 0.05, 0.5, 0.0, 0.04)
	_sweep(b, 300, 700, 0.15, 12.0)
	out["dash"] = _wav(b)

	b = _buf(0.35)
	_sweep(b, 260, 70, 0.9, 11.0)
	_sweep(b, 520, 300, 0.25, 18.0, 0.0, 2)
	_noise(b, 0.5, 40.0, 0.4, 0.1)
	out["bonk"] = _wav(b)

	b = _buf(0.55)
	for f in [820.0, 1236.0, 1757.0, 2410.0]:
		_sweep(b, f, f * 0.98, 0.22, 7.0)
	_noise(b, 0.6, 30.0, 0.8, 0.3)
	out["clash"] = _wav(b)

	b = _buf(0.16)
	_sweep(b, 160, 90, 0.7, 25.0)
	_noise(b, 0.25, 40.0, 0.2, 0.05)
	out["bump"] = _wav(b)

	b = _buf(0.8)
	_sweep(b, 1100, 160, 0.45, 2.5, 0.0, 0, 0.03)
	out["fall"] = _wav(b)

	b = _buf(0.25)
	_sweep(b, 140, 60, 0.8, 18.0)
	_noise(b, 0.45, 25.0, 0.3, 0.05)
	out["land"] = _wav(b)

	b = _buf(0.25)
	_sweep(b, 1046, 1046, 0.35, 14.0, 0.0, 1)
	_sweep(b, 1568, 1568, 0.35, 12.0, 0.07, 1)
	out["pickup"] = _wav(b)

	b = _buf(0.5)
	var notes := [784.0, 988.0, 1175.0, 1568.0]
	for i in notes.size():
		_sweep(b, notes[i], notes[i], 0.28, 9.0, i * 0.06, 1)
	out["big_pickup"] = _wav(b)

	b = _buf(0.3)
	_noise(b, 0.9, 14.0, 0.6, 0.05)
	_sweep(b, 220, 110, 0.3, 16.0)
	out["splat"] = _wav(b)

	b = _buf(1.4)
	_noise(b, 1.0, 3.2, 0.7, 0.03)
	_sweep(b, 90, 30, 0.9, 3.0)
	_sweep(b, 180, 50, 0.4, 6.0, 0.0, 2)
	out["explode"] = _wav(b)

	b = _buf(0.12)
	_sweep(b, 880, 880, 0.4, 20.0, 0.0, 2)
	out["beep"] = _wav(b)

	b = _buf(0.5)
	for f in [1046.0, 1318.0, 1568.0]:
		_sweep(b, f, f, 0.22, 5.0, 0.0, 1)
	out["go"] = _wav(b)

	b = _buf(0.05)
	_noise(b, 0.6, 90.0, 0.9, 0.9)
	_sweep(b, 2200, 2000, 0.3, 80.0)
	out["tick"] = _wav(b)

	b = _buf(1.1)
	var fan := [523.0, 659.0, 784.0, 1046.0]
	for i in fan.size():
		_sweep(b, fan[i], fan[i], 0.22, 3.0, i * 0.09, 1)
	_sweep(b, 1046, 1046, 0.15, 2.0, 0.4, 2)
	_sweep(b, 1318, 1318, 0.15, 2.0, 0.4, 2)
	out["goal"] = _wav(b)

	b = _buf(2.0)
	var jingle := [[523.0, 0.0], [659.0, 0.12], [784.0, 0.24], [1046.0, 0.36], [784.0, 0.6], [1046.0, 0.72]]
	for nt in jingle:
		_sweep(b, nt[0], nt[0], 0.24, 3.5, nt[1], 1)
	for f in [523.0, 659.0, 784.0]:
		_sweep(b, f, f, 0.12, 1.5, 0.84, 2)
	out["win"] = _wav(b)

	b = _buf(0.4)
	_sweep(b, 300, 600, 0.6, 9.0, 0.0, 0, 0.15)
	out["boing"] = _wav(b)

	b = _buf(0.3)
	_sweep(b, 1400, 500, 0.35, 10.0, 0.0, 1)
	out["steal"] = _wav(b)

	b = _buf(0.18)
	_sweep(b, 660, 990, 0.35, 14.0, 0.0, 2)
	out["ready"] = _wav(b)

	b = _buf(0.7)
	_noise(b, 0.7, 6.0, 0.02, 0.4, 0.0, 0.3)
	out["whoosh"] = _wav(b)

	b = _buf(0.35)
	_sweep(b, 500, 900, 0.3, 8.0, 0.0, 2)
	_sweep(b, 750, 1350, 0.2, 8.0, 0.05, 2)
	out["respawn"] = _wav(b)

	b = _buf(0.6)
	_noise(b, 0.8, 7.0, 0.4, 0.02)
	_sweep(b, 120, 40, 0.8, 6.0)
	out["meteor"] = _wav(b)

	b = _buf(0.18)
	_sweep(b, 1800, 2400, 0.18, 22.0)
	_sweep(b, 2700, 3200, 0.12, 22.0, 0.04)
	out["sparkle"] = _wav(b)

	b = _buf(0.12)
	_sweep(b, 520, 520, 0.3, 30.0, 0.0, 1)
	out["blip"] = _wav(b)
	_set_sounds.call_deferred(out)


func _set_sounds(out: Dictionary) -> void:
	sounds = out


## A breezy 8-bar loop: bass, plucked arpeggio and soft hats.
func _build_music() -> AudioStreamWAV:
	var bpm := 112.0
	var beat := 60.0 / bpm
	var bars := 8
	var total := beat * 4.0 * bars
	var n := int(total * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	# I - vi - IV - V in C, twice
	var chords := [
		[261.63, 329.63, 392.0], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66],
		[261.63, 329.63, 392.0], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 392.0],
	]
	var step := beat * 0.5
	for bar in bars:
		var ch: Array = chords[bar]
		for s in 8:
			var t0 := (bar * 8 + s) * step
			var idx := int(t0 * RATE)
			# bass on beats
			if s % 2 == 0:
				var bf: float = ch[0] * 0.5 if s % 4 == 0 else ch[0] * 0.75
				_note(b, idx, bf * 0.5, step * 1.6, 0.20, 2, 6.0)
			# arpeggio
			var pattern := [0, 1, 2, 1, 0, 2, 1, 2]
			var f: float = ch[pattern[s]] * 2.0
			_note(b, idx, f, step * 0.9, 0.07, 1, 9.0)
			_note(b, idx, f * 2.0, step * 0.5, 0.025, 0, 12.0)
			# soft hat
			_hat(b, idx, 0.05 if s % 2 == 1 else 0.025)
	# gentle fade at loop edges to avoid clicks
	for i in 200:
		var k := float(i) / 200.0
		b[i] *= k
		b[n - 1 - i] *= k
	return _wav(b, true)


func _note(b: PackedFloat32Array, start: int, f: float, dur: float, amp: float, wave: int, decay: float) -> void:
	var count := int(dur * RATE)
	var phase := 0.0
	for i in count:
		var j := start + i
		if j >= b.size():
			j -= b.size()
		var t := float(i) / RATE
		phase += f / RATE
		var v: float
		match wave:
			1:
				v = (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) * 0.4
			2:
				v = 2.0 * absf(2.0 * fmod(phase, 1.0) - 1.0) - 1.0
			_:
				v = sin(phase * TAU)
		var env := exp(-t * decay) * minf(1.0, t * 300.0) * minf(1.0, (dur - t) * 60.0)
		b[j] += v * amp * env


func _hat(b: PackedFloat32Array, start: int, amp: float) -> void:
	var count := int(0.04 * RATE)
	var prev := 0.0
	for i in count:
		var j := start + i
		if j >= b.size():
			break
		var x := _srng.randf_range(-1.0, 1.0)
		var hp := x - prev
		prev = x
		b[j] += hp * amp * exp(-float(i) / RATE * 90.0)
