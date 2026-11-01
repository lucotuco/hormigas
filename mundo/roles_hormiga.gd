class_name RolesHormiga
extends RefCounted
## Roles consultados al decidir, no por cuadro. El llamado manual tiene prioridad.
const DANOS := {
	"obrera": [1.0, 0.8, 0.5, 0.35], "mini": [1.0, 0.5, 0.3, 0.2],
	"veloz": [1.0, 0.65, 0.4, 0.25], "voladora": [1.0, 0.6, 0.4, 0.25],
	"roja": [1.0, 0.8, 2.2, 1.0], "cargadora": [1.0, 0.8, 0.6, 0.5],
	"carpintera": [0.5, 3.0, 0.5, 0.25], "demoledora": [0.35, 0.6, 1.5, 3.0],
	"reina": [1.0, 1.0, 0.8, 0.6],
}
static func dano(casta: String, material: int) -> float:
	var valor: float = DANOS.get(casta, DANOS.obrera)[clampi(material, 0, 3)]
	if casta == "carpintera" and Juego.hitos.has("primera_silla"):
		valor *= 1.2
	if casta == "demoledora" and Juego.hitos.has("primer_derrumbe"):
		valor *= 1.2
	return valor

static func peso_maximo(casta: String) -> int:
	if casta == "voladora" and Juego.evolucion_activa("puente"):
		return maxi(1, int(Juego.stat("peso_voladora_alzada")))
	return 1 if casta in ["voladora", "mini", "veloz"] else (4 if casta == "cargadora" else 2)

static func puede_cargar(casta: String, resto: FragmentoCasa) -> bool:
	if resto.peso > peso_maximo(casta):
		return false
	# Resistentes y paredes pesan dos, pero Puente no autoriza muros ni
	# montones mixtos con muro. La búsqueda y la recogida usan la misma regla.
	if casta == "voladora":
		return resto.material_id <= (2 if Juego.evolucion_activa("puente") else 1)
	return true

static func afinidad(casta: String, c: Comida) -> float:
	if c is FragmentoCasa:
		if not puede_cargar(casta, c):
			return 0
		return 4.0 if casta == "cargadora" else 1.4
	if c is PiezaCasa:
		return dano(casta, c.nivel_requerido)
	return 1.3 if casta in ["obrera", "veloz", "voladora", "mini"] else 1.0
