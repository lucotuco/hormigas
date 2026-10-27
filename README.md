# Hormigas 🐜

Incremental para PC hecho en **Godot 4.7.2**. Guiás a tu colonia manteniendo el clic donde querés reunir hormigas para que se coma todo lo que hay en la casa. Cada run dura unos segundos; con lo recolectado mejorás el hormiguero, el territorio crece y aparece comida más grande (y más lejos).

## Arrancar

1. Instalen **Godot 4.7.2** los dos (la versión estándar, no la .NET). Importante: **la misma versión exacta**, si no el editor reescribe archivos y aparecen conflictos.
2. Cloná el repo y abrí `project.godot` desde Godot (Importar → elegir la carpeta).
3. La primera vez tarda unos segundos en importar los recursos.
4. **F5** para jugar.

## Controles

| Acción | Cómo |
|---|---|
| Atraer las hormigas más cercanas | Mantener clic izquierdo en el destino; moverlo cambia el punto, soltar termina la orden |
| Morder comida directamente | Clic sobre la comida |
| Acercar o alejar el mapa | Rueda del mouse; el zoom apunta al cursor |
| Moverse por el mapa | Arrastrar con botón derecho o central; también WASD o flechas |
| Volver al hormiguero y al encuadre automático | R |
| Ver el plano de la casa completa | H |
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
    hormiga.gd     Máquina de estados de una hormiga (explorar, responder al llamado, morder, volver)
    colonia.gd     Hace nacer hormigas y ajusta su tamaño al zoom
  mundo/
    run.tscn       ESCENA PRINCIPAL: una run completa
    run.gd         Coordina la run: inicio, fin, combos, clics, comida destruida
    comidas.gd     Genera el mapa (siempre igual, semilla fija) y busca comida cercana
    comida.gd      Una comida: vida, grietas, sacudida, dibujo por forma
    feromonas.gd   Punto de atracción activo mientras se mantiene el clic
    plano_casa.gd  Siete ambientes, paredes, puertas, muebles y límites compartidos
    dibujo_casa.gd Ilustración de muebles y detalles de la casa
    cocina.gd     Navegación compartida por grilla, con rutas para caminantes y voladoras
    hormiguero.gd  La entrada del hormiguero en (0, 0)
    niebla.gd      Oscuridad fuera del territorio
    efectos.gd     Partículas, ondas y números flotantes (todo en un nodo)
    camara.gd      Zoom según el territorio + sacudidas
    suelo.gd       Pisos de madera, cerámica y baldosas por ambiente
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

## Casa y hormiguero

La tienda se recorre eligiendo una de las seis cámaras del hormiguero. Cada
cámara muestra sus mejoras, requisitos y la estadística exacta antes y después
de comprar. Los botones **×1, ×10 y Máx** se comparten entre mejoras y castas.
×10 compra el lote completo (o los niveles restantes hasta el límite); Máx
calcula cuántos podés pagar. El precio suma el costo creciente de cada nivel,
se cobra una sola vez y la vista previa muestra el resultado del lote entero.
Cada rama señala cuántas mejoras podés comprar en el modo seleccionado.
Las cámaras crecen y se iluminan con su desarrollo. El sonido se
puede silenciar y regular desde el pie de la tienda; `M` sigue funcionando.

La casa tiene cocina, comedor, living, pasillo, dormitorio, estudio y baño/lavadero.
Mesadas, heladera, cocina, mesas con sillas, sillón, cama, escritorio y sanitarios
dan identidad a cada ambiente. Paredes y puertas organizan los recorridos.
`mundo/plano_casa.gd` centraliza la geometría que comparten dibujo, navegación
y generación de comida. `mundo/cocina.gd` usa grillas A* compartidas y caché de
rutas para rodear muebles y atravesar puertas; las voladoras ignoran los muebles,
pero no atraviesan paredes. La comida se distribuye por ambientes, fuera de obstáculos.
El gran banquete está en el comedor. El territorio inicial es de 620 unidades;
Excavar permite abrir progresivamente el resto de la casa.

Las feromonas son un **llamado al punto actual del cursor**, no un camino.
Al mantener el clic, las 24 hormigas disponibles más cercanas se aproximan;
la mejora Llamado potente aumenta esa cantidad de a tres. Si movés el cursor,
se actualizan el destino y la selección. Al soltar, termina la atracción sin
dejar rastros anteriores. Sobre comida, las hormigas que llegan recolectan.
Las que ya transportan una carga terminan su regreso antes de responder.
No se puede dar órdenes fuera del territorio descubierto.

La cámara empieza encuadrando el territorio. Cuando usás la rueda o movés el
mapa, conserva tu encuadre; `R` recupera la vista automática del hormiguero
y `H` encuadra la casa entera.
Los controles de cámara no dibujan feromonas. El piso usa juntas filtradas para
mantener un patrón estable al cambiar el zoom.

Los efectos actuales se sintetizan en `global/audio_suave.gd`, con ataques y
finales suaves, notas armónicas y límites de superposición. Los WAV originales
se conservan como referencia. No se necesitan recursos externos adicionales.

### Castas y reclutamiento

La pestaña **Castas y reclutamiento** permite conocer y comprar cinco tipos de
hormiga. Cada unidad comprada es **permanente** y sale en todas las
expediciones siguientes. Se puede reclutar de a una, diez o el máximo posible.
Los precios crecen por unidad y cada casta tiene un
límite. Las fichas muestran las estadísticas con las mejoras actuales incluidas.

- **Exploradora veloz:** velocidad ×2.2; mordida más débil.
- **Roja:** aplica veneno corrosivo durante 3 s. El daño por segundo equivale al
  80% de su mordida y esas migas se suman automáticamente. Renovar el veneno
  conserva la potencia más fuerte; no acumula daño sin límite.
- **Voladora:** cruza sobre muebles y tiene más velocidad y olfato. Respeta el
  territorio descubierto y usa las puertas para cambiar de habitación.
- **Cargadora:** transporta cuatro veces más bocados y muerde más fuerte, pero
  camina más lento.
- **Reina:** despliega dos miniobreras cada 6 s, hasta 24 por reina y expedición.
  Las minis recolectan, pero no se guardan como unidades permanentes.

`datos/castas.csv` define nombres, información, multiplicadores, colores,
precios y límites. Las mejoras generales afectan a todas las castas. Las
partidas anteriores conservan su progreso y comienzan sin especialistas.

## Balance: los CSV de `/datos`

El balance se edita en cuatro CSV que pueden abrir en Google Sheets o Excel.
Los intervalos de las habilidades especiales están junto a su implementación.

| Archivo | Qué define |
|---|---|
| `stats_base.csv` | Valor inicial de cada stat (hormigas, velocidad, daño, duración de la run, radio del territorio…) |
| `mejoras.csv` | Cada mejora: rama (columna del árbol), stat que afecta, si **suma** o **multiplica**, costo base, crecimiento del costo, nivel máximo y requisito (`otra_mejora:nivel`) |
| `comidas.csv` | Cada comida: forma, color, vida, recompensa, tamaño, distancia del hormiguero, cantidad y ambientes preferidos (`zonas`) |
| `castas.csv` | Castas, descripción de habilidades, multiplicadores, color, tamaño, precio y límite de reclutamiento |

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

Regresiones de movimiento (incluye 500 regresos alrededor de un mueble,
llegada rápida, comida en el borde y final de feromonas):

```bash
godot --headless --path . res://tests/prueba_movimiento.tscn
```

Para revisar la presentación con el renderizador real, sin modificar la partida:

```bash
godot --path . res://tests/revision_visual.tscn
```

Genera capturas de las seis cámaras, compras y cocina en `.godot/qa/` y cierra.
La simulación de 500 hormigas es una prueba lógica; no mide FPS de renderizado.

Compras, carga de partidas antiguas, despliegue y habilidades de las castas:

```bash
godot --headless --path . res://tests/prueba_castas.tscn
```

Atracción de las más cercanas, llegada y liberación, recolección y eventos reales de mouse/cámara:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_controles.tscn
```

Compras por lote, precios acumulados, límites, indicadores de ramas y rutas por los siete ambientes:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_casa_lotes.tscn
```

`tests/revision_mapa.tscn` renderiza la casa completa, un recorrido por sus
ambientes, el llamado y la tienda en distintos tamaños; guarda las capturas
en `.godot/qa/` sin modificar la partida.

## Exportar

*Proyecto → Exportar → Agregar → Windows Desktop* (la primera vez Godot pide descargar las plantillas de exportación). Si al exportar faltan los CSV, agreguen `datos/*.csv` en *Recursos → Filtros para exportar archivos que no son recursos*.
