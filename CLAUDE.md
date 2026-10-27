# Hormigas: instrucciones para agentes

Incremental 2D para PC en **Godot 4.7.2** (GDScript, renderer GL Compatibility).
Lo hacen dos personas. Todo el código, los comentarios y los textos del juego
van en **español rioplatense**: nombres de variables, funciones, commits y PRs.

El detalle de mecánicas, controles y pruebas está en `README.md`. Las tareas
pendientes y quién hace qué, en `TAREAS.md`.

## Reglas de trabajo

- **Cambios chicos.** Un tema por rama y por PR, nunca directo a `main`.
  Si un pedido es grande, partilo en varios PRs que se puedan revisar solos.
- **No cambies la versión de Godot** ni actualices formatos de escena: los dos
  usan 4.7.2 exacto.
- **Antes de commitear, corré las pruebas** (ver abajo). Si cambiás un
  comportamiento a propósito, actualizá la prueba que lo cubre y explicalo en el PR.
- No subas `.godot/`. Sí subí los `.import` y `.uid` que genera Godot.
- No edites a mano las `.tscn` que otro puede estar tocando. La interfaz se arma
  por código (`ui/*.gd`) justamente para evitar conflictos en escenas.
- `mundo/run.gd` es el punto donde se cruzan los dos: mantené los cambios ahí mínimos.

## Dónde está cada cosa

- `global/juego.gd` (autoload `Juego`): única fuente de verdad del estado.
  Migas, niveles, castas, destinos, hitos, legado, guardado y lectura de `/datos`.
  Cualquier número del juego sale de `Juego.stat("nombre")`.
- `global/graficos.gd` (autoload `Graficos`): atlas generado una vez al iniciar.
  En headless no se genera; el código tiene que funcionar sin él.
- `global/sonido.gd` y `global/audio_suave.gd`: efectos sintetizados.
- `hormigas/`: hormiga (máquina de estados), colonia (nacimientos, castas) y aspecto.
- `mundo/`: la run y el mapa. `cocina.gd` es la navegación (AStarGrid2D con cola
  y presupuesto por cuadro); `plano_casa.gd` y `mundos.gd` definen los planos;
  `pieza_casa.gd` son muebles y muros comestibles por celdas.
- `ui/`: HUD, tienda y paneles, todo por código. Colores en `ui/estilo.gd`.
- `datos/*.csv`: **todo el balance**. Costos, stats base, comidas y castas van
  en los CSV, no en el código. Una mejora nueva es una fila en `mejoras.csv`.

## Pruebas

Pruebas lógicas, headless (sin ventana):

```bash
GODOT=/ruta/a/godot tests/correr_todas.sh
```

Una sola suite: `godot --headless --fixed-fps 60 --path . res://tests/prueba_campana.tscn`.
Cada suite imprime `OK` o `FALLA` por verificación y sale con código 1 si algo falla.
Toda escena `tests/prueba_*.tscn` se corre sola: una suite nueva sólo necesita
ese nombre, terminar con `get_tree().quit(0 o 1)` e imprimir `FALLA` cuando algo falla.
CI corre lo mismo en cada PR (`.github/workflows/pruebas.yml`).

Revisión visual con el renderer real (no headless): `tests/revision_*.tscn`
guardan capturas en `.godot/qa/`. Benchmarks: `tests/perfil_*.tscn`, ver
`tests/RENDIMIENTO.md`. No se miden FPS en headless.

Las pruebas nunca tocan la partida del jugador: ponen
`Juego.guardado_habilitado = false` al empezar. Hacé lo mismo en pruebas nuevas.

## Convenciones de código

- Tipado estático (`var x := ...`, `-> void`) salvo cuando un objeto puede
  estar liberado: ahí el parámetro va sin tipo y se valida con `is_instance_valid`.
- Las decisiones caras de cientos de hormigas se reparten en el tiempo
  (intervalos, colas, cachés). No agregues trabajo por hormiga y por cuadro.
- Partidas viejas: si agregás un campo a `datos_partida()`, `restaurar_partida()`
  tiene que tolerar que falte.
