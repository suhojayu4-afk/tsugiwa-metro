"""Things beside the line for the trip view, modelled and rendered in Blender
(the same light and scale as tools/blender/train3d.py): level crossing,
signal, trackside hut, utility pole, sound wall, truss bridge (its back and
front sides apart, so the train runs between them), bridge pier, tunnel
portal. Each is seen from the side, a little from above. Two passes:

  base  the thing as lit, with its shadow
  lamp  only its lamps (lit after dark; the crossing's blink)

  "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b -P tools/blender/props3d.py -- <out dir>

then tools/blender/pack_props3d.py packs them for the app.
"""

import json
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)

PX_PER_M = 9.25 * 2  # two render pixels to one grid pixel (the train's scale)
PITCH = 8

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def material(name, color, rough=0.5, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def emission(name, color, strength=4.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (*color, 1)
    e.inputs["Strength"].default_value = strength
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs[0])
    return m


def holdout(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(nt.nodes.new("ShaderNodeHoldout").outputs[0], o.inputs[0])
    return m


M = {
    "steel": material("steel", (0.45, 0.47, 0.5), 0.45, 0.6),
    "grey": material("grey", (0.62, 0.63, 0.64), 0.7),
    "concrete": material("concrete", (0.68, 0.66, 0.62), 0.85),
    "dark": material("dark", (0.06, 0.06, 0.07), 0.7),
    "yellow": material("yellow", (0.95, 0.72, 0.05), 0.5),
    "black": material("black", (0.03, 0.03, 0.03), 0.6),
    "white": material("white", (0.88, 0.88, 0.86), 0.5),
    "red": material("red", (0.65, 0.08, 0.06), 0.5),
    "wood": material("wood", (0.36, 0.22, 0.12), 0.8),
    "roof": material("roof", (0.18, 0.22, 0.3), 0.6),
    "wall": material("wall", (0.8, 0.74, 0.6), 0.8),
    "green": material("green", (0.18, 0.4, 0.32), 0.6),
    "bridge": material("bridge", (0.55, 0.12, 0.1), 0.5, 0.3),
    "brick": material("brick", (0.42, 0.2, 0.14), 0.9),
    "glass": material("glass", (0.05, 0.08, 0.12), 0.1),
}
LAMP_RED = emission("lamp_red", (1, 0.1, 0.05), 6)
LAMP_GREEN = emission("lamp_green", (0.1, 1, 0.4), 6)
LAMP_WARM = emission("lamp_warm", (1, 0.85, 0.55), 5)
HOLD = holdout("hold")
WHITE = emission("white_lit", (1, 1, 1), 1)

parts = []  # (object, prop name, role)
current = {"name": None}


def add(o, mat, role="body"):
    o.data.materials.append(mat)
    parts.append((o, current["name"], role))
    return o


def box(size, loc, mat, role="body", rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        m = o.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = 2
        m.limit_method = "ANGLE"
    return add(o, mat, role)


def cyl(r, h, loc, mat, role="body", rot=(0, 0, 0), verts=16, smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, rotation=rot, vertices=verts)
    if smooth:
        bpy.ops.object.shade_smooth()
    return add(bpy.context.object, mat, role)


def beam(a, b, t, mat):
    """A square bar of thickness t from point a to point b (both at the same y)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cube_add(size=1, location=(a + b) / 2, rotation=(0, math.atan2(d.x, d.z), 0))
    o = bpy.context.object
    o.scale = (t, t, d.length)
    bpy.ops.object.transform_apply(scale=True)
    return add(o, mat)


# Each prop is built at the origin (ground z=0, the rail's far side at y=+2.5),
# in its own collection, with its width along x.
PROPS = {}


def prop(name, width, height, x0=None):
    def deco(fn):
        PROPS[name] = (fn, width, height, x0)
        return fn

    return deco


@prop("crossing", 9, 7)
def crossing():
    for x in (-3.2, 3.2):
        # Warning post: yellow-black, two red lamps, an X sign and a bell.
        for i in range(8):
            cyl(0.09, 0.36, (x, 0, 0.18 + i * 0.36), M["yellow"] if i % 2 == 0 else M["black"])
        cyl(0.09, 1.4, (x, 0, 3.6), M["steel"])
        box((0.9, 0.12, 0.42), (x, -0.05, 3.1), M["black"])
        for dx in (-0.28, 0.28):
            cyl(0.16, 0.08, (x + dx, -0.13, 3.1), LAMP_RED, "lamp", rot=(math.pi / 2, 0, 0))
        for s in (-1, 1):
            box((1.3, 0.06, 0.18), (x, -0.1, 3.75), M["yellow"], rot=(0, s * math.radians(35), 0))
        cyl(0.18, 0.2, (x, -0.05, 4.35), M["black"])
        # The barrier arm, up.
        box((0.25, 0.25, 0.5), (x, 0.3, 0.9), M["grey"])
    for x, s in ((-3.2, 1), (3.2, -1)):
        for i in range(6):
            box((0.12, 0.12, 0.6), (x + s * 0.2, 0.3, 1.3 + i * 0.6), M["yellow"] if i % 2 == 0 else M["black"])
    # Road crossing the rails, in front.
    box((6.0, 6.0, 0.08), (0, 0, 0.04), M["grey"])


@prop("signal", 3, 7)
def signal():
    cyl(0.12, 5.0, (0, 0, 2.5), M["grey"])
    box((0.75, 0.4, 1.9), (0, -0.05, 5.6), M["black"], bevel=0.08)
    for i, mat in enumerate((LAMP_RED, M["dark"], LAMP_GREEN)):
        cyl(0.19, 0.1, (0, -0.27, 6.2 - i * 0.6), mat, "lamp" if mat is not M["dark"] else "body", rot=(math.pi / 2, 0, 0))
        box((0.5, 0.25, 0.08), (0, -0.33, 6.42 - i * 0.6), M["black"])
    box((0.9, 0.9, 0.25), (0, 0, 0.12), M["concrete"])


@prop("hut", 6, 4.5)
def hut():
    box((4.0, 2.4, 2.4), (0, 0, 1.2), M["wall"])
    box((4.5, 2.9, 0.18), (0, 0, 2.5), M["roof"], rot=(math.radians(-6), 0, 0))
    box((0.9, 0.06, 1.8), (-1.1, -1.21, 0.9), M["green"])
    box((1.1, 0.06, 0.8), (0.9, -1.21, 1.5), M["glass"])
    box((0.18, 0.18, 0.18), (-1.1, -1.4, 2.2), LAMP_WARM, "lamp")
    for i in range(3):
        cyl(0.45, 0.9, (2.7, 0.3 * i - 0.3, 0.45), M["steel"], rot=(0, 0, 0))


@prop("pole", 4, 10)
def pole():
    cyl(0.17, 9.0, (0, 0, 4.5), M["concrete"])
    for z in (8.4, 7.6):
        box((2.2, 0.12, 0.12), (0, 0, z), M["steel"])
        for x in (-0.9, -0.3, 0.3, 0.9):
            cyl(0.06, 0.2, (x, 0, z + 0.15), M["white"])
    cyl(0.35, 0.9, (0.45, -0.1, 6.6), M["grey"])
    box((0.6, 0.1, 0.12), (0.3, 0, 6.1), M["steel"])
    box((0.5, 0.25, 0.25), (0, -0.25, 3.2), LAMP_WARM, "lamp")
    box((0.3, 0.3, 0.45), (0, -0.32, 3.55), M["steel"])


@prop("wall", 8, 3.6, x0=-4)
def wall():
    # One module of a sound wall: concrete foot, panels between H posts.
    box((8.0, 0.4, 0.7), (0, 0, 0.35), M["concrete"])
    for x in (-4.0, 0.0):
        box((0.25, 0.3, 3.4), (x, 0, 1.7), M["steel"])
    for x in (-2.0, 2.0):
        box((3.75, 0.12, 2.6), (x, 0.05, 2.0), M["grey"])
        for z in (1.0, 1.6, 2.2, 2.8):
            box((3.75, 0.16, 0.04), (x, 0, z), M["concrete"])


def truss(side_y):
    w = 12.0
    h = 5.0
    for z in (0.6, h):
        box((w, 0.35, 0.45), (0, side_y, z), M["bridge"])
    for x in (-6.0, 0.0):
        box((0.35, 0.35, h - 0.6), (x, side_y, (h + 0.6) / 2), M["bridge"])
    beam((-6.0, side_y, 0.6), (0.0, side_y, h), 0.3, M["bridge"])
    beam((0.0, side_y, h), (6.0, side_y, 0.6), 0.3, M["bridge"])


@prop("truss_back", 12, 6, x0=-6)
def truss_back():
    truss(2.0)
    box((12.0, 4.4, 0.4), (0, 0, 0.3), M["bridge"])


@prop("truss_front", 12, 6, x0=-6)
def truss_front():
    truss(-2.0)


@prop("pier", 8, 7, x0=-4)
def pier():
    box((2.2, 3.0, 6.0), (0, 0, -3.0 + 0.0), M["brick"], bevel=0.1)
    box((2.8, 3.4, 0.4), (0, 0, -0.1), M["concrete"])


@prop("portal", 12, 9)
def portal():
    # A tunnel mouth in a hillside: stone face with an arch, dark inside.
    box((12.0, 1.2, 9.0), (0, 0.6, 4.5), M["concrete"], bevel=0.2)
    box((5.4, 1.4, 5.6), (0, 0.4, 2.8), M["black"])
    cyl(2.7, 1.42, (0, 0.4, 5.6), M["black"], rot=(math.pi / 2, 0, 0), verts=32, smooth=False)
    for z in (1.5, 3.0, 4.5, 6.0, 7.5):
        box((12.0, 0.04, 0.06), (0, -0.01, z), M["grey"])
    box((12.4, 1.4, 0.5), (0, 0.4, 9.0), M["grey"])
    box((12.0, 0.8, 1.0), (0, 1.6, 9.4), M["green"])


# ---------------------------------------------------------------- render

sun_data = bpy.data.lights.new("sun", "SUN")
sun_data.energy = 2.6
sun_data.angle = math.radians(12)
sun = bpy.data.objects.new("sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(32), 0, math.radians(-30))
fill_data = bpy.data.lights.new("fill", "SUN")
fill_data.energy = 0.8
fill = bpy.data.objects.new("fill", fill_data)
scene.collection.objects.link(fill)
fill.rotation_euler = (math.radians(70), 0, math.radians(150))
world = bpy.data.worlds.new("world")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.82, 0.92, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.45

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"

bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
ground = bpy.context.object
ground.is_shadow_catcher = True

meta = {"pxPerM": PX_PER_M, "pitch": PITCH, "props": {}}
for name, (fn, width, height, x0) in PROPS.items():
    current["name"] = name
    fn()
for name, (fn, width, height, x0) in PROPS.items():
    mine = [(o, role) for o, n, role in parts if n == name]
    for o, n, _ in parts:
        o.hide_render = n != name
    margin = 1.5
    # Height range in metres: the pier hangs below the rail, the rest stand on the ground.
    low, high = (-6.6, 0.6) if name == "pier" else (-0.8, height + margin)
    w_m, h_m = width + 2 * margin, high - low
    scene.render.resolution_x = int(w_m * PX_PER_M)
    scene.render.resolution_y = int(h_m * PX_PER_M)
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.ortho_scale = w_m
    e = math.radians(PITCH)
    centre = Vector((0, 0, (low + high) / 2))
    d = Vector((0, -math.cos(e), math.sin(e)))
    cam.location = centre + d * 60
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    ground.hide_render = name in ("pier",)
    for pname in ("base", "lamp"):
        for o, role in mine:
            if "orig" not in o:
                o["orig"] = o.data.materials[0].name
            orig = bpy.data.materials[o["orig"]]
            if pname == "base":
                o.data.materials[0] = orig
            else:
                o.data.materials[0] = WHITE if role == "lamp" else HOLD
        if pname == "lamp":
            ground.hide_render = True
        scene.cycles.samples = 48 if pname == "base" else 16
        scene.render.filepath = os.path.join(OUT, f"{pname}_{name}.png")
        if not os.path.exists(scene.render.filepath):
            bpy.ops.render.render(write_still=True)
    v = world_to_camera_view(scene, cam, Vector((x0 if x0 is not None else 0, 0, 0)))
    meta["props"][name] = {
        "w": scene.render.resolution_x,
        "h": scene.render.resolution_y,
        # Where the ground at the prop's anchor (its centre, or a tiling module's left end) falls.
        "anchor": [round(v.x * scene.render.resolution_x, 1), round((1 - v.y) * scene.render.resolution_y, 1)],
        "width_m": width,
    }
with open(os.path.join(OUT, "meta.json"), "w") as f:
    json.dump(meta, f, indent=1)
print("done", len(meta["props"]))
