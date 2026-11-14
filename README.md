# Bounce Back: Ascenso al Olimpo

Plataformas de precisión hecho en Godot 4.7 para un hackathon con el tema **bounce back**.

Kira cae del Olimpo al pantano a un paso de la Manzana de Ambrosía, la única cura para Melina, que se está volviendo piedra. Para llegar a la cima tiene que volver a levantarse: rebota en hongos azules, devuelve los escupitajos de los slimes con un parry y sigue subiendo.

## Controles

| Acción | Teclado | Mando |
|---|---|---|
| Moverse | Flechas | Stick / cruceta |
| Saltar | C | A |
| Impulso (sandalias de Hermes) | X | X / B |
| Agarrarse al musgo | Z | Gatillo |
| Parry | A | Y |

## Abrir y editar

Abre `project.godot` con Godot 4.7. Las salas están en `scenes/rooms/` y son escenas normales:

- **Capas de tiles:** `Terrain`, `Moss`, `Water`, `Rims` y `Backdrop`.
- **Props:** `Spawn`, `Idol`, `Mushroom`, `Slime` y `AmbrosiaApple`.

## Exportar a web

```
godot --headless --path . --export-release "Web" build/web/index.html
```

El build es sin hilos (`thread_support=false`), así que funciona en itch.io y en GitHub Pages sin cabeceras especiales.

## Créditos

- Fantasy Swamp Forest: @theflavare
- Super Pixel Effects Gigapack: Will Tice / unTied Games
- 2D Platformer Character Template (base de Kira y Melina)
- BoldPixels: YukiPixels, CC BY-SA 4.0
- Paper UI System: Humble Gift
- Dungeon Tile Set
- 32x32 Isometric Slimes

Los packs de terceros siguen bajo sus propias licencias y solo se incluyen los archivos que usa el juego.
