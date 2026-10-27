class_name Camara
extends Camera2D
## Cámara centrada en el hormiguero. Se aleja a medida que crece el territorio
## y sabe sacudirse cuando pasa algo grande.

const MARGEN := 1.22      # cuánto espacio extra alrededor del territorio
const ZOOM_MAXIMO := 1.6

var _zoom_objetivo := 1.0
var _sacudida := 0.0


func ajustar_a_radio(radio: float, inmediato := false) -> void:
	var tamano := get_viewport_rect().size
	var lado := minf(tamano.x, tamano.y)
	_zoom_objetivo = minf(ZOOM_MAXIMO, lado / (2.0 * maxf(radio, 1.0) * MARGEN))
	if inmediato:
		zoom = Vector2.ONE * _zoom_objetivo


## intensidad en píxeles de pantalla.
func sacudir(intensidad: float) -> void:
	_sacudida = minf(_sacudida + intensidad, 24.0)


func _process(delta: float) -> void:
	var z := lerpf(zoom.x, _zoom_objetivo, 1.0 - exp(-6.0 * delta))
	zoom = Vector2(z, z)
	if _sacudida > 0.05:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _sacudida / z
		_sacudida *= exp(-12.0 * delta)
	else:
		_sacudida = 0.0
		offset = Vector2.ZERO
