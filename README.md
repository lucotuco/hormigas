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
| Pisotón | Clic sobre la comida: la daña al instante y da la mitad de migas que una mordida |
| Atraer las hormigas más cercanas | Mantener clic izquierdo en el destino; moverlo cambia el punto, soltar termina la orden |
| Acercar o alejar el mapa | Rueda del mouse; el zoom apunta al cursor |
| Moverse por el mapa | Arrastrar con botón derecho o central; también WASD o flechas |
| Volver al hormiguero y al encuadre automático | R |
| Ver el plano de la casa completa | H |
| Enfocar el gran objetivo del destino | G o botón Gran objetivo |
| Priorizar alimentos, muebles o estructuras | Botones de la barra inferior; el llamado manual siempre manda |
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
    graficos.gd    "Graficos": atlas generado una sola vez para hormigas, comida y muebles
  hormigas/
    hormiga.gd     Máquina de estados de una hormiga (explorar, responder al llamado, morder, volver)
    colonia.gd     Hace nacer hormigas y ajusta su tamaño al zoom
  mundo/
    run.tscn       ESCENA PRINCIPAL: una run completa
    run.gd         Coordina la run: inicio, fin, combos y comida destruida
    comidas.gd     Genera el mapa (siempre igual, semilla fija) y busca comida cercana
    comida.gd      Una comida: vida, grietas, sacudida, dibujo por forma
    feromonas.gd   Punto de atracción activo mientras se mantiene el clic
    plano_casa.gd  Siete ambientes, paredes, puertas, muebles y límites compartidos
    dibujo_casa.gd Ilustración de muebles y detalles de la casa
    cocina.gd     Navegación compartida por grilla, con rutas para caminantes y voladoras
    pieza_casa.gd Muebles y tramos de muro comestibles, con colisión y resistencia
    materiales_casa.gd Etapas, resistencia, recompensas y división de paredes en tramos
    mundos.gd     Seis destinos y sus planos, objetivos y progresión de campaña
    fragmento_casa.gd Montones de fragmentos transportables, sin física individual
    roles_hormiga.gd Afinidades por material, carga y preferencias de las castas
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
la mejora Llamado potente aumenta esa cantidad de a tres y Coordinación de a una
(máximo 64 a la vez). El antiguo Pisotón se convirtió en Coordinación conservando
sus niveles y costos. Además, **el clic sobre comida es un pisotón**: la daña al
instante (stat `dano_clic`, mejora Pisotón en el taller) y da la mitad de migas
que una mordida. Sólo afecta alimentos; muebles, muros y restos son trabajo de
las hormigas. Así los primeros minutos, con pocas hormigas, tienen acción directa. Si movés el cursor,
se actualizan el destino y la selección. Al soltar, termina la atracción sin
dejar rastros anteriores. Sobre comida, las hormigas que llegan recolectan.
Las que ya transportan una carga terminan su regreso antes de responder.
No se puede dar órdenes fuera del territorio descubierto.

La cámara empieza encuadrando el territorio. Cuando usás la rueda o movés el
mapa, conserva tu encuadre; `R` recupera la vista automática del hormiguero
y `H` encuadra la casa entera.
Los controles de cámara no dibujan feromonas. El piso usa juntas filtradas para
mantener un patrón estable al cambiar el zoom.

### Los primeros minutos

Las mecánicas aparecen de a una para no abrumar (`Juego.REVELABLES`). Una vez
reveladas quedan visibles para siempre, y lo nuevo se marca con "¡Nuevo!":

| Mecánica | Aparece |
|---|---|
| Compra ×10 / Máx y frenesí | Desde la segunda run |
| Botón y texto del gran objetivo | Desde la tercera run |
| Pestaña Castas | Desde la cuarta run (o al tener una especialista) |
| Barra de prioridades | Al desbloquear la dieta de madera |
| Pestaña Viajes | Al conquistar el primer destino |
| Pestaña Jalea real (árbol de la reina e hitos) | Con el primer hito o la primera corona |

El HUD muestra siempre la **próxima meta** con una barra (`Juego.proxima_meta()`):
primero subir Mandíbulas fuertes a nivel 4, después juntar las migas de cada
dieta, después el gran objetivo y por último el próximo viaje. Las migas de la
run en curso ya cuentan, y avisa cuando alcanza para comprar.

La colonia arranca con 8 obreras y, con la cámara alejada, las hormigas se
dibujan más grandes (`Colonia.ESCALA_EN_PANTALLA`) para que se lea qué hacen.

### De comer migas a devorar la casa

El taller (rama **Mandíbulas**) tiene tres desbloqueos permanentes, en orden:

| Dieta | Qué incorpora | Requisito / costo |
|---|---|---|
| Comida del piso | Los alimentos habituales | Desde el inicio |
| Madera y telas | Sillas, mesas, muebles, sillones, cama y macetas | Mandíbulas fuertes 4; 900 migas |
| Materiales resistentes | Electrodomésticos, mesadas y sanitarios | Madera y telas; 12.000 migas |
| Paredes | Muros divididos en tramos de hasta 420 unidades | Materiales resistentes; 120.000 migas |

Mantené el clic sobre la pieza: las hormigas se acercan a su **borde accesible**,
la muerden, transportan las migas y vuelven. Los materiales bloqueados no
reciben daño. Sólo las hormigas y su corrosión extraen material de muebles y
muros; el pisotón sólo afecta alimentos. Al señalar una pieza, el HUD muestra
su resistencia y la dieta requerida. El daño recorta la silueta junto a la mordida:
cada objeto tiene como máximo 16 celdas lógicas y una máscara de dibujo. Las
celdas agotadas dejan huecos transitables. Al perder soportes, los restos caen
por etapas, sin cientos de cuerpos físicos.

Cada extracción entrega 65% del valor a la hormiga y deja 35% en fragmentos;
el material que cae en un derrumbe queda como fragmentos para recoger. Los
montones se agrupan por zona y material, hasta 64 activos, conservando su valor
al fusionarse. No reciben otra vez el multiplicador ni el bonus de destrucción.
Las cargadoras los priorizan y las voladoras no levantan montones pesados.
Alacenas, heladeras, bibliotecas y vitrinas revelan comida al abrirse; hay un
máximo de 24 alimentos ocultos por expedición.

La resistencia escala con el tamaño del objeto. Las mejoras de daño, velocidad,
carga y recolección siguen teniendo efecto sobre estos objetivos. Cada nueva
expedición reconstruye la casa, igual que repone los alimentos; **los desbloqueos
y mejoras sí se guardan**. No se borra el progreso de partidas anteriores.

### Viajes, grandes objetivos y jalea real

La tienda tiene pestañas **Mejoras**, **Castas**, **Viajes** y **Jalea real**.
Los destinos son casa, restaurante, museo, Obelisco, Coliseo y Torre Eiffel.
Cada uno tiene su propio plano y un gran objetivo: mesa familiar, barra del
chef, escultura, Obelisco, arco imperial y torre. Devorar ese objetivo abre el
destino siguiente y entrega de 1 a 6 coronas. `G` permite localizarlo; la niebla
y los requisitos de material siguen vigentes.

**Fundar colonia** (pestaña Jalea real, con confirmación) reinicia migas,
mejoras y castas y los convierte en **jalea real**: 3 por corona de la colonia
más la raíz cuarta de (migas juntadas en la colonia / 100.000). La jalea se gasta en el
**árbol de la reina** (`datos/jalea.csv`), que es permanente: atajos (nacer con
las dietas aprendidas, conservar migas o castas), poder (daño, migas, obreras,
tiempo) y reglas nuevas (pisotón automático, más niveles de tope, corona doble).
Toda la jalea ganada en la historia da además +3% de daño y migas por punto,
aunque se gaste. Se conservan destinos, hitos y el árbol. Cada gran objetivo
paga sus coronas una vez por colonia.

Cada destino conquistado **sube el tope** de las mejoras (`tope_por_destino` en
`mejoras.csv`) y trae **mejoras propias** (marcadas con ✦, columna `destino`).
Mandíbulas fuertes y Pisotón duplican su efecto cada 25 niveles. El diseño
completo y sus razones están en [`docs/DISENO_PROGRESION.md`](docs/DISENO_PROGRESION.md).

Los seis hitos son opcionales y tienen premios visibles en la tienda: primera
silla (+20% daño de carpinteras), primer derrumbe (+20% daño de demoledoras),
cuatro sillas en una run (+2 bocados para cargadoras), primer tesoro (olfato +10),
cocina desmantelada (migas +10%) y primer monumento (migas +15% y corona evolucionada).

Los depósitos cargan el **frenesí**: 20 depósitos activan 6 segundos de velocidad
y ritmo de mordida ×1.5, con descanso para no encadenarlo indefinidamente. Las
mandíbulas crecen visualmente con sus mejoras; buche y legado cambian el abdomen
y las marcas del cuerpo. La reina adquiere una corona especial al conquistar
un monumento.

### Rendimiento

- Arte compartido en un atlas: se genera una vez al abrir el juego y se reutiliza.
  Los cuerpos animan a 12 cuadros por segundo y el movimiento sigue siendo fluido.
- Búsquedas espaciales por sectores para alimento y obstáculos, en vez de recorrer
  todos los objetos por cada decisión de cada hormiga.
- Selección de feromonas con un heap acotado, cada 0,2 segundos, sin ordenar
  toda la colonia. Cursor compartido por suelo/vuelo; anillos a 30 Hz.
- Rutas con una cola justa: hasta seis pedidos por cuadro y un presupuesto
  blando de 2 ms. Hasta dos turnos priorizan llamados y retornos; las demás
  conservan su lugar. Mientras esperan pueden continuar su ruta segura anterior.
  Mover unos pocos píxeles no obliga a recalcular; fallos se reintentan cada
  0,5–0,8 s y también tienen caché. Los giros se comprimen y el suavizado tiene
  trabajo acotado, sin probar cada celda contra todo el resto del recorrido.
- Rutas recalculadas al cambiar el objetivo. La grilla se
  prepara conforme crece el territorio; los recortes actualizan sólo su zona,
  con un presupuesto de 384 celdas por cuadro. Las rutas anteriores siguen
  siendo válidas al quitar material, sin forzar a todas las hormigas a recalcular.
- Niebla en una superficie, textos con un tamaño de fuente fijo y efectos limitados.
  Lo que está fuera de pantalla no vuelve a dibujar la animación de sus hormigas.
- El juego normal está limitado a 60 FPS. Un solo atlas compartido de unos
  33 MiB RGBA8 sirve para los seis destinos y tres etapas visuales; sólo el
  escenario activo tiene nodos. Máximos: 64 montones, 600 partículas, 24 ondas
  y 40 textos. No se generan efectos visuales lejos de cámara.

El benchmark gráfico usa el renderizador real, la casa completa y grupos de 5,
150 y 500 hormigas; añade una fase de demolición con 500. No guarda la partida;
desactiva VSync y el límite de 60 FPS sólo durante la medición:

```bash
godot --path . --fixed-fps 60 res://tests/perfil_rendimiento.tscn
godot --path . --fixed-fps 60 res://tests/perfil_feromonas.tscn
```

Informa tiempo real por cuadro, percentil 95, peor cuadro y llamadas de dibujo.
Comparar en la misma PC, sin ejecutar dos pruebas gráficas a la vez. No usar
`--headless` para medir el renderizado: sólo sirve para pruebas lógicas.
El segundo benchmark reparte 500 hormigas por toda la casa y mueve el cursor
continuamente entre habitaciones y sobre muebles, con 24 y hasta 64 llamadas.
Ver resultados y límites de la medición en `tests/RENDIMIENTO.md`.

Los efectos actuales se sintetizan en `global/audio_suave.gd`, con ataques y
finales suaves, notas armónicas y límites de superposición. Los WAV originales
se conservan como referencia. No se necesitan recursos externos adicionales.

### Castas y reclutamiento

La pestaña **Castas** permite conocer y comprar siete tipos de
hormiga. Cada unidad comprada es **permanente** y sale en todas las
expediciones siguientes. Se puede reclutar de a una, diez o el máximo posible.
Los precios crecen por unidad y cada casta tiene un
límite. Las fichas muestran las estadísticas con las mejoras actuales incluidas.

- **Exploradora veloz:** velocidad ×2.2; mordida más débil.
- **Roja:** aplica veneno corrosivo durante 3 s. El daño por segundo equivale al
  80% de su mordida y esas migas se suman automáticamente. Renovar el veneno
  conserva la potencia más fuerte; no acumula daño sin límite. Hace ×2.2 contra
  resistentes y deja corrosión que mejora 20% los ataques del grupo sobre esa pieza.
- **Voladora:** cruza sobre muebles y tiene más velocidad y olfato. Respeta el
  territorio descubierto y usa las puertas para cambiar de habitación. Sólo
  levanta fragmentos de peso 1.
- **Cargadora:** transporta cuatro veces más bocados y muerde más fuerte, pero
  camina más lento. Prioriza fragmentos y levanta hasta peso 4.
- **Reina:** despliega dos miniobreras cada 6 s, hasta 24 por reina y expedición.
  Las minis recolectan, pero no se guardan como unidades permanentes.
- **Carpintera:** ×3 contra madera/telas, ×0.5 contra alimentos; requiere la dieta
  de madera. Funciona bien con cargadoras que retiren los restos.
- **Demoledora:** ×3 contra muros, ×1.5 contra resistentes, ×0.35 contra alimentos;
  requiere paredes. Es lenta y aprovecha la corrosión de las rojas.

En automático, los roles influyen en la búsqueda. Las prioridades de la barra
inferior cambian la preferencia del grupo sin prohibir otros trabajos; mantener
el clic en un objetivo permite dar una orden directa por encima de esa prioridad.

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

### Medir el ritmo con el bot

`tests/bot_balance.tscn` juega solo, como un jugador activo (3 pisotones por
segundo, llamado sobre el gran objetivo, compra lo más barato y ahorra para
cada dieta), y anota el minuto de juego de cada desbloqueo y de cada destino:

```bash
godot --headless --fixed-fps 60 --path . res://tests/bot_balance.tscn
```

Juega a velocidad ×8, así que una hora de juego tarda un par de minutos. Con
`BOT_ESTADO=archivo.json` se puede cortar y retomar por tandas; con `BOT_LOG`
también escribe el registro en un archivo. No corre en CI.

Medición actual (28/10). Primera hora: dos corridas; campaña completa: una
corrida por etapas, retomando desde cada conquista.

| Hito | Momento | Fundaciones |
|---|---|---|
| Mandíbulas fuertes 4 | 1,5–3,5 min | — |
| Madera y telas (8.000 migas) | ~10 min | — |
| Materiales resistentes (150.000) | ~26 min | — |
| Paredes (4.000.000) | ~42 min | — |
| Casa conquistada | ~45 min | 0 |
| Restaurante | ~3,5–4,5 h | 2–3 |
| Museo | ~5,3 h | 4 |
| Obelisco | ~6,2 h | 5 |
| Coliseo | ~8,2 h | 6 |
| Torre Eiffel | TORRE_PENDIENTE | TORRE_FUND |

El gran objetivo pide la dieta completa (`PiezaCasa.NIVEL_META`) y su
resistencia se multiplica por `Mundos.vida_meta(destino)` (`vida_meta` en
`mundo/mundos.gd`). Como la casa se reconstruye en cada expedición, es un
chequeo de daño dentro de una sola run. Desde el restaurante, cada destino
pide más o menos una colonia nueva: cada fundación multiplica el daño de la
colonia por cientos o miles.

Para recalibrar un destino: copiá el `estado_<destino>.json` que el bot guarda
al conquistar el anterior, poné un `vida_meta.json` junto al estado (por
ejemplo `{"coliseo": 1e30}`) para hacerlo invulnerable, mirá en el registro
el daño por run (`meta X/Y`) y elegí una resistencia entre la meseta de una
colonia y la siguiente.

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

## Pruebas

Para correr todas las pruebas lógicas de una vez (en Windows, desde Git Bash):

```bash
GODOT=/ruta/a/godot tests/correr_todas.sh
```

GitHub Actions corre lo mismo en cada PR y en cada push a `main` (`.github/workflows/pruebas.yml`);
si el check queda en rojo, no se mergea. Las instrucciones para agentes de IA
(Claude Code y similares) están en `CLAUDE.md`.

### Prueba de humo

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

Regresión de feromonas bajo carga: selección exacta entre 500, clics reales sin
daño, objetivo liberado entre muestreos, destino encerrado y reapertura de paso,
presupuesto real de rutas, turnos justos y llegada de las 64 seleccionadas:

```bash
godot --headless --path . res://tests/prueba_feromonas.tscn
```

Sin `--headless`, también guarda `.godot/qa/feromonas_500.png`. Las pruebas
lógicas antiguas que avanzan cientos de pasos en un único cuadro desactivan
la cuota de rutas; esta regresión mantiene la cuota de producción activada.

Compras por lote, precios acumulados, límites, indicadores de ramas y rutas por los siete ambientes:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_casa_lotes.tscn
```

`tests/revision_mapa.tscn` renderiza la casa completa, un recorrido por sus
ambientes, el llamado y la tienda en distintos tamaños; guarda las capturas
en `.godot/qa/` sin modificar la partida.

Materiales bloqueados, desbloqueos, guardado, destrucción desde el borde,
recompensas, búsqueda espacial y apertura de pasos:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_materiales.tscn
```

`tests/revision_materiales.tscn` captura la silla antes, durante y después de
devorarla, un muro abierto y las nuevas mejoras en dos tamaños de ventana.

Campaña completa, recortes, derrumbes, roles, prioridades, frenesí, guardado,
legado y conservación del valor de fragmentos:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_campana.tscn
```

`tests/revision_campana.tscn` captura los seis escenarios, los nuevos menús y la
confirmación de legado, también en 1000×620. Todas las revisiones desactivan el guardado.

Primeros minutos: mecánicas que aparecen de a una, próxima meta, pisotón y
tamaño de las hormigas en pantalla:

```bash
godot --headless --fixed-fps 60 --path . res://tests/prueba_progresion.tscn
```

## Exportar

*Proyecto → Exportar → Agregar → Windows Desktop* (la primera vez Godot pide descargar las plantillas de exportación). Si al exportar faltan los CSV, agreguen `datos/*.csv` en *Recursos → Filtros para exportar archivos que no son recursos*.
