# Audio y sensación — 2/11/2026

El objetivo es distinguir **extraer → levantar → transportar → entregar** y
reservar una respuesta más grande para una victoria real. No se acredita
dinero desde el audio o las partículas, ni se simula una entrega que no llegó.

## Referencias consultadas y límites

Consulta web realizada el **2026-11-02**, sólo a fuentes públicas. No se descargó
ni copió ninguna grabación, melodía o muestra de esos juegos.

| Referencia primaria | Qué se pudo verificar |
|---|---|
| [Cookie Clicker: banda sonora oficial](https://store.steampowered.com/app/1738020/Cookie_Clicker_Soundtrack/) | Créditos a C418 y repertorio oficial; la presentación describe una escucha tranquila. |
| [Rusty's Retirement OST, del compositor Lars Asger](https://larsasger.bandcamp.com/album/rustys-retirement-ost) | Siete pistas del juego; el compositor identifica su intención acogedora y lo-fi. |
| [Rusty's Retirement, ficha del desarrollador](https://store.steampowered.com/app/2666510/Rustys_Retirement/) | Juego relajado que convive con otras tareas; referencia de baja invasividad, no especificación de sus efectos. |
| [Berry Bury Berry, ficha oficial](https://store.steampowered.com/app/3370870/Berry_Bury_Berry/) | Bucle físico de cultivar y arrojar bayas; referencia de distinguir acción y resultado. |
| [Chop Chains, ficha oficial](https://store.steampowered.com/app/4139720/Chop_Chains/) | Cortar, recoger y mejorar se presentan como acciones separadas de un incremental relajado. |
| [Fortune Mill, ficha oficial](https://store.steampowered.com/app/4731620/Fortune_Mill/) | Varios minijuegos con automatización y sinergias; referencia de contraste entre acción repetida y resultado importante. |

Las páginas identifican las obras y su intención; **no se escucharon ni
midieron sus trailers o grabaciones con esta herramienta**. No se atribuyen
a esos juegos milisegundos de ataque, notas, variación de tono, capas ni
límites de voces. Tampoco se deduce que un sonido explique su éxito.
La separación de gestos, la mezcla tranquila y el contraste entre repetición
y premio son criterios inspirados en ese contexto. Los parámetros concretos
siguientes son **autoría de este proyecto**, sujetos a escucha humana.

## Banco propio

El archivo global/audio_suave.gd sintetiza el banco una sola vez. Usa PCM mono
de 16 bits a 22.050 Hz; osciladores senoidales, un armónico breve, ruido filtrado
y semilla privada fija. No hay archivos remotos, streaming de red ni samples
extraídos de otro juego. El ataque se suaviza en 6–9 ms y el final tiene salida
gradual para evitar discontinuidades; la suite inspecciona amplitud y extremos,
no puede demostrar agrado ni ausencia perceptiva de fatiga.

| Gesto | Duración base | Intención |
|---|---:|---|
| Mordida alimentaria | 55 ms | Crujido pequeño amortiguado. |
| Cartón / madera / metal / piedra | 70 / 75 / 85 / 85 ms | Timbres distintos sin alarma aguda por hormiga. |
| Recogida de montón | 40 ms | Gesto separado de arrancar material. |
| Entrega | 130 ms | Confirmación cálida, base 392/587,33 Hz; cinco grados pentatónicos acotados. |
| Clic / compra / rechazo | 90 / 280 / 160 ms | Interacción, confirmación y acción no disponible. |
| Aviso / espantar | 240 / 100 ms | Tiempo para reaccionar; sin fanfarria por cada clic. |
| Épico | 850 ms | Acorde arpegiado desde 196 Hz con cuerpo grave, sólo para victoria o hito real. |

La escala de entrega vuelve al inicio tras cinco grados; no sube eternamente
con un combo enorme. Sus factores 0,8 / 0,9 / 1 / 1,2 / 4/3 conservan los
intervalos pentatónicos incluso con variación, sin chocar los límites.
El tono se limita a 0,65–1,6. La variación pedida se
limita al 8%; entrega y celebración usan 1,2%. Las duraciones de la tabla son
del WAV base: la duración escuchada cambia con el tono aplicado en ejecución.

## Puertas, reutilización y cierre

- Dieciséis reproductores globales: diez para mundo y seis reservados para
  interfaz/hitos. Una mordida no corta una compra para conseguir una voz.
- Todos los materiales y la recogida comparten una puerta de 180 ms:
  como máximo seis inicios en una ventana de un segundo. La entrega conserva
  su puerta de 110 ms; el épico, 900 ms; el aviso, 700 ms.
- Sonido.entrega(combo, especial) sólo presenta la entrega confirmada.
  Sonido.detener_mundo() frena voces de la expedición; UI y cierre pueden
  completar su acorde. Silenciar detiene las voces y no consume sus puertas.
- Efectos.entrega(...) admite un pulso cada 100 ms, de cuatro a ocho partículas
  y una onda. Efectos.epico(...) admite una ráfaga cada 750 ms, de hasta
  36 partículas y dos ondas. No construyen nodos por efecto.
- Un solo lienzo comparte hasta 600 partículas, 24 ondas, 40 textos almacenados
  y hasta diez visibles. Partículas y ondas se reutilizan; el procesamiento se
  apaga cuando no hay efectos ni puertas pendientes. El azar visual es privado
  y no consume el generador de enemigos/IA.
- Efectos.limpiar() y Eventos.cerrar() son terminales por instancia:
  callbacks tardíos no reaniman partículas, premios o enemigos de una run cerrada.

Estos límites acotan trabajo y memoria, pero **no garantizan 60 FPS** ni
representan un benchmark. Hay que medir con renderer real, sin otras pruebas
concurrentes y en equipos modestos, además del equipo de desarrollo.

## Amenazas y participación

Se conservan las amenazas originales y alternan dos variantes: la cucaracha
arranca una porción real de alimento; el escarabajo prefiere montones ya
extraídos y necesita cargarlos antes de huir. No agregan IA por hormiga.
Ambos tienen aviso de entrada de 1,5 s y carga anunciada de 1,8 s;
se espantan con tres o dos clics, no con una secuencia ilimitada.

El límite es **tres individuos reales**, incluso cuando son palomas, y como
máximo una miga dorada adicional. Las amenazas de captura respetan un máximo
de ocho capturas por individuo y no se llevan a la última trabajadora.
Su tamaño/hitbox está en unidades de mundo, no aumenta al alejar la cámara.
Las animaciones se redibujan a 24 Hz; la lógica conserva su paso normal.

La espera posterior queda entre 12 y 22 s según destino/presión. Se conserva
el botín original: la mayor frecuencia **puede aumentar el ingreso del juego
activo**. No es una comparación de economía idéntica ni una prueba de duración
de campaña. Falta observar invasividad y decisiones reales con personas.

Un robo usa un origen transitorio explícito: retirar la última porción no
dispara bonus de destrucción, estadística ni celebración de la colonia.
El botín se recupera sólo al vencer la amenaza. Si roba papel, el contenido
se revela físicamente, pero el hallazgo no se adjudica al jugador.
El origen se restaura tras robos parciales para conservar el bonus de un
trabajo normal posterior; el silbato también bloquea el retiro entero tardío.

## Exportación para escuchar

La fuente ejecutable es AudioSuave.crear(nombre), la misma que carga el
autoload. La suite tests/prueba_feedback_amenazas.tscn exporta sus WAV sólo
si se inicia con EXPORTAR_AUDIO_QA=1. Van a .godot/qa/audio_feedback/,
no a assets versionados ni a la partida personal. Sin esa variable, la suite
no escribe audio. Son WAV base: no incluyen el cambio de tono del combo
ni la mezcla de varias voces en ejecución.

Las pruebas headless validan forma de onda, puertas, identidad de los timbres,
pool, conservación de dinero y cierre. **No son una escucha ni una medición
de latencia del dispositivo de audio.**

## Diez pasos de escucha humana

1. Exportar los WAV a QA y reproducirlos en un cuarto tranquilo, con volumen
   moderado y el dispositivo que se usará al jugar. No subir el volumen
   sólo para lograr que una mordida dé más satisfacción.
2. Escuchar mordida y recogida por separado: distinguir material y gesto
   sin necesitar una nota más aguda o un golpe más fuerte.
3. Comparar principio y final de cada WAV: descartar clics digitales, recortes,
   silencios molestos y colas que invadan la acción siguiente.
4. Comparar entrega, compra y rechazo al mismo volumen del juego: deberían
   comunicar estados distintos aun sin mirar la pantalla.
5. Jugar desde cero con una obrera: observar extracción, carga y primera entrega.
   Verificar que el pulso llegue con el depósito, no cuando todavía camina.
6. Mantener una sucesión de entregas durante un minuto. Escuchar los cinco
   grados reales del combo, no sólo el WAV base; anotar fatiga y repetición.
7. Comprar varias mejoras mientras la colonia trabaja: comprobar que su
   confirmación no se pierda ni quede tapada por mordidas.
8. Probar una amenaza sin vencerla, luego espantarla: distinguir aviso, golpes
   y victoria. Esperar/hacerla huir no debe fabricar una celebración de victoria.
9. Repetir en un escenario controlado de 500 hormigas, cerca y lejos de cámara:
   escuchar densidad, contraste y saturación. Medir rendimiento aparte; el
   silencio o la música no deben esconder un problema de cuadros.
10. Salir durante una carga y un evento; abrir otra expedición,
    silenciar/reactivar y pausar. No deben quedar sonidos/partículas viejos.
    Repetir una sesión de 15–20 minutos y registrar dispositivo, volumen,
    preferencias y molestias antes de afirmar que el audio quedó satisfactorio.
