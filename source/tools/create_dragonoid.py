"""Build original Dragonoid assets and CPU-rendered previews with Blender.

Run: blender --background --python tools/create_dragonoid.py -- --render
The public Sketchfab thumbnail supplies the red/gold mechanical ball palette.
Five user screenshots supply the open mechanical toy's visible silhouette.
All geometry and decorative layouts are authored here from those references.
No source geometry or textures from the referenced model are included.
"""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "models"
PREVIEWS = ROOT / "builds" / "previews"
ASSETS.mkdir(parents=True, exist_ok=True)
PREVIEWS.mkdir(parents=True, exist_ok=True)
TAU = math.tau


def rgb(hex_value):
    color = [int(hex_value[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in color)


def material(name, color, metal=0.0, rough=0.35, glow=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb(color), 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Coat Weight"].default_value = 0.35
    bsdf.inputs["Coat Roughness"].default_value = 0.22
    if glow:
        bsdf.inputs["Emission Color"].default_value = (*rgb(color), 1)
        bsdf.inputs["Emission Strength"].default_value = glow
    mat.diffuse_color = (*rgb(color), 1)
    return mat


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
MATS = {
    "red": material("Shell_Red", "CF3526", 0.30, 0.29),
    "shadow": material("Armor_Shadow", "81241E", 0.24, 0.38),
    "gold": material("Gold_Armor", "F4BD32", 0.55, 0.26),
    "seam": material("Dark_Seams", "191E24", 0.45, 0.43),
    "steel": material("Hinge_Steel", "879399", 0.82, 0.27),
    "eye": material("Eye_Green", "70F292", 0.08, 0.20, 0.7),
    "ivory": material("Claw_Ivory", "FFF0C2", 0.15, 0.32),
    "white": material("Emblem_White", "F4F1D5", 0.08, 0.35),
    "owner": material("Owner_Accent", "86DFE9", 0.40, 0.25, 0.20),
}


def empty(name, parent=None, location=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = location
    return obj


def mesh(name, verts, faces, mat, parent=None, smooth=True, subdiv=0, solid=0.0):
    data = bpy.data.meshes.new(name + "_mesh")
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(mat)
    for polygon in data.polygons:
        polygon.use_smooth = smooth
    if subdiv:
        mod = obj.modifiers.new("Sculpted curvature", "SUBSURF")
        mod.levels = subdiv
        mod.render_levels = subdiv
    if solid:
        mod = obj.modifiers.new("Shell thickness", "SOLIDIFY")
        mod.thickness = solid
    return obj


def uv(name, center, scale, mat, parent, seg=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.parent = parent
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def tube(name, points, radii, mat, parent, sides=10, smooth=True):
    """Tapered swept mesh, used for curved horns, claws, ribs and trim."""
    pts = [Vector(p) for p in points]
    verts, faces = [], []
    for i, point in enumerate(pts):
        tangent = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(tangent.z) < 0.88 else Vector((0, 1, 0))
        right = tangent.cross(ref).normalized()
        up = right.cross(tangent).normalized()
        radius = radii[i] if isinstance(radii, (list, tuple)) else radii
        for j in range(sides):
            angle = TAU * j / sides
            verts.append(tuple(point + radius * (math.cos(angle) * right + math.sin(angle) * up)))
    for i in range(len(pts) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(pts) - 1) * sides + j for j in range(sides)))
    return mesh(name, verts, faces, mat, parent, smooth)


def ribbon(name, points, widths, normals, mat, parent, project_radius=None):
    """Thin surface markings; these follow the shell instead of forming pipes."""
    pts = [Vector(p) for p in points]
    verts, faces = [], []
    for index, point in enumerate(pts):
        tangent = (pts[min(index + 1, len(pts) - 1)] - pts[max(index - 1, 0)]).normalized()
        right = Vector(normals[index]).normalized().cross(tangent).normalized()
        width = widths[index] if isinstance(widths, (list, tuple)) else widths
        for direction in (-1, 1):
            vertex = point + right * width * direction / 2
            if project_radius is not None:
                vertex = vertex.normalized() * project_radius
            verts.append(tuple(vertex))
    for index in range(len(pts) - 1):
        faces.append((index * 2, index * 2 + 1, index * 2 + 3, index * 2 + 2))
    return mesh(name, verts, faces, mat, parent, smooth=True, solid=0.001)


def loft(name, sections, mat, parent, sides=16, subdiv=1):
    """Closed curved shell with elliptical cross-sections along its vertical axis."""
    verts, faces = [], []
    for x, y, z, rx, ry in sections:
        for j in range(sides):
            angle = TAU * j / sides
            verts.append((x + rx * math.cos(angle), y + ry * math.sin(angle), z))
    for i in range(len(sections) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(sections) - 1) * sides + j for j in range(sides)))
    return mesh(name, verts, faces, mat, parent, subdiv=subdiv)


def patch(name, center, radii, lat_min, lat_max, lon_min, lon_max, mat, parent, nlat=6, nlon=8, solid=0.015):
    """A separate curved armor plate with visible gaps, rather than a box primitive."""
    verts, faces = [], []
    cx, cy, cz = center
    rx, ry, rz = radii
    for i in range(nlat + 1):
        lat = lat_min + (lat_max - lat_min) * i / nlat
        for j in range(nlon + 1):
            lon = lon_min + (lon_max - lon_min) * j / nlon
            verts.append((cx + rx * math.cos(lat) * math.sin(lon), cy - ry * math.cos(lat) * math.cos(lon), cz + rz * math.sin(lat)))
    for i in range(nlat):
        for j in range(nlon):
            a = i * (nlon + 1) + j
            faces.append((a, a + 1, a + nlon + 2, a + nlon + 1))
    return mesh(name, verts, faces, mat, parent, solid=solid)


def flame_medallion(parent, name, center, normal, radius):
    emblem = empty(name, parent, center)
    emblem.rotation_euler = Vector(normal).normalized().to_track_quat("Z", "Y").to_euler()
    uv(name + "_Gold_Rim", (0, 0, 0), (radius * 1.12, radius * 1.12, 0.007), MATS["gold"], emblem, 28, 8)
    uv(name + "_Ivory_Disc", (0, 0, 0.008), (radius, radius, 0.007), MATS["white"], emblem, 28, 8)
    outline = [(-0.46, -0.38), (-0.65, -0.08), (-0.36, 0.47), (-0.29, 0.13),
               (0.04, 0.79), (0.20, 0.32), (0.41, 0.56), (0.60, 0.06),
               (0.38, -0.40), (0, -0.54)]
    verts = [(x * radius, y * radius, 0.017) for x, y in outline]
    mesh(name + "_Original_Flame", verts, [tuple(range(len(verts)))], MATS["red"], emblem, smooth=False, solid=0.002)
    return emblem


def semicircular_shell(name, center, radius, depth, parent, mat):
    """Half a curved sphere panel, with a horizontal hinge edge."""
    cx, cy, cz = center
    steps, rings = 28, 9
    verts = [(cx, cy + depth, cz)]
    for ring in range(1, rings + 1):
        r = radius * ring / rings
        dome = depth * math.sqrt(max(0, 1 - (r / radius) ** 2))
        for j in range(steps + 1):
            angle = math.pi * j / steps
            verts.append((cx + r * math.cos(angle), cy + dome, cz + r * math.sin(angle)))
    faces = [(0, j + 2, j + 1) for j in range(steps)]
    for ring in range(rings - 1):
        start = 1 + ring * (steps + 1)
        for j in range(steps):
            a = start + j
            faces.append((a, a + 1, a + steps + 2, a + steps + 1))
    return mesh(name, verts, faces, mat, parent, smooth=True, solid=0.024)


def arch_plate(name, begin, end, parent, width=0.41):
    verts, faces = [], []
    rows, cols = max(4, int((end - begin) * 20)), 6
    for row in range(rows + 1):
        angle = begin + (end - begin) * row / rows
        for col in range(cols + 1):
            x = width * (col / cols - 0.5)
            # Crown curvature connects the long neck strip to the spherical shell.
            radial = 0.66 + 0.027 * (1 - (2 * x / width) ** 2)
            verts.append((x, -0.005 + radial * math.cos(angle), 1.20 + radial * math.sin(angle)))
    for row in range(rows):
        for col in range(cols):
            a = row * (cols + 1) + col
            faces.append((a, a + cols + 1, a + cols + 2, a + 1))
    return mesh(name, verts, faces, MATS["red"], parent, smooth=True, solid=0.053)


def arch_point(angle, x, offset=0):
    radial = 0.66 + 0.027 * (1 - (2 * x / 0.41) ** 2) + offset
    return (x, -0.005 + radial * math.cos(angle), 1.20 + radial * math.sin(angle))


def foot_point(side, u, v, offset=0):
    width = 0.19 + 0.045 * math.sin(math.pi * v)
    return (side * (0.365 + 0.085 * v) + u * width,
            -0.395 - 0.39 * math.sin(v * math.pi / 2) + 0.09 * u * u - offset,
            0.73 - 0.69 * v + 0.07 * u * u)


def build_dragon():
    """Recreate the mechanical toy silhouette seen in five supplied screenshots.

    Geometry and decorative linework are original; dimensions are estimated from
    the images. No anatomy, horns, claws or bat membranes are invented here.
    """
    root = empty("Dragonoid_Model")
    root["asset_origin"] = "Original mechanical toy recreation from five user supplied reference views"
    bowl = empty("Lower_Hemisphere", root)
    patch("Inner_Dark_Bowl", (0, 0, 0.98), (0.622,) * 3, -math.pi / 2, -0.018, 0, TAU, MATS["seam"], bowl, 10, 48, 0.01)
    for panel in range(12):
        lon0 = panel * TAU / 12 + 0.009
        lon1 = (panel + 1) * TAU / 12 - 0.009
        patch("Bowl_Shell_%02d" % panel, (0, 0, 0.98), (0.650,) * 3, -math.pi / 2 + 0.018, -0.022, lon0, lon1, MATS["red"], bowl, 9, 5, 0.018)
        triangle = []
        for lat, lon in [(-0.16, lon0 + 0.09), (-0.16, lon1 - 0.09), (-0.43, (lon0 + lon1) / 2)]:
            p = ball_point(lat, lon, 0.658)
            triangle.append((p.x, p.y, p.z + 0.98))
        mesh("Bowl_Gold_Triangle_%02d" % panel, triangle, [(0, 1, 2)], MATS["gold"], bowl, smooth=False, solid=0.003)
        for line in range(2):
            lat = -0.52 - line * 0.24
            points = []
            for dx, dz in [(-0.15, 0), (-0.07, 0.06), (0.03, -0.055), (0.16, 0.025)]:
                p = ball_point(lat + dz, (lon0 + lon1) / 2 + dx, 0.654)
                points.append((p.x, p.y, p.z + 0.98))
            tube("Bowl_Engraved_Trace_%02d_%d" % (panel, line), points, 0.004, MATS["shadow"], bowl, 5)
    # The broad horizontal lid is a defining feature of this toy's open form.
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.650, depth=0.048, location=(0, 0, 0.972))
    disc = bpy.context.object
    disc.name = "Flat_Upper_Disc"
    disc.parent = bowl
    disc.data.materials.append(MATS["shadow"])
    for r, material_name, z in [(0.648, "gold", 0.997), (0.619, "red", 1.002)]:
        pts = [(r * math.sin(TAU * i / 64), -r * math.cos(TAU * i / 64), z) for i in range(65)]
        tube("Disc_Rim_" + material_name, pts, 0.012 if material_name == "red" else 0.006, MATS[material_name], bowl, 6)
    for side in (-1, 1):
        for trace in range(3):
            y = -0.26 + trace * 0.20
            pts = [(side * 0.09, y, 1.001), (side * 0.20, y + 0.06, 1.001), (side * 0.34, y - 0.035, 1.001), (side * 0.46, y + 0.045, 1.001)]
            tube("Disc_Circuit_%s_%d" % (side, trace), pts, 0.0046, MATS["gold"], bowl, 6)
    for lon in (-0.8, 0.8, math.pi - 0.8, math.pi + 0.8):
        center = ball_point(-0.40, lon, 0.662) + Vector((0, 0, 0.98))
        normal = center - Vector((0, 0, 0.98))
        hub = empty("Bowl_Hinge_Hub", bowl, center)
        hub.rotation_euler = normal.normalized().to_track_quat("Z", "Y").to_euler()
        uv("Bowl_Hub_Dark_Rim", (0, 0, 0), (0.065, 0.065, 0.014), MATS["seam"], hub, 20, 8)
        uv("Bowl_Hub_Metal", (0, 0, 0.010), (0.044, 0.044, 0.015), MATS["steel"], hub, 20, 8)
    neck = empty("Arched_Shell_Neck", root)
    head = empty("Head", root)
    # Distinct shell segments form the curled neck/head, rather than a skull.
    breaks = [-0.31, 0.28, 0.88, 1.49, 2.10, 2.66, 3.23]
    for index in range(len(breaks) - 1):
        start, finish = breaks[index] + 0.012, breaks[index + 1] - 0.012
        group = head if index >= 4 else neck
        arch_plate("Curved_Neck_Shell_%d" % index, start, finish, group)
        for side in (-1, 1):
            points = [arch_point(start + (finish - start) * i / 9, side * 0.195, 0.012) for i in range(10)]
            tube("Neck_Edge_Rail_%d_%s" % (index, side), points, 0.011, MATS["gold"], group, 6)
            inner = [arch_point(start + (finish - start) * i / 7, side * 0.156, -0.052) for i in range(8)]
            tube("Neck_Inner_Rib_%d_%s" % (index, side), inner, 0.010, MATS["shadow"], group, 6)
        # Raised schematic traces on the outer shell are independent linework.
        mid = (start + finish) / 2
        for side in (-1, 1):
            points = [arch_point(start + 0.065, side * 0.105, 0.007), arch_point(mid, side * 0.145, 0.007), arch_point(mid + 0.065, side * 0.055, 0.007), arch_point(finish - 0.07, side * 0.105, 0.007)]
            tube("Neck_Engraved_Path_%d_%s" % (index, side), points, 0.007, MATS["seam"], group, 6)
        for groove in (-1, 1):
            points = [arch_point(start + (finish - start) * i / 10, groove * 0.132, 0.009) for i in range(11)]
            tube("Neck_Longitudinal_Groove_%d_%s" % (index, groove), points, 0.006, MATS["seam"], group, 6)
        for trace in range(3):
            at = start + 0.075 + (finish - start - 0.15) * trace / 2
            pts = [arch_point(at, -0.093, 0.011), arch_point(at + 0.045, 0, 0.011), arch_point(at, 0.093, 0.011)]
            tube("Neck_Chevron_%d_%d" % (index, trace), pts, 0.005, MATS["seam"], group, 5)
        if index in range(6):
            coords = [arch_point(mid - 0.09, -0.066, 0.010), arch_point(mid - 0.09, 0.066, 0.010), arch_point(mid + 0.10, 0.027, 0.010), arch_point(mid + 0.10, -0.027, 0.010)]
            mesh("Neck_Yellow_Marking_%d" % index, coords, [(0, 1, 2, 3)], MATS["gold"], group, smooth=False, solid=0.003)
    # Rear neck pedestal and its small horizontal mechanical hinge.
    for side in (-1, 1):
        uv("Neck_Base_Pivot_%s" % side, (side * 0.165, 0.585, 1.015), (0.073, 0.075, 0.083), MATS["red"], neck, 20, 10)
        uv("Neck_Base_Gold_Pin_%s" % side, (side * 0.202, 0.58, 1.014), (0.022, 0.034, 0.035), MATS["gold"], neck, 16, 8)
    for side in (-1, 1):
        pivot = empty("WingPivot_L" if side < 0 else "WingPivot_R", root, (side * 0.445, 0.075, 1.015))
        center = (side * 0.58, 0.085, 0)
        radius, depth = 0.615, 0.270
        semicircular_shell("Semicircular_Wing_Shell_%s" % side, center, radius, depth, pivot, MATS["red"])
        # The outside carries broad gold curves and a pale flame medallion.
        def wing_point(rho, theta, outward=0):
            return (center[0] + rho * math.cos(theta), center[1] + depth * math.sqrt(max(0, 1 - (rho / radius) ** 2)) + outward, rho * math.sin(theta))
        border = [wing_point(radius, math.pi * i / 30, 0.002) for i in range(31)]
        tube("Wing_Curved_Rim_%s" % side, border, 0.016, MATS["shadow"], pivot, 8)
        def wing_normal(point):
            return Vector(((point[0] - center[0]) / radius ** 2, (point[1] - center[1]) / depth ** 2, point[2] / radius ** 2)).normalized()
        stripe = [wing_point(radius * 0.78, math.pi * (0.10 + 0.80 * i / 28), 0.010) for i in range(29)]
        ribbon("Wing_Gold_Sweep_%s" % side, stripe, 0.077, [wing_normal(p) for p in stripe], MATS["gold"], pivot)
        low_stripe = [wing_point(radius * (0.24 + 0.51 * i / 18), math.pi * (0.14 + 0.74 * i / 18), 0.010) for i in range(19)]
        ribbon("Wing_Gold_Lower_Sweep_%s" % side, low_stripe, 0.050, [wing_normal(p) for p in low_stripe], MATS["gold"], pivot)
        emblem_center = wing_point(radius * 0.46, math.pi / 2, 0.012)
        flame_medallion(pivot, "Wing_Flame_Emblem_%s" % side, emblem_center, (0, 1, 0.3), 0.117)
        for ring in range(2):
            for trace in range(7):
                theta = math.pi * (0.10 + trace * 0.132)
                rho = radius * (0.60 + ring * 0.26)
                points = [wing_point(rho, theta - 0.052, 0.011), wing_point(rho + 0.045, theta, 0.011), wing_point(rho - 0.005, theta + 0.066, 0.011), wing_point(rho + 0.030, theta + 0.11, 0.011)]
                tube("Wing_Outer_Engraving_%s_%d_%d" % (side, ring, trace), points, 0.0045, MATS["seam"], pivot, 5)
        # Concave inner side: gold branching mechanisms seen in the front view.
        for branch in range(5):
            theta = math.pi * (0.10 + branch * 0.19)
            points = [wing_point(radius * rho, theta + 0.09 * math.sin(rho * math.pi), -0.033) for rho in (0.20, 0.42, 0.63, 0.84, 0.96)]
            tube("Wing_Inner_Circuit_%s_%d" % (side, branch), points, 0.009, MATS["gold"], pivot, 6)
        for side_x in (-1, 1):
            uv("Wing_Hinge_Bearing_%s_%s" % (side, side_x), (side_x * 0.046, 0.006, 0), (0.026, 0.048, 0.044), MATS["gold"], pivot, 16, 8)
        # Descending front shell flaps are feet, with no organic legs or claws.
        foot = empty("FootShell_L" if side < 0 else "FootShell_R", root)
        rows, cols = 16, 10
        verts, faces = [], []
        for row in range(rows + 1):
            v = row / rows
            for col in range(cols + 1):
                verts.append(foot_point(side, 2 * col / cols - 1, v))
        for row in range(rows):
            for col in range(cols):
                a = row * (cols + 1) + col
                faces.append((a, a + cols + 1, a + cols + 2, a + 1))
        mesh("Curved_Foot_Shell_%s" % side, verts, faces, MATS["red"], foot, smooth=True, solid=0.028)
        for edge in (-1, 1):
            points = [foot_point(side, edge, i / 20, 0.005) for i in range(21)]
            tube("Foot_Shell_Rim_%s_%s" % (side, edge), points, 0.008, MATS["shadow"], foot, 6)
        for trace in range(4):
            v = 0.18 + trace * 0.18
            points = [foot_point(side, -0.80, v, 0.009), foot_point(side, -0.36, v + 0.065, 0.009), foot_point(side, 0.05, v - 0.025, 0.009), foot_point(side, 0.72, v + 0.075, 0.009)]
            tube("Foot_Engraved_Trace_%s_%d" % (side, trace), points, 0.005, MATS["seam"], foot, 5)
        gold = [foot_point(side, -0.65, i / 16, 0.010) for i in range(17)]
        tube("Foot_Gold_Mechanism_%s" % side, gold, 0.008, MATS["gold"], foot, 6)
        for vent in range(3):
            u = -0.58 + vent * 0.57
            position = foot_point(side, u, 0.87, 0.012)
            obj = uv("Foot_Silver_Vent_%s_%d" % (side, vent), position, (0.017, 0.012, 0.065), MATS["steel"], foot, 16, 8)
            obj.rotation_euler.x = 0.16
        for side_x in (-1, 1):
            uv("Foot_Hinge_Pin_%s_%s" % (side, side_x), (side * 0.37 + side_x * 0.07, -0.42, 0.723), (0.027, 0.039, 0.031), MATS["gold"], foot, 16, 8)
    tail = empty("Segmented_Tail", root)
    tail_points = [(0, 0.49, 0.61, 0.19), (0, 0.77, 0.54, 0.17), (0, 1.02, 0.65, 0.14), (0, 1.22, 0.82, 0.12), (0, 1.38, 1.02, 0.08), (0, 1.48, 1.23, 0.012)]
    verts = []
    for x, y, z, width in tail_points:
        verts.extend([(x - width / 2, y, z), (x + width / 2, y, z)])
    faces = [(i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2) for i in range(len(tail_points) - 1)]
    mesh("Thin_Curled_Tail_Strip", verts, faces, MATS["red"], tail, smooth=True, solid=0.036)
    for index in range(1, 5):
        x, y, z, width = tail_points[index]
        tube("Tail_Joint_%d" % index, [(x - width * 0.48, y - 0.018, z), (x + width * 0.48, y - 0.018, z)], 0.008, MATS["shadow"], tail, 6)
        emblem = uv("Tail_Mechanism_%d" % index, (x, y - 0.023, z + 0.014), (0.022, 0.007, 0.022), MATS["gold"], tail, 16, 6)
        emblem.rotation_euler.x = -0.35
    return root


def ball_point(lat, lon, radius=0.381):
    return Vector((radius * math.cos(lat) * math.sin(lon), -radius * math.cos(lat) * math.cos(lon), radius * math.sin(lat)))


def ball_decoration(name, lat, lon, radius, color, root, offset=0):
    center = ball_point(lat, lon, 0.386 + offset)
    obj = uv(name, center, (radius, radius, 0.008), color, root, 20, 8)
    obj.rotation_euler = center.normalized().to_track_quat("Z", "Y").to_euler()
    return obj


def build_ball():
    root = empty("Dragonoid_Ball_Model")
    root["asset_origin"] = "Original mechanical sphere inspired by a public reference thumbnail"
    uv("Dark_Internal_Sphere", (0, 0, 0), (0.37,) * 3, MATS["seam"], root, 48, 24)
    # Curved independent shell plates leave dark engraved seams between them.
    for band in range(4):
        lat0 = -math.pi / 2 + band * math.pi / 4 + 0.012
        lat1 = -math.pi / 2 + (band + 1) * math.pi / 4 - 0.012
        for panel in range(8):
            lon0 = panel * TAU / 8 + 0.014
            lon1 = (panel + 1) * TAU / 8 - 0.014
            patch("Curved_Shell_%d_%d" % (band, panel), (0, 0, 0), (0.378,) * 3, lat0, lat1, lon0, lon1, MATS["red"], root, 5, 6, 0.006)
    for lat in (-0.024, 0.024):
        pts = [ball_point(lat, TAU * i / 80, 0.380) for i in range(81)]
        tube("Equator_Hinge_Ring_%.2f" % lat, pts, 0.0032, MATS["steel"], root, 6)
    # Original sweeping gold motifs, not a raster copy of the reference texture.
    for side in (-1, 1):
        pts = [ball_point(0.20 + 0.82 * t, side * (0.85 - 0.44 * math.sin(t * math.pi)), 0.385) for t in [i / 20 for i in range(21)]]
        ribbon("Gold_Upper_Arc_%s" % side, pts, [0.045 + 0.015 * math.sin(i * math.pi / 20) for i in range(21)], [p.normalized() for p in pts], MATS["gold"], root, project_radius=0.382)
        lower = [ball_point(-0.13 - 0.86 * t, side * (1.10 - 0.45 * t), 0.385) for t in [i / 20 for i in range(21)]]
        ribbon("Gold_Lower_Arc_%s" % side, lower, 0.035, [p.normalized() for p in lower], MATS["gold"], root, project_radius=0.382)
    for side in (-1, 1):
        for band in (-1, 1):
            lat, lon = band * 0.38, side * 1.58
            points = [ball_point(lat + 0.10, lon - 0.12, 0.386), ball_point(lat + 0.09, lon + 0.12, 0.386), ball_point(lat - 0.12, lon + 0.02, 0.386)]
            mesh("Gold_Triangle_%s_%s" % (side, band), points, [(0, 1, 2)], MATS["gold"], root, solid=0.003)
    for panel in range(8):
        mid = (panel + 0.5) * TAU / 8
        for band in (-1, 1):
            for line in range(3):
                lat = band * (0.24 + line * 0.14)
                points = [ball_point(lat, mid - 0.22, 0.383), ball_point(lat + 0.06, mid - 0.11, 0.383), ball_point(lat - 0.07, mid + 0.015, 0.383), ball_point(lat + 0.045, mid + 0.17, 0.383)]
                tube("Engraved_Circuit_%d_%s_%d" % (panel, band, line), points, 0.0025, MATS["seam"], root, 5)
            for bolt in range(2):
                ball_decoration("Hinge_Bolt_%d_%s_%d" % (panel, band, bolt), band * 0.12, mid + (bolt - 0.5) * 0.20, 0.010, MATS["steel"], root)
    # A hand-authored flame medallion in the upper front quadrant.
    center = ball_point(0.61, 0, 0.390)
    normal = center.normalized()
    medallion = empty("Flame_Medallion", root, center)
    medallion.rotation_euler = normal.to_track_quat("Z", "Y").to_euler()
    uv("Medallion_Gold_Rim", (0, 0, 0), (0.097, 0.097, 0.010), MATS["gold"], medallion, 32, 10)
    uv("Medallion_Ivory", (0, 0, 0.008), (0.084, 0.084, 0.010), MATS["white"], medallion, 32, 10)
    flame = [(-0.037, -0.034, 0.020), (-0.056, -0.003, 0.020), (-0.028, 0.045, 0.020), (-0.028, 0.012, 0.020), (0.001, 0.068, 0.020), (0.020, 0.026, 0.020), (0.037, 0.045, 0.020), (0.048, 0.005, 0.020), (0.034, -0.035, 0.020), (0, -0.047, 0.020)]
    mesh("Original_Flame_Icon", flame, [tuple(range(len(flame)))], MATS["red"], medallion, smooth=False, solid=0.002)
    ball_decoration("Lower_Mechanism_Socket", -0.28, -0.28, 0.055, MATS["seam"], root)
    ball_decoration("Lower_Mechanism_Hub", -0.28, -0.28, 0.036, MATS["steel"], root, offset=0.008)
    ball_decoration("Owner_Signal", -0.28, -0.28, 0.018, MATS["owner"], root, offset=0.015)
    return root


def descendants(root):
    return [root] + list(root.children_recursive)


def export(root, path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in descendants(root):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True, export_animations=False, export_yup=True, export_materials="EXPORT", export_extras=True)
    tris = sum(len(o.data.polygons) for o in descendants(root) if o.type == "MESH")
    print("Exported", path, "mesh objects", sum(o.type == "MESH" for o in descendants(root)), "base faces", tris)


def look_at(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat("-Z", "Y").to_euler()


def area(name, pos, energy, color, size, target):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = pos
    look_at(obj, target)
    return obj


def render(root, other, filename, ball=False, fast=False, front=False):
    for obj in descendants(other):
        obj.hide_render = True
    for obj in descendants(root):
        obj.hide_render = False
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16 if fast else 80
    # Debian's Blender build lacks OpenImageDenoise; CPU samples remain portable.
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 700 if fast else 1100
    scene.render.resolution_y = 640 if fast else 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.color = (0.055, 0.065, 0.085)
    scene.view_settings.view_transform = "AgX"
    camera_data = bpy.data.cameras.new("Preview_Camera")
    camera = bpy.data.objects.new("Preview_Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    target = (0, 0.18, 0.98) if not ball else (0, 0, 0)
    camera.location = (4.3, 7.0, 3.1) if not ball else (1.5, -2.7, 1.20)
    if front and not ball:
        camera.location = (4.3, -7.0, 3.1)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.5 if not ball else 1.08
    look_at(camera, target)
    scene.camera = camera
    lights = [area("Warm_Key", (-3.4, -4.8, 5.8), 720, (1.0, 0.91, 0.80), 4, target), area("Cool_Fill", (3.8, -1.5, 3.0), 500, (0.66, 0.81, 1.0), 3, target), area("Golden_Rim", (1.0, 3.5, 4.8), 1100, (1.0, 0.75, 0.43), 3, target)]
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.02 if not ball else -0.425))
    ground = bpy.context.object
    ground.name = "Preview_Ground"
    ground.data.materials.append(material("Preview_Ground_Material", "192533", 0.12, 0.42))
    scene.render.filepath = str(PREVIEWS / filename)
    bpy.ops.render.render(write_still=True)
    for obj in lights + [camera, ground]:
        bpy.data.objects.remove(obj, do_unlink=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--preview-fast", action="store_true")
    options = parser.parse_args(args)
    dragon = build_dragon()
    ball = build_ball()
    export(dragon, ASSETS / "dragonoid.glb")
    export(ball, ASSETS / "dragonoid_ball.glb")
    if options.render or options.preview_fast:
        render(dragon, ball, "dragonoid-open-0.5.png", fast=options.preview_fast)
        render(dragon, ball, "dragonoid-open-front-0.5.png", fast=options.preview_fast, front=True)
        render(ball, dragon, "dragonoid-ball-0.5.png", ball=True, fast=options.preview_fast)
    print("Original Dragonoid assets ready")


if __name__ == "__main__":
    main()
