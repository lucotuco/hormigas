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
