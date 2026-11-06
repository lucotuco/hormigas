class_name AudioSuave
extends RefCounted
## Banco sintetizado al iniciar: ataques suaves, timbres cálidos y sin clips.
## No necesita archivos nuevos ni descargas. Semilla fija para el crujido.

const TEXTURAS := {
	"mordida": 0.065,
	"mordida_carton": 0.085,
	"mordida_madera": 0.09,
	"mordida_metal": 0.095,
	"mordida_piedra": 0.09,
	"levantar": 0.065,
	"deposito": 0.15,
}


static func crear(nombre: String) -> AudioStreamWAV:
	if TEXTURAS.has(nombre):
		return _crear_textura(nombre)
	var notas: Array = [660.0]
	var duracion := 0.12
	var ruido := 0.0
	match nombre:
		"clic":
			notas = [520.0, 780.0]
			duracion = 0.09
			ruido = 0.08
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
		"impacto":
			notas = [155.0, 232.5]
			duracion = 0.075
			ruido = 0.34
		"racha":
			notas = [392.0, 523.25, 659.25]
			duracion = 0.25
		"poder":
			notas = [196.0, 293.66, 392.0, 587.33]
			duracion = 0.48
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
		"nivel":
			# Arpegio que sube y queda arriba: "subiste".
			notas = [392.0, 493.88, 587.33, 783.99, 987.77]
			duracion = 0.62
		"carta":
			notas = [587.33, 880.0]
			duracion = 0.16
			ruido = 0.05
		"legendaria":
			notas = [261.63, 392.0, 523.25, 659.25, 783.99, 1046.5]
			duracion = 0.88
		"critico":
			notas = [196.0, 392.0]
			duracion = 0.09
			ruido = 0.4
	var frecuencia := 22050
	var muestras := int(duracion * frecuencia)
	var bytes := PackedByteArray()
	bytes.resize(muestras * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = nombre.hash()
	var filtro := 0.0
	var celebracion := nombre in ["epico", "crecer", "fin", "racha", "poder", "nivel", "legendaria"]
	for i in muestras:
		var t := float(i) / frecuencia
		var muestra := 0.0
		for n in notas.size():
			var inicio := n * duracion * (0.12 if celebracion else 0.08)
			var edad := t - inicio
			if edad < 0.0:
				continue
			var ataque := smoothstep(0.0, 0.009, edad)
			var envolvente := ataque * exp(-edad * 5.0 / duracion)
			var f: float = notas[n]
			# Fundamental redonda, armónico corto y cuerpo grave: no una alarma
			# aguda por cada depósito. Toda la grabación se sintetiza acá.
			var cuerpo := sin(TAU * f * edad)
			cuerpo += 0.10 * sin(TAU * f * 2.0 * edad) * exp(-edad * 35.0)
			if celebracion:
				cuerpo += 0.18 * sin(TAU * f * 0.5 * edad)
			muestra += cuerpo * envolvente / notas.size()
		filtro = lerpf(filtro, rng.randf_range(-1.0, 1.0), 0.32)
		muestra += filtro * ruido * exp(-t * 20.0 / duracion) * minf(t / 0.004, 1.0)
		var salida := minf((duracion - t) / 0.018, 1.0)
		bytes.encode_s16(i * 2, int(clampf(muestra * salida * 0.7, -1.0, 1.0) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = frecuencia
	stream.data = bytes
	return stream


## Familias físicas originales, no el mismo pitido con otra afinación.
## Se generan UNA vez al iniciar el banco: durante la run sólo se reutiliza
## el WAV y las voces existentes. No consumen el azar del mapa o de la IA.
static func _crear_textura(nombre: String) -> AudioStreamWAV:
	var duracion: float = TEXTURAS[nombre]
	var frecuencia := 22050
	var muestras := roundi(duracion * frecuencia)
	var bytes := PackedByteArray()
	bytes.resize(muestras * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = nombre.hash() + 5849
	var filtro := 0.0
	var anterior := 0.0
	for i in muestras:
		var t := float(i) / frecuencia
		var blanco := rng.randf_range(-1.0, 1.0)
		filtro = lerpf(filtro, blanco, 0.15)
		var fino := blanco - filtro
		var ataque := smoothstep(0.0, 0.0025, t)
		var segundo := maxf(t - 0.014, 0.0)
		var fractura := smoothstep(0.0, 0.0025, segundo) * exp(-segundo * 165.0)
		var muestra := 0.0
		match nombre:
			"mordida":
				# Cáscara/miga: dos crujidos secos y una cavidad diminuta, no
				# una nota afinada que compita con las entregas.
				muestra = (fino * 0.38 + filtro * 0.8) * (exp(-t * 105.0) + fractura * 0.6)
				muestra += sin(TAU * 270.0 * t) * exp(-t * 140.0) * 0.28
			"mordida_carton":
				# Fibra que se desgarra: roce ancho, no un golpe de madera.
				var fibra := 0.65 + 0.35 * sin(TAU * 145.0 * t)
				muestra = fino * fibra * (exp(-t * 58.0) + fractura * 0.65) * 0.48
				muestra += sin(TAU * 145.0 * t) * exp(-t * 95.0) * 0.1
			"mordida_madera":
				# Astilla: dos fracturas con caja resonante grave amortiguada.
				muestra = (sin(TAU * 190.0 * t) * 0.48 + sin(TAU * 437.0 * t) * 0.19) * exp(-t * 70.0)
				muestra += fino * (exp(-t * 170.0) + fractura * 0.85) * 0.44
			"mordida_metal":
				# Resonancias inarmónicas cortas; el volumen del banco conserva
				# el metal más bajo para evitar agudos repetitivos invasivos.
				muestra = (sin(TAU * 710.0 * t) * 0.48 + sin(TAU * 1607.0 * t) * 0.22 + sin(TAU * 2431.0 * t) * 0.1) * exp(-t * 53.0)
				muestra += fino * exp(-t * 240.0) * 0.1
			"mordida_piedra":
				# Grano y cuerpo opaco: más grave y menos tonal que la astilla.
				muestra = filtro * (exp(-t * 62.0) + fractura * 0.5) * 1.4
				muestra += (sin(TAU * 107.0 * t) * 0.32 + sin(TAU * 293.0 * t) * 0.13) * exp(-t * 85.0)
			"levantar":
				# La pieza ya está suelta: pinza blanda y roce, sin otra rotura.
				muestra = sin(TAU * (330.0 * t + 540.0 * t * t)) * exp(-t * 85.0) * 0.42
				muestra += filtro * exp(-t * 100.0) * 0.22
			"deposito":
				# Primero toca el suelo, después confirma la recompensa con
				# dos resonancias cálidas. La racha afina este mismo gesto.
				muestra = sin(TAU * 165.0 * t) * exp(-t * 180.0) * 0.22
				var edad := maxf(t - 0.012, 0.0)
				var pulso := smoothstep(0.0, 0.006, edad) * exp(-edad * 38.0)
				muestra += (sin(TAU * 392.0 * edad) * 0.62 + sin(TAU * 587.33 * edad) * 0.21) * pulso
		# Amortiguar también el ruido antes del fundido elimina el "clic
		# digital" duro, sin volver intercambiables las familias.
		anterior = lerpf(anterior, muestra, 0.7)
		var salida := smoothstep(0.0, 0.012, duracion - t)
		bytes.encode_s16(i * 2, roundi(clampf(anterior * ataque * salida * 0.8, -0.96, 0.96) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = frecuencia
	stream.data = bytes
	return stream
