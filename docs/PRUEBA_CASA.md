# Probar la casa hasta la primera fundación

Objetivo: comprobar que alguien entiende y quiere repetir el ciclo, no sólo
que los scripts funcionan. Las pruebas automáticas y el bot no responden eso.

## Sesión aislada para jugar

1. Abrí el proyecto con Godot **4.7.2**.
2. Abrí `tests/sesion_casa.tscn` y ejecutá esa escena con **F6**, no el juego
   normal con F5. El menú debe indicar que es una sesión de prueba.
3. Jugá normalmente: el ensayo empieza desde cero en memoria. La carga inicial
   de los autoloads no se usa para progresar y se deshabilitan las escrituras
   de partida/configuración antes de permitir interacciones. No borra archivos.
4. **F7** abre/cierra el informe y conserva la pausa que había antes. **F8**
   sigue deteniendo la ejecución desde Godot. F1/F2/F9 no dan dinero ni borran
   durante el ensayo.
5. Si quieren conservar resultados, elegí **Exportar informe JSON** y un archivo
   nuevo. No se exporta automáticamente, no se envía nada y no contiene nombres,
   archivos personales ni la partida completa. Cerrar la ejecución descarta el
   progreso del ensayo. Después F5 vuelve al juego y a la partida normal.

El informe guarda las primeras compras/dietas/hitos/fundación, hasta 256 eventos
y las últimas 32 expediciones. Las pausas no suman tiempo activo. El primer
ingreso se observa a 10 Hz y puede incluir premios o corrosión: **no es una
medición de primera entrega**. Las compras y los hitos se registran por señal.
No inspecciona cada hormiga ni añade procesos al juego normal.

## Cómo observar sin enseñar

Hagan primero 5–10 sesiones con personas que no hayan visto el proyecto.
No explicar controles ni recomendar compras mientras juegan; registrar cada
intervención si de verdad necesitan ayuda. Evitar que todos vean antes una
demostración hecha por ustedes.

Anotar, con permiso para observar su juego:

- Cuándo entienden que la colonia trabaja sola y para qué sirve el llamado.
- Si notan recortes/fragmentos y quieren probar un mueble nuevo.
- Qué compra eligen, qué creen que cambiará y si después pueden reconocerlo.
- Cuándo no saben qué hacer, esperan sin propósito, piden ayuda o quieren salir.
- Si entienden qué pierden/conservan al fundar y si el regreso se siente más fuerte.
- Si eligen otra expedición por iniciativa propia, sin pedirles que sigan.

Al terminar preguntar sin sugerir respuestas: “¿qué momento recordás?”,
“¿qué cambiarías primero?” y “¿cómo se lo describirías a un amigo?”. El informe
no reemplaza esas respuestas ni registra conversaciones.

Como criterios internos de avance hacia una demo: la mayoría puede identificar
su próximo objetivo y anticipar una compra sin ayuda; reconoce la diferencia
tras fundar; no necesita el llamado para reparar una IA detenida; y puede
recordar un momento propio del juego. Son objetivos de diseño, no porcentajes
de éxito comercial ni resultados ya obtenidos.

## Equipos y rendimiento

Probar también una GPU integrada, una sesión de al menos una hora y repetidos
alt-tab/capturas. Comprobar que pausa, arrastre y feromonas se liberan y reanudan
bien. Mantener el tope de 500 y el presupuesto de seis rutas por cuadro.
Medir cuadro medio/p95/picos con renderer real; headless no mide FPS. No abrir
varios perfiles simultáneamente. Los resultados RTX 3060 son sólo una referencia.

## Después de esta validación

Primero corregir lo observado en este recorrido; después extender aprendizajes
a los destinos tardíos y definir su cierre sin impedir seguir creciendo.
Para una demo pública faltan distribución/exportación, pruebas en otras PCs,
identidad y audio final, página de Steam y revisión humana de traducciones.
Esta herramienta F6 no se presenta como una demo comercial terminada.

Un primer clip debe mostrar gameplay real: migas → recortes de una silla →
compra visible → colonia más capaz. No acelerar la simulación para prometer
tiempos irreales ni usar un render que no exista jugando. La fantasía que se
quiere comunicar es una colonia pequeña que termina desarmando una casa.
