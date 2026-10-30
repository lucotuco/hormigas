extends Node
## Exportación de geometría del arte, no escribe ni lee la partida del jugador.
func _ready() -> void:
	Juego.guardado_habilitado = false
	Sonido.silenciado = true
	Ajustes.pausar_sin_foco = false
	if not Graficos.listo:
		await Graficos.preparado
	Graficos._preparar_siluetas_alimentos()
	var datos := {}
	for tipo in Juego.comidas:
		var zonas := []
		for r: Rect2 in Graficos.formas_alimento(tipo.id):
			zonas.append([r.position.x, r.position.y, r.size.x, r.size.y])
		datos[tipo.id] = zonas
	print("SILUETAS_JSON=" + JSON.stringify(datos))
	get_tree().quit()
