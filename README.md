# Hormigas 🐜

Incremental para PC hecho en **Godot 4.7.2**. Guiás a tu colonia con rastros de feromonas para que se coma todo lo que hay en la casa. Cada run dura unos segundos; con lo recolectado mejorás el hormiguero, el territorio crece y aparece comida más grande (y más lejos).

## Arrancar

1. Instalen **Godot 4.7.2** los dos (la versión estándar, no la .NET). Importante: **la misma versión exacta**, si no el editor reescribe archivos y aparecen conflictos.
2. Cloná el repo y abrí `project.godot` desde Godot (Importar → elegir la carpeta).
3. La primera vez tarda unos segundos en importar los recursos.
4. **F5** para jugar.

## Controles

| Acción | Cómo |
|---|---|
| Dejar rastro de feromonas | Mantener apretado el clic izquierdo y arrastrar |
| Morder comida directamente | Clic sobre la comida |
| Terminar la run antes | Esc |
| Silenciar sonido | M |

### Atajos de desarrollo (solo al correr desde el editor)

| Tecla | Efecto |
|---|---|
| F1 | +1000 migas |
| F2 | Migas ×10 |
| F9 | Borrar la partida guardada |

## Estructura

```
res://
  global/        Autoloads, disponibles desde cualquier script
    juego.gd       "Juego": estado, partida guardada, stats, mejoras, lectura de /datos
    sonido.gd      "Sonido": efectos con pool de reproductores
  hormigas/
    hormiga.gd     Máquina de estados de una hormiga (explorar, seguir rastro, morder, volver)
    colonia.gd     Hace nacer hormigas y ajusta su tamaño al zoom
  mundo/
    run.tscn       ESCENA PRINCIPAL: una run completa
    run.gd         Coordina la run: inicio, fin, combos, clics, comida destruida
    comidas.gd     Genera el mapa (siempre igual, semilla fija) y busca comida cercana
    comida.gd      Una comida: vida, grietas, sacudida, dibujo por forma
    feromonas.gd   Rastro que dibuja el jugador y que siguen las hormigas
    hormiguero.gd  La entrada del hormiguero en (0, 0)
    niebla.gd      Oscuridad fuera del territorio
    efectos.gd     Partículas, ondas y números flotantes (todo en un nodo)
    camara.gd      Zoom según el territorio + sacudidas
    suelo.gd       Piso de baldosas
  ui/
    hud.gd         Migas, tiempo, combo, avisos, panel de fin de run
    tienda.gd      Árbol de mejoras entre runs
    estilo.gd      Colores y helpers de interfaz compartidos
  datos/         Tablas de balance (CSV)
  sonidos/       Efectos .wav
  tests/         Prueba de humo
```

### Cómo se conectan las piezas

- **`Juego`** (autoload) es la única fuente de verdad: migas, niveles de mejoras y la stat actual de cualquier cosa con `Juego.stat("velocidad")`. Las stats salen de `stats_base.csv` + las mejoras compradas.
- **`run.gd`** es el centro de la run. Las hormigas le avisan con `run.depositar(cantidad)` cuando llegan con comida; las comidas emiten la señal `destruida` y `comidas.gd` la reenvía a la run, que suma bonus, lanza efectos y sacude la cámara.
- Todo cuelga de nodos en el origen y el hormiguero está en (0, 0), así que posición local = posición global.
- La interfaz (HUD y tienda) se arma por código, para no tener que editar escenas a la par.

## Balance: los CSV de `/datos`

Los números del juego **no están en el código**: se editan en tres CSV que pueden abrir en Google Sheets o Excel.

| Archivo | Qué define |
|---|---|
| `stats_base.csv` | Valor inicial de cada stat (hormigas, velocidad, daño, duración de la run, radio del territorio…) |
| `mejoras.csv` | Cada mejora: rama (columna del árbol), stat que afecta, si **suma** o **multiplica**, costo base, crecimiento del costo, nivel máximo y requisito (`otra_mejora:nivel`) |
| `comidas.csv` | Cada comida: forma, color, vida, recompensa, tamaño, a qué distancia del hormiguero aparece y cuántas hay |

**Flujo recomendado:** suban los CSV a una planilla compartida, balanceen ahí y cuando les guste hagan *Archivo → Descargar → CSV* de cada hoja y reemplacen el archivo. La coma decimal (`1,5`) también se acepta. Una fila que empieza con `#` se ignora.

- Costo de una mejora = `costo_base × crecimiento ^ nivel`.
- Una mejora tipo `multiplica` con valor `1.12` y nivel 3 multiplica la stat por `1.12³`.
- Para agregar una mejora nueva alcanza con agregar una fila; aparece sola en la tienda. Si afecta una stat nueva, agregala también a `stats_base.csv` y usala en el código con `Juego.stat("nombre")`.

## Trabajar de a dos con Git

**Reglas:**

1. **Una rama por tarea** (`git checkout -b hormigas-soldado`), y se integra a `main` con un Pull Request que el otro mira.
2. **Nunca editar la misma escena (`.tscn`) a la vez.** Los scripts se combinan bien; las escenas no.
3. **Sí se suben** los `.import` y `.uid` que crea Godot. **No se sube** la carpeta `.godot/` (ya está en `.gitignore`).
4. Antes de abrir un PR, `git pull origin main` y probar que el juego arranca.
5. Si tocan `run.gd` (es el punto donde se cruzan los dos), avísense.

Las tareas y quién hace qué están en [`TAREAS.md`](TAREAS.md).

### Subir el proyecto a GitHub (una sola vez)

1. En GitHub: **New repository** → nombre `hormigas` → **sin** README, sin .gitignore (ya están acá).
2. En la carpeta del proyecto:
   ```bash
   git remote add origin https://github.com/TU_USUARIO/hormigas.git
   git branch -M main
   git push -u origin main
   ```
3. En el repo: **Settings → Collaborators → Add people** y sumá a tu compañero.
4. Tu compañero: `git clone https://github.com/TU_USUARIO/hormigas.git` y abre el proyecto en Godot.
5. Opcional: en la pestaña **Projects** creen un tablero y copien las tareas de `TAREAS.md`.

## Prueba de humo

Verifica que el juego arranca, que una run se juega entera sin errores, que las mejoras funcionan y que la tienda se arma. No toca tu partida guardada.

```bash
godot --headless --path . res://tests/prueba_humo.tscn
```

Termina con código 0 si todo anduvo. Córranla antes de cada PR.

## Exportar

*Proyecto → Exportar → Agregar → Windows Desktop* (la primera vez Godot pide descargar las plantillas de exportación). Si al exportar faltan los CSV, agreguen `datos/*.csv` en *Recursos → Filtros para exportar archivos que no son recursos*.
