"""The trip view's train, modelled and rendered in Blender.

A short, round commuter train of three cars (an original design: no real
train copied), rendered from every angle the trip view's camera can turn to:
yaw -30 … 30 degrees in steps of 5, three heights. Three passes per angle:

  base   the train as lit, the line band in white, with its shadow
  stripe only the line band (the app tints it with the line colour)
  glass  only the window glass (lit up warm after dark and in tunnels)

  "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b -P tools/blender/train3d.py -- <out dir>

then tools/blender/pack_train3d.py packs the frames into the app's atlases.
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

W, H = 1050, 280  # about 2 frame pixels to one pixel of the view's art
YAWS = list(range(-30, 31, 5))
PITCHES = [2, 12, 22]
ORTHO = 50.0  # metres across the frame
if os.environ.get("QUICK"):
    YAWS, PITCHES = [20], [12]

CAR_L = 13.0  # short, chunky cars: cute next to the paper town
CAR_W = 2.9
BODY_H = 3.0
FLOOR_Z = 1.15
GAP = 0.6
# KIND=dmu: a two-car diesel railcar for the lines without overhead wires
# (no pantograph, an exhaust on the roof, a flatter cab).
KIND = os.environ.get("KIND", "emu")
CARS = 3 if KIND == "emu" else 2

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ---------------------------------------------------------------- materials


def material(name, color, rough=0.45, metal=0.0, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if coat:
        b.inputs["Coat Weight"].default_value = coat
    return m


def emission(name, color, strength=1.0):
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
    h = nt.nodes.new("ShaderNodeHoldout")
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(h.outputs[0], o.inputs[0])
    return m


M_BODY = material("body", (0.74, 0.75, 0.78), rough=0.4, coat=0.25)
M_ROOF = material("roof", (0.42, 0.44, 0.48), rough=0.6)
M_DARK = material("dark", (0.05, 0.05, 0.06), rough=0.7)
M_UNDER = material("under", (0.16, 0.17, 0.19), rough=0.7)
M_DOOR = material("door", (0.55, 0.57, 0.61), rough=0.35, metal=0.4)
M_GLASS = material("glass", (0.012, 0.02, 0.04), rough=0.15, coat=0.3)
M_STRIPE = material("stripe", (0.92, 0.92, 0.92), rough=0.35, coat=0.4)
M_LAMP = emission("lamp", (1.0, 0.95, 0.75), 6)
M_TAIL = emission("tail", (1.0, 0.15, 0.1), 3)
M_HOLD = holdout("hold")
M_GLASS_LIT = emission("glass_lit", (1, 1, 1), 1)

objects = []  # (object, role) role: body | stripe | glass


def box(size, loc, mat, role="body", bevel=0.0, segs=3, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        m = o.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = segs
        m.limit_method = "ANGLE"
        m.harden_normals = True
        bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    objects.append((o, role))
    return o


def cylinder(r, depth, loc, mat, rot=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=24)
    o = bpy.context.object
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    objects.append((o, "body"))
    return o


# ---------------------------------------------------------------- the train

top = FLOOR_Z + BODY_H
mid_z = FLOOR_Z + BODY_H / 2
win_z = FLOOR_Z + BODY_H * 0.64
SLANT = 1.1 if KIND == "emu" else 0.35  # how far the cab's top leans back


def car(cx, lead=False, pantograph=False, tail=False):
    # Body: a rounded box; the cab's upper front leans back.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, 0, mid_z))
    o = bpy.context.object
    o.scale = (CAR_L, CAR_W, BODY_H)
    bpy.ops.object.transform_apply(scale=True)
    if lead:
        for v in o.data.vertices:
            if v.co.x > 0 and v.co.z > 0:
                v.co.x -= SLANT
    m = o.modifiers.new("bevel", "BEVEL")
    m.width = 0.32
    m.segments = 5
    m.limit_method = "ANGLE"
    m.harden_normals = True
    bpy.ops.object.shade_smooth()
    o.data.materials.append(M_BODY)
    objects.append((o, "body"))

    half = CAR_L / 2
    # Roof and its units.
    box((CAR_L - 0.5 - (SLANT if lead else 0), CAR_W - 0.35, 0.22), (cx - (SLANT / 2 if lead else 0), 0, top + 0.06), M_ROOF, bevel=0.1)
    box((2.2, 1.5, 0.34), (cx - 2.6, 0, top + 0.3), M_ROOF, bevel=0.12)
    if KIND == "dmu":
        # Exhaust stack and radiator on the roof.
        box((0.5, 0.5, 0.55), (cx + 1.0, 0.6, top + 0.35), M_DARK, bevel=0.06)
        box((1.6, 1.2, 0.25), (cx + 1.0, -0.2, top + 0.2), M_ROOF, bevel=0.05)
    if not pantograph:
        box((2.2, 1.5, 0.34), (cx + 2.6 - (0.8 if lead else 0), 0, top + 0.3), M_ROOF, bevel=0.12)

    # The line band, a thin one under the roof edge, and the skirt.
    box((CAR_L - 0.75, CAR_W + 0.03, 0.34), (cx, 0, FLOOR_Z + 0.78), M_STRIPE, "stripe", bevel=0.05)
    box((CAR_L - 0.5 - (SLANT if lead else 0), CAR_W + 0.02, 0.1), (cx - (SLANT / 2 if lead else 0), 0, top - 0.32), M_STRIPE, "stripe", bevel=0.03)
    box((CAR_L - 1.4, CAR_W - 0.4, 0.55), (cx, 0, FLOOR_Z - 0.2), M_UNDER, bevel=0.08)

    for side in (-1, 1):
        y = side * (CAR_W / 2 + 0.01)
        # Two doors a side, each with its window.
        for dx in (-3.1, 3.1):
            box((1.3, 0.05, 2.25), (cx + dx, y, FLOOR_Z + 1.22), M_DOOR, bevel=0.06)
            box((0.95, 0.07, 0.95), (cx + dx, y, win_z), M_GLASS, "glass", bevel=0.08)
        # Windows: a wide one in the middle, one at each end.
        box((3.4, 0.06, 1.0), (cx, y, win_z), M_GLASS, "glass", bevel=0.1)
        box((1.2, 0.06, 1.0), (cx - 5.2, y, win_z), M_GLASS, "glass", bevel=0.1)
        if lead:
            box((0.9, 0.06, 0.9), (cx + 4.95, y, win_z), M_GLASS, "glass", bevel=0.1)
        else:
            box((1.2, 0.06, 1.0), (cx + 5.2, y, win_z), M_GLASS, "glass", bevel=0.1)

    # Bogies with their wheels.
    for bx in (-half + 2.3, half - 2.3):
        box((2.5, CAR_W - 0.7, 0.5), (cx + bx, 0, 0.72), M_DARK, bevel=0.08)
        for wx in (-0.75, 0.75):
            for side in (-1, 1):
                cylinder(0.42, 0.18, (cx + bx + wx, side * 1.1, 0.42), M_DARK)
                cylinder(0.2, 0.2, (cx + bx + wx, side * 1.17, 0.42), M_UNDER)

    if lead:
        # Windscreen on the leaning face, headlights and the number board.
        face = math.atan2(SLANT, BODY_H / 2)
        t = 0.55
        x = cx + half - 0.05 - t * SLANT
        z = mid_z + t * BODY_H / 2
        box((0.06, CAR_W - 0.55, 1.25), (x, 0, z), M_GLASS, "glass", bevel=0.12, rot=(0, -face, 0))
        for y in (-0.95, 0.95):
            box((0.08, 0.5, 0.22), (cx + half - 0.06, y, FLOOR_Z + 0.42), M_LAMP)
        box((0.06, 0.9, 0.3), (cx + half - 0.06, 0, FLOOR_Z + 0.42), M_GLASS, "glass", bevel=0.04)
    if tail:
        for y in (-0.95, 0.95):
            box((0.08, 0.45, 0.2), (cx - half - 0.0, y, FLOOR_Z + 0.42), M_TAIL)

    if pantograph:
        px = cx + 2.4
        box((1.6, 1.2, 0.2), (px, 0, top + 0.25), M_DARK, bevel=0.04)
        reach = 1.35
        for s in (-1, 1):
            # The two arms of a diamond, and the bar that touches the wire.
            ang = math.atan2(reach / 2, 0.6)
            box((0.06, 0.06, math.hypot(0.6, reach / 2) * 2), (px + s * 0.3, 0, top + 0.35 + reach / 4), M_DARK, rot=(0, -s * ang, 0))
            box((0.06, 0.06, math.hypot(0.6, reach / 2) * 2), (px + s * 0.3, 0, top + 0.35 + reach * 3 / 4), M_DARK, rot=(0, s * ang, 0))
        box((0.12, 1.7, 0.06), (px, 0, top + 0.38 + reach), M_DARK)


span = CARS * CAR_L + (CARS - 1) * GAP
for i in range(CARS):
    cx = span / 2 - CAR_L / 2 - i * (CAR_L + GAP)
    car(cx, lead=i == 0, pantograph=KIND == "emu" and i == 1, tail=i == CARS - 1)
    if i < CARS - 1:
        box((GAP + 0.4, 2.1, 2.5), (cx - CAR_L / 2 - GAP / 2, 0, FLOOR_Z + 1.35), M_DARK, bevel=0.1)

# Shadow on the ground (transparent but for the shadow).
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
ground = bpy.context.object
ground.is_shadow_catcher = True

# ---------------------------------------------------------------- light, camera

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
cam_data.ortho_scale = ORTHO
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.use_denoising = True
scene.render.resolution_x = W
scene.render.resolution_y = H
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"

TARGET = Vector((0, 0, 2.0))


def aim(yaw, pitch):
    a, e = math.radians(yaw), math.radians(pitch)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.location = TARGET + d * 80
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


def set_pass(name):
    for o, role in objects:
        keep = name == "base" or role == name
        base_mat = o.data.materials[0] if "orig" not in o else bpy.data.materials[o["orig"]]
        if "orig" not in o:
            o["orig"] = base_mat.name
        if name == "glass" and role == "glass":
            o.data.materials[0] = M_GLASS_LIT
        elif keep:
            o.data.materials[0] = base_mat
        else:
            o.data.materials[0] = M_HOLD
    ground.hide_render = name != "base"
    scene.cycles.samples = 64 if name == "base" else 24


meta = {"w": W, "h": H, "ortho": ORTHO, "span": span, "yaws": YAWS, "pitches": PITCHES, "frames": {}}
for pname in ("base", "stripe", "glass"):
    set_pass(pname)
    for e in PITCHES:
        for a in YAWS:
            aim(a, e)
            key = f"{a}_{e}"
            scene.render.filepath = os.path.join(OUT, f"{pname}_{key}.png")
            if not os.path.exists(scene.render.filepath):  # resume: keep frames already made
                bpy.ops.render.render(write_still=True)
            if pname == "base":
                bpy.context.view_layer.update()
                # Where the rail under the train's middle, and its nose, fall in the frame.
                def px(p):
                    v = world_to_camera_view(scene, cam, Vector(p))
                    return [round(v.x * W, 1), round((1 - v.y) * H, 1)]

                meta["frames"][key] = {"rail": px((0, 0, 0)), "nose": px((span / 2, 0, 0)), "tail": px((-span / 2, 0, 0))}

with open(os.path.join(OUT, "meta.json"), "w") as f:
    json.dump(meta, f, indent=1)
print("done", len(meta["frames"]))
