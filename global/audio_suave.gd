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
			notas = [300.0]
			duracion = 0.055
			ruido = 0.24
		"mordida_madera":
			notas = [220.0, 340.0]
			duracion = 0.075
			ruido = 0.43
		"mordida_metal":
			notas = [570.0, 1280.0]
			duracion = 0.085
			ruido = 0.025
		"mordida_piedra":
			notas = [135.0, 205.0]
			duracion = 0.085
			ruido = 0.28
		"clic":
			notas = [520.0, 780.0]
			duracion = 0.09
			ruido = 0.08
		"deposito":
			notas = [660.0, 990.0]
			duracion = 0.115
		"romper":
			notas = [294.0, 392.0, 490.0]
			duracion = 0.23
			ruido = 0.18
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
	var material := nombre.begins_with("mordida")
	for i in muestras:
		var t := float(i) / frecuencia
		var muestra := 0.0
		for n in notas.size():
			var inicio := n * duracion * 0.11
			var edad := t - inicio
			if edad < 0.0:
				continue
			var ataque := minf(edad / 0.008, 1.0)
			var envolvente := ataque * exp(-edad * (9.0 if material else 7.0) / duracion)
			var f: float = notas[n]
			muestra += (sin(TAU * f * edad) + 0.16 * sin(TAU * f * 2.0 * edad)) * envolvente / notas.size()
		filtro = lerpf(filtro, rng.randf_range(-1.0, 1.0), 0.22 if material else 0.32)
		# Un crujido amortiguado y breve, no una nota larga por cada hormiga.
		muestra += filtro * ruido * exp(-t * (12.0 if material else 20.0) / duracion) * minf(t / 0.004, 1.0)
		var salida := minf((duracion - t) / 0.018, 1.0)
		bytes.encode_s16(i * 2, int(clampf(muestra * salida * 0.7, -1.0, 1.0) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = frecuencia
	stream.data = bytes
	return stream
