@tool
extends EditorScript

const MIX_RATE := 44100

func _run() -> void:
	var wav_golpe := _crear_golpe_vidrio()
	wav_golpe.save_to_wav("res://sonidos/golpe_vidrio.wav")
	
	var wav_rotura := _crear_rotura_vidrio()
	wav_rotura.save_to_wav("res://sonidos/rotura_vidrio.wav")
	
	print("¡Listo! Archivos guardados en res://sonidos/golpe_vidrio.wav y rotura_vidrio.wav")
	EditorInterface.get_resource_filesystem().scan()

func _crear_golpe_vidrio() -> AudioStreamWAV:
	var duracion := 0.35
	var total := int(MIX_RATE * duracion)
	var data := PackedByteArray()
	data.resize(total * 2)
	
	# Frecuencias agudas típicas de resonancia de cristal
	var freqs := [2450.0, 3820.0, 5190.0, 6840.0]
	var decays := [22.0, 28.0, 35.0, 45.0]
	var amps := [0.40, 0.30, 0.20, 0.12]
	
	for i in total:
		var t := float(i) / MIX_RATE
		var muestra := 0.0
		
		# Golpe inicial seco (ruido breve de 18 ms)
		if t < 0.018:
			muestra += randf_range(-1.0, 1.0) * exp(-t * 180.0) * 0.65
			
		# Timbre cristalino
		for k in freqs.size():
			muestra += sin(TAU * freqs[k] * t) * exp(-t * decays[k]) * amps[k]
			
		data.encode_s16(i * 2, clampi(int(muestra * 32767.0), -32768, 32767))
	
	return _empaquetar_wav(data)

func _crear_rotura_vidrio() -> AudioStreamWAV:
	var duracion := 1.25
	var total := int(MIX_RATE * duracion)
	var buffer := PackedFloat32Array()
	buffer.resize(total)
	
	# 1. Estallido inicial del impacto
	for i in int(MIX_RATE * 0.25):
		var t := float(i) / MIX_RATE
		var crack := randf_range(-1.0, 1.0) * exp(-t * 24.0) * 0.75
		crack += sin(TAU * 1950.0 * t) * exp(-t * 18.0) * 0.35
		buffer[i] += crack
		
	# 2. Lluvia de 35 esquirlas cayendo y tintineando
	for s in 35:
		var inicio := int(randf_range(0.02, 0.75) * MIX_RATE)
		var largo := int(randf_range(0.06, 0.22) * MIX_RATE)
		var f1 := randf_range(2800.0, 7500.0)
		var f2 := f1 * randf_range(1.35, 1.85)
		var vol := randf_range(0.08, 0.26)
		var dec := randf_range(25.0, 55.0)
		
		for j in largo:
			var idx := inicio + j
			if idx >= total:
				break
			var t := float(j) / MIX_RATE
			var tintineo := (sin(TAU * f1 * t) + 0.6 * sin(TAU * f2 * t)) * exp(-t * dec) * vol
			tintineo += randf_range(-1.0, 1.0) * exp(-t * 140.0) * (vol * 0.5)
			buffer[idx] += tintineo
			
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, clampi(int(buffer[i] * 32767.0), -32768, 32767))
		
	return _empaquetar_wav(data)

func _empaquetar_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
