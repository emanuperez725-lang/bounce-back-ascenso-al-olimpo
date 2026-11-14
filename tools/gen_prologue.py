"""Generates the prologue room scenes (scenes/rooms/*.tscn) and scenes/game.tscn.

LEGACY: rooms now live as editable scenes (see tools/bake_rooms.gd).
Run from the project root:  python tools/gen_prologue.py [room names...]
Writes only rooms whose scene does not exist yet, plus any room named on the command
line (that one is OVERWRITTEN, hand edits lost). Then run tools/bake_rooms.gd.
Layout chars: # swamp rock, G mossy rock (climbable), ^ swamp water, B blue mushroom (bounce), M slime, A Ambrosia Apple (ends the game),
P spawn, S stone idol, H idol of Hermes (dash). 16 px tiles, 40x23 = 640x368.
Rooms can also be edited by hand afterwards (Inspector > layout).
"""
import pathlib
import random
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
W, H = 40, 23
FLOOR = 20  # top row of the ground


def new():
    return [["."] * W for _ in range(H)]


def fill(g, x, y, w, h, c="#"):
    for j in range(y, y + h):
        for i in range(x, x + w):
            g[j][i] = c


def base(g, exit_right=True):
    fill(g, 0, 0, W, 1)
    fill(g, 0, 0, 1, H)
    fill(g, W - 1, 0, 1, H)
    fill(g, 0, FLOOR, W, H - FLOOR)
    if exit_right:
        fill(g, W - 1, FLOOR - 5, 1, 5, ".")
    g[FLOOR - 1][2] = "P"


def pit(g, x, w):
    """Gap in the floor, two tiles deep, swamp water at the bottom."""
    fill(g, x, FLOOR, w, 2, ".")
    fill(g, x, FLOOR + 1, w, 1, "^")


def enter(g, top, floor, w=3):
    """Doorway in the left wall at the previous room's exit rows; spawn on its sill."""
    g[FLOOR - 1][2] = "."
    fill(g, 0, top, w + 1, floor - top, ".")
    if floor < FLOOR:
        fill(g, 1, floor, w, FLOOR - floor)
    g[floor - 1][2] = "P"


def roof(g, x0, x1, bottom, seed):
    """Rock from the ceiling down to `bottom` (row), jagged upward only, with rare
    one-tile drips. Bottoms are chosen per room so a full jump never hits it."""
    rnd = random.Random(seed)
    d = bottom
    for x in range(x0, x1 + 1):
        if rnd.random() < 0.4:
            d = max(bottom - 2, min(bottom, d + rnd.choice((-1, 1))))
        fill(g, x, 1, 1, d)
        if rnd.random() < 0.12:
            g[d + 1][x] = "#"


rooms = []  # (file, grid, title, inscriptions, stuck_hint)
DUNGEON = {"p_04_muro_musgo", "p_05_chimenea", "p_15_torre"}  # old ruins inside the swamp: Dungeon Tile Set
# Kira (16x24 px) jumps ~3.5 tiles up and ~6 across while climbing 3. Each room's
# left doorway sits at the previous room's exit rows.

# 1. The swamp under Olympus: Kira fell from the mountain and wakes in the mud.
g = new(); base(g); g[19][7] = "S"
roof(g, 1, 38, 11, 1)
rooms.append(("p_01_pantano", g, "BOUNCE BACK\nAscenso al Olimpo", [
    "Kira cayó del Olimpo con la Manzana de Ambrosía a un paso.\n"
    "Melina se vuelve piedra desde los pies hacia el corazón. "
    "Desde el fondo del pantano, solo queda un camino: hacia arriba.",
], "← →  caminar   ·   stick / cruceta"))

# 2. Toppled stones climbing to a high gap; water waits between them.
g = new(); base(g, exit_right=False)
fill(g, 8, 17, 5, 3); fill(g, 16, 14, 5, 6); fill(g, 24, 11, 5, 9); fill(g, 32, 8, 7, 12)
pit(g, 13, 3); pit(g, 21, 3); pit(g, 29, 3)  # fall between stones = back to the door
roof(g, 1, 7, 12, 2); roof(g, 8, 15, 9, 3); roof(g, 16, 23, 6, 4); roof(g, 24, 31, 3, 5); roof(g, 32, 38, 1, 6)
fill(g, W - 1, 3, 1, 5, ".")
enter(g, 15, 20)
rooms.append(("p_02_piedras", g, "", [], "C (A)  saltar   ·   mantenlo para llegar más alto"))

# 3. Black water: two pools, a mushroom in the second throws Kira back up.
g = new(); base(g, exit_right=False); g[19][8] = "S"
pit(g, 12, 4)
fill(g, 16, 18, 8, 2)                       # slab, 2 up
pit(g, 24, 5); g[21][26] = "B"              # mushroom in the pool: fall, bounce back
fill(g, 29, 17, 10, 3)                      # far terrace, 1 more up
roof(g, 1, 11, 2, 7); roof(g, 12, 23, 10, 8); roof(g, 24, 38, 9, 9)
fill(g, W - 1, 11, 1, 6, ".")
enter(g, 3, 8)                              # high door from the stones' top
rooms.append(("p_03_aguas", g, "", [
    "El agua del pantano pesa como la derrota.\n"
    "Pero los hongos azules devuelven hacia arriba todo lo que cae sobre ellos.",
], "Mantén C para saltar más lejos   ·   cae sobre el hongo azul"))

# 4. The mossy wall: moss = grip, in a shaft up to the exit. Bare rock gives no grip.
g = new(); base(g, exit_right=False); g[19][16] = "S"
fill(g, 25, 10, 14, 10)
fill(g, 25, 10, 1, 10, "G")
roof(g, 1, 21, 10, 10); roof(g, 22, 24, 3, 11); roof(g, 25, 38, 2, 12)
fill(g, W - 1, 4, 1, 6, ".")
enter(g, 11, 17)
rooms.append(("p_04_muro_musgo", g, "", [
    "Donde crece el musgo, los dedos se aferran. La roca desnuda no perdona.\n"
    "[ Z  aferrarse   ·   ↑ ↓  trepar ]",
], "Z (gatillo) + ↑ para trepar   ·   arriba del todo, salta con C"))

# 5. The drowned ruins: drop into the hall, duck under the hanging rock,
#    wall-jump up the smooth chimney to the corridor out right.
g = new(); base(g, exit_right=False)
fill(g, 1, 1, 38, 2)                        # corridor roof
fill(g, 20, 3, 6, 13)                       # hanging rock: chimney's left wall
fill(g, 30, 7, 9, 13)                       # rock; its top is the corridor floor
fill(g, W - 1, 3, 1, 4, ".")
enter(g, 4, 10)
rooms.append(("p_05_chimenea", g, "", [], "C pegado a un muro  rebota hacia el otro"))

# 6. The drowned shrine: Hermes' idol keeps the Winged Sandals. The pool beyond needs them.
g = new(); base(g); g[19][11] = "S"; g[19][14] = "H"
pit(g, 17, 11)
roof(g, 8, 38, 10, 13)
enter(g, 3, 7)
rooms.append(("p_06_santuario", g, "", [
    "Un ídolo de Hermes, hundido en el pantano.\n"
    "Hasta los dioses caen. Algunos se levantan.",
    "LAS SANDALIAS ALADAS\n"
    "Un único impulso en el aire. La tierra firme las recarga.\n"
    "[ X  impulso   ·   + dirección ]",
], "Salta (C) y en el aire pulsa X"))

# 7. The frogs croak: escape up the high ledge with an upward dash.
g = new(); base(g, exit_right=False); g[19][11] = "S"
fill(g, 23, 13, 16, 7)
roof(g, 1, 38, 5, 14)
fill(g, W - 1, 7, 1, 6, ".")
enter(g, 15, 20)
rooms.append(("p_07_ranas", g, "", [
    "Las ranas callan. El bosque sabe que no te rindes.",
], "Mantén ↑ y pulsa X   ·   las sandalias van hacia donde apuntes"))

# 8. Two pools, one island. Gold sandals = charged, white = spent.
g = new(); base(g)
pit(g, 7, 10); pit(g, 26, 10)
roof(g, 1, 38, 5, 15)
enter(g, 7, 13, w=6)                        # sill runs to the first pool
rooms.append(("p_08_charcas", g, "", [], "Sandalias doradas = impulso listo   ·   pisar tierra las recarga"))

# 9. The mossy gate: two pillars to climb over.
g = new(); base(g); g[19][19] = "S"
roof(g, 1, 38, 3, 16)
fill(g, 24, 10, 2, 10, "G"); fill(g, 32, 10, 2, 10, "G")  # mossy pillars: climb and hop over
enter(g, 15, 20)
rooms.append(("p_09_puerta", g, "TRAMO I\nLa Puerta del Bosque", [
    "Arriba, el Olimpo. Abajo, el pantano.\nNo hay vuelta atrás.",
], "Sigue a la derecha"))

# 10. What falls, rises: blue mushrooms throw Kira up terraces no jump can reach.
g = new(); base(g, exit_right=False)
fill(g, 12, 14, 6, 6); fill(g, 20, 8, 10, 12); fill(g, 32, 4, 7, 16)
pit(g, 18, 2); pit(g, 30, 2)                # missed bounce = back to the door
g[19][10] = "B"; g[13][17] = "B"; g[7][29] = "B"; g[3][35] = "S"
fill(g, W - 1, 1, 1, 3, ".")                # exit at the very top
enter(g, 15, 20)
rooms.append(("p_10_rebote", g, "LO QUE CAE, SE LEVANTA", [
    "Caíste, y te levantaste.\n"
    "El Olimpo no premia al que nunca cae, sino al que vuelve.",
], "Pisa el hongo azul: te devuelve hacia arriba"))

# --- TRAMO II: the roots. Every room mixes what Kira already knows. -----------

# 11. Down the roots: drop from step to step, a mushroom throws her back up.
g = new(); base(g, exit_right=False)
pit(g, 4, 22)
fill(g, 6, 8, 4, 2); fill(g, 13, 12, 4, 2); fill(g, 18, 15, 4, 2)
g[14][20] = "B"; g[14][21] = "B"
fill(g, 24, 10, 15, 10)
fill(g, W - 1, 5, 1, 5, ".")
enter(g, 1, 4)
rooms.append(("p_11_raices", g, "TRAMO II\nLas Raíces", [], "Déjate caer   ·   el hongo te devuelve arriba"))

# 12. The tall moss: jump the pool, climb the mossy cliff to the top.
g = new(); base(g, exit_right=False)
pit(g, 13, 4)
fill(g, 17, 17, 6, 3)
fill(g, 23, 8, 16, 12); fill(g, 23, 8, 1, 12, "G")
g[19][7] = "S"
fill(g, W - 1, 3, 1, 5, ".")
enter(g, 5, 10)
rooms.append(("p_12_musgo_alto", g, "", [
    "Las raíces del Olimpo beben de este pantano.\n"
    "Quien sube por ellas, sube por la montaña.",
], "Z + ↑ en el musgo   ·   no te sueltes hasta arriba"))

# 13. Stepping pillars over black water: two of the gaps need the sandals.
g = new(); base(g, exit_right=False)
pit(g, 6, 33)
fill(g, 15, 10, 5, 12); fill(g, 28, 9, 4, 13); fill(g, 36, 8, 3, 14)
fill(g, W - 1, 3, 1, 5, ".")
enter(g, 3, 8, w=5)
rooms.append(("p_13_pilares", g, "", [], "Salta y en el aire pulsa X   ·   tocar piedra recarga"))

# 14. Mushroom chain: never touch the water, bounce from cap to cap.
g = new(); base(g, exit_right=False)
pit(g, 4, 35)
fill(g, 7, 16, 4, 6); g[15][8] = "B"; g[15][9] = "B"
fill(g, 16, 14, 4, 8); g[13][17] = "B"; g[13][18] = "B"
fill(g, 25, 12, 4, 10); g[11][26] = "B"; g[11][27] = "B"
fill(g, 33, 9, 6, 13)
fill(g, W - 1, 4, 1, 5, ".")
enter(g, 3, 8)
rooms.append(("p_14_cadena", g, "", [], "Mantén → y deja que los hongos te lleven"))

# 15. The sunken tower (old ruins): climb the mossy pillar, cross the flooded hall.
g = new(); base(g, exit_right=False)
fill(g, 12, 8, 3, 12); fill(g, 12, 8, 1, 12, "G")
pit(g, 15, 24)
fill(g, 18, 8, 5, 2); fill(g, 27, 8, 12, 14)
g[7][33] = "S"
fill(g, W - 1, 3, 1, 5, ".")
enter(g, 4, 9)
rooms.append(("p_15_torre", g, "", [
    "Una torre de los hombres, tragada por el pantano.\n"
    "Ellos también cayeron. Ellos también volvieron a construir.",
], "Trepa el pilar de musgo   ·   salta de losa en losa"))

# 16. Rain steps: walk down the stairs, then jump and dash over the pools.
g = new(); base(g)
fill(g, 5, 11, 3, 9); fill(g, 8, 14, 3, 6); fill(g, 11, 17, 3, 3)
pit(g, 18, 4); pit(g, 25, 8)
roof(g, 12, 38, 9, 21)
enter(g, 3, 8, w=4)
rooms.append(("p_16_escalones", g, "", [], "El charco grande necesita salto + X"))

# 17. The way out: three mushrooms up to the last idol.
g = new(); base(g, exit_right=False)
pit(g, 13, 26)
g[19][6] = "B"
fill(g, 8, 15, 5, 5); g[14][12] = "B"
fill(g, 16, 9, 5, 2); g[8][20] = "B"
fill(g, 24, 4, 15, 2); g[3][30] = "S"
fill(g, W - 1, 1, 1, 3, ".")
enter(g, 15, 20)
rooms.append(("p_17_salida", g, "FIN DEL TRAMO II", [
    "Cada caída te trajo hasta aquí.\n"
    "Más arriba, algo se mueve en el musgo. Y escupe.",
], "Camina hacia el hongo"))

# --- TRAMO III: the slimes. Parry their globs and they fly back (M = slime). ----

# 18. First slime, in a low tunnel: parry its glob to pop it.
g = new(); base(g, exit_right=False)
fill(g, 22, 1, 17, 16)                      # tunnel roof: rows 17-19 stay open
g[19][8] = "S"; g[19][33] = "M"
fill(g, W - 1, 17, 1, 3, ".")
enter(g, 1, 4)
rooms.append(("p_18_primer_slime", g, "TRAMO III\nLos Slimes", [
    "PARRY\n"
    "Pulsa A (Y) justo antes de que el escupitajo te toque: rebota hacia el slime.\n"
    "Lo que te lanzan, se lo devuelves.",
], "A (Y) justo antes del impacto"))

# 19. Acid pools: a slime guards the middle stump, another the far bank.
g = new(); base(g)
pit(g, 6, 29)
fill(g, 10, 17, 4, 5); fill(g, 17, 15, 5, 7); fill(g, 27, 17, 4, 5)
g[14][17] = "M"; g[19][37] = "M"
enter(g, 17, 20)
rooms.append(("p_19_charcas_acidas", g, "", [], "Devuelve el escupitajo antes de saltar"))

# 20. The watched wall: climb the moss while a slime on the ledge spits at you.
g = new(); base(g, exit_right=False)
fill(g, 24, 8, 15, 12); fill(g, 24, 8, 1, 12, "G")
fill(g, 8, 9, 6, 1); g[8][10] = "M"
fill(g, W - 1, 3, 1, 5, ".")
enter(g, 15, 20)
rooms.append(("p_20_muro_vigilado", g, "", [], "Puedes hacer parry mientras trepas"))

# 21. The slime court: three slimes between Kira and the last idol.
g = new(); base(g)
fill(g, 20, 14, 5, 1)
g[19][14] = "M"; g[13][22] = "M"; g[19][31] = "M"; g[19][36] = "S"
enter(g, 3, 8)
rooms.append(("p_21_corte", g, "EL REY DEL PANTANO", [
    "Te escupieron, y lo devolviste. Caíste, y volviste.\n"
    "Arriba esperan las nubes del Olimpo, y Melina.",
], "A (Y): parry   ·   espera a que escupan"))

# 22. The summit: the last bounces up to the Ambrosia Apple (A). Taking it ends the game.
g = new(); base(g, exit_right=False)
fill(g, 12, 14, 6, 6); fill(g, 20, 8, 8, 12); fill(g, 30, 8, 9, 12)
pit(g, 18, 2); pit(g, 28, 2)
g[19][10] = "B"; g[13][17] = "B"; g[7][23] = "S"; g[7][35] = "A"
enter(g, 15, 20)
rooms.append(("p_22_cima", g, "LA CIMA", [
    "Una voz, desde las nubes:\n"
    "«Me robaste las sandalias, niña. Y aun así, cada vez que caíste, volviste a subir.»",
], "Pisa el hongo azul"))


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


out = ROOT / "scenes" / "rooms"
out.mkdir(parents=True, exist_ok=True)
for name, g, title, texts, hint in rooms:
    assert len(g) == H and all(len(r) == W for r in g)
    if (out / f"{name}.tscn").exists() and name not in sys.argv:
        continue  # baked and maybe hand-edited: keep it
    print("writing", name)
    layout = "\n".join("".join(r) for r in g)
    node = "".join(p.capitalize() for p in name.split("_"))
    lines = ['[gd_scene load_steps=2 format=3]', '',
             '[ext_resource type="Script" path="res://scripts/room.gd" id="1_room"]', '',
             f'[node name="{node}" type="Node2D"]', 'script = ExtResource("1_room")',
             f'title = {q(title)}', f'layout = {q(layout)}',
             f'inscriptions = Array[String]([{", ".join(q(t) for t in texts)}])',
             f'stuck_hint = {q(hint)}'] + (['style = "dungeon"'] if name in DUNGEON else []) + ['']
    (out / f"{name}.tscn").write_text("\n".join(lines), encoding="utf-8", newline="\n")

game = [f'[gd_scene load_steps={len(rooms) + 3} format=3]', '',
        '[ext_resource type="Script" path="res://scripts/game.gd" id="1_game"]',
        '[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="2_player"]']
ids = []
for i, (name, *_rest) in enumerate(rooms):
    game.append(f'[ext_resource type="PackedScene" path="res://scenes/rooms/{name}.tscn" id="r{i + 1}"]')
    ids.append(f'ExtResource("r{i + 1}")')
game += ['', '[node name="Game" type="Node2D"]', 'script = ExtResource("1_game")',
         f'rooms = Array[PackedScene]([{", ".join(ids)}])', '',
         '[node name="Player" parent="." instance=ExtResource("2_player")]',
         'position = Vector2(40, 308)', 'dash_unlocked = false', '']
(ROOT / "scenes" / "game.tscn").write_text("\n".join(game), encoding="utf-8", newline="\n")
print("generated", len(rooms), "rooms")
