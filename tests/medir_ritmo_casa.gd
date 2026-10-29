extends Node
## A/B de economía sobre el MISMO mapa y la misma IA. No reescribe CSV ni usa
## estados con compras ya hechas: sólo repone precios anteriores en memoria.
## RITMO_BASELINE=1 aplica el control; sin esa variable mide el CSV actual.
## El bot conserva sus propias opciones BOT_* y nunca guarda al jugador.
const BOT := preload("res://tests/bot_balance.tscn")
const PRECIOS_ANTERIORES := {
	"mas_obreras": [8.0, 1.55], "mandibulas": [12.0, 1.6], "pisada": [10.0, 1.5],
	"mordida_madera": [900.0, 1.0], "mordida_resistente": [150000.0, 1.0],
	"mordida_muros": [4000000.0, 1.0], "buche": [30.0, 1.75],
	"recoleccion_eficiente": [100.0, 1.9], "huevos_dorados": [5000.0, 3.0],
}


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Sonido.silenciado = true
	var control := OS.get_environment("RITMO_BASELINE") == "1"
	if control:
		for id: String in PRECIOS_ANTERIORES:
			var valores: Array = PRECIOS_ANTERIORES[id]
			for mejora in Juego.mejoras:
				if mejora.id == id:
					mejora.costo_base = valores[0]
					mejora.crecimiento = valores[1]
			Juego.mejoras_por_id[id].costo_base = valores[0]
			Juego.mejoras_por_id[id].crecimiento = valores[1]
	var huellas: Dictionary = {}
	for ruta in ["mundo/plano_casa.gd", "mundo/mundos.gd", "mundo/comidas.gd", "hormigas/hormiga.gd", "global/juego.gd"]:
		huellas[ruta] = FileAccess.get_sha256("res://" + ruta)
	print("RITMO ECONOMÍA %s · geometría/IA %s" % ["control anterior" if control else "candidato CSV actual", JSON.stringify(huellas)])
	add_child(BOT.instantiate())
