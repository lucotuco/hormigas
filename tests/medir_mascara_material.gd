extends Node
## Costo CPU de máscaras retenidas; no es una medición de FPS.
func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	for tamano in [Vector2(110, 130), Vector2(1550, 2100), Vector2(4096, 4096)]:
		var rect := Rect2(Vector2.ZERO, tamano)
		var formas := []
		var vidas := PackedFloat64Array()
		for y in 4:
			for x in 4:
				formas.append([Rect2(Vector2(x, y) * tamano / 4.0, tamano / 4.0)])
				vidas.append(1000)
		var m := MordiscosMaterial.new()
		m.configurar(rect, Vector2i(4, 4), formas, vidas)
		var inicio := Time.get_ticks_usec()
		var cortes := 0
		for i in 1000:
			var celda := i % 16
			var desde := m.origen_exterior(celda, Vector2.ZERO)
			cortes += int(m.recortar_local(celda, 1e6, desde, 6) > 0)
		print("MÁSCARA %s: resolución=%s; CPU configuración=%.3fms; bufferR8=%d bytes; 1000 intentos (%d cortes)=%.3fms; área restante=%.3f" % [tamano, m.tamano_mascara(), m.tiempo_configuracion_usec / 1000.0, m.bytes_mascara_cpu(), cortes, (Time.get_ticks_usec() - inicio) / 1000.0, m.area_total()])
	get_tree().quit()
