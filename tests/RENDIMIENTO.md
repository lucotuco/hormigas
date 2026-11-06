# Rendimiento gráfico y memoria

La pasada de controles/feedback del **2/11/2026** se documenta al final. Cambia
la colocación de accesos y el trabajo por ciclo; sus mediciones no son un A/B
de economía idéntica contra las anteriores.

La medición de cuerpo/sombra y contacto exterior está al final de **30/10/2026**;
la ampliación por proyectos y su estrés específico, en **1/11/2026**.
Las tablas anteriores conservan su contexto histórico: no son un control A/B
del sistema actual ni una garantía de rendimiento del juego completo.

## Medición gráfica — 27/10/2026 (histórico)

Godot 4.7.2, Windows, GL Compatibility, NVIDIA RTX 3060, ventana de 1280×720.
Referencia: commit `c3a6832`; comparación con la optimización y materiales nuevos.

Mismo script `perfil_rendimiento.gd`, semilla 171, casa completa, VSync desactivado,
paso de simulación fijo de 1/60 s, 60 cuadros de preparación y 300 de medición por
grupo. Las dos versiones se ejecutaron por separado. El tiempo se toma del reloj
real: `--fixed-fps 60` fija el paso de simulación, no limita esta medición a 60 FPS.

| Hormigas | Antes: media / p95 | Después: media / p95 | Dibujos antes → después |
|---|---|---|---|
| 5 | 8,87 / 15,87 ms | 2,38 / 2,54 ms | 2.240 → 492 |
| 150 | 50,26 / 53,69 ms | 3,67 / 4,31 ms | 5.260 → 596 |
| 500 | 160,03 / 171,22 ms | 5,99 / 7,59 ms | 13.523 → 702 |

Son resultados de esta PC y este escenario, no una garantía de FPS en otras
máquinas. No incluyen el arranque, la generación inicial del atlas ni la tienda.
Tampoco sustituyen un playtest de una expedición completa en hardware más lento.

## Cambios que explican la diferencia

- Atlas único para cuerpos, animaciones, comida y muebles; se renderiza una vez.
- Cuerpos animados a 12 Hz; posición y orientación siguen actualizándose por cuadro.
- Comida y obstáculos indexados por sectores; el llamado comparte su consulta.
- No se vuelve a ajustar ni validar un destino idéntico en cada cuadro.
- Navegación construida por territorio y modificada localmente al destruir piezas.
- Niebla en un solo rectángulo con shader, fuentes flotantes de tamaño fijo y
  límites de efectos para que no crezcan sin control.

Ejecutar con renderizador real, sin otras pruebas gráficas a la vez:

```bash
godot --path . --fixed-fps 60 res://tests/perfil_rendimiento.tscn
```

Las pruebas lógicas (`prueba_movimiento.tscn`, etc.) no miden rendimiento gráfico.

## Campaña y destrucción por partes

Misma PC y configuración, con seis planos disponibles, tres etapas visuales,
recortes por celdas, roles y montones transportables. Se carga sólo un escenario.
El benchmark ahora desactiva también el límite normal de 60 FPS.

| Escenario | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Casa, 5 hormigas | 2,52 ms | 2,71 ms | 3,21 ms |
| Casa, 150 hormigas | 3,71 ms | 4,34 ms | 5,70 ms |
| Casa, 500 hormigas | 6,15 ms | 7,83 ms | 9,34 ms |
| Demolición, 500 de varios roles | 7,87 ms | 10,44 ms | 12,97 ms |

Atlas compartido: 2048×4224, aproximadamente 33 MiB RGBA8. Es un recurso fijo,
no uno por destino. En la fase de demolición terminaron activos 13/64 montones,
486/600 partículas y 40/40 textos; los topes impiden crecer sin límite. Los valores
pueden variar por carga del sistema y el agrupamiento de efectos de cada ejecución.

## Feromonas con cursor en movimiento — segunda optimización

La medición anterior mantenía el llamado casi siempre quieto y cerca del nido.
No representaba la situación reportada de moverlo continuamente por la casa.
`perfil_feromonas.tscn` añade 500 hormigas repartidas por el plano completo,
semilla 417, velocidad 240, cursor que cambia de habitación y cursor sobre
muebles. Cada fase usa 240 cuadros: descarta 40 iniciales y mide 200. El atlas
y la primera preparación de la navegación quedan fuera del intervalo.

Misma PC, renderer, resolución, paso fijo 1/60, VSync y límite de FPS desactivados.
Antes y después se ejecutaron por separado:

| Escenario, 500 hormigas | Antes: media / p95 / peor | Después: media / p95 / peor |
|---|---:|---:|
| Sin llamado, colonia repartida | 15,62 / 39,08 / 53,05 ms | 5,74 / 7,80 / 9,64 ms |
| Cursor móvil, 24 llamadas | 14,94 / 29,15 / 56,41 ms | 5,98 / 7,50 / 9,19 ms |
| Cursor móvil, llamada mejorada | 19,32 / 33,75 / 48,39 ms | 6,34 / 8,01 / 9,25 ms |
| Cursor pasando sobre muebles | 21,99 / 41,16 / 66,54 ms | 6,69 / 8,59 / 10,41 ms |

En las últimas dos fases la versión anterior llamaba 54 hormigas; la nueva
llama 64 por la conversión de Pisotón a Coordinación. No se redujo la colonia
para conseguir estos resultados. Las trayectorias posteriores cambian con el
planificador, por lo que es una comparación del mismo escenario y secuencia de
entrada, no de exactamente las mismas posiciones de cada hormiga por cuadro.

Cambios principales:

- Heap de las K más cercanas: sin un Dictionary temporal por hormiga ni ordenación
  de toda la colonia; selección a 5 Hz y visual a 30 Hz.
- Destino compartido por tipo de movimiento, tolerancia de 12 unidades y 0,18 s
  entre recálculos del mismo llamado; evita perseguir cada movimiento mínimo.
- Cola FIFO con hasta dos turnos prioritarios para llamados/retornos, máximo
  seis pedidos por cuadro y corte blando al alcanzar 2 ms de navegación. No
  interrumpe un A* ya iniciado: no es una garantía absoluta de tiempo máximo.
- Giro comprimido de rutas, suavizado de hasta ocho candidatos por tramo,
  consumo por índice (sin quitar/copiar el primer punto en cada paso).
- Reutilización de rutas positivas al quitar obstáculos; caché de negativas y
  reintento espaciado, invalidado cuando se abre un paso.
- Consultas geométricas puntuales sin listas temporales, accesos a muebles sin
  ordenar 64 candidatos y efectos fuera de cámara descartados. Ondas limitadas
  a 24 y ancho de textos flotantes calculado una sola vez.

La regresión `prueba_feromonas.tscn` usa la cuota real de producción: las 500
hormigas recibieron turno, las 64 seleccionadas llegaron y ninguna cuota por
cuadro se excedió. Un objetivo encerrado hizo diez consultas en seis segundos
simulados, en lugar de una por cuadro; al abrir un paso vuelve a ser alcanzable.
También verifica eventos reales sin daño por clic y referencias a objetivos liberados.

Repetición del benchmark general con la cola final:

| Escenario | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Casa, 5 hormigas | 1,57 ms | 1,79 ms | 2,04 ms |
| Casa, 150 hormigas | 2,80 ms | 3,42 ms | 5,01 ms |
| Casa, 500 hormigas | 4,09 ms | 5,51 ms | 6,89 ms |
| Demolición, 500 de varios roles | 5,09 ms | 6,83 ms | 8,69 ms |

Son resultados locales de una prueba de estrés acotada, no una promesa de cero
tirones en cualquier PC o en cualquier partida. El juego normal conserva su
límite de 60 FPS; las pruebas no modifican el archivo de partida.

## IA cooperativa y evoluciones — 28/10/2026

Revisión sobre `d57d022`, misma RTX 3060, Godot 4.7.2 GL Compatibility,
1280×720, VSync apagado y paso fijo 1/60. Ambas pruebas se ejecutaron
separadas, sin el bot de balance en paralelo. No incluye carga inicial.

| Escenario | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Casa, 5 hormigas | 1,68 ms | 2,12 ms | 2,87 ms |
| Casa, 150 hormigas | 2,99 ms | 3,52 ms | 4,03 ms |
| Casa, 500 hormigas | 5,24 ms | 6,76 ms | 9,30 ms |
| Demolición, 500 de varios roles | 6,00 ms | 7,71 ms | 9,67 ms |
| Continuación con contagio y barrido, 500 | 5,11 ms | 6,19 ms | 8,54 ms |
| Colonia repartida, sin llamado, 500 | 6,55 ms | 8,37 ms | 9,39 ms |
| Cursor móvil, 24 llamadas | 6,75 ms | 8,46 ms | 9,74 ms |
| Cursor móvil, 64 llamadas | 8,19 ms | 9,86 ms | 17,68 ms |
| Cursor pasando sobre muebles, 64 llamadas | 9,29 ms | 11,52 ms | 13,66 ms |

La fase con evoluciones continúa después de la demolición: queda menos
material en pie. Su menor costo no demuestra que activar habilidades acelere
el juego. El atlas sigue en 33 MiB y los topes no cambiaron: 500 hormigas,
64 montones, 600 partículas, 40 textos y 24 ondas.

La IA agrega reservas de puestos, hallazgos compartidos y destinos repartidos;
además el llamado sigue trabajando cuando se abre un hueco bajo el cursor.
Esto cuesta más que la anterior versión optimizada: el escenario de cursor
sobre muebles pasó de 6,69 a 9,29 ms de media. No se presenta como una mejora
de FPS respecto de aquella versión. Mantiene margen medio para 60 FPS en
esta PC, pero hubo un cuadro de 17,68 ms: no se garantiza ausencia de tirones.

Para contener ese costo:

- Navegación con corte blando de **1,2 ms**, seis rutas/cuadro y dos turnos
  prioritarios. Un A* en curso no se interrumpe; el límite no es duro.
- Memoria común de **24 objetivos**, consultada a lo sumo cada **0,6 s** sólo
  cuando no hay alimento local; sin comparaciones entre pares de hormigas.
- Reservas enteras en cada recurso y liberación al cambiar objetivo o salir.
- Animaciones compartidas sin formatear claves del atlas por hormiga/cuadro.
- Indicadores de selección agrupados en puntos rellenos, hasta 16 guías;
  contador a 8,3 Hz. La primera variante con 64 arcos intercalados se descartó.
- Contagio hasta dos vecinos cada 1,5 s; dominó hasta 24 piezas, un evento
  cada 0,12 s. No hay física por fragmento ni otros destinos procesándose.

`prueba_enjambre.tscn` verifica también ocho obreras desmontando el tutorial
con el cursor fijo: los huecos no dejan la colonia detenida. Las once suites
suman 347 verificaciones sin fallos. Falta medir en una GPU integrada y en
expediciones largas reales; los tiempos del bot headless no sirven como FPS.

## Dispersión autónoma — corrección del amontonamiento

La primera reproducción sin llamado (`prueba_dispersion.tscn`, semilla 519,
territorio 3.500, 500 obreras, velocidad 240, daño 200, capacidad 6 y olfato
100) dejaba 451 exploradoras cerca del nido a los 10 s. Sólo 49 de las 500
habían pasado de 1.000 px del nido a los 40 s: no era principalmente un bloqueo
al liberar comida, sino una caminata aleatoria de pasos de 40–110 px.

El reparto nuevo reserva sectores de 320 px y elige entre hasta doce destinos
de recorrido más largo. Prefiere sectores menos visitados/ocupados y conserva
la meta durante la espera de rutas. No compara pares de hormigas. Las consultas
geométricas se hacen sólo si el candidato mejora el puntaje; el caso sin salida
reintenta con pausa y no conserva una meta vieja. Trabajo, regreso y llamado
liberan las reservas de exploración.

En las últimas corridas entre 486 y 493 de 500 visitaron zonas a más de 1.000
px a los 40 s, con unos 7.800–8.300 pedidos de ruta en lugar de 9.245. La cuota
temporal de producción y el generador aleatorio compartido hacen variar las
trayectorias entre corridas; no son posiciones idénticas por cuadro. El test
verifica además cambio de alimento agotado, destinos estables, pausa ante falta
de salida, ausencia de grupos ociosos inmóviles y liberación de reservas.

Última medición con renderer real, misma RTX 3060 y condiciones anteriores:

| Escenario | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Casa, 5 hormigas | 1,66 ms | 1,87 ms | 2,19 ms |
| Casa, 150 hormigas | 2,96 ms | 3,50 ms | 4,06 ms |
| Casa, 500 hormigas | 5,39 ms | 6,25 ms | 7,02 ms |
| Demolición, 500 | 8,56 ms | 10,53 ms | 13,81 ms |
| Continuación con evoluciones, 500 | 6,93 ms | 8,53 ms | 10,66 ms |
| Colonia repartida sin llamado, 500 | 6,46 ms | 8,27 ms | 9,04 ms |
| Cursor móvil, 24 llamadas | 7,61 ms | 9,02 ms | 10,96 ms |
| Cursor móvil, 64 llamadas | 8,62 ms | 9,91 ms | 11,26 ms |
| Cursor sobre muebles, 64 llamadas | 8,87 ms | 11,19 ms | 14,24 ms |

Hay más actividad, desplazamiento y trabajo que antes; no se afirma que esta
corrección mejore todos los tiempos de cuadro. Conserva la cuota de seis rutas
y corte blando de 1,2 ms, el atlas y los límites de entidades. Los resultados
siguen siendo locales, no una garantía en GPU integrada. Las doce suites suman
357 verificaciones sin fallos. La escena de dispersión con renderer guarda
capturas de los segundos 10 y 40 con cámara fija, sin afectar el guardado.

## Logística y progresión — 28/10

Godot 4.7.2 GL Compatibility, RTX 3060, 1280×720, paso 1/60 s, VSync y límite
de FPS desactivados sólo en el benchmark. Escenas gráficas ejecutadas de a una,
sin bot de balance simultáneo. Los controles de mouse reales quedan desactivados
en las pruebas para no cambiar la cámara o el llamado durante la medición.

| Escenario | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Casa, 5 hormigas | 1,62 ms | 1,79 ms | 1,96 ms |
| Casa, 150 hormigas | 3,02 ms | 3,58 ms | 4,33 ms |
| Casa, 500 hormigas | 5,26 ms | 6,14 ms | 7,22 ms |
| Demolición, 500 | 8,05 ms | 10,00 ms | 11,73 ms |
| Continuación con evoluciones, 500 | 7,03 ms | 8,48 ms | 10,41 ms |
| Cursor móvil, 24 llamadas | 7,18 ms | 8,39 ms | 9,69 ms |
| Cursor móvil, 64 llamadas | 8,30 ms | 9,68 ms | 10,59 ms |
| Cursor sobre muebles, 64 llamadas | 8,25 ms | 10,23 ms | 13,80 ms |

`perfil_logistica.tscn` agrega una prueba independiente de los seis escenarios:
500 hormigas de seis castas, seis entradas secundarias, adaptaciones de todos
los destinos, Corte aserrado continuo y Barrido, cursor en movimiento. 90 cuadros de
calentamiento y 360 medidos por mapa; se recrea la escena entre destinos.

| Destino | Media | p95 | Peor cuadro | Máximo rutas/cuadro |
|---|---:|---:|---:|---:|
| Casa | 7,25 ms | 8,88 ms | 11,81 ms | 6 |
| Restaurante | 7,15 ms | 9,25 ms | 11,34 ms | 6 |
| Museo | 7,20 ms | 9,48 ms | 11,90 ms | 6 |
| Obelisco | 6,44 ms | 8,61 ms | 10,57 ms | 6 |
| Coliseo | 6,79 ms | 8,96 ms | 9,66 ms | 6 |
| Eiffel | 7,49 ms | 9,80 ms | 11,83 ms | 6 |

El atlas sigue en 33 MiB. No cambian los topes de 500 hormigas, 64 montones,
600 partículas, 40 textos y 24 ondas. Hay hasta 16 trazos de habilidades con
enfriamiento global de 0,08 s. Los accesos se preparan al generar el mapa,
se habilitan a 2 Hz al crecer el territorio y se consultan sólo al regresar.
No simulan túneles ni usan búsquedas de rutas adicionales al presupuesto.
La IA conserva el puesto de acercamiento hasta cambiar el recurso o geometría.
Al iniciar la retirada conserva los recorridos y turnos de las hormigas que
ya estaban regresando, evitando una nueva oleada de solicitudes.

Las **13 suites suman 389 verificaciones**, sin errores de script. La suite
`prueba_logistica` agrega 31: migración v5→v6, récords y adaptaciones conservados
al fundar, depósitos por accesos secundarios, recuperación de una entrada
encerrada por paredes usando A* real, retirada sin nuevos recursos ni doble
cobro, cierre acotado, efectos agrupados y desglose de montones mixtos con
flotantes de 64 bits. La prueba de contagio usa objetivos aislados para que
la nueva distribución de comida no altere su escenario de regresión.
`prueba_enjambre` suma 32 verificaciones, incluyendo conservación del valor y
trabajo continuo de la carpintera sin viajes ni acreditaciones gratuitas.

`revision_logistica.tscn` verifica mapa, corrosión y entradas, resumen de fin
de expedición, viajes y jalea en 1280×720 y 1000×620. Capturas locales:
`.godot/qa/logistica_*.png`. Guardado real desactivado en todas estas escenas.

Estas mediciones conservan margen para 60 FPS en esta PC; no certifican GPU
integrada ni sesiones prolongadas. El presupuesto temporal de A* sigue siendo
blando (1,2 ms): una búsqueda en curso no puede interrumpirse. Cambiar comida,
objetivos y entradas también cambia la actividad; las diferencias con versiones
anteriores no se atribuyen exclusivamente a optimizaciones de código.

## Integración de main y renovación estética — 28/10

Se integraron menú, traducciones, eventos, decretos y resistencias de `main`
sin perder IA, entradas, retirada ni registros. El clic manual sólo interactúa
con eventos: no vuelve a extraer comida ni muebles. La mejora automática que
ya estaba en `main` se conserva. El piloto anterior es histórico: no mide esta
combinación de cambios.

Arte cenital renovado: sillas con marco y tapizado, vajilla, utensilios,
puertas/tiradores, textiles y hojas; sombras suaves precalculadas y luz estática
de ventanas. Bancos de plaza reemplazan consolas con la misma geometría y
economía. Césped y arena ya no usan juntas de cerámica. Los accesorios del
mueble comparten su máscara: no quedan flotando tras destruirlo.

El atlas distingue color, orientación y acabado, y omite instancias duplicadas.
Con las comidas adicionales de `main` y los nuevos acabados mide **2048×4352,
34 MiB RGBA8**, 40 acabados de mobiliario. Se renderiza una vez; no se agregan
luces dinámicas, cuerpos físicos ni texturas por hormiga.

Medición gráfica final, misma RTX 3060 y configuración de la sección anterior,
500 hormigas, Corte + Barrido, seis entradas, todas las adaptaciones:

| Destino | Media | p95 | Peor cuadro | Máximo rutas/cuadro |
|---|---:|---:|---:|---:|
| Casa | 7,45 ms | 9,69 ms | 10,70 ms | 6 |
| Restaurante | 7,23 ms | 9,86 ms | 11,59 ms | 6 |
| Museo | 6,74 ms | 8,89 ms | 11,28 ms | 6 |
| Obelisco | 6,32 ms | 8,96 ms | 11,27 ms | 6 |
| Coliseo | 6,24 ms | 8,34 ms | 9,53 ms | 6 |
| Eiffel | 7,24 ms | 9,65 ms | 11,24 ms | 6 |

Feromonas (500 hormigas): sin llamado 6,78 ms media; cursor móvil con 24
respuestas 8,05 ms; con 64 respuestas 8,95 ms. Sobre muebles: **8,93 ms media,
10,92 ms p95, 12,27 ms peor cuadro**. Son muestras locales cortas, no una
garantía de ausencia de tirones en otros equipos.

Se descarta una primera medición porque el menú nuevo pausaba al perder foco:
medía escenas quietas, no IA. Los perfiles ahora desactivan esa preferencia
sólo en memoria (sin guardar) y el de logística comprueba 500 hormigas, árbol
sin pausa y consultas reales de navegación. La pausa del juego sigue activa.

Las **18 suites suman 543 verificaciones sin fallos**. `prueba_estetica` cubre
acabados de todos los destinos, identidad del tutorial, equivalencia económica
de los bancos y ubicación de comida en su ambiente. `revision_estetica` captura
cada ambiente de la casa, el inicio con HUD y los seis destinos completos en
`.godot/qa/estetica_*.png`. Las pruebas no escriben la partida del jugador.
Siguen pendientes GPU integrada y sesiones prolongadas.

## Arte preiluminado y legibilidad — 28/10, segunda revisión

Se sustituyen los dibujos planos del mobiliario doméstico por sprites con
materiales y sombras precalculadas. Pisos y alfombras usan texturas filtradas;
el Obelisco, los arcos y la Torre Eiffel tienen ilustraciones nuevas. La plaza
incorpora calzadas y cruces transitables, sin cambiar obstáculos ni recompensas.
Los recortes de destrucción y la navegación conservan su geometría.

El atlas continúa en **2048×4352 / 34 MiB RGBA8**, ahora con 41 acabados:
se agrega la biblioteca horizontal del museo que faltaba. Las cuatro hojas
fuente ocupan aproximadamente **8,85 MiB en disco** y agregan memoria de textura
fija compartida (ese dato de disco no representa su costo en VRAM). No se
generan texturas por objeto ni luces dinámicas. El suelo realiza un muestreo
de material por fragmento; las alfombras usan mipmaps al alejar.

Los textos tienen un máximo de diez visibles, seis en vista alejada, se
agrupan por distancia en pantalla y evitan superponerse. Los indicadores de
eventos muestran el nombre y reservan el HUD; se actualizan a 10 Hz y se
deduplican por tipo de evento. El dinero acreditado no cambia.

Medición final con renderer Compatibility, RTX 3060, 1280×720, sin VSync,
500 hormigas y los mismos perfiles, ejecutados de a uno:

| Destino | Media | p95 | Peor cuadro | Máximo rutas/cuadro |
|---|---:|---:|---:|---:|
| Casa | 7,94 ms | 10,99 ms | 12,80 ms | 6 |
| Restaurante | 7,60 ms | 9,76 ms | 10,97 ms | 6 |
| Museo | 7,23 ms | 10,09 ms | 13,34 ms | 6 |
| Obelisco | 6,30 ms | 8,69 ms | 10,14 ms | 6 |
| Coliseo | 5,91 ms | 7,83 ms | 9,50 ms | 6 |
| Eiffel | 6,91 ms | 9,24 ms | 11,17 ms | 6 |

Feromonas: sin llamado **6,68 ms** de media; cursor con 24 seleccionadas
**8,18 ms**; cursor con 64 **9,01 ms**, p95 10,55 y peor 14,89 ms. Sobre muebles:
**9,49 ms** de media, p95 11,62 y peor 13,94 ms. Una pasada anterior de esta
revisión dio 8,83 ms sobre muebles: hay variación entre muestras. Se mantiene
margen para 60 FPS en esta PC, no se garantiza ese resultado en hardware distinto.

**18 suites / 549 verificaciones lógicas sin fallos**, más **13 verificaciones
con render real** en `revision_realismo.tscn`: indicadores en los cuatro
bordes y dos tamaños de ventana, deduplicado de bandadas, números sin
superposición y pérdida de fragmentos de la mesa ilustrada. Capturas:
`.godot/qa/estetica_*.png` y `.godot/qa/realismo_*.png`. No se escribió la partida.
Fuentes y prompts de generación: `arte/realista/PROCEDENCIA.md`.

### Hormiguero integrado y base Full HD (28/10/2026)

`project.godot` ahora diseña a **1920×1080**, con escalado de `canvas_items`
para ventanas menores. La tienda mantiene las cuatro cámaras principales
visibles al cambiar de sección. El corte de tierra no ejecuta `_process`:
su dibujo queda retenido y las once rutas se precalculan sólo al redimensionar.
Las 22 hormigas decorativas se dibujan juntas en un único Control a 30 Hz;
no usan la IA, colisiones, búsquedas A* ni nodos individuales de la expedición.
La animación no avanza si el hormiguero está oculto.

`prueba_nido.tscn`: 41 verificaciones, incluyendo clics de ventana reales a
1920×1080 y 1280×720, secciones dentro del corte, navegación persistente,
movimiento, presupuesto de redibujos y reutilización de rutas. Las 18 suites
preexistentes también pasan (19 suites en total). `revision_nido.tscn` guarda
capturas Full HD en `.godot/qa/nido_1920.png` y `nido_seccion_*.png`.

Para revisar el cambio de resolución también se ejecutó
`perfil_feromonas.tscn --resolution 1920x1080`, renderer Compatibility,
RTX 3060, sin VSync, 500 hormigas, sin otros benchmarks simultáneos:

| Carga | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Sin llamado | 6,45 ms | 8,68 ms | 10,36 ms |
| Cursor / 24 seleccionadas | 7,07 ms | 8,64 ms | 9,45 ms |
| Cursor / 64 seleccionadas | 7,77 ms | 9,25 ms | 10,68 ms |
| Cursor sobre muebles | 7,79 ms | 10,21 ms | 12,29 ms |

Es una medición de la expedición en esta PC, no del costo aislado del menú ni
una garantía para otro hardware. Las muestras anteriores siguen documentadas
con su resolución original y no son una comparación A/B controlada.

### Contornos de material y acabado de escenarios (28/10/2026)

El perfil compartido de `SiluetaMueble` usa hasta 31 bandas por objeto. Se
prepara al crear el mapa: no se consulta el alfa del PNG durante la simulación.
`Cocina` registra esos contornos desde el inicio; `PiezaCasa` los intersecta con
sus hasta 16 secciones y sólo reconstruye los recortes cuando desaparece una
sección. La resistencia total se conserva; la torre conserva cuatro pisos de
igual resistencia. Las consultas de contacto siguen cacheadas y la orientación
de mordida sólo consulta el material al llegar o al cambiar esa pieza.

El suelo conserva un muestreo de textura por píxel, ahora con relieve tenue y
paleta por ambiente. Sombras de monumentos horneadas en el atlas; bordes de
rotura y corrosión en la máscara ya existente. Feromonas con un pulso en lugar
de tres, estado fuera del objeto y avisos compactos de a uno.

Las 19 suites lógicas pasan. La regresión de materiales incluye márgenes
transparentes transitables, vanos abiertos, contactos alcanzables, resistencia
total, extracción completa y orientación hacia la superficie. La revisión con
renderer real compara 24 contactos por monumento con el alfa del PNG de
Obelisco, Eiffel y arco, y guarda planos y roturas en `.godot/qa/acabado_*.png`.
La revisión de superposiciones del HUD suma 13 comprobaciones sin fallos.

Medición final de `perfil_logistica.tscn`, ejecutada sola: RTX 3060,
1920×1080, Compatibility, VSync desactivado y 500 hormigas:

| Destino | Media | p95 | Peor cuadro | Rutas/cuadro máx. |
|---|---:|---:|---:|---:|
| Casa | 6,40 ms | 8,81 ms | 10,77 ms | 6 |
| Restaurante | 4,31 ms | 6,34 ms | 10,49 ms | 6 |
| Museo | 3,44 ms | 4,52 ms | 7,75 ms | 6 |
| Obelisco | 3,24 ms | 4,28 ms | 5,22 ms | 6 |
| Coliseo | 3,47 ms | 4,45 ms | 5,30 ms | 6 |
| Eiffel | 2,95 ms | 3,72 ms | 5,17 ms | 6 |

`perfil_feromonas.tscn`, también ejecutado solo en Full HD: sin llamado,
**5,46 ms** de media; 24 seleccionadas, **6,16 ms**; 64 seleccionadas,
**7,60 ms**, p95 8,94 y peor 10,74 ms; sobre muebles, **7,56 ms**, p95 9,05
y peor 10,33 ms. Son resultados de esta PC, no una promesa para otro hardware
ni una comparación A/B controlada con las mediciones anteriores.

### Coherencia cenital, recuperación del llamado y claridad (28/10/2026)

La casa usa dibujos cenitales retenidos: materiales mates, contornos y sombra
consistentes, alfombras sin fotografía y accesorios por función del mueble.
Sillas, plantas e inodoro respetan los perfiles anteriores. No hay nodos,
texturas individuales ni trabajo adicional de dibujo por mueble y por cuadro.
El atlas sigue en **2048×4352, 289 regiones** (~34 MiB RGBA8, sin contar otros
recursos del renderer). Las hojas originales de muebles/detalles se cargan
sólo si se consultan. Los efectos sintetizados suman **131.628 bytes PCM**;
se mantiene el pool de 16 y el intervalo compartido de mordidas de 0,14 s.

La IA deja de reservar piezas en derrumbe y conserva el puesto hasta que cambia
la geometría de SU recurso. Si el cursor queda sobre suelo/comida agotada,
conserva trabajo local y busca cerca al llegar, como máximo cada 0,6 s por
seleccionada, respetando cupos. No añade búsquedas por cuadro ni comparaciones
entre pares de hormigas. Los avisos se actualizan a 10 Hz y sólo sus tarjetas
capturan clics. La vista previa de fundación corre en el menú al elegir decreto,
sin mutar guardado ni caché.

`revision_estilo_casa` valida 16 contactos por cada una de 14 sillas, plantas e
inodoro contra el alfa del atlas final (224 contactos), con tolerancia de 12
unidades del mundo; no contra la imagen anterior. Usa un solo readback de QA,
sin lecturas de píxeles durante la simulación. Las seis capturas Full HD se
guardan en `.godot/qa/estilo_casa_*.png`.

21 suites lógicas, **680 verificaciones sin fallos**. La nueva `prueba_claridad`
contrasta cuatro decretos (e inválido) contra la fundación real, comprueba el
paso de madera y separa el cartón de los hitos de silla. `revision_claridad`
verifica clic real sobre tarjeta, ausencia de feromonas accidentales, separación
del tutorial y confirmación visible al redimensionar Full HD / 1280 / 1000.

Medición integrada, ejecutando cada benchmark solo: Godot 4.7.2, RTX 3060,
GL Compatibility, **1920×1080**, VSync apagado, 500 hormigas, paso 1/60.
Se excluyen arranque y horneado; no es una comparación A/B ni una garantía de
FPS en otra PC. Los escenarios anteriores tienen otras trayectorias y estados.

| Feromonas | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Sin llamado | 6,91 ms | 8,80 ms | 10,29 ms |
| Cursor móvil, 24 | 8,06 ms | 9,58 ms | 10,83 ms |
| Cursor móvil, 64 | 8,99 ms | 10,73 ms | 11,63 ms |
| Cursor sobre muebles | 9,12 ms | 10,71 ms | 12,05 ms |
| Suelo sin objetivo, 64 cercanas | 8,41 ms | 10,29 ms | 11,02 ms |
| Objetivo agotado, 64 cercanas | 7,85 ms | 9,35 ms | 11,05 ms |

Las dos fases nuevas recolocan 64 de las 500 hormigas antes de medir; mantienen
el cursor quieto y comprueban que sigan seleccionadas, sin simular daño por clic.
Sus muestras y contadores de rutas excluyen esa preparación. Son estrés
secuencial, no una comparación controlada de recuperación frente a ausencia de
orden. Registro: `.godot/qa/perfil_producto_feromonas.log`.

| Logística por destino | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Casa | 8,35 ms | 10,27 ms | 14,18 ms |
| Restaurante | 7,78 ms | 10,05 ms | 12,26 ms |
| Museo | 6,90 ms | 8,98 ms | 10,80 ms |
| Obelisco | 6,92 ms | 9,22 ms | 10,17 ms |
| Coliseo | 7,32 ms | 9,64 ms | 12,88 ms |
| Eiffel | 7,29 ms | 9,47 ms | 14,98 ms |

Todos conservaron las 500 hormigas y el máximo de seis rutas/cuadro. Falta
validar GPU integrada, sesiones largas y juego humano; el resultado local no
resuelve esas tareas. Registro: `.godot/qa/perfil_producto_logistica.log`.

### Mapas poblados, archivo y árbol completo (28/10/2026)

El contenido ampliado usa un atlas único de **2048×5504, 307 regiones**
(aproximadamente **43 MiB RGBA8**, sin sumar el resto del renderer). Hay 59
acabados compartidos. Los accesorios se hornean, no crean procesos individuales;
los nuevos objetos reutilizan perfiles de navegación. La generación respeta
los límites del plano y los pasos reales se prueban con A*, no sólo con distancias.
Casa/restaurante/museo/BA/Roma/París tienen 55/49/29/33/39/37 muebles.

La detección de limpieza se ejecuta cada 0,5 s, no por hormiga ni por cuadro.
Recorre recursos con salida temprana y no solicita rutas. El instante final se
fecha en los cambios relevantes; el chequeo periódico no se suma al récord.
El archivo queda fuera de la simulación: máximo 128 entradas recientes y 1024
contextos, con ocho tarjetas construidas por página y exportación sólo a pedido.

El hormiguero dibuja 31 nodos de mejoras, seis ramas y cuatro secciones. Su
fondo queda retenido; las 41 rutas se preparan al distribuir o cambiar progreso,
no cada cuadro. Hasta 22 hormigas visuales comparten una capa a 30 Hz, sin IA.
No aumenta el tope de 500 hormigas ni el presupuesto de seis rutas de la run.

**24 suites / 803 verificaciones lógicas sin fallos**: guardados deshabilitados,
paso fijo 1/60 y ejecuciones headless secuenciales. Dos fixtures se actualizan por
el cambio intencional de reconquista, no se relaja el contrato productivo.
`prueba_limpieza` suma 31 casos, `prueba_rebirth_archivo` 37, `prueba_poblacion`
46 y `prueba_nido` 50. Resumen local: `.godot/qa/integracion-resumen.json`.

Revisión gráfica de los seis mapas y del árbol inicial/desarrollado, más nueve
verificaciones del archivo/resultado en cada idioma (1920, 1280 y 1000 de ancho).
Se comprobó exportación JSON real a la carpeta ignorada de QA, sin escribir la
partida del jugador. Capturas: `poblacion_*.png`, `nido_*.png`, `archivo_*.png`
y `limpieza_resultado_*.png` dentro de `.godot/qa/`.

Medición actual con Godot 4.7.2, GL Compatibility, RTX 3060, Full HD, VSync
desactivado y paso 1/60. Los tres perfiles se ejecutaron de a uno, sin pruebas
headless simultáneas; **el editor y una ejecución del usuario seguían abiertos**.
No se cerraron sesiones del usuario para medir, por lo que hay carga concurrente:
no es una comparación A/B controlada ni una medición completamente aislada.

| Escenario, 500 hormigas | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Casa | 8,71 ms | 10,80 ms | 13,38 ms |
| Restaurante | 7,80 ms | 10,16 ms | 12,40 ms |
| Museo | 7,91 ms | 10,29 ms | 12,36 ms |
| Obelisco | 7,33 ms | 9,87 ms | 12,09 ms |
| Coliseo | 7,08 ms | 9,43 ms | 12,34 ms |
| Eiffel | 7,96 ms | 10,41 ms | 14,90 ms |

Se mantienen 500 hormigas, navegación activa y seis rutas/cuadro como máximo.
El perfil de logística desactiva el reloj de Run para medir IA/transporte sin
terminar la muestra; no mide la detección de limpieza ni el cierre. Registro:
`.godot/qa/perfil_contenido_logistica.log`.

| Feromonas, 500 hormigas | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Sin llamado | 7,04 ms | 8,65 ms | 9,94 ms |
| Cursor / 24 | 7,90 ms | 9,60 ms | 10,60 ms |
| Cursor / 64 | 8,91 ms | 10,14 ms | 11,09 ms |
| Sobre muebles / 64 | 8,92 ms | 10,22 ms | 10,89 ms |
| Suelo sin objetivo / 64 | 8,32 ms | 9,65 ms | 10,59 ms |
| Objetivo agotado / 64 | 8,33 ms | 9,93 ms | 10,73 ms |

Registro: `.godot/qa/perfil_contenido_feromonas.log`. Las fases son secuenciales
y el mundo evoluciona entre ellas; no comparan estrategias de IA con igual estado.

`perfil_hormiguero.tscn` espera el atlas y descarta 90 cuadros antes de cada
muestra de 360. Inicial: media 4,01 / p95 4,84 / peor 5,38 ms; desarrollado:
5,35 / 6,42 / 7,83 ms. En ambos conserva 786 nodos y la identidad de sus rutas;
no hay reconstrucción continua. Registro: `.godot/qa/perfil_hormiguero_integrado.log`.
Las cifras del menú no representan expediciones. Falta probar GPU integrada,
sesiones largas y ritmo de reconquista con jugadores.

### Casa hasta primera fundación — pulido del 28/10/2026

Cambios sobre `bef0dfb`, sin alterar precios, resistencias ni el atlas compartido
de 307 regiones / aproximadamente 43 MiB RGBA8. Al reservar comida ya al alcance,
la hormiga empieza a morder sin pedir una ruta al centro. Alcance y orientación
comparten caché hasta cambiar recurso, geometría o posición: la regresión cuenta
una consulta geométrica en 120 cuadros inmóviles, en vez de una por cuadro.
No cambia el límite de 500 hormigas, los cupos de trabajo ni seis rutas/cuadro.

Próxima compra, resumen y preparación se calculan al actualizar la interfaz o
elegir una opción, no recorriendo hormigas por cuadro. La preparación cotiza
hasta doce compras explícitas y sólo las aplica al confirmar. La sesión F6 es
una herramienta aparte: observa señales y estado a 10 Hz, con topes de 256
eventos y 32 expediciones; no añade trabajo al juego normal.

**30 suites / 998 verificaciones lógicas, sin fallas**, con guardado deshabilitado.
Regresión completa y repetición final de sesión (30) e idiomas (9, 700 claves).
Revisión con renderer: 24 verificaciones de lectura y 15 de sesión por idioma,
español e inglés, a 1920×1080 y 1000×620. Las pruebas de sesión verifican que
los archivos personales de partida/configuración conserven su huella exacta.
Registros: `.godot/qa/pulido_final_prueba_*.log`; capturas `lectura_*` y `sesion_*`.

Medición gráfica final: Godot 4.7.2, GL Compatibility, RTX 3060, **1920×1080**,
VSync y tope de FPS desactivados, paso fijo 1/60. Perfiles ejecutados de a uno,
sin bot ni pruebas headless simultáneas. El editor y la ejecución del usuario
seguían abiertos: no es una medición aislada ni una comparación A/B controlada.
Se excluyen arranque y horneado. No se modificó la partida personal.

| Feromonas, 500 hormigas | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Sin llamado | 6,63 ms | 8,14 ms | 9,52 ms |
| Cursor / 24 | 8,02 ms | 9,98 ms | 16,21 ms |
| Cursor / 64 | 9,13 ms | 10,80 ms | 11,73 ms |
| Sobre muebles / 64 | 9,14 ms | 10,88 ms | 11,71 ms |
| Suelo sin objetivo / 64 | 8,08 ms | 9,49 ms | 10,91 ms |
| Objetivo agotado / 64 | 7,91 ms | 9,33 ms | 10,28 ms |

Las fases son consecutivas y el mundo evoluciona; las últimas dos conservan
64 seleccionadas y 500 hormigas activas. No representan estados idénticos ni
demuestran por sí solas que la caché aumente los FPS globales. Registro:
`.godot/qa/perfil_casa_pulida_feromonas.log`.

| Logística por destino, 500 hormigas | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Casa | 8,77 ms | 10,82 ms | 12,72 ms |
| Restaurante | 8,05 ms | 10,94 ms | 14,26 ms |
| Museo | 8,04 ms | 10,41 ms | 13,07 ms |
| Obelisco | 7,53 ms | 10,03 ms | 11,41 ms |
| Coliseo | 6,92 ms | 9,18 ms | 10,83 ms |
| Eiffel | 8,08 ms | 10,53 ms | 12,85 ms |

Se conservan las seis entradas y un máximo de seis rutas/cuadro en cada
destino. Como en el perfil anterior, Run tiene su reloj normal desactivado:
esta muestra mide IA/transporte, no detección de limpieza ni cierre. Registro:
`.godot/qa/perfil_casa_pulida_logistica.log`.

Hormiguero: inicial **4,34 / 4,95 / 6,58 ms** (media/p95/peor); desarrollado
**5,60 / 6,36 / 7,43 ms**. Conserva 790 nodos durante cada muestra, 31 mejoras,
41 rutas retenidas y 22 hormigas decorativas. Calentamiento de 90 cuadros y
360 medidos por estado. Registro: `.godot/qa/perfil_casa_pulida_hormiguero.log`.

Son resultados cortos de esta PC, no garantía de ausencia de tirones ni de
rendimiento en otro hardware. La navegación conserva corte blando de 1,2 ms,
no interrumpe un A* en curso. Siguen pendientes GPU integrada, sesiones largas
y observación humana del recorrido, según `docs/PRUEBA_CASA.md`.

### Terreno ampliado e inicio gradual — 28/10/2026

El terreno navegable pasa de 7900×5600 a 10300×7400; el paisaje de 15600×9200
queda fuera del grafo. Ocho objetos reales por destino reutilizan los acabados:
el atlas sigue en **2048×5504, 307 regiones / 43 MiB RGBA8**. Hasta seis alimentos
existentes se redistribuyen al patio, sin aumentar nodos ni valor alimentario.
El dibujo exterior queda retenido, sin procesos decorativos individuales.
Los 43 MiB describen sólo el atlas, no el consumo total de RAM/VRAM del juego.

La cámara cachea límites y adapta zoom/paneo al viewport completo. El llamado
rechaza el paisaje no jugable antes de seleccionar hormigas o buscar destinos,
aunque el radio de territorio alcance allí; arrastrar de vuelta permite llamar.
Se mantienen las 500 hormigas, las seis rutas por cuadro y el corte blando de
1,2 ms. Un A* en curso no puede interrumpirse.

Dos ahorros comprobados directamente, no inferidos de promedios de FPS:

- Filtro envolvente inclusivo antes de las siluetas: 45.198 puntos conservan
  el resultado exacto en los seis destinos; 3.600 consultas lejanas evitan
  recorrer las bandas de material.
- El veneno conserva daño/pagos cada 0,5 s y el último tick fraccionario, sin
  forzar el dibujo base de Comida en cada cuadro de PiezaCasa. 81 renovaciones
  en 1,25 s producen como máximo 16 actualizaciones de máscara, no 81 ni una
  por cuadro. La corrosión termina de desvanecerse y apaga su procesamiento;
  antes podía quedar congelada al detenerse el proceso al expirar el veneno.

Medición final: Godot 4.7.2, GL Compatibility, RTX 3060, **1920×1080**, paso
1/60, VSync y límite de FPS apagados sólo para medir. Cada perfil corre solo,
sin bots ni pruebas headless simultáneas. El editor del usuario seguía abierto;
no se cerraron sus sesiones ni se controlan las demás aplicaciones del equipo.
Se excluyen arranque y preparación inicial de navegación/atlas.

| Feromonas, 500 hormigas | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Sin llamado | 8,39 ms | 11,10 ms | 12,68 ms |
| Cursor / 24 | 8,77 ms | 10,43 ms | 11,94 ms |
| Cursor / 64 | 9,57 ms | 10,95 ms | 11,80 ms |
| Sobre muebles / 64 | 9,54 ms | 10,79 ms | 12,87 ms |
| Suelo sin objetivo / 64 | 8,88 ms | 10,03 ms | 17,33 ms |
| Objetivo agotado / 64 | 9,88 ms | 11,85 ms | 16,69 ms |

Registro: `.godot/qa/perfil_expansion_feromonas_final.log`.

| Logística por destino, 500 hormigas | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Casa | 8,96 ms | 10,83 ms | 13,51 ms |
| Restaurante | 8,48 ms | 11,13 ms | 14,07 ms |
| Museo | 8,26 ms | 10,58 ms | 13,23 ms |
| Obelisco | 7,36 ms | 9,93 ms | 12,58 ms |
| Coliseo | 7,26 ms | 9,44 ms | 15,21 ms |
| Eiffel | 8,30 ms | 10,64 ms | 17,76 ms |

En todos, seis entradas y máximo de seis rutas/cuadro. Como en mediciones
anteriores, el reloj de Run está desactivado: no mide el cierre ni limpieza.
Registro: `.godot/qa/perfil_expansion_logistica_final.log`.

`perfil_periferia.tscn` agrega un estrés diferente, no comparable directamente
al perfil de feromonas anterior: seis castas con daño/carga/olfato mejorados,
500 IA activas y 250 ubicadas inicialmente fuera del interior antiguo. Colonia
mantiene su escala y visibilidad normales, no desactiva su `_process` como el
perfil anterior. La cámara muestra todo el plano en H. Cada fase descarta 200
cuadros y mide 360; las hormigas siguen moviéndose entre ambas fases.

| Destino | H sin llamado: media / p95 / peor | H llamado móvil: media / p95 / peor |
|---|---:|---:|
| Casa | 12,11 / 16,49 / 26,60 ms | 10,55 / 12,28 / 14,18 ms |
| Restaurante | 11,86 / 15,86 / 19,95 ms | 10,18 / 12,90 / 15,33 ms |
| Museo | 10,08 / 12,90 / 14,63 ms | 9,67 / 12,25 / 13,57 ms |
| Obelisco | 9,67 / 12,04 / 14,06 ms | 8,85 / 11,12 / 12,85 ms |
| Coliseo | 8,32 / 10,55 / 20,12 ms | 8,35 / 11,14 / 16,14 ms |
| Eiffel | 8,97 / 11,12 / 14,93 ms | 8,64 / 10,87 / 12,98 ms |

Todas las fases conservaron 500 IA activas, cuota máxima de seis rutas y
64 seleccionadas como máximo al llamar. El perfil informa distribuciones al
cierre y topes de efectos; las fases no tienen idénticas posiciones ni recursos.
Registro: `.godot/qa/perfil_expansion_periferia_final.log`.

**No es una garantía de 60 FPS constantes**: en el estrés extremo hubo cuadros
de 26,60 ms. Los ahorros de código tienen contadores/regresiones específicos;
las diferencias entre pasadas no permiten atribuir cada milisegundo a ellos.
Siguen pendientes GPU integrada, expediciones largas y juego humano.

`revision_periferia` pasa 21 verificaciones con renderer: seis destinos, H
completo en Full HD, zoom/arrastre extremos y ventanas 1000×620 / 2560×1080.
Capturas `.godot/qa/periferia_*.png`. La prueba lógica de cámara también cubre
viewport vertical. Ninguna prueba escribe la partida personal.

Regresión definitiva después de los ahorros y del límite del llamado:
**34 suites / 1.345 verificaciones OK, cero fallas y cero errores de script**.
Incluye Cámara 222, Periferia 58, Economía 29, Geometría/veneno 34 y Controles
24. Las suites se ejecutaron headless secuencialmente, nunca durante los perfiles.
Registros: `.godot/qa/expansion_definitiva_prueba_*.log`.

## Mordiscos y cargas del mismo material — 29/10/2026 (histórico)

Esta sección mide el intento anterior de 64 frentes. No valida las porciones
limitadas implementadas el 30/10 ni su nuevo ritmo: una franja grande podía
desaparecer mientras la carga se mostraba miniaturizada. Los resultados nuevos
se documentan aparte después de comprobar la máscara fina y el contacto.

Godot 4.7.2, GL Compatibility, RTX 3060, **1920×1080**, VSync y límite de
FPS desactivados, paso fijo 1/60. Cada perfil se ejecutó solo, sin bots ni
otras suites simultáneas. Son mediciones del balance nuevo, no un A/B de
costo aislado contra las tablas anteriores.

| Perfil general | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Casa, 5 hormigas | 2,20 ms | 2,36 ms | 3,01 ms |
| Casa, 150 hormigas | 3,60 ms | 4,22 ms | 5,58 ms |
| Casa, 500 hormigas | 6,12 ms | 7,52 ms | 9,20 ms |
| Demolición, 500 hormigas | 8,95 ms | 10,95 ms | 11,64 ms |
| Evoluciones, 500 hormigas | 7,91 ms | 9,49 ms | 10,99 ms |

| Feromonas, 500 hormigas | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Sin llamado | 7,14 ms | 9,34 ms | 11,43 ms |
| Cursor / 24 | 7,81 ms | 9,19 ms | 9,79 ms |
| Cursor / 64 | 8,19 ms | 9,34 ms | 10,54 ms |
| Sobre muebles / 64 | 8,11 ms | 9,73 ms | 10,77 ms |
| Suelo sin objetivo / 64 | 7,62 ms | 8,95 ms | 9,53 ms |
| Objetivo agotado / 64 | 7,88 ms | 9,34 ms | 11,25 ms |

Registros: `.godot/qa/perfil_bocados_general_final.log` y
`.godot/qa/perfil_bocados_feromonas_final.log`. El atlas sigue en **2048×5504,
43 MiB**; la muestra de pared entra en el mismo recurso. En el cierre del
perfil general quedaron 33/64 montones, 141/600 partículas y 25/40 textos.

La pieza conserva hasta 16 celdas físicas y suma cuatro frentes visuales por
celda, hasta 64 rectángulos decrecientes. El shader consulta uno, sin bucles
por píxel. Sólo se suben máscaras sucias a 12,5 Hz; los alimentos crean el
estado al primer bocado. No se recalcula A* por cada astilla visual.

Las cargas son regiones del atlas original, por valor: no leen la GPU ni
crean texturas, nodos o tweens por mordisco. Se reutiliza el Sprite2D de carga
y hasta dos muestras más en el CanvasItem de la hormiga. El límite de tres
es visual, no limita el buche ni descarta dinero. El transporte y el reparto
65/35 se comprueban por separado de las muestras.

`revision_mordiscos.tscn` prueba con el renderer la monotonía alfa entre
ataques opuestos (ningún píxel reaparece), el recorte de una comida rotada,
el retazo del mueble, la fuente liberada y la limpieza al descargar. También
guarda capturas Full HD `bocados_*.png`. No sustituye observar una sesión
humana ni garantiza estos tiempos en una GPU integrada o cualquier partida.

La revisión adicional de siluetas cubre **108 bocados iniciales** (27 alimentos,
cuatro lados): sus retazos contienen material opaco, también en baguettes,
medialunas y formas con huecos. Para no cortar el aire del cuadrado del sprite,
se prepara una caché de hasta 64 cajas ocupadas por tipo de comida. Se lee el
atlas **una sola vez al arrancar**, nunca al morder: en la revisión local costó
12,55 ms de lectura y 125,03 ms de CPU para 535.776 píxeles. La copia temporal
de 43 MiB se libera al finalizar; la caché conserva rectángulos, no imágenes.
Headless usa la geometría rectangular de respaldo y conserva el mismo daño,
valor y transporte. Las tablas gráficas de esta sección ya incluyen la caché.

Regresión final: **37 suites / 1.445 verificaciones, cero fallas, errores o
advertencias**. Incluye 42 de recortes y conservación, 14 del arranque individual
y 15 de primera madera. Esta última conserva las mediciones desde la señal de
destrucción, antes de liberar el objeto; otras tres repeticiones también pasaron.
Registros: `.godot/qa/definitiva_lectura_prueba_*.log`.

## Porciones locales, contacto y máscara fina — 30/10/2026

Godot 4.7.2, GL Compatibility, NVIDIA RTX 3060, **1920×1080**. Perfiles
ejecutados en serie, sin otros tests ni bots simultáneos, con VSync y límite
de FPS desactivados sólo para medir. `--fixed-fps 60` fija el paso de simulación
en 1/60 s, no fuerza cuadros de 16,67 ms: la tabla mide tiempo real de cuadro.
Guardado personal desactivado. Atlas y preparación inicial de navegación
quedan fuera de la muestra; el reloj normal de Run también está desactivado,
por lo que no mide duración de expediciones, limpieza ni cierre.

| Perfil general | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Casa, 5 hormigas | 2,55 ms | 3,07 ms | 5,12 ms |
| Casa, 150 hormigas | 3,95 ms | 4,68 ms | 5,56 ms |
| Casa, 500 hormigas | 7,00 ms | 8,47 ms | 12,19 ms |
| Demolición, 500 hormigas | 11,54 ms | 15,58 ms | 21,02 ms |
| Continuación con evoluciones, 500 hormigas | 12,57 ms | 17,42 ms | 23,80 ms |

Registro: `.godot/qa/porciones_poda_perfil_rendimiento.log`. Cada fase descarta
60 cuadros y mide 300, semilla 171. Evoluciones continúa después de demolición:
cambia el trabajo y el material disponible; no es una comparación aislada del
costo de activar habilidades. Al cierre quedaron 8/64 montones, 70/600
partículas y 18/40 textos, sin quitar los topes de producción.

| Feromonas, 500 hormigas | Media | p95 | Peor cuadro |
|---|---:|---:|---:|
| Sin llamado | 8,57 ms | 11,55 ms | 13,87 ms |
| Cursor / 24 | 9,48 ms | 12,33 ms | 14,65 ms |
| Cursor / 64 | 9,13 ms | 11,13 ms | 13,10 ms |
| Sobre muebles / 64 | 9,21 ms | 11,02 ms | 12,84 ms |
| Suelo sin objetivo / 64 | 9,18 ms | 11,26 ms | 12,92 ms |
| Objetivo agotado / 64 | 9,91 ms | 12,27 ms | 15,94 ms |

Registro: `.godot/qa/porciones_poda_perfil_feromonas.log`, semilla 417. Las
cuatro primeras fases usan 240 cuadros, 40 de preparación y 200 medidos;
las dos fases finales conservan su fixture específico. Son fases consecutivas,
no las mismas posiciones y recursos por cuadro ni un control contra el 29/10.

**El estrés de 500 hormigas con evoluciones supera el presupuesto de 60 FPS
en p95: 17,42 ms frente a 16,67 ms, con un peor cuadro de 23,80 ms.** También
hay picos de 21,02 ms en demolición. Estas muestras no garantizan 60 FPS
constantes ni ausencia de tirones, tampoco en esta GPU. No validan GPU
integrada, hardware más modesto, campaña tardía ni sesiones prolongadas.
Las franjas de 64 frentes del 29/10 son históricas, no un A/B que permita
atribuir las diferencias sólo a la máscara o a la poda del contacto.

### Costos y límites del material nuevo

El atlas sigue compartido en **2048×5504 / 43 MiB RGBA8**. Ahora se suma una
máscara R8 fina por recurso que recibió mordidas, creada de forma diferida:
los intactos no reservan esa máscara. No es una textura por bocado ni por
hormiga. Los 43 MiB no incluyen las máscaras, las imágenes/índices de CPU,
otras texturas, fuentes ni memoria del renderer; no describen la RAM/VRAM total.

Microprueba de configuración de máscara, registrada aparte en
`.godot/qa/porciones_final_medir_mascara_material.log`:

| Caso | Resolución R8 | Buffer R8 | Configuración CPU |
|---|---:|---:|---:|
| Cartón, 110×130 | 56×68 | 3.808 bytes | 0,187 ms |
| Torre, 1550×2100 | 776×1052 | 816.352 bytes | 7,485 ms |
| Caso artificial máximo, 4096×4096 | 2048×2048 | 4.194.304 bytes | 15,870 ms |

El límite de **4 MiB es sólo el buffer R8 por objeto**, no toda su memoria:
también existen `Image`, índices/contadores de CPU y la textura de GPU cuando
se renderiza. El costo se acumula con la cantidad y el tamaño de recursos
mordidos. Son tiempos puntuales de inicialización, no FPS ni un máximo duro
de cuadro; la primera máscara grande puede causar un pico fuera del intervalo
gráfico preparado. No se presenta el caso artificial como un mueble habitual.

El material conserva hasta 16 celdas lógicas. La búsqueda exacta del contacto
poda por distancia celdas/bloques que no pueden mejorar el resultado, en vez
de repetir 16 recorridos completos del árbol por mordida. La máscara pierde
material de forma irreversible y se actualiza sólo si está sucia, hasta
12,5 Hz. Las envolventes físicas se sincronizan por lotes de 0,12 s; la
navegación sigue siendo conservadora entre sincronizaciones, no física por
cada astilla. Continúan la cuota de seis rutas por cuadro y el corte blando
de 1,2 ms; un A* ya iniciado no se puede interrumpir.

### Revisión del renderer y pendientes

`.godot/qa/porciones_poda_revision_mordiscos.log` terminó con código 0 y
**13 verificaciones OK**. Una de ellas agrupa los **108 bocados iniciales**
del catálogo (27 alimentos desde cuatro lados). Se verifica monotonía de
los píxeles reales en GPU, hueco y
retazo con el mismo tamaño, daño extremo limitado a una porción de hasta 6×6,
persistencia de más del 99% del cartón tras un viaje, fuente liberada y
descarga sin muestra fantasma. Es QA acotada del renderer, no un playtest.

Pendientes: reducir picos del estrés de 500 con evoluciones, medir en GPU
integrada/PC modesta y observar sesiones humanas largas, incluyendo el primer
ahorro y el viaje completo de cada retazo. El inicio autónomo/guiado y la
regresión lógica se documentan por separado; no se deducen de estos FPS.

### Regresión lógica final

La pasada secuencial de `porciones_definitivas_prueba_*.log` completó las
**38 suites y 1.604 verificaciones**, todas con código 0 y sin fallas ni errores
de script. El menú dejó un aviso al salir por un clic de su fixture después de
reactivar sonido al probar idiomas, no por máscaras R8. La fixture restablece
el silencio y dos repeticiones con `--verbose` terminaron **56/56**, sin avisos
ni fugas (`menu_limpieza_verbose3.log` y `menu_limpieza_verbose4.log`). No se
cambió audio de producción ni el guardado del jugador para hacer pasar la prueba.

## Cuerpo, sombra y contacto exterior — 30/10/2026

### Cambios y costo retenido

Los 59 acabados/orientaciones comparten metadatos de cuerpo opaco prehorneado:
3.272 rectángulos RLE finos en `datos/siluetas_muebles.json` (unos 170 KB en
JSON compacto). No se lee el atlas de GPU para decidir el daño ni el valor.
La navegación conserva hasta 16 bandas; una banda puede tener varios vanos.
El dibujo de autoría usa `perfil_base`, nunca su propia máscara derivada:
regenerar metadatos no va deformando el arte en cada arranque.

Una segunda pasada GPU de arranque elimina sólo la transparencia exterior del
sprite compuesto. Hay transitoriamente dos atlas de 43 MiB (unos **86 MiB**),
además de otras texturas/memoria; el crudo y los nodos de copia se liberan.
Después queda el mismo atlas **2048×5504 / 43 MiB**, no dos atlas permanentes.
La sombra del mobiliario se proyecta con la misma máscara dentro de su dibujo,
sin nodos, texturas o físicas por bocado. Las primitivas de barras/anillos se
distinguen en vértices por su transformación UV, no por el tamaño de `TEXTURE`:
Godot puede conservar el atlas enlazado para una primitiva sin textura.

El material exige aire conectado al exterior y primer contacto sobre el
segmento; ni una voladora dentro del cuerpo ni un hueco cerrado producen carga.
Veneno avanza desde su origen, sin el atajo letal de eventos/derrumbes. El aire y
la frontera se retienen por bloques 8×8 y bits; sólo se propagan aperturas nuevas.
El nearest prueba primero el píxel proyectado y poda por distancia; veneno
reutiliza esa consulta en lugar de recorrer hasta 16 fronteras completas.

Las máscaras se preparan al necesitar contacto preciso o extracción, no para
todo el mapa al cargar; elegir un puesto puede prepararlas antes de morder.
El máximo de 4 MiB sigue siendo **sólo el buffer R8 por objeto**. Ahora también
hay índices de aire/frontera y sus árboles, además de las imágenes, contadores
y textura GPU: no equivale a toda la memoria del objeto ni del juego.

Microprueba final `.godot/qa/cuerpo_definitivo_mascara.log`, sin renderer:

| Caso denso artificial | Buffer R8 | Preparación CPU | 1.000 intentos / cortes reales / CPU |
|---|---:|---:|---:|
| 110×130 | 3.808 B | 0,445 ms | 145 cortes / 31,231 ms |
| 1550×2100 | 816.352 B | 11,268 ms | 63 cortes / 58,344 ms |
| 4096×4096 | 4.194.304 B | 24,827 ms | 63 cortes / 112,527 ms |

Son intentos desde el exterior global de celdas de una grilla densa, no mil
bocados exitosos: las celdas interiores inaccesibles no se perforan. No es FPS,
no usa el RLE real de Eiffel y no se compara directamente con el microbenchmark
anterior que permitía bocas interiores. La preparación máxima puede causar un
pico; no se presenta el caso artificial como mueble habitual.

### Renderer real, Full HD

Godot 4.7.2, GL Compatibility, RTX 3060, 1920×1080, VSync desactivado.
Ejecuciones seriales, sin otros Godot ni procesos de QA a la vez.
Registro: `.godot/qa/cuerpo_perfil_rendimiento_optimizado.log`.

| Escenario | Media | p95 | Peor |
|---|---:|---:|---:|
| Casa, 5 hormigas | 2,16 ms | 2,35 ms | 2,67 ms |
| Casa, 150 | 2,89 ms | 3,38 ms | 4,24 ms |
| Casa, 500 | 4,52 ms | 5,62 ms | 6,91 ms |
| Demolición, 500 | 7,22 ms | 9,70 ms | 14,80 ms |
| Evoluciones, 500 | 14,48 ms | 21,22 ms | 36,80 ms |

La primera medición de ESTA corrección, antes de podar consultas, dio
16,14 / 26,11 / 62,57 ms con evoluciones. La instrumentación temporal señaló
consultas de borde y erosión; se retiró antes de medir el cierre. El mundo y el
tiempo simulado evolucionan durante cada fase: estas cifras no son un control
A/B del juego anterior, ni prueban 60 FPS constantes. **El estrés de 500 con
todas las evoluciones sigue superando 16,67 ms**; reducir esos picos y medir en
GPU integrada/PC modesta quedan pendientes.

Feromonas final, `.godot/qa/cuerpo_definitivo_feromonas.log`, también en serie:

| Fase, 500 hormigas | Media | p95 | Peor |
|---|---:|---:|---:|
| Sin llamado | 7,49 ms | 10,49 ms | 13,37 ms |
| Cursor, 24 seleccionadas | 7,76 ms | 10,20 ms | 12,32 ms |
| Cursor máximo, 64 | 8,63 ms | 10,57 ms | 12,69 ms |
| Cursor sobre muebles | 8,78 ms | 13,61 ms | 16,37 ms |
| Suelo sin objetivo, 64 | 7,52 ms | 9,62 ms | 10,58 ms |
| Objetivo agotado, 64 | 7,57 ms | 9,38 ms | 10,92 ms |

También son fases consecutivas de estrés, no una comparación causal entre filas.

### Regresión y revisión gráfica

`cuerpo_definitivo_prueba_*.log`: **39 suites**, todas con código 0 y sin fallas
ni errores de script. La nueva suite `prueba_material_visible` aporta 130
verificaciones: borde conectado, cavidad cerrada, voladora interior→borde→carga,
veneno lateral real y HP/material de todo el catálogo. Se corrigieron fixtures
viejas que colocaban bocas dentro del cuerpo o heredaban recortes de otra pieza;
no se relajó el bloqueo de mordidas interiores.

`cuerpo_definitivo_revision_material_visible.log`: **68 verificaciones OK**,
incluyendo las 59 variantes desde cuatro lados, alpha binaria cuerpo/aire,
coincidencia del retazo con la RLE, PNG originales, barras y círculo primitivos,
y cartón antes / un bocado / 32 bocados. La transparencia propia entre las
patitas es legítima: viaja el mismo fragmento con su alpha, no un rectángulo
de madera inventado ni una sombra gris. Se comprueba opaco↔material y
transparente↔aire; no sólo que la muestra contenga algún píxel visible.

`cuerpo_definitivo_revision_mordiscos.log`: **13 verificaciones OK**, incluyendo
los 108 bocados iniciales de alimentos, monotonía GPU, escala del retazo,
fuente liberada y descarga. Las capturas son QA acotada; sigue pendiente el
playtest humano de lectura y satisfacción durante una sesión larga.

## Proyectos y evoluciones de viaje — 1/11/2026

La ampliación conserva el atlas, los muebles y los límites de población/restos.
Los veinte proyectos son datos y eventos de destrucción: no tienen procesos
por cuadro ni búsquedas añadidas a cada hormiga. El objetivo sugerido conserva
su referencia hasta que termina; el marcador se redibuja al mover cámara,
cambiar objetivo o revelar territorio. La interfaz no reconstruye el catálogo
por depósito. Los checkpoints se agrupan en una llamada diferida por cuadro.

Se agregan dos podas exactas del aire: un bloque completamente sólido no
recibe visitas de aire, y entre bloques vacíos no se intentan marcar píxeles
de frontera. Misma conectividad de cuatro vecinos, semilla, máscara y HP.
Comparación serial headless de 28 objetos reales contra una subclase con el
algoritmo anterior: buffers, bits y árboles idénticos. Torre: preparación
153,34→79,86 ms; arco imperial: 56,36→49,57 ms. **No son FPS**; una preparación
de 80 ms todavía puede producir un tirón al primer contacto. La nueva suite
`prueba_aire_material` verifica aparte aire y frontera contra un flood por píxel,
incluyendo cavidades cerradas y bloques incompletos. Con la comparación del
borrado por bloques suma 30 verificaciones.

### Estrés nuevo y límite detectado

`perfil_proyectos.tscn` usa renderer real, Full HD, VSync desactivado, 500 hormigas
de seis roles, 90 cuadros de preparación y 360 de medición por destino. Es un
**stress artificial**, no un piloto de balance: velocidad 300, capacidad 6 y
daño igual al 0,5% del primer proyecto para ejercitar cortes y restos incluso
en escenarios tardíos. No se fuerzan HP y los eventos se desactivan para
conservar las 500 unidades. Se mantienen hasta seis rutas por cuadro y 64
montones. Los resultados de fases sucesivas no son un A/B causal entre equipos.

La instrumentación puntual encontró el pico mayor en la erosión del veneno,
no en nuevas búsquedas de IA: un daño de 1.175.489 sobre una biblioteca nativa
ejecutó cientos de extracciones de frente y tardó unos 396 ms en una llamada.
También hubo golpes ambientales de vaciado de 46–67 ms. El diagnóstico
temporal se retiró de producción. No se aplicó el atajo de vaciar una celda
por presupuesto letal: saltearía la oclusión y el material de cavidades cerradas.

Se agregó borrado por bloques sólo en rectángulos sólidos de al menos 32
píxeles que el extractor ya eligió. Conserva la misma semilla, orden de cortes,
flood y DDA; no cambia HP, DPS ni carga. Comparación final serial en los 28
objetos, tras cada corte local y de daño alto: estado completo idéntico
(buffer, árboles, aire, frontera, filas/columnas, límites y crédito). El caso
de biblioteca de 360×900 pasó de 374,17 a 324,44 ms **totales** en el barrido
de daño alto por celdas/cuatro orígenes del microbenchmark, no por frame.
Los recortes chicos mantuvieron el costo cercano al anterior. Registro:
`.godot/qa/contenido_batch_reales_final.log`.

Cierre gráfico serial, Godot 4.7.2/GL Compatibility/RTX 3060, 1920×1080,
sin bot ni otras pruebas activas. Registro:
`.godot/qa/contenido_20261101_perfil_final.log`.

| Destino / equipo, 500 hormigas | Media | p95 | Peor |
|---|---:|---:|---:|
| Museo / Sondeo + Barrido | 10,73 ms | 13,54 ms | 358,73 ms |
| Coliseo / Cantera + Contagio | 10,89 ms | 17,96 ms | 192,48 ms |
| Eiffel / Cantera + Puente | 9,76 ms | 13,19 ms | 112,02 ms |

La preparación de la torre sigue cerca de 80 ms y la erosión masiva todavía
produce picos importantes. Queda pendiente reducir búsquedas/propagación de
daño extremo y medir primer contacto en GPU integrada. **La optimización no
eliminó los tirones de este estrés**: las medias/p95 no demuestran ausencia de
picos ni 60 FPS constantes. No extrapolar este daño artificial al rendimiento
habitual, ni usar esa diferencia para ignorar el límite detectado.

### Regresión y lectura

44 suites lógicas completas sin fallas ni errores de script. Cobertura nueva:
catálogo, conservación/persistencia por objeto, migración, checkpoints,
idempotencia de coronas/alijos, contexto de récord y las tres evoluciones.
`revision_proyectos.tscn`: 52 verificaciones en español e inglés, Full HD y
1000×620; cuatro proyectos visibles, hover real respetado y objetivo de cámara
coherente con el HUD. No se carga ni se escribe la partida personal.

## Erosión por servicios y componentes conservados — 1/11, mapa 7

La corrosión deja de ejecutar todo el daño de un tick dentro de una llamada.
`ColaErosion` comparte hasta 32 servicios por cuadro con presupuesto suave de
1 ms; cada servicio retira una sola porción de hasta 16 unidades de lado.
Al cerrar, hasta 128 servicios/4 ms suaves liquidan sólo trabajo ya emitido.
No siguen trabajando las hormigas, el veneno no gana segundos futuros y la
espera se contabiliza en la expedición. Cámara y pausa permanecen disponibles.
La preparación de una máscara sigue indivisible: el presupuesto NO limita el
peor caso de esa primera operación. Medir el máximo, no sólo la media.

La admisión de crédito y el valor extraído son distintos. No se paga trabajo
en espera ni se mezcla con crédito de buche; se conserva el 65/35 ambiental de
muebles y la masa real. Se corrigió también el descuento de crédito de la ruta
síncrona: antes podía descartar el sobrante al saturar una celda con crédito
subpíxel previo. Un tramo sin frente accesible se aparca individualmente, sin
bloquear otros orígenes del recurso ni insistir por cuadro hasta que cambie
la geometría o llegue un tick. Sólo trabajo accesible participa del drenaje;
aparcar no da dinero ni obliga a esperar indefinidamente.

Diagnóstico real: 28 objetos × tres orígenes, máscara y HP iguales después
de cada aplicación; cero diferencias al final. Antes de corregir admisión y
bloqueo por origen había 14 comparaciones divergentes, incluyendo la torre.
Registro `.godot/qa/equivalencia_cola_real_fix2.log`. La suite permanente
`prueba_erosion_presupuestada` pasó 47 verificaciones (masa, tres siluetas reales,
crédito previo, otros orígenes, cierre, pausa, limpieza y referencias liberadas).

Los componentes conservados usan el mismo atlas y como máximo dieciséis bits
por pieza para omitir secciones iniciales; no crean R8 al cargar. Se hornea la
navegación una vez con los mismos huecos. Los recuerdos del hormiguero comparten
una capa retenida que cambia sólo con el historial. El acceso adelantado suma
un punto a la selección al iniciar regreso (máximo ocho contando el centro),
sin otro A* ni búsquedas de proyectos por hormiga/cuadro.

### Cierre medido en GPU real

Godot 4.7.2, GL Compatibility, RTX 3060, 1920×1080, pruebas/bots en serie.
Escena de estrés de 500 hormigas, con daño artificial explícito (no balance ni
FPS habituales). Registro `.godot/qa/componentes_cierre_perfil_proyectos.log`.

| Destino / equipo | Media | p95 | Peor | Peor de la pasada anterior |
|---|---:|---:|---:|---:|
| Museo / Sondeo + Barrido | 10,62 ms | 14,84 ms | 21,73 ms | 358,73 ms |
| Coliseo / Cantera + Contagio | 11,16 ms | 19,81 ms | 60,66 ms | 192,48 ms |
| Eiffel / Cantera + Puente | 10,87 ms | 15,59 ms | 91,44 ms | 112,02 ms |

El costo continuo no desaparece: se reparte entre cuadros. El p95 subió
respecto de la pasada anterior y en Coliseo todavía supera 16,67 ms; **no son
60 FPS constantes**. Los picos mayores ahora coinciden con preparación inicial
de máscaras: arco grande 49,64 ms y torre 80,76 ms sólo de configuración.
Queda pendiente fraccionar esa preparación y medir GPU integrada.

La cola ejecutó como máximo 12/10/9 operaciones por cuadro en estos tres casos,
con operación individual de 0,84/0,75/0,89 ms. Esos máximos NO incluyen máscaras
preparadas por una mordida normal. Al cortar la muestra había 2/1/3 recursos
activos todavía en cola: el trabajo no admitido no se pagó, y esta escena
destruye sus fixtures al terminar. Por eso no se interpreta el perfil como
igual cantidad de daño ya liquidado en el mismo frame; la equivalencia de
material/valor y el drenaje completo se verifican aparte en la suite lógica.

Regresión completa final: 48 suites sin fallas ni errores de script.
Revisión gráfica con renderer real: componentes 46 verificaciones y proyectos
52, además de hormiguero y mordiscos (incluye 108 primeros bocados del catálogo
desde cuatro lados). Capturas de componentes intactos/restaurados, máscara sin
R8 inicial y lectura inglesa también en ventana de 1000×620. Sin tocar el
guardado personal.

## Primer contacto presupuestado y lectura del bocado — 1/11, mapa 8

La limitación indivisible de mapa 7 queda reemplazada por
`PreparadorMordiscos`: una sola cola por Run, hasta 128 unidades / 1 ms suave por
cuadro, con publicación atómica. Reserva nativa de imagen/arrays, raster en
teselas 32×32, árbol y aire exterior se sirven por etapas. Los muebles intactos
siguen sin reservar R8. No se publica material parcial ni se paga crédito
antes de extraerlo. Los fixtures directos eligen explícitamente la referencia
síncrona; gameplay, IA, bots y perfiles mantienen la cola asíncrona.

`prueba_preparacion_mordiscos`: 145 verificaciones, incluyendo 59 acabados,
cavidades, superposiciones, componentes restaurados, máscara 2048, pausa,
weakrefs y cierre real de Run con veneno pendiente. Buffers, árboles, aire,
frontera, masa y resultados de mordidas idénticos a la referencia síncrona.
El cierre sólo termina máscaras de trabajo ya emitido, cancela precalentados
sin trabajo y no congela cámara/UI ni regala tiempo de extracción.

### Primer contacto aislado, sin hormigas

Godot 4.7.2, GL Compatibility, RTX 3060, Full HD, VSync apagado. Perfil
`perfil_preparacion_mordiscos.tscn`, log
`.godot/qa/preparacion_perfil_grandes_final.log`:

| Objeto real | Configuración síncrona | Solicitud async | Cuadros / latencia real | Peor cuadro async | CPU total de preparación |
|---|---:|---:|---:|---:|---:|
| Arco 1300×700 | 50,38 ms | 0,074 ms | 91 / 179,48 ms | 2,62 ms | 65,47 ms |
| Torre 1550×2100 | 81,42 ms | 0,106 ms | 131 / 284,05 ms | 3,38 ms | 102,53 ms |

El servicio compartido máximo fue 1,057/1,065 ms y la publicación 0,083/0,125 ms.
Es una mejora del bloqueo, no menos trabajo total: la CPU de preparación subió
aproximadamente 27–30% en este aislado. No confundir los 179/284 ms sin VSync con
latencia a 60 Hz: 91/131 cuadros equivalen a 1,52/2,18 s a esa frecuencia si se sirve
la misma cantidad por cuadro. Se solicita al elegir un frente para aprovechar
el viaje; si todavía falta, la hormiga espera sin perder su reserva/reloj.
Las asignaciones/subidas nativas son indivisibles: el presupuesto no es un
techo absoluto ni esta escena demuestra FPS con 500 hormigas.

### Estrés con 500 hormigas y paso fijo 1/60

Misma GPU/Full HD, escenas en serie, daño artificial declarado. 360 cuadros
medidos después de 90 de calentamiento. Ejecución explícita con
`--fixed-fps 60`: simula la misma duración aunque el render sea más rápido.
Log `.godot/qa/contacto_perfil_proyectos_paso_fijo.log`:

| Destino / equipo | Media | p95 | Peor | Máscaras completas / pendientes |
|---|---:|---:|---:|---:|
| Museo / Sondeo+Barrido | 11,00 ms | 14,84 ms | 17,92 ms | 126 / 0 |
| Coliseo / Cantera+Contagio | 9,52 ms | 13,13 ms | 21,15 ms | 131 / 11 |
| Eiffel / Cantera+Puente | 10,27 ms | 14,25 ms | 17,42 ms | 137 / 0 |

Se mantiene el máximo de 6 rutas/cuadro y 64 montones; hubo 5/5/8 montones activos.
Servicio máximo de preparación 1,201/1,104/1,088 ms; publicación máxima
0,476/0,103/0,078 ms. Erosión: 10/32/11 operaciones por cuadro y 0,92/0,78/0,51 ms
de operación individual máxima. Al cortar quedaban 2/0/5 recursos de erosión
activos; no se pagó su trabajo no admitido. El log registra emisión/admisión
y máscaras pendientes para no presentar menos actividad como más eficiencia.

No es un A/B exacto contra la tabla histórica sin paso fijo ni una garantía
de 60 FPS: todavía hay cuadros de 17–21 ms y falta GPU integrada. La preparación
aislada contrasta la misma geometría y la suite lógica prueba equivalencia;
el estrés muestra el costo integrado de esta configuración concreta.

Las poses reutilizan el tick visual a 12 Hz, hasta tres retazos del mismo atlas y
cero nodos por astilla. Los dos retazos secundarios se redibujan sólo durante
el levantado de 0,18 s y su asiento. Sonidos de material comparten una puerta
global de 0,18 s, se descartan fuera de cámara y en colonias lejanas; UI/entrega
conservan sus puertas. Los tres envoltorios suman sólo tres regiones pequeñas
al atlas, sin lecturas GPU para decidir masa o dinero.

Revisión con renderer real: secuencia de cartón/madera/los tres envoltorios,
componentes 46 verificaciones, material visible 68 y mordiscos 13 (incluye 108
bocados/lados del catálogo), sin fallas. Las capturas y seis WAV están en QA.

Regresión final: 52 suites sin fallas ni errores de script. Arte de hallazgos
118 verificaciones, integración/robo completo 35 y sensación 35. El retiro por
aspiradora/rata no prepara una máscara para un objeto que levanta entero;
conserva sólo el valor todavía presente y no duplica masa, bonus ni botín.

## Residuos de alimentos y sombra desde el material — 2/11

La revisión reprodujo líneas y sombras incluso con una máscara corporal vacía:
el quad del alimento tiene cinco unidades de padding y el shader anterior
dejaba pasar lo que caía fuera de ±radio. Además, las grietas independientes
podían dibujarse sobre huecos transparentes. Ahora el quad completo recorta
cuerpo/sombra; el cuerpo usa alfa material ≥0,55 y la sombra se proyecta desde
ese mismo material restante. No se dibujan grietas artificiales cuando existe
la máscara física. Barras e indicadores conservan su pasada sin recorte.

Intacto y preparado usan la misma presentación para evitar saltos al primer
contacto. Son 30 materiales/texturas R8 **compartidos por tipo**, no por objeto:
34.229 bytes R8 en total, más los recursos del renderer. Construcción medida
en 28,63–30,41 ms una sola vez durante el arranque del atlas. Los helpers CPU
se descartan; las máscaras físicas mutables siguen preparándose bajo demanda
y por la cola de la Run. No hay lecturas GPU, nodos nuevos por comida ni
escaneos por hormiga agregados durante el juego. El recorte inicial también
ajusta los pequeños salientes del arte que excedían su dominio físico; no
es una conservación píxel a píxel del dibujo crudo anterior.

Se corrigieron detalles de autoría: una semilla fuera de la frutilla y círculos
fuera del triángulo del queso. Se reexportaron sólo esas dos siluetas; las otras
25 quedan idénticas. No se cambian HP totales, recompensas, daño, IA ni precios.
No se borra el último material ni se acredita trabajo para esconder residuos.

`revision_residuos_comida.tscn`: 341 verificaciones con renderer real. Treinta
tipos, rotaciones 0 y 0,37, intacto/preparado, desgaste parcial y vaciado de R8
con el nodo todavía vivo. Los 60 vaciados dejan alfa **estrictamente cero** en
todo el visor, incluidos márgenes. Se contrasta cada píxel parcial con atlas
bilinear y material R8 nearest, con tolerancia de transformación de sólo
0,002048 píxeles de imagen y un nivel RGBA8 de alfa; no hay cupo de píxeles
huérfanos permitido. También cubre independencia de máscaras privadas,
inmutabilidad del cache compartido, callback tardío, barras/veneno y un único
cuerpo opaco conectado a ocho vecinos en los 27 alimentos intactos.
Capturas y log: `.godot/qa/residuos_comida_despues.png`,
`residuos_frutilla_intacto_preparado_despues.png`,
`residuos_bombon_intacto_preparado_despues.png` y
`residuos_gpu_fuentes_final.log`. La línea de base quedó en
`residuos_comida_antes.png`: el mismo vaciado conservaba trazos en 47 de 60 casos.

### Estrés integrado, no garantía de FPS

Godot 4.7.2, GL Compatibility, RTX 3060, 1920×1080, 500 hormigas,
`perfil_proyectos.tscn --fixed-fps 60`, 90 cuadros de calentamiento y 360 medidos.
Log `.godot/qa/residuos_perfil_proyectos.log`:

| Destino / equipo | Media | p95 | Peor | Dibujos medios | Máscaras completas / pendientes |
|---|---:|---:|---:|---:|---:|
| Museo / Sondeo+Barrido | 10,78 ms | 15,27 ms | 22,56 ms | 959 | 127 / 0 |
| Coliseo / Cantera+Contagio | 8,97 ms | 12,60 ms | 22,24 ms | 834 | 132 / 9 |
| Eiffel / Cantera+Puente | 10,65 ms | 14,80 ms | 16,97 ms | 909 | 134 / 3 |

Mismos caps: seis rutas/cuadro y 64 montones (8/5/10 activos). Erosión: 12/32/12
operaciones máximas, servicio individual máximo 0,80/0,70/0,56 ms. Preparación:
servicio máximo 1,071/1,114/1,119 ms. Quedaban 2/0/4 recursos de erosión activos
al cortar la muestra; el log incluye trabajo emitido/admitido para no presentar
menos trabajo liquidado como una mejora. Es una repetición integrada, no A/B
exacto ni demostración en GPU integrada. Hay cuadros de más de 16,67 ms.
La pequeña corrección posterior de semillas/agujeros no cambia esos caps.

Revisión gráfica de material visible (68) y mordiscos (13, incluidos 108
primeros bocados/lados), sin fallas después de corregir las dos siluetas.
Regresión completa posterior a la reexportación: 52 suites headless sin fallas,
errores de script ni advertencias. Guardado y configuración personal intactos.

## Controles activos, microbocados y feedback — 2/11/2026

Se elimina la escala compensada de hormigas al alejar la cámara. Se conserva
el descarte por cámara y el detalle visual espaciado, no la escala artificial.
El área de feromonas comparte candidatas cada 0,2 s: no se hace un escaneo de
todo el mapa por cada hormiga. El frente exacto y A* siguen usando sus colas.

Aprender materiales permite hasta 1/2/3 porciones por ciclo. Sólo la primera
admite daño; las otras gastan crédito del mismo frente, revalidando alcance,
capacidad y material real. Cada muestra sigue limitada a 6×6, sin lectura GPU
ni nuevos nodos por astilla. Es una mejora intencional del flujo tardío, no una
reducción de la resistencia de los objetos ni una comparación de igual ingreso.

El vuelo al contador reutiliza 40 registros desde un solo Control. Cien tandas
no crean nodos/tweens por miga; el procesamiento vacío se apaga. El feedback
mundial comparte topes de 600 partículas, 24 ondas y puertas de emisión.
Audio: 16 voces fijas, seis reservadas a UI/hitos; ver
[criterios y límites de la investigación](../docs/AUDIO_Y_SENSACION.md).
El azar de audio/presentación no consume el de IA. Se retiran el shader de
franjas no referenciado, sus buffers/uniforms antiguos, dioramas y métodos
exclusivos del drenaje de cierre eliminado; no se borran guardados ni fixtures.

### Estrés con cinco accesos elegidos y 500 hormigas

Godot 4.7.2, GL Compatibility, RTX 3060, 1920×1080, VSync apagado,
`perfil_proyectos.tscn --fixed-fps 60`, 90 cuadros de calentamiento y 360 medidos.
El fixture coloca los cinco accesos comprados mediante la misma API manual y
validación de piso del juego, antes de medir. Busca puntos distribuidos una
sola vez; esa búsqueda sintética no existe en gameplay. Daño artificial de
estrés declarado; no es una medición de duración de campaña.
Log: `.godot/qa/activa_perfil_accesos5.log`.

| Destino / equipo | Media | p95 | Peor | Dibujos medios | Máscaras completas / pendientes |
|---|---:|---:|---:|---:|---:|
| Museo / Sondeo+Barrido | 9,48 ms | 12,44 ms | 13,80 ms | 719 | 96 / 0 |
| Coliseo / Cantera+Contagio | 8,12 ms | 11,31 ms | 13,32 ms | 666 | 96 / 6 |
| Eiffel / Cantera+Puente | 10,06 ms | 14,41 ms | 17,25 ms | 724 | 118 / 1 |

Topes observados: seis rutas/cuadro; 2/4/5 montones activos de un máximo 64.
Erosión: 8/11/12 operaciones máximas por cuadro, 0,61/0,35/0,58 ms de operación
individual máxima, 2/0/0 recursos pendientes. Preparación: servicio máximo
1,094/1,113/1,094 ms. El log conserva trabajo emitido/admitido e ingresos reales;
el silbato descarta lo todavía no retirado, no liquida daños después del cierre.

Las posiciones de accesos y el orden de trabajo difieren del sistema automático
anterior. No corresponde atribuir toda diferencia de tiempo sólo a optimización,
ni ocultar trabajo pendiente. Aún hubo un cuadro de 17,25 ms: no garantiza 60 FPS
constantes, campaña completa ni rendimiento en GPU integrada.

### Revisión de presentación y entrada real

Pruebas con renderer real a 1920×1080 y 1000×620. La revisión de entrada usa
eventos reales de teclado/mouse: N, clic inválido, cancelación, clic exacto en
piso libre, no ataque/feromona accidental, E con feedback y Esc de pausa.
`revision_input_poderes`: 26 verificaciones sin fallas. Las coordenadas del
clic se toman del evento, no de una posición global de mouse potencialmente
vieja. Capturas de hormiguero y controles en `.godot/qa/activa_*.png`.

`revision_residuos_comida`: 341 verificaciones; `revision_material_visible`: 68;
`revision_mordiscos`: 13, que incluye 108 primeros bocados/lados. Sin fallas,
incluidos 60 vaciados de material con alfa estrictamente cero. Las barras
físicas ya no se dibujan; la inspección usa un porcentaje gris discreto.

### Cursor sostenido y en movimiento

Misma GPU/paso fijo, 500 hormigas, `perfil_feromonas.tscn`; 40 cuadros de
calentamiento y 200 medidos por fase. Log
`.godot/qa/cierre_perfil_feromonas.log`. Son fases consecutivas: el mundo y la
carga evolucionan, no es A/B contra cada fila anterior.

| Fase | Seleccionadas al final | Media | p95 | Peor |
|---|---:|---:|---:|---:|
| Sin llamado | 0 | 8,12 ms | 11,08 ms | 13,18 ms |
| Cursor de 24 | 24 | 8,32 ms | 10,44 ms | 14,05 ms |
| Máximo comprable | 63 | 9,63 ms | 11,79 ms | 16,66 ms |
| Sobre muebles | 63 | 9,75 ms | 13,63 ms | 16,89 ms |
| Suelo sin objetivo, estrés técnico 64 | 64 | 8,23 ms | 9,92 ms | 11,64 ms |
| Objetivo agotado sin soltar, estrés técnico 64 | 64 | 8,86 ms | 11,42 ms | 17,90 ms |

Las dos últimas fases fijan explícitamente el límite técnico 64 en la caché
del fixture: el máximo comprable normal sigue siendo 63, no se cambian los CSV.
Conservan orden y 500 hormigas activas. El fixture anterior exigía 64 aunque
sus niveles daban 63; se corrigió su preparación, no se rebajó la verificación.

### Pilotos de ritmo, no duración humana

`bot_balance.tscn --headless --fixed-fps 60`, órdenes materiales, ingresos reales,
sin calibración ni daño manual. Sólo escriben estados nuevos dentro de QA.
Seis expediciones desde cero: 4,91 min de simulación incluyendo retirada y sin
tienda; una obrera inicial, segunda comprada tras la tercera, dos en la sexta.
Log/salida: `.godot/qa/activa_inicio_sin_calibrar_v9.txt` y su JSON homónimo.
No alcanzan la primera dieta y no validan toda la progresión temprana.

Una expedición avanzada retoma **sólo como entrada** el snapshot QA histórico
`componentes_piloto_restaurante_20261101.json` (min 87,23 de aquella simulación,
no campaña actual desde cero). Completa 3,27 min adicionales con dieta 3 y 500
unidades máximas: 105 partes consumidas, cero cargas sin entregar y final por
tiempo. Ingresos incluyendo bonus: comida 4.378,78M, muebles 87,72M,
estructura 1.525,30M; la suma no es sólo valor de objetos ni una tasa comparable
al inicio. El bot decide fundar después de esa run; no prueba otra expedición
de la siguiente colonia. Salida separada: `activa_tardia_sin_calibrar_v9.json/.txt`.

Ambos resultados corresponden al origen enemigo corregido: robar el último
material no paga bonus al jugador. La batería completa final pasó 57 suites
sin fallas, errores de script ni advertencias. Se repitieron después las
revisiones gráficas de entrada real (26), interfaz (sin fallas) y residuos (341).
Los flags opcionales del bot se activan por existencia, incluso vacíos: estos
pilotos verificaron su ausencia antes de lanzar. La tanda `_verificado_` que
los definía vacíos activó calibración y se descartó, no se usa en estos números.

Estos recorridos comprueban ingreso, transporte y avance reales en dos
configuraciones; no prueban satisfacción ni estiman horas de una persona.
Los FPS sólo se midieron con renderer real en los perfiles anteriores.

### Entradas conservadas y fundación visible — 2/11/2026

El layout completo de entradas se conserva aunque una nueva colonia tenga
menos cupos. Las posiciones pendientes sólo se reconsideran cuando cambia
la geometría, el territorio o la capacidad, dentro de la actualización existente
de 2 Hz. No se agrega un recorrido del mapa por cuadro.

Al levantar una entrada, un único recorrido de la colonia reasigna sólo sus
retornos. Conserva carga, origen y retazos; invalida la ruta vieja, pero no
ejecuta A* inmediatamente ni duplica un ticket ya en espera. La ruta nueva
usa la misma cola y el límite existente de seis consultas por cuadro.

Son correcciones de estado y navegación, no una nueva medición de FPS ni
un cambio de economía. Las pruebas específicas cubren seis entradas guardadas
con un cupo después de fundar, la siguiente expedición y una entrega única
después de retirar el acceso que tenía una ruta ya en cola.

Verificación: 57 suites lógicas sin fallas, errores de script ni advertencias.
La nueva suite de fundación tiene 32 verificaciones e incluye la transición
de seis a siete fundaciones, hover sintético y cancelación real del foco.
Revisiones con renderer real: reina e interfaz sin fallas; controles de poderes,
26 verificaciones a 1920×1080 y 1000×620. Logs de cierre
`arreglos_final_*.log` en `.godot/qa/`; controles en
`correcciones_revision_input_poderes.log`. El guardado personal no se escribe.

## Estímulos y encuentros activos — 4/11/2026

Godot 4.7.2, GL Compatibility, Windows, RTX 3060, 1920×1080, VSync desactivado.
`perfil_estimulos.tscn`: semilla 827, paso 1/60 y tiempo ×1, 500 hormigas reales
con castas mixtas, cinco entradas legales, visibilidad, IA, navegación,
preparación y erosión activas. Fuerza/velocidad de estrés declaradas en el
fixture: no representa un equipo comprado ni una duración de campaña.
Cada caso tiene 40 cuadros de calentamiento y 600 medidos.

Control mantiene los efectos naturales. Completo agrega demanda visual
sintética mediante las APIs normales y cuatro amenazas reales, incluidas
avispa/rival. Si no hubo restos naturales, una sola pila de seis migas habilita
el encuentro de saqueo: se informa por separado y no se acredita al crearla.
Las amenazas cambian el trabajo; no es un A/B causal puro ni una comparación
con la versión anterior del juego. Audio silenciado; CPU aislada no medida.

| Destino | Control: media / p95 / peor | Completo: media / p95 / peor | Cuadros completos >16,67 ms |
|---|---|---|---|
| Museo | 9,99 / 13,42 / 16,15 ms | 11,67 / 15,29 / 17,51 ms | 7/600 |
| Coliseo | 9,12 / 14,14 / 19,00 ms | 11,37 / 16,78 / 22,02 ms | 31/600 |
| Eiffel | 9,78 / 13,38 / 17,04 ms | 11,53 / 15,18 / 18,16 ms | 9/600 |

Topes observados: seis consultas de ruta/cuadro, 128 unidades de preparación,
hasta 32 operaciones de erosión, cuatro amenazas más una dorada, 154 partículas,
11 ondas, siete textos y dos marcas. Cero nodos por efecto; mismos límites
duros de pools. La prueba registra ataques/picados/robos/escapes reales y el
botín observado, sin suponer que toda amenaza atacó. En particular, el gato
permaneció dormido en esta ventana y el botín de avispa en Eiffel fue cero.
No se valida toda conducta enemiga sólo con ese benchmark; la suite específica
también verifica la pasada sobre una cargadora caminando y su cancelación.

Los seis cierres cancelaron colas, enemigos y presentación, sin nodos huérfanos
nuevos ni ingresos/extracción tardíos. Partida y ajustes conservaron existencia
y SHA-256. Hubo picos de 22,02 ms: no garantiza 60 FPS constantes, GPU integrada,
sesiones largas, agrado del audio ni satisfacción humana. La primera tanda
de 180 cuadros era demasiado corta para observar ataques; se amplió a 600.
Se descartó telemetría TIME_PROCESS no sincronizada con la muestra: no se
presentan esos valores como CPU aislada.

Informe: `.godot/qa/perfil_estimulos.json`; log válido:
`.godot/qa/estimulos_perfil_600.log`. Revisiones gráficas: estímulos 15,
enemigos 16 y controles reales 28 verificaciones sin fallas, en Full HD y
1000×620 para los controles. Las capturas usan nodos/dibujo reales; los paneles
comparativos de efectos no simulan ingresos ni consumo.

Piloto `bot_balance` desde cero, ocho expediciones, tiempo ×1/paso 1/60,
sin calibración ni guardado personal: 6,44 minutos simulados, segunda obrera
comprada tras la tercera expedición y primera especialista tras la octava.
No llegó a madera ni fundación. Las cinco amenazas vencidas y cinco doradas
cobradas aumentan el ingreso activo: no es neutral para la economía aunque
los precios no cambien. No se extrapola a duración humana o campaña completa.
Registro válido `estimulos_piloto8_limpio_20261104.txt/.json` en `.godot/qa/`.
La tanda anterior sin «limpio» activó calibración por una variable vacía y se
descartó; la repetición verifica ausencia de esas opciones antes de lanzar.

Cierre lógico: 60 suites sin fallas, errores de script ni advertencias, logs
`estimulos_cierre_prueba_*.log`. Enemigos activos suma 46 verificaciones tras
repetir las suites afectadas por la corrección final del radio de aparición:
un llamado válido a 9004 unidades en la plaza mantiene el encuentro a no más
de 280 unidades del trabajo, sin volver a proyectarlo hacia el 70% del territorio.
La selección de objetivos de avispa usa intervalos de 0,5 s; el contacto de araña
sin presas, 0,2 s en lugar de un barrido de la colonia por cuadro. No se infiere
diversión de estas pruebas.

### Ganancias visibles desde la primera obrera — segunda pasada, 4/11

La presentación anterior no conectaba `Run.depositar` con los números y
descartaba importes menores a 0,5. Ahora cada pago real produce su cuenta en
la entrada y su recibo en el HUD. No hay una segunda acreditación ni cambios
de precio, daño, carga o velocidad. Los decimales no se convierten en «+0».
Ventanas finitas: 0,28 s en el mundo y 0,32 s en el HUD; entradas, categorías y
bonus no comparten la misma cuenta del mundo. Un pago no prolonga la vida
del número anterior. Ganancia y combo se formatean una vez por cuadro.

Depósitos de 24–26 px y bonus de 32 px como mínimo, con pop inicial, contorno,
sombra y reparto sin superposición; hasta 12 textos dibujados y ocho con zoom
menor a 0,25. Entrega con aro mínimo de 30 px y estelas; vuelo de tres a cinco
migas por emisión, dentro del mismo pool fijo de 40. Un solo lienzo conserva
los topes de 600 partículas, 24 ondas, 40 textos y 16 marcas. Hormigas y carga
física mantienen su escala nativa. El cierre también limpia el HUD y bloquea
la reaparición de números o vuelos por callbacks tardíos.

`revision_recompensas_juego`: 45 verificaciones sin fallas, Run real Full HD.
Primera miga nativa mordida/transportada/entregada, tanda de seis obreras,
racha y bonus de una segunda miga nativa. Sólo se controlan posiciones y se
declaran las fuentes adicionales del fixture; el bonus usa un buche mayor
declarado para vaciar la miga, no HP, daño ni valor inventados. Comprueba sumas
reales y números efectivamente dibujados a zoom 0,85 y 0,30, no sólo objetos
guardados en el pool. Capturas `recompensas_00…09.png`; log
`numeros_final_revision_recompensas_juego.log` en `.godot/qa/`.

La demostración comparativa de efectos pasa 17 verificaciones; no genera
ingresos. La suite lógica de estímulos pasa 40 y la de feedback de colonia 21,
incluidos mil pagos agrupados, decimales, combo diferido, origen mixto y cierre.
Son comprobaciones técnicas; la intensidad y la satisfacción requieren jugarlo.

Repetición final de `perfil_estimulos`, mismo equipo/resolución/500 hormigas,
40 cuadros de calentamiento y 600 medidos. Ahora los números y vuelos vienen
exclusivamente de descargas naturales: se eliminaron los «+12» sintéticos del
perfil anterior. Completo conserva ráfagas/impactos cosméticos sintéticos y
cuatro enemigos reales; no es un A/B causal ni mide CPU aislada. Audio silenciado.

| Destino | Control: media / p95 / peor | Completo: media / p95 / peor | Completos >16,67 ms |
|---|---|---|---|
| Museo | 10,16 / 13,98 / 18,97 ms | 12,10 / 16,61 / 24,32 ms | 30/600 |
| Coliseo | 9,07 / 14,11 / 21,58 ms | 11,97 / 18,35 / 24,08 ms | 69/600 |
| Eiffel | 9,82 / 13,50 / 17,11 ms | 11,84 / 16,68 / 23,33 ms | 31/600 |

Los seis casos terminaron sin fallas. Se observaron números de pago realmente
dibujados, recibos del HUD y vuelos con sus pools activos+libres acotados;
no se inyectaron fracciones para forzar cobertura (apareció una natural en
Museo control). Se verificó limpieza terminal tras los seis cierres y callbacks
tardíos, sin dinero nuevo ni daño posterior. Partida y ajustes conservaron
existencia y SHA-256. Hubo picos de 24,32 ms: no garantiza 60 FPS constantes,
otras GPU ni satisfacción humana. Datos en `.godot/qa/perfil_estimulos.json`,
log `numeros_cierre_perfil_estimulos.log`.

Cierre repetido: 60 suites lógicas sin fallas, errores de script ni advertencias
(`numeros_cierre_prueba_*.log`, todas con su resumen final). Renderer real:
recompensas 45, efectos 17, controles 28 y realismo 13 verificaciones sin fallas.
Realismo sirve preparación y erosión de la mesa con sus colas normales:
una solicitud pendiente no se toma por daño ni se falsean sus celdas para QA.

### Recorrido inicial, gesto y definición — 4/11, mapa 11

Seis migas existentes se acercan a la entrada. La primera silla conserva dos
componentes completos y libera una galletita reservada al abrir el paso. Las
fichas comparan capacidades reales con un dibujo retenido; no ejecutan IA ni
rutas. RecorridoCasa sólo se consulta en el refresco existente del HUD.
El gesto corporal usa el tick visual de 12 Hz y mantiene el descarte lejano.
Siete texturas sonoras propias se generan al arrancar; crujidos y recogidas
comparten hasta seis inicios por segundo y el pool global sigue en 16 voces.
La gran mesa conserva timbre de madera aunque su requisito de dieta sea 3.

El atlas pasa de 2048×5248 (41 MiB) a 2048×5760 (45 MiB), con siete acabados
de mayor definición y preflight de 9,27 ms en esta medición. Queda un atlas
retenido; durante la separación inicial conviven transitoriamente dos. El
tope adicional de 4 MiB no incluye otras texturas o memoria del proceso.
La revisión detectó ocho desacuerdos entre dibujo y máscara al usar las
siluetas anteriores. Se reexportaron sólo los siete acabados afectados con
`exportar_material_muebles`; los metadatos pasan de 3272 a 3404 rectángulos
finos. No se leen píxeles GPU durante una mordida. Si cambia la resolución de
autoría, sus siluetas se deben regenerar y comprobar conjuntamente.

Cierre: 64 suites lógicas con resumen de éxito y sin errores de script ni
advertencias. Se actualizaron las expectativas de segunda obrera, componentes
de silla y mapa 11. La prueba de controles retiraba comida de la lista pero
no del índice antes de `queue_free`; se corrigió su aislamiento. Se repitieron
las diez suites afectadas por la reexportación de siluetas, todas sin fallas.
Logs `casa_cierre_prueba_*` (usar `_v2` donde existe) y `casa_siluetas_prueba_*`.
El primer resumen PowerShell confundía «0 fallas» con un error por usar una
búsqueda sin distinguir mayúsculas; se corrigió el criterio y se revisaron
los logs completos, no ese resumen incorrecto.

Renderer real: material visible 68, residuos 341 y recorrido de casa 15
verificaciones sin fallas; compras y sensación también terminan con cero
fallas. Las capturas de recorrido separan una obrera desde cero de una colonia
QA declarada de 24 obreras con mejoras existentes. Esta última desarma la
silla mediante IA y porciones reales, abre el segmento transitable y transporta
la galletita. No es una estimación de duración ni de la primera compra. El
primer ensayo visual olvidaba procesar cambios de navegación al congelar el
árbol; se corrigió el servicio manual y se repitió completo. Partida y ajustes
conservaron existencia y SHA-256.

Estrés Full HD, Godot 4.7.2 GL Compatibility, RTX 3060: 500 hormigas, 40 cuadros
de calentamiento y 600 medidos por caso. Mismo protocolo de pagos naturales,
amenazas reales y demanda cosmética sintética; no es un A/B causal. Audio
silenciado y CPU aislada no medida.

| Destino | Control: media / p95 / peor | Completo: media / p95 / peor | Completos >16,67 ms |
|---|---|---|---|
| Museo | 9,37 / 12,40 / 17,85 ms | 11,81 / 15,61 / 19,21 ms | 8/600 |
| Coliseo | 8,85 / 14,12 / 19,60 ms | 11,15 / 16,78 / 22,54 ms | 33/600 |
| Eiffel | 9,81 / 13,80 / 19,47 ms | 11,44 / 15,48 / 19,42 ms | 7/600 |

Los seis casos finalizaron sin fallas, con colas y efectos cancelados al cerrar,
sin nuevos ingresos o extracción tardíos y sin nuevos nodos huérfanos. Los
picos impiden prometer 60 FPS constantes; GPU integrada, sesión humana larga
y agrado del audio quedan sin medir. Informe `.godot/qa/perfil_estimulos.json`;
logs gráficos finales `casa_pulida_*_final2.log`. Capturas de la escena real
`casa_pulida_00…06.png`, fichas `compras_00…08.png` y detalle
`definicion_casa_*.png`. El protocolo F6 de observación humana sigue pendiente.

Piloto nuevo desde cero: 24 expediciones, 26,13 minutos simulados, paso 1/60 y
tiempo ×1, política «materiales», sin calibración ni HP forzada. Segunda obrera
comprada después de la tercera expedición (~2,3 min); primera casta a 5,48 min,
madera a 10,06 min y primera silla a 11,75 min (expedición 14). El snapshot
conserva ambos componentes de `casa/silla_inicial`; el cartón cae a 22,08 min.
No llegó a resistentes, conquista ni fundación. Atiende doradas y amenazas,
por lo que esos ingresos participan del resultado; no mide tiempo en tienda ni
duración humana. Archivos aislados en
`.godot/qa/casa_piloto_20261104_184422/` (`registro.txt`, `motor.log`, `estado.json`),
sin errores de script ni advertencias. No se reutilizó ninguna partida personal.

### Corrección de contornos de sillas — 4/11

Las siete sillas normales ya no se dibujan con el perfil simplificado de
navegación. Respaldo, largueros y asiento se hornean con curvas y biseles finos;
el hueco entre respaldo/asiento pertenece al dibujo y a su material. Las cuatro
verdes usan escala 3 y margen 4; las otras tres, hasta escala 2. Sin cambios en
shaders, daño, carga, precios, tamaño físico ni cantidad de nodos por instancia.

Atlas final 2048×6336 = 49,5 MiB, frente a 45 MiB antes de esta corrección. El
baseline con márgenes compactos mide 40,5 MiB; el extra medido es 9 MiB y el
presupuesto de autoría 12 MiB. Se retiró la reducción dinámica de escala porque
desalineaba el dibujo con la RLE exportada. Sólo se reexportaron las siete
sillas: catálogo de 59 claves/3771 rectángulos finos. No hay lecturas GPU por mordida.

Pasaron 11 suites lógicas relevantes (dirección de material, material visible,
materiales, componentes, recorrido, sensación, población, preparación de
fundación, periferia, mordiscos y microbocados). Revisiones GPU: definición 12,
material visible 68 y recorrido 15 verificaciones, todas sin fallas. Se revisaron
capturas a zoom máximo 4, un retazo y 24 bocados; además la IA desarma la silla
y transporta su descubrimiento en el recorrido real. Logs finales
`.godot/qa/bordes_prueba_*.log` y `bordes_revision_*.log`. El intento inicial de
invocar una suite inexistente `prueba_bocados` no cuenta como prueba ejecutada;
se corrieron las suites reales `prueba_mordiscos` y `prueba_microbocados`.

Perfil gráfico de Casa, Godot 4.7.2 GL/RTX 3060, 1920×1080, 60 cuadros de
calentamiento y 300 de muestra por fase, audio silenciado. Fases consecutivas,
no A/B causal ni medición aislada de CPU:

| Fase | Media / p95 / peor |
|---|---|
| Casa, 5 hormigas | 2,04 / 2,29 / 3,09 ms |
| Casa, 150 hormigas | 3,23 / 3,97 / 5,02 ms |
| Casa, 500 hormigas | 5,05 / 6,47 / 8,13 ms |
| Demolición, 500 | 8,00 / 13,26 / 16,44 ms |
| Evoluciones, 500 | 15,66 / 18,88 / 36,64 ms |

El escenario extremo de evoluciones sigue teniendo picos; no se prometen 60 FPS
constantes ni se extrapola a GPU integrada. Informe textual
`.godot/qa/bordes_perfil_rendimiento.log`. No se cerraron procesos del usuario.

### Pulido general y contornos completos — 4/11

Muebles: biseles y sombras más cortas, curvas nativas y detalle de esquina 20.
Plantas y sanitarios ya no se dibujan con las bandas de navegación. Obelisco,
arco y torre usan geometría ilustrada propia, horneada en el mismo atlas.
Comida a escala 3 y elipses más subdivididas; interfaz con paneles retenidos y
bordes finos. Suelo procedural más tranquilo, sin muestreo del mosaico antiguo;
periferia simplificada, sin añadir antialiasing por primitiva del escenario.
No cambian precios, HP, tamaño del bocado, población máxima ni IA.

Las consultas de colisión descartan primero el AABB exacto de los recortes,
cacheado en su descriptor al iniciar/cambiar material. Sólo si la consulta
entra en ese límite se recorren las bandas de siempre. No se agranda ni
simplifica el perfil; el array vacío sigue sin bloquear con cualquier margen.
La regresión de movimiento contrasta resultados exactos contra las consultas
anteriores: puntos, cinco márgenes, segmentos y bandas, suelo/vuelo y estados
intacto, recortado, vacío, reemplazado sin caché y eliminado. Los 500 retornos
siguen entregando sin atravesar objetos. Esa prueba lógica no mide FPS.
Después del descarte se repitieron las 64 suites completas: todas incluyen
resumen de éxito, sin errores de script ni advertencias. También se repitió
el recorrido GPU real hasta abrir el paso y transportar la galletita: 15/0.
Logs finales `pulido_aabb_prueba_*` y `pulido_aabb_revision_recorrido_casa.log`.

El corte binario de alfa del horneado perdía la cobertura de los bordes. Ahora
se conserva y se reparan costuras interiores/pequeños trazos sin material
mediante una vecindad de nueve muestras **sólo al preparar el atlas**. La
clasificación física sigue siendo alfa >0,5, equivalente al umbral anterior de
0,75 en la fuente. El shader de juego adapta el suavizado al tamaño del píxel
de pantalla sin muestras adicionales para ese suavizado. R8 nearest y paso
máximo de extracción 2 no cambian; tampoco hay lecturas GPU al comer.

MaxRects calcula dos planes al arrancar y reutiliza las posiciones al montar;
sin rotación ni cálculo por cuadro. Catálogo 59 acabados, atlas final
**2048×6144 / 48 MiB RGBA8**, frente a 49,5 MiB antes. El plan sin el detalle
prioritario mide 40 MiB; adicional 8 MiB dentro del presupuesto de autoría
de 12 MiB. Preflight local: 56,98 ms, frente a unos 9 ms del empaquetado
anterior; es un coste único de arranque, no tiempo de cuadro. La separación
inicial conserva dos atlas transitorios como antes, y después sólo uno.
Estas cifras no representan toda la RAM/VRAM del proceso. Las hojas antiguas
de monumentos pasan a carga diferida y el suelo ya no solicita su mosaico.

Se regeneraron las 59 claves de material (5303 rectángulos finos) y las 27
siluetas alimenticias. Los exportadores aceptan `-- --guardar` para actualizar
sus JSON de autoría; sin ese argumento sólo imprimen los datos. No escriben
partidas. La revisión GPU rasteriza cada RLE y compara **todo el cuerpo de
cada acabado**, además de los recortes exteriores. Los píxeles parciales
deben pertenecer al contorno, con material y aire próximos: no se aceptan
costuras interiores como un borde suavizado válido.

Cierre: 64 suites lógicas sin fallas. La prueba de erosión conserva la
comparación exacta de tres lados sobre muebles reales; el estado de origen
aparcado se comprueba ahora en una torre fresca, con precondiciones geométricas
explícitas. El antiguo supuesto «27% desde la izquierda siempre queda
aparcado» dejó de ser cierto con los calados de la nueva torre; no se cambió
producción ni se quitó esa cobertura de estado. Logs `pulido_final_prueba_*`
y `pulido_cierre_prueba_*` (estos últimos prevalecen).

Renderer real: material visible 69, residuos 341, definición 17 y recorrido 15
verificaciones sin fallas. Compras, sensación, hormiguero y sesión real
(1920×1080 y 1000×620, 15 comprobaciones) también terminan sin fallas.
Se ajustó la altura del estado cuando desaparecen filas y se separó el aviso
local F6 de la barra de tiempo. No se añaden tweens, procesos ni polling para
esos cambios. La sesión confirma SHA-256 de partida y ajustes intactos.
Capturas `estetica_*.png`, `definicion_casa_*.png`, `sesion_casa_*_es.png`
y `compras_*.png` dentro de `.godot/qa/`.

Perfil real Full HD, Godot 4.7.2 GL Compatibility / RTX 3060, sin VSync ni
límite de FPS, audio silenciado; 60 cuadros de calentamiento y 300 medidos por
fase. Dos ejecuciones completas antes del descarte AABB, con fases consecutivas
y delta real:

| Fase | Primera: media / p95 / peor | Segunda: media / p95 / peor |
|---|---|---|
| Casa, 5 hormigas | 1,99 / 2,36 / 2,83 ms | 2,03 / 2,46 / 4,01 ms |
| Casa, 150 | 3,22 / 3,96 / 4,96 ms | 3,20 / 3,88 / 4,71 ms |
| Casa, 500 | 5,82 / 7,91 / 12,12 ms | 5,63 / 7,46 / 8,73 ms |
| Demolición, 500 | 10,91 / 17,00 / 20,64 ms | 12,55 / 18,99 / 32,79 ms |
| Evoluciones, 500 | 17,51 / 21,79 / 24,98 ms | 16,86 / 20,47 / 25,34 ms |

La referencia tomada durante esta pasada marcaba 2,50 / 3,89 / 5,94 / 9,51 /
17,19 ms de media, respectivamente. Incluía el primer cambio de suelo/UI y
una versión intermedia de la periferia, por lo que **no es un A/B causal**.
En las nuevas ejecuciones, Casa500 usa 709–721 drawcalls frente a 899 en esa
referencia; las cargas de demolición/evolución no son estados idénticos,
pues el delta real cambia el trabajo alcanzado. No se afirma una mejora
uniforme: la demolición fue más lenta y el extremo sigue superando 16,67 ms.
No se prometen 60 FPS constantes ni resultados de GPU integrada. Logs
`pulido_base_rendimiento.log`, `pulido_final_perfil_rendimiento.log` y
`pulido_cierre_perfil_rendimiento.log`. No se cerraron procesos del usuario.

Medición final con el descarte AABB, mismo protocolo, en
`pulido_aabb_perfil_rendimiento.log`:

| Fase | Media / p95 / peor | Drawcalls medios |
|---|---|---|
| Casa, 5 hormigas | 1,88 / 2,18 / 2,55 ms | 551 |
| Casa, 150 | 2,96 / 3,66 / 4,82 ms | 627 |
| Casa, 500 | 5,53 / 6,93 / 8,31 ms | 723 |
| Demolición, 500 | 8,18 / 12,15 / 17,63 ms | 1028 |
| Evoluciones, 500 | 16,86 / 20,34 / 22,47 ms | 1834 |

Este resultado no demuestra cuánto aporta aisladamente el AABB: las fases
con delta real no mantienen estados físicos idénticos entre ejecuciones.
Sí verifica la carga real de esta versión y mantiene las cotas: 19/64 restos,
51/600 partículas y 23/40 textos. El escenario extremo todavía tiene picos
por encima de 16,67 ms; siguen pendientes GPU integrada y sesiones humanas.

### Combo por etapas y mejoras visibles — 4/11

Un Control y un Label compartidos para el combo, seis StyleBox retenidos y
32 partículas preasignadas. Los depósitos se coalescen una vez por cuadro;
cambiar de 3 a 250 en ese cuadro celebra una sola vez. Fuente 24→36 por
etapas, colores, brillo, pulso y sacudida local. Sólo se mide el ancho de
texto al cambiar la cantidad de dígitos o etapa; no hay Tween por depósito.
El reloj del HUD respeta pausa y el ajuste de temblor cero. Combo 1/2 reinicia
la jerarquía anterior; cerrar es terminal. No cambia el ingreso por combo.

Las tres compras cachean booleanos al iniciar la expedición. Migas brillantes
agrega cuatro brillos y un aro de recibo; Mordida chispeante, dos chispas y
un corte; Pulso de la colonia dibuja hasta ocho halos sólo durante frenesí
real. Conservan las puertas de entrega/mordida y los pools de 600/24, sin nodos
por hormiga. El estado de entradas se refresca en el reloj existente de 0,5 s
y al activar/cerrar frenesí. Los halos vencen también localmente. Atlas sin
cambios: 48 MiB; las insignias de las cámaras son dibujo retenido.

Regresión: **67 suites completas**, con resumen de éxito, sin errores ni
advertencias. Las nuevas cubren combo 38, efectos 24 y compras 102 comprobaciones.
Guardado anterior sin los IDs, JSON, lotes 1/10/Máx, precio único y fundación
están cubiertos. No se modificaron los archivos personales.
Logs `combo_final_prueba_*`. Renderer: combo 19 y mejoras 10 sin fallas;
la revisión detectó una superposición con el pulso/ganancia del contador,
corregida reservando su altura máxima. Se revisaron 1920×1080 y 1000×620,
seis etapas, 1000 descargas coalescidas, temblor cero y cámaras compradas.
Capturas `combo_*.png` y `mejoras_visuales_*.png` en `.godot/qa/`.

Estrés final: Godot 4.7.2 GL Compatibility, RTX 3060, Full HD, sin VSync/límite
de render, audio silenciado, **--fixed-fps 60**. Son pasos de simulación
de 1/60, no un cap gráfico: se mide tiempo real entre cuadros de GPU.
500 hormigas, 40 cuadros de calentamiento y 600 medidos por caso. Frenesí revelado
en ambos casos; completo compra las tres mejoras, agrega amenazas reales y
la demanda cosmética sintética ya declarada por el perfil. Sus bonus y los
enemigos alteran el trabajo: **no es un A/B causal del costo de los efectos**.

| Destino | Control media / p95 / peor | Completo media / p95 / peor | Completos >16,67 ms |
|---|---|---|---|
| Museo | 9,51 / 12,84 / 17,61 ms | 12,99 / 19,59 / 32,29 ms | 96/600 |
| Coliseo | 9,38 / 13,68 / 58,63 ms | 11,52 / 16,85 / 61,16 ms | 39/600 |
| Eiffel | 9,73 / 14,37 / 19,20 ms | 12,62 / 18,18 / 25,69 ms | 76/600 |

Seis casos / 0 fallas, con descargas naturales y cierre sin daño/ingresos tardíos,
sin nodos huérfanos ni pools que crezcan. Máximos observados completos:
165 partículas, 21 ondas, 32 slots de chispa y 2 halos dibujados; etapas de combo 4/5
vinieron de descargas reales. El escalón 6 y el límite de 8 halos se verifican
aparte, no se presentan como cobertura de este estrés. Persisten picos:
no se prometen 60 FPS constantes ni resultados en GPU integrada.
Informe `.godot/qa/perfil_estimulos.json`, log
`combo_cierre_perfil_estimulos.log`. CPU aislada y mezcla de audio no medidas.

El primer intento sin paso fijo rindió más cuadros por segundo pero sólo
unos pocos segundos simulados: tres casos no llegaron a observar depósitos
visibles dentro de 600 cuadros. No se retiró esa exigencia ni se inventaron
pagos: se repitió con `--fixed-fps 60` y pasó. Una pasada intermedia fija no
revelaba frenesí; la final sí lo activa y observó los halos. Los resultados
anteriores sin ese protocolo no se comparan como mejora de esta versión.

Piloto aislado desde cero, 16 expediciones, paso 1/60 y tiempo ×1, política
materiales: 14,51 min simulados, madera a 12,28 min y primera silla a 14,21.
No se prefijaron ingresos ni compras. En esa muestra el bot **no compró las
tres hojas nuevas**: valida continuidad del recorrido, no su balance,
beneficio comparativo ni duración humana. No alcanzó el primer rebirth.
Archivos `.godot/qa/combo_piloto_20261104_211504/`, sin errores de script ni
advertencias. La compra y activación reales se cubren por separado en las
pruebas de 102/24 comprobaciones y la revisión GPU.

### Combo central de impacto — 4/11

Sustituye la celebración local anterior: 0,44 s enorme en el centro y viaje
al HUD hasta 1,04 s, con la nueva paleta. Una fuente fija de 96 px conserva
definición al escalar; siguen siendo un Control, un Label y 32 partículas
retenidas. Dos ondas y doce rayos de geometría acotada, sin bloom, emisores
ni Tween por depósito. Cruzar otra etapa durante el efecto actualiza el
número/color sin reiniciar reloj ni encolar animaciones. No pausa la IA ni
cambia pagos, ventana de combo, daño o precios.

Temblor cero omite el centro/viaje y conserva el contador quieto. La pausa
congela el mismo reloj; el modal queda encima del efecto. El cierre cancela
texto y sacudida. Cámara con oscilación determinista, sin RNG global ni
zoom/reencuadre; respeta los límites del escenario. Mantener feromonas o
arrastrar limita la amplitud a 3 px por eje, incluso si se empieza después
del golpe. En retirada no se inician nuevos impulsos.

Unidad de combo: 67 comprobaciones sin fallas. Revisión GPU: 36, seis
etapas con capturas de impacto/regreso/llegada, 1000 pagos coalescidos,
ventanas de 1920×1080 y 1000×620, movimiento reducido y cierre.
Regresión completa final: 67 suites sin fallas/errores/advertencias,
logs `epico_total_prueba_*`. Entradas reales durante el efecto: 51 sin
fallas, clic mantenido, rueda, arrastre, Esc/pausa/reanudación y cierre
durante el regreso, en ambos tamaños. El observador independiente del
despachador sigue el último MouseMotion real, también si el SO lo emite
después de la entrada sintética; conserva la tolerancia de 7 px. Logs
`epico_final_revision_input_combo` y `epico_final_revision_combo_visual`.

Estrés con el mismo protocolo fijo de 500 hormigas, 40 warm + 600 muestras,
RTX 3060/GL Compatibility, audio silenciado y sin VSync. Ahora avanza también
la sacudida real, sin leer teclado/mouse. Temblor 1 sólo en memoria. Exige
que un combo de depósitos naturales haya sido grande y regresado durante
la ventana medida; cuenta chispas vivas, no sólo slots asignados.

| Destino | Control media / p95 / peor | Completo media / p95 / peor |
|---|---|---|
| Museo | 9,80 / 13,51 / 15,89 ms | 12,89 / 17,17 / 20,43 ms |
| Coliseo | 9,46 / 14,94 / 59,25 ms | 11,96 / 17,79 / 67,90 ms |
| Eiffel | 9,93 / 15,84 / 21,28 ms | 12,36 / 17,12 / 20,51 ms |

Seis casos / 0 fallas, ambos tramos visibles en todos: 78–130 cuadros de
impacto y 108–148 de regreso por caso, 1158–1267 px de ancho central máximo.
Las etapas naturales fueron 4/5; la 6 se cubre en la revisión dedicada.
Máximo 28 chispas vivas de 32 slots. Sin crecimiento de nodos/pools ni daño
o ingresos tras cerrar; SHA de archivos personales intactos.
No es un A/B causal: compras/amenazas y ahora la eliminación del RNG de
cámara cambian el trabajo recorrido. Persisten picos, sobre todo en Coliseo;
esto no garantiza 60 FPS constantes, GPU integrada ni satisfacción humana.
Log `epico_perfil_estimulos.log`, informe `.godot/qa/perfil_estimulos.json`.

### Combo sin placas y regreso desde muebles — 4/11

El combo ya no conserva seis StyleBox ni dibuja placa o cortina fullscreen.
Contraste en el contorno de la letra y su sombra teñida, conservando el
único Label de 96 px y los 32 slots. Se comprueba transparencia real en un
SubViewport: HUD, impacto, regreso y aterrizaje, ocultando sólo la letra
durante esa inspección. No se sustituye el recuadro por otra textura.

Reproductor de navegación: tres puestos exactos de heladera/alacena, con
carga obtenida por una mordida real, quedaban inmóviles durante 1600 pasos.
El piso era libre con margen 8, pero los pasillos de 50/55/75 unidades no
ofrecían centros de celda con el certificado conservador de 30,72. Por eso
volver a elegir entrada no resolvía el fallo. Antes del cambio: 4 fallas,
incluida la suma sin entregar, en `bordes_reproduccion.log`.

La ruta conserva la rejilla 32, margen 8, A* y cola de seis pedidos/1200 µs.
Sólo al faltar un anclaje se conecta origen/destino por hasta dos esquinas
seguras: cuatro obstáculos adyacentes, 16 vértices, 32 pruebas de segmento
por extremo. Caché positivo exacto de 128 enlaces como máximo, invalidado
por colisiones y cualquier cambio de radio. No hay teletransporte, pago a
distancia ni búsqueda por hormiga/cuadro cuando ya tiene una ruta.

`prueba_regreso_bordes`: 88 comprobaciones sin fallas. Incluye 28 mordidas y
regresos, tres recorridos naturales desde el nido con ida/retorno validados,
seis cargas parciales tras varios recortes y con feromonas mantenidas, y
500 cargadas desde orígenes distintos. Estas últimas son un fixture de
transporte explícito: 62,5 migas entregadas exactamente, sin fingir un piloto
de economía. Cota observada de 15 pruebas por enlace y 128 entradas cacheadas;
ninguna atravesó muebles ni superó el cupo de rutas. Guardado personal intacto.
Se exige que existan los 28 puestos y se certifican las aristas completas
de las 500 rutas, además de sus posiciones por cuadro. Esta ejecución
headless no mide FPS. Log `regreso_bordes_auditada.log`.

Regresión completa: 68 suites sin fallas, errores ni advertencias, logs
`regreso_total_prueba_*`; repetida la suite de bordes al endurecer esas dos
comprobaciones. Revisión gráfica del combo: 42, incluida transparencia real.
Entradas reales durante el efecto: 51 sin fallas en Full HD y ventana pequeña,
logs `regreso_final_revision_combo_visual` y `regreso_final_revision_input_combo`.

Perfil específico de esos pasillos: renderer real GL Compatibility / RTX 3060,
Full HD, sin VSync, audio silenciado, `--fixed-fps 60`. Grilla precalentada,
puentes fríos, 30 cuadros de calentamiento y 500 IA con callbacks normales.
Orígenes distintos, carga sintética de 0,125 y velocidad de fixture de 1500;
no es un piloto de extracción ni economía. Incluye entrega y combo normales,
culling y el costo del observador de seguridad. Mide hasta que todas llegan:
260 cuadros, **7,06 ms media / 10,14 p95 / 13,84 peor**, 0 sobre 16,67 ms.
500 entregadas, 62,5 migas exactas, sin atravesar material. Caché máx 128,
15 pruebas por enlace, hasta tres rutas por cuadro y 1,976 ms de navegación
acumulada máxima. Los 1200 µs son admisión blanda: una operación puede
terminar después, sin habilitar una búsqueda ilimitada adicional.
11 comprobaciones sin fallas; nodos/pools y SHA personales conservados.
Log `regreso_perfil_bordes.log`, JSON `.godot/qa/perfil_regreso_bordes.json`.
No mide CPU aislada, audio, campaña ni GPU integrada, ni garantiza los mismos
tiempos en todo el juego. Las cargas y velocidad del fixture están declaradas.

### Frentes vivos, consumo local y orden retenida — 5/11

La captura de la mesa tenía fallas distintas al antiguo puente de pasillos:
la máscara abría cavidades, pero la navegación seguía usando el AABB de hasta
dieciséis celdas. El veneno podía perseguir ese frente desde un origen fijo
hasta otra región. Las portadoras buscaban otra orilla para llenar el buche;
además, al vaciarse el píxel bajo el cursor las feromonas perdían el mueble y
pasaban a ordenar espera. El arreglo anterior de puentes no cubría esos casos.

Ahora Cocina consulta el mismo árbol de ocupación de la máscara para regiones
y segmentos. Cada corte publica su zona, aunque no achique el AABB, con el
reloj de geometría existente de 0,12 s. No reconstruye miles de rectángulos ni
agrega cuerpos físicos por bocado. La poda conserva también el último píxel
rasterizado exterior. Nearest global y por fila en una búsqueda, nodos llenos
aceptados inmediatamente, semilla proyectada exacta y deduplicación por sello
de los objetos presentes en varios sectores. Los puestos se proyectan sobre
el frente cercano con hasta tres intentos, sin otro A*.

Perder contacto con carga inicia su entrega parcial. Con contacto se conserva
la capacidad normal. Las cinco listas visuales retienen las tres muestras más
recientes, sin cambiar masa, tamaño, valor ni crear sprites. Mantener sobre un
mueble conserva esa orden hasta salir de su huella, elegir otro objeto o
soltar; la regresión incluye el cursor vacío y el frente fuera del radio visual.

La corrosión queda en una zona fija alineada de hasta 32×32 unidades, porciones
de hasta 16 por servicio, y nunca proyecta un origen ocluido a otra cara. Las
fracciones admitidas se descartan al cambiar de ancla, no se trasladan ni se
cobran. El contacto recordado es FIFO de 64 actores por recurso; alternar A/B/A
no revive una zona agotada. La preparación asíncrona conserva el tiempo de DPS
pendiente. Mancha, fragmentos y recibo numérico señalan la extracción real.

Regresión lógica: **71 suites sin fallas/errores/advertencias**, logs
`material_final_prueba_*`. Se repitieron geometría (69 comprobaciones, incluida
la última poda raster) y movimiento después del cierre de esa revisión.
`prueba_geometria_material` contrasta regiones, segmentos y nearest global/por
fila contra referencias por píxel, una cavidad conectada de la mesa que no
altera su AABB, puestos repartidos y la orden retenida. Su notch es preparación
sintética declarada, no una mordida ni una medida de producción.

`prueba_frente_mesa`: ocho hormigas, dos escenarios de 120 s simulados con/sin
llamado. Todos los cortes se auditan inmediatamente después de cada boca:
máximo 6u por porción, cercanía al material, recorrido libre, ingreso efectivo
en material anteriormente ocupado y varios regresos de CADA hormiga. El acceso
local, daño, velocidad y cadencia están acelerados y declarados como fixture;
no estima duración humana ni economía. Revisión GPU Full HD: 13 comprobaciones,
648/669 recortes; mínimo 48/50 entregas por unidad; inmovilidad con carga sin
nuevo bocado como máximo 0,25 s. Capturas antes/mitad/después en
`.godot/qa/mesa_*`, revisadas visualmente: distintos puestos, viajes y borde
local continuo. No hay una orden de terminar la mesa desde el script del test.

Veneno geométrico: 52 comprobaciones. Dos manchas fuertes sobre otra mesa
limpia; comparación de TODOS los píxeles antes/después demuestra cero cambios
fuera de sus zonas. Mil renovaciones alternadas no dañan ni pagan otra región.
La prueba débil separada conserva el reloj/fracción sin agotar su mancha antes
de vencer. Erosión presupuestada: 54 comprobaciones, con trabajo retirado,
crédito, descarte y cancelación distinguidos; piso ocluido y otro frente real
de Eiffel. Ciclo de carga: 14, incluida capacidad doce y entrega parcial exacta.
Silla inicial con IA y mejoras reales: 23; desarme/transporte/materiales: 43.
Los SHA de partida y preferencias permanecen intactos.

Perfil final con renderer GL Compatibility / RTX 3060, Full HD, audio
silenciado, VSync desactivado y paso fijo de 1/60. Los seis escenarios conservan
500 IA, navegación/extracción reales y los presupuestos/pools existentes;
40 cuadros de calentamiento y 600 muestras por caso. Completo agrega las
amenazas y la demanda cosmética declaradas en el script; no es un A/B causal
puro porque también cambian trabajo, compras e ingresos.

| Destino | Control media / p95 / peor | Completo media / p95 / peor |
|---|---|---|
| Museo | 12,83 / 17,61 / 24,32 ms | 16,68 / 22,75 / 28,02 ms |
| Coliseo | 11,17 / 17,27 / 26,44 ms | 14,14 / 20,96 / 27,71 ms |
| Eiffel | 11,75 / 18,60 / 26,08 ms | 14,47 / 21,91 / 25,94 ms |

Seis casos / 0 fallas. La geometría precisa tiene costo: estos resultados no
demuestran ausencia de regresión frente a los perfiles antiguos con AABB ni
60 FPS constantes; los p95 todavía exceden 16,67 ms. Sin crecimiento de nodos
o pools, pagos/daño nuevos tras cerrar ni escrituras personales. Informe
`.godot/qa/perfil_estimulos.json`, log `material_gpu_final_perfil_estimulos.log`.

Regreso de 500 portadoras por pasillos, mismo protocolo sintético declarado:
260 cuadros, 6,68 ms media / 9,49 p95 / 11,34 peor, ninguno sobre 16,67 ms;
500 cargas entregadas, 62,5 migas exactas, tres rutas por cuadro como máximo,
caché 128 y 15 pruebas de enlace. Once comprobaciones sin fallas, log
`material_gpu_final_perfil_regreso_bordes.log`. No mide CPU aislada, mezcla de
audio, GPU integrada, satisfacción ni duración de campaña.

### Masticación legible sin otro proceso por hormiga — 5/11

Cuatro poses propias de trabajo por casta/evolución (108 en total): patas
apoyadas, cabeza y pinzas claras, alas plegadas. Se eligen en el tick visual
existente de 12 Hz, con dos ciclos por segundo independientes de las mejoras
económicas. No hay nodos, tweens, partículas ni consultas de geometría desde
el renderer de la hormiga. El apoyo sólo desplaza su sprite: no toca posición,
rotación física, daño, rutas ni RNG. El tirón y levantado siguen ligados a
una porción realmente retirada, conservando su región, tamaño y valor.

La pieza comparte el contacto ya calculado. El alimento confirma una vez
su primer contacto al llegar, para mostrar esfuerzo también con capacidad
uno; las mordidas normales lo renuevan. Esperar la máscara, perder contacto,
volver y detenerse no muestran masticación. El detalle se omite fuera de
cámara o bajo zoom 0,28, sin agrandar las hormigas.

Caminar conserva sus ocho poses y tres texeles por unidad: se recortó sólo
aire en castas sin alas (18u); voladoras mantienen 24u. Las bocas caben en
18u. Atlas publicado **2048×6080 / 47,5 MiB**, frente a los 48 MiB anteriores;
tope de 49,5 MiB sin aumentar. La revisión detectó una sombra de pared que
desbordaba su reserva hacia una cargadora: el material transportable ahora
se hornea sin esa sombra externa. No se agregaron contenedores por región.

Lógica: 24 comprobaciones específicas, 36 de sensación de bocado y **72
suites sin fallas/errores/advertencias**, logs `masticar_cierre_prueba_*`.
Revisión GPU: **153 comprobaciones**; cuatro bocas distintas por píxel en las
27 variantes y perímetros libres de las 324 poses de caminar/trabajar.
Mesa y sofá reales, zoom1 y3,4, esfuerzo sin extracción y tirón con retazo
real; capturas `.godot/qa/masticar_*`, revisadas visualmente. Repetidas
definición (17), residuos (341) y recorrido de materiales sin errores.
SHA de partida y ajustes conservados; no se valida duración humana.

Perfil de cierre con GL Compatibility / RTX 3060, Full HD, audio silenciado,
sin VSync, paso fijo de 1/60: 500 IA, 40 cuadros de calentamiento y 600 muestras
por caso. Cuenta mandíbulas nuevas realmente visibles durante extracción
y navegación normales. Completo agrega amenazas y cosméticos declarados;
no es un A/B causal aislado. Valores en ms (media / p95 / peor):

| Destino | Control | Completo |
|---|---|---|
| Museo | 12,69 / 17,57 / 23,08 | 15,55 / 21,59 / 28,07 |
| Coliseo | 10,63 / 16,41 / 22,98 | 13,89 / 20,67 / 26,76 |
| Eiffel | 11,36 / 17,88 / 24,15 | 14,14 / 21,68 / 27,14 |

Seis casos / 0 fallas; máximos muestreados de 38–57 hormigas masticando
visiblemente por caso. Sin crecimiento de pools/nodos ni actividad nueva
tras cerrar. Log `masticar_validado_perfil_estimulos.log`, informe
`.godot/qa/perfil_estimulos.json`. No demuestra costo cero de animación ni
60 FPS constantes: p95 aún supera 16,67 ms. CPU aislada, audio y GPU
integrada pendientes; la legibilidad/fatiga requiere una sesión humana.

### Continuidad de apoyo, objetivo y regreso — 5/11

Se reprodujeron cinco fallas antes del arreglo (`apoyo_antes.log`): una boca
entraba a 13u aunque su puesto estuviera a 9u, y otras seguían MORDIENDO con
1,5s pendientes después de que otra operación retirara su contacto real.
No se agotó el reloj ni se publicó la geometría para fabricar la reacción.
La prueba separada de regreso (`retorno_antes.log`) obtenía carga real y
quedaba inmóvil al cerrar el presupuesto del cuadro: una falla antes del fix.

La llegada a muebles ahora exige estar a 0,25u del puesto elegido, no sólo
dentro del alcance geométrico máximo. Se conserva ese alcance de 13u: un
margen cuadrado de 8u necesita más de 9u en algunas curvas y diagonales.
Reducirlo globalmente dejaba partes de sillas y monumentos inaccesibles;
no es el arreglo. La distancia del apoyo efectivamente alcanzado se retiene
y un retroceso obliga a buscar puesto nuevo o entregar la carga parcial.

El contacto se invalida por vida/material real además de geometría y posición.
Hasta cuatro lecturas directas R8 verifican el punto; sólo al retirarlo se
recalcula nearest. Tolerancia de borde 0,01u, no un radio de búsqueda. El
caché de hasta 64 accesos guarda puesto/contacto: un contacto todavía vivo
se valida por distancia, sin otro nearest. Su desaparición invalida también
un puesto que aún estuviera dentro de los 13u. Los alimentos usan contacto
real al llegar a su AABB y miran su mordida, no el centro de un objeto hueco.

Ir a comida usa la misma precisión de 0,25u al renovar una ruta: ya no ignora
un ajuste de 2u del objetivo. Llegar al extremo de una ruta anterior mientras
espera turno tampoco abandona la comida. El regreso conserva el prefijo de
ida en reversa, sólo si sigue sobre su último segmento realmente recorrido.
Puede avanzar por él mientras espera, sin otra ruta ni chequeos de píxeles
por cada paso; el material sólo desaparece en la run. Las rutas vacías,
fallidas, reposicionamientos y prolongaciones del segmento no se reutilizan.
La cola mantiene seis rutas y admisión blanda de 1200µs por cuadro.

Regresión: **74 suites sin fallas/errores/advertencias**, logs
`apoyo_final_prueba_*`; repetidas seis afectadas tras ajustar la precisión
de rutas (`apoyo_cierre_prueba_*`). Contacto continuo: **75 comprobaciones**,
mesa/galletita/torta reales, carga vacía/parcial, reloj pendiente, retroceso
corto de 9–13u, caché renovado y reanudación estable. Incluye bordes R8 y
un doble explícito de orientación lateral; este último no prueba geometría
ni balance. Retorno continuo: **29 comprobaciones**, ida/mordida reales,
varios cuadros de presupuesto cerrado con posiciones contrastadas contra
la polilínea observada, esquinas, pago exacto y nueve guardas sintéticas.
También cubre el objetivo desplazado 2u y su ticket único mientras espera.

Autonomía mantiene 18 comprobaciones y cuenta la nueva consulta exacta:
una en 120 ticks, otra por geometría/movimiento y al cambiar recurso,
sin un segundo nearest redundante de alcance. Microbocados (40), consumo
de materiales/silla completa (43), catálogo de material (130) y proyectos
(816) conservan sus contratos. No se cambiaron precios, daño, intervalos,
créditos ni masa de retazos. SHA de partida y ajustes intactos.

Cierre GPU: 153 comprobaciones de las poses y 13 del ciclo real de mesa con
y sin llamado. Ocho obreras, fixture acelerado declarado: 595/583 cortes,
mínimo 55/50 entregas por obrera y 0,23/0,25s de inmovilidad cargada máxima.
Las pausas que corresponden a trabajo real no se cuentan como congelamiento;
estos valores no afirman cero espera de navegación en cualquier colonia.
Capturas `.godot/qa/mesa_*`, log `apoyo_cierre_prueba_frente_mesa.log`.

Se agregó la casa al perfil de estrés existente, manteniendo su protocolo:
GL Compatibility / RTX 3060, Full HD, sin VSync, audio silenciado, 500 IA,
40 cuadros de calentamiento + 600 muestras. Completo agrega amenazas al
tope y demanda cosmética explícita; no es un A/B causal ni un piloto de
balance. Milisegundos (media / p95 / peor):

| Destino | Control | Completo |
|---|---|---|
| Casa | 12,68 / 16,89 / 24,69 | 17,19 / 24,38 / 34,55 |
| Museo | 12,11 / 16,46 / 24,77 | 16,40 / 22,73 / 28,90 |
| Coliseo | 12,02 / 18,61 / 26,78 | 15,73 / 22,90 / 32,22 |
| Eiffel | 11,28 / 17,32 / 23,98 | 14,38 / 21,29 / 28,96 |

**Ocho casos / 0 fallas**, sin crecimiento de pools/nodos ni trabajo/pagos
nuevos tras cerrar; las bocas se dibujan durante extracción normal. Los p95
de estrés todavía exceden 16,67ms: no garantiza 60 FPS constantes ni ausencia
de costo de la IA. CPU aislada, audio, GPU integrada y sensación humana no
medidos. Log `apoyo_cierre_perfil_estimulos.log`, informe
`.godot/qa/perfil_estimulos.json`. El atlas permanece en 47,5MiB.

### Integración con el balance de main — 6/11

Se conserva el balance remoto: los objetivos grandes aprovechan el daño con
bocados de hasta 24u, mientras los muebles comunes siguen en 6u. La regresión
de circulación en la mesa calibra su fuerza a una porción base; no reduce
la mesa ni relaja sus límites de contacto, localidad o entregas. La suite
nueva `prueba_bocado_adaptativo` cubre ambos tamaños, sus límites y entradas
inválidas, y sigue el mismo material desde la extracción hasta el depósito:
31 comprobaciones tanto en headless como con el atlas real.

**75 suites lógicas / 0 fallas**, sin errores ni advertencias; logs
`main_integrado_prueba_*`. GPU: 153 comprobaciones de masticación y 13 del
ciclo de mesa, además de las 31 adaptativas; logs `main_gpu_*`. Se conservan
las huellas de partida y ajustes. No se volvió a medir la campaña completa:
la estimación histórica de cuatro horas no valida esta combinación de IA.

Repetido el protocolo Full HD / GL Compatibility / RTX 3060, sin VSync,
audio silenciado, 500 IA, 40 cuadros de calentamiento y 600 muestras por
caso. Milisegundos entre cuadros (media / p95 / peor):

| Destino | Control | Completo |
|---|---|---|
| Casa | 15,65 / 20,81 / 29,59 | 20,54 / 27,32 / 36,60 |
| Museo | 15,08 / 20,73 / 25,82 | 19,72 / 25,86 / 29,60 |
| Coliseo | 13,98 / 20,70 / 26,54 | 17,72 / 25,40 / 34,56 |
| Eiffel | 13,97 / 19,91 / 30,48 | 18,23 / 25,48 / 34,78 |

Ocho casos / 0 fallas, navegación y extracción reales, pools acotados y
sin actividad nueva tras cerrar. Log `main_integrado_perfil_estimulos.log`.
No es un A/B causal de rendimiento respecto de la versión anterior: cambió
el trabajo por bocado y no se aisló la carga de la máquina. El p95 supera
16,67ms; no garantiza 60 FPS constantes, CPU aislada, audio ni GPU integrada.
