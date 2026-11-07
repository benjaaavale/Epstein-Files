# Mansión Ebner: guía del nivel

`diseño_pruebafinal.tscn` es la escena principal (Play / F5). Trae su propio menú (`MenuInicio`,
`menu_mansion.gd`), que se monta sobre la mansión con una cámara recorriendo el hall.
Al reiniciar desde la pausa o el final se entra directo, sin menú (`Ajustes.saltar_menu`).

## Recorrido de puzzles

| # | Dónde | Qué hay que hacer | Da |
|---|-------|-------------------|----|
| 1 | Cuarto de servicio (inicio) | Tomar el filtro rojo de la mesa. Con luz roja aparecen pisadas de sangre que llevan a una caja con la llave. | Salida al hall |
| 2 | Hall | La puerta principal "no gira" (le falta energía). La llave dorada de la mesita es una **trampa**: se parte en la cerradura. | Susto |
| 3 | Salón (planta baja, norte) | Con luz roja cada retrato muestra un número romano. Enderezarlos en orden I→IV (si te equivocas, se tuercen todos). | Abre la alacena con el **filtro azul** |
| 4 | Biblioteca | Con luz azul aparece en la pared el código **0417** y "el cofre duerme arriba, junto a su cama". | Código |
| 5 | Dormitorio (2° piso, oeste) | Cofre a los pies de la cama, candado 0417. | **Filtro violeta**, diario y una pila |
| 6 | Rellano (2° piso) | Con luz morada (Shift + clic) se borra la pared falsa del lado este. | Cuarto sellado |
| 7 | Cuarto sellado | Altar con la **llave antigua**. Al tomarla se cortan las velas y aparece "Ella". | Llave de la salida |
| 8 | Hall, junto a la puerta | Con luz morada se ven tres cables enredados. Solo el de la palanca II llega al cerrojo de la puerta; las otras dan chispazo y apagón. | Energía |
| 9 | Puerta principal | Llave antigua. | Fin |

Extra: con luz morada, la pared oeste del hall esconde el cuarto de los seis desaparecidos (screamer del retrato).

## Archivos nuevos o cambiados

- `guion_mansion.gd`: objetivos en pantalla, monólogos por lugar o luz, sustos. `guion_nivel1.gd` queda para la escena chica.
- `mapa/superficie_sucia.gdshader` + `mapa/mugre.gdshaderinc`: suciedad procedural (humedad, chorreos, manchas de techo, moho, grietas, papel despegado). Se regula con `mugre`, `descascarado`, `grietas` y `humedad_altura` en cada material.
- `filtro_linterna.tscn`: los filtros ahora son lentes redondos en un soporte.
- `hud.gd`: candado con flechas / números / clic, línea de objetivo, ayuda de luces.
- `muros_secretos.gd`: la máscara se dibuja sobre la cara de la pared; al borrar ~45 % se desvanece y deja pasar.
- `mapa/escrito.gd`: algo pintado que solo se ve con un color de luz (pistas y frases).
- `mapa/deco/`: cama, ropero, mesa de comedor, muebles tapados, cuadros, espejo, muñeca, altar, banca, cuna, perchero, papeles, libros.
