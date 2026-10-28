# Idiomas

El juego está en **español** (el idioma del código) e **inglés** (`en.po`).

- Todo texto que ve el jugador se escribe en español dentro de `tr("…")`.
  Los textos de `/datos` (nombres y descripciones de mejoras, castas, comidas y
  el árbol de la reina) y las constantes de nombres (`Mundos.INFO`, `HITOS`…)
  se traducen al mostrarse: `tr(m.nombre)`.
- Los nodos no se traducen solos (`auto_translate_mode` desactivado en la raíz):
  si te olvidás un `tr()`, la prueba lo encuentra.
- Si cambia un formato, mantené los mismos `%d` / `%s` en el mismo orden.
  Para plurales, dos textos enteros ("1 colonia fundada" / "%d colonias
  fundadas"), nunca pegar pedazos.

## Agregar o cambiar un texto

1. Escribilo en español con `tr()`.
2. Corré `tests/prueba_idiomas.tscn`: imprime el bloque que falta, listo para
   pegar en `en.po`, y avisa si sobra alguna traducción vieja.
3. Completá `msgstr` con el inglés.

Para ver una pantalla en inglés: `IDIOMA=en godot --path . res://tests/revision_jalea.tscn`.
