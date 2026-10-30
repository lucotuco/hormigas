# Rendimiento gráfico y memoria

La medición vigente de cuerpo/sombra y contacto exterior está al final,
en **30/10/2026**.
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
