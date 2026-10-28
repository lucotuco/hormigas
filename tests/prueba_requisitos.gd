extends Node
## Requisitos: una mejora puede pedir varias anteriores (una cámara compartida
## entre dos ramas) y las castas leen los suyos de castas.csv.
##   godot --headless --fixed-fps 60 --path . res://tests/prueba_requisitos.tscn
var total := 0
var fallas := 0


func _ready() -> void:
	Juego.guardado_habilitado = false
	Juego.usar_idioma("es")
	Juego.reiniciar_estado()
	probar_lectura()
	probar_desbloqueo()
	probar_castas()
	probar_datos()
	Juego.reiniciar_estado()
	print("Requisitos: %d verificaciones; %d fallas." % [total, fallas])
	get_tree().quit(1 if fallas else 0)


func probar_lectura() -> void:
	var dos := Juego._leer_requisitos("buche:2|cria_acelerada:3")
	verificar(dos.size() == 2 and dos[0].id == "buche" and dos[0].nivel == 2 and dos[1].id == "cria_acelerada" and dos[1].nivel == 3, "se leen dos requisitos separados por |")
	var solo := Juego._leer_requisitos("mandibulas")
	verificar(solo.size() == 1 and solo[0].nivel == 1, "sin nivel se entiende nivel 1")
	verificar(Juego._leer_requisitos("").is_empty() and Juego._leer_requisitos(" | ").is_empty(), "vacío no inventa requisitos")


func probar_desbloqueo() -> void:
	# Una mejora inventada que comparten dos ramas: pide las dos.
	var m: Dictionary = Juego.mejoras_por_id.huevos_dorados.duplicate(true)
	m.id = "prueba_compartida"
	m.requisitos = Juego._leer_requisitos("recoleccion_eficiente:5|cria_acelerada:3")
	Juego.mejoras_por_id[m.id] = m
	Juego.niveles = {"recoleccion_eficiente": 5}
	verificar(not Juego.esta_desbloqueada(m.id), "con un solo requisito cumplido sigue cerrada")
	var faltan := Juego.requisitos_faltantes(m.requisitos)
	verificar(faltan.size() == 1 and faltan[0].id == "cria_acelerada", "se informa sólo el requisito que falta")
	var tienda := preload("res://ui/tienda.gd").new()
	verificar(tienda.texto_requisitos(faltan) == "Requiere Cría acelerada · nivel 3", "un requisito usa el texto de siempre")
	Juego.niveles = {}
	verificar(tienda.texto_requisitos(Juego.requisitos_faltantes(m.requisitos)) == "Requiere: Recolección eficiente nivel 5 + Cría acelerada nivel 3", "dos requisitos se muestran juntos")
	tienda.free()
	Juego.niveles = {"recoleccion_eficiente": 5, "cria_acelerada": 3}
	verificar(Juego.esta_desbloqueada(m.id), "con los dos cumplidos se abre")
	Juego.mejoras_por_id.erase(m.id)
	Juego.niveles = {}


func probar_castas() -> void:
	verificar(Juego.castas_por_id.carpintera.requisitos.size() == 1 and Juego.castas_por_id.carpintera.requisitos[0].id == "mordida_madera", "la carpintera pide la dieta de madera desde castas.csv")
	Juego.niveles = {}
	verificar(not Juego.casta_desbloqueada("carpintera") and not Juego.casta_desbloqueada("demoledora") and Juego.casta_desbloqueada("veloz"), "sin dietas sólo se cierran las especializadas")
	Juego.niveles = {"mordida_madera": 1}
	verificar(Juego.casta_desbloqueada("carpintera") and not Juego.casta_desbloqueada("demoledora"), "la madera abre la carpintera")
	Juego.niveles = {"mordida_madera": 1, "mordida_resistente": 1, "mordida_muros": 1}
	verificar(Juego.casta_desbloqueada("demoledora") and Juego.stat("materiales") >= 3, "las paredes abren la demoledora, como antes con materiales 3")
	Juego.niveles = {}
	Juego._cache_stats.clear()


func probar_datos() -> void:
	var ok := true
	for m in Juego.mejoras:
		for r in m.requisitos:
			ok = ok and Juego.mejoras_por_id.has(r.id) and r.id != m.id and int(r.nivel) >= 1
		ok = ok and m.requiere_id == (m.requisitos[0].id if not m.requisitos.is_empty() else "")
	verificar(ok, "cada requisito de mejoras.csv existe y el primero sigue disponible como requiere_id")
	# Sin ciclos: desde cualquier mejora se llega a una raíz.
	var sin_ciclos := true
	for m in Juego.mejoras:
		var visitadas := {}
		var pila: Array = [m.id]
		while not pila.is_empty():
			var actual: String = pila.pop_back()
			if visitadas.has(actual):
				continue
			visitadas[actual] = true
			for r in Juego.mejoras_por_id[actual].requisitos:
				if r.id == m.id:
					sin_ciclos = false
				pila.append(r.id)
	verificar(sin_ciclos, "ninguna mejora se pide a sí misma a través de otras")


func verificar(valor: bool, mensaje: String) -> void:
	total += 1
	if not valor:
		fallas += 1
	print(("OK: " if valor else "FALLA: ") + mensaje)
