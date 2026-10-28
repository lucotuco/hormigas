# Medición gráfica — 27/10/2026

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
