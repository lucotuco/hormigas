class_name AudioSuave
extends RefCounted
## Banco sintetizado al iniciar: ataques suaves, timbres cálidos y sin clips.
## No necesita archivos nuevos ni descargas. Semilla fija para el crujido.

static func crear(nombre: String) -> AudioStreamWAV:
	var notas: Array = [660.0]
	var duracion := 0.12
	var ruido := 0.0
	match nombre:
		"mordida":
			notas = [320.0]
			duracion = 0.065
			ruido = 0.32
		"mordida_madera":
			notas = [260.0, 390.0]
			duracion = 0.085
			ruido = 0.5
		"mordida_metal":
			notas = [620.0, 930.0]
			duracion = 0.12
			ruido = 0.06
		"mordida_piedra":
			notas = [145.0, 217.5]
			duracion = 0.11
			ruido = 0.28
		"clic":
			notas = [520.0, 780.0]
			duracion = 0.09
			ruido = 0.08
		"deposito":
			notas = [784.0, 1174.66]
			duracion = 0.19
		"romper":
			notas = [392.0, 493.88, 587.33]
			duracion = 0.32
			ruido = 0.15
		"comprar":
			notas = [523.25, 659.25, 783.99, 1046.5]
			duracion = 0.42
		"no":
			notas = [293.66, 261.63]
			duracion = 0.16
		"crecer":
			notas = [261.63, 329.63, 392.0, 523.25, 659.25]
			duracion = 0.85
		"tic":
			notas = [880.0]
			duracion = 0.07
		"fin":
			notas = [659.25, 587.33, 523.25, 392.0]
			duracion = 0.75
	var frecuencia := 22050
	var muestras := int(duracion * frecuencia)
	var bytes := PackedByteArray()
	bytes.resize(muestras * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = nombre.hash()
	var filtro := 0.0
	for i in muestras:
		var t := float(i) / frecuencia
		var muestra := 0.0
		for n in notas.size():
			var inicio := n * duracion * 0.11
			var edad := t - inicio
			if edad < 0.0:
				continue
			var ataque := minf(edad / 0.008, 1.0)
			var envolvente := ataque * exp(-edad * 7.0 / duracion)
			var f: float = notas[n]
			muestra += (sin(TAU * f * edad) + 0.16 * sin(TAU * f * 2.0 * edad)) * envolvente / notas.size()
		filtro = lerpf(filtro, rng.randf_range(-1.0, 1.0), 0.32)
		muestra += filtro * ruido * exp(-t * 20.0 / duracion) * minf(t / 0.004, 1.0)
		var salida := minf((duracion - t) / 0.018, 1.0)
		bytes.encode_s16(i * 2, int(clampf(muestra * salida * 0.7, -1.0, 1.0) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = frecuencia
	stream.data = bytes
	return stream
