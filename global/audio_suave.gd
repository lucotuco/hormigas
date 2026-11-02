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
		"mordida_carton":
			notas = [180.0, 275.0]
			duracion = 0.07
			ruido = 0.55
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
		"levantar":
			notas = [280.0, 420.0]
			duracion = 0.04
			ruido = 0.10
		"clic":
			notas = [520.0, 780.0]
			duracion = 0.09
			ruido = 0.08
		"deposito":
			notas = [392.0, 587.33]
			duracion = 0.13
		"epico":
			notas = [196.0, 261.63, 329.63, 392.0, 523.25]
			duracion = 0.85
		"aviso":
			notas = [392.0, 293.66]
			duracion = 0.24
		"espantar":
			notas = [240.0, 350.0]
			duracion = 0.10
			ruido = 0.28
		"romper":
			notas = [294.0, 392.0, 490.0]
			duracion = 0.23
			ruido = 0.18
		"comprar":
			notas = [392.0, 493.88, 587.33]
			duracion = 0.28
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
	var material := nombre.begins_with("mordida") or nombre == "levantar"
	var celebracion := nombre in ["epico", "crecer", "fin"]
	for i in muestras:
		var t := float(i) / frecuencia
		var muestra := 0.0
		for n in notas.size():
			var inicio := n * duracion * (0.12 if celebracion else 0.08)
			var edad := t - inicio
			if edad < 0.0:
				continue
			var ataque := smoothstep(0.0, 0.006 if material else 0.009, edad)
			var envolvente := ataque * exp(-edad * (9.0 if material else 5.0) / duracion)
			var f: float = notas[n]
			# Fundamental redonda, armónico corto y cuerpo grave: no una alarma
			# aguda por cada depósito. Toda la grabación se sintetiza acá.
			var cuerpo := sin(TAU * f * edad)
			cuerpo += 0.10 * sin(TAU * f * 2.0 * edad) * exp(-edad * 35.0)
			if celebracion:
				cuerpo += 0.18 * sin(TAU * f * 0.5 * edad)
			muestra += cuerpo * envolvente / notas.size()
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
